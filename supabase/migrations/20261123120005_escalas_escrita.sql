-- Escalas: criar, editar, vagas, avisos, publicar e cancelar (FR-005 a FR-018).
-- Contrato: specs/003-escalas-ministerios/contracts/banco-rpc.md
--
-- Erros levantados (a mensagem é o código; o app traduz para português):
--   sem_permissao, nao_encontrado, ministerio_inativo, evento_invalido, data_passada,
--   escala_somente_leitura, escala_cancelada, escala_sem_vagas, funcao_invalida,
--   nao_participante, limite_vagas.
-- Toda função que altera uma escala a TRAVA antes (exigir_gestor_escala): duas alterações
-- simultâneas na mesma escala acontecem uma depois da outra, nunca misturadas.

-- Pedidos de troca pendentes de uma escala (ou só de uma vaga) perdem efeito. Usada quando a escala
-- é cancelada, a data/horário muda, ou a pessoa da vaga muda (FR-013, FR-015, FR-032).
create function public.encerrar_pedidos_pendentes(p_escala uuid, p_vaga uuid default null)
returns void
language sql
security definer
set search_path = public
as $$
  update public.pedidos_troca
     set situacao = 'sem_efeito', decidido_em = now()
   where escala_id = p_escala
     and (p_vaga is null or vaga_id = p_vaga)
     and situacao in ('aguardando_indicada', 'aguardando_lider');
$$;

-- Quando alguém deixa de ocupar qualquer vaga da escala, a resposta dela some junto: só existe
-- resposta para quem está escalado (data-model.md, tabela respostas_escala).
create function public.soltar_pessoa_da_escala(p_escala uuid, p_perfil uuid)
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.respostas_escala r
   where r.escala_id = p_escala
     and r.perfil_id = p_perfil
     and not exists (
       select 1 from public.vagas_escala v where v.escala_id = p_escala and v.perfil_id = p_perfil
     );
$$;
revoke execute on function public.encerrar_pedidos_pendentes(uuid, uuid) from public, anon, authenticated;
revoke execute on function public.soltar_pessoa_da_escala(uuid, uuid) from public, anon, authenticated;

-- Valida os textos de uma escala; qualquer campo fora das regras vira evento_invalido.
create function public.validar_dados_escala(p_evento text, p_data date, p_horario time, p_observacao text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_evento text := btrim(coalesce(p_evento, ''));
begin
  if char_length(v_evento) not between 2 and 80
     or p_data is null
     or p_horario is null
     or char_length(coalesce(p_observacao, '')) > 300 then
    raise exception 'evento_invalido';
  end if;
  return v_evento;
end;
$$;
revoke execute on function public.validar_dados_escala(text, date, time, text) from public, anon, authenticated;

-- Cria a escala como rascunho. A data não pode ser anterior a hoje (FR-007).
create function public.criar_escala(
  p_ministerio uuid, p_evento text, p_data date, p_horario time, p_observacao text default ''
)
returns public.escalas
language plpgsql
security definer
set search_path = public
as $$
declare
  v_evento text;
  v_escala public.escalas;
begin
  perform public.exigir_gestor_ministerio(p_ministerio);
  v_evento := public.validar_dados_escala(p_evento, p_data, p_horario, p_observacao);
  if p_data < public.hoje_sp() then
    raise exception 'data_passada';
  end if;
  insert into public.escalas (ministerio_id, evento, data, horario, observacao, criada_por)
  values (p_ministerio, v_evento, p_data, p_horario, coalesce(p_observacao, ''), auth.uid())
  returning * into v_escala;
  return v_escala;
end;
$$;

-- Edita a escala. Se data ou horário mudam em escala PUBLICADA, todas as respostas voltam a
-- "pendente" (apagadas) e os pedidos de troca pendentes perdem efeito (FR-015). Mudar só o nome do
-- evento ou a observação não mexe em respostas nem pedidos.
create function public.editar_escala(
  p_escala uuid, p_evento text, p_data date, p_horario time, p_observacao text
)
returns public.escalas
language plpgsql
security definer
set search_path = public
as $$
declare
  v_atual public.escalas;
  v_evento text;
  v_escala public.escalas;
begin
  v_atual := public.exigir_gestor_escala(p_escala);
  perform public.exigir_escala_editavel(v_atual);
  v_evento := public.validar_dados_escala(p_evento, p_data, p_horario, p_observacao);
  if p_data < public.hoje_sp() then
    raise exception 'data_passada';
  end if;

  update public.escalas
     set evento = v_evento, data = p_data, horario = p_horario,
         observacao = coalesce(p_observacao, ''), atualizada_em = now()
   where id = p_escala
  returning * into v_escala;

  if v_atual.situacao = 'publicada' and (v_atual.data <> p_data or v_atual.horario <> p_horario) then
    delete from public.respostas_escala where escala_id = p_escala;
    perform public.encerrar_pedidos_pendentes(p_escala);
  end if;
  return v_escala;
end;
$$;

-- Avisos que NÃO bloqueiam (FR-017, FR-018): o líder pode continuar. Interna: quem decide o que
-- fazer com eles é `salvar_vaga` (e, na troca, `decidir_troca_lider`).
--  * outro_ministerio: a pessoa já CONFIRMOU uma escala PUBLICADA de outro ministério no mesmo dia.
--    O horário é só informado, nunca comparado. Rascunho, cancelada, resposta pendente ou recusada e
--    escalas do mesmo ministério não contam. Quem já ocupa outra vaga NESTA escala não gera o aviso de
--    novo (o líder já o viu ao escalar a primeira).
--  * sem_aptidao: a pessoa não está apta para a função (sem nenhuma aptidão = não apta).
create function public.avisos_para_vaga(p_escala uuid, p_perfil uuid, p_funcao uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_escala public.escalas;
  v_avisos jsonb := '[]'::jsonb;
  v_outra record;
  v_funcao text;
begin
  select * into v_escala from public.escalas where id = p_escala;

  if not exists (
    select 1 from public.vagas_escala v where v.escala_id = p_escala and v.perfil_id = p_perfil
  ) then
    for v_outra in
      select distinct m.nome as ministerio, e.evento, e.horario
        from public.escalas e
        join public.ministerios m on m.id = e.ministerio_id
        join public.vagas_escala v on v.escala_id = e.id and v.perfil_id = p_perfil
        join public.respostas_escala r on r.escala_id = e.id and r.perfil_id = p_perfil and r.resposta = 'confirmado'
       where e.ministerio_id <> v_escala.ministerio_id
         and e.data = v_escala.data
         and e.situacao = 'publicada'
       order by e.horario, m.nome, e.evento
    loop
      v_avisos := v_avisos || jsonb_build_array(jsonb_build_object(
        'tipo', 'outro_ministerio',
        'ministerio', v_outra.ministerio,
        'evento', v_outra.evento,
        'horario', to_char(v_outra.horario, 'HH24:MI')
      ));
    end loop;
  end if;

  if not exists (
    select 1 from public.aptidoes a where a.funcao_id = p_funcao and a.perfil_id = p_perfil
  ) then
    select nome into v_funcao from public.funcoes_ministerio where id = p_funcao;
    v_avisos := v_avisos || jsonb_build_array(jsonb_build_object('tipo', 'sem_aptidao', 'funcao', v_funcao));
  end if;

  return v_avisos;
end;
$$;
revoke execute on function public.avisos_para_vaga(uuid, uuid, uuid) from public, anon, authenticated;

-- Cria (p_vaga nulo) ou altera uma vaga. `p_perfil` nulo = vaga em aberto.
-- Retorno: { "salvo": true, "avisos": [...], "vaga": {...} }, ou, quando há avisos e o líder ainda
-- não confirmou (`p_ciente` falso), { "salvo": false, "avisos": [...] } SEM gravar nada
-- (research.md, decisão 5). Os avisos só são calculados quando a pessoa ou a função mudam.
-- Em escala publicada, trocar a pessoa de uma vaga: a nova fica pendente (sem resposta), a anterior
-- deixa de estar escalada (e perde a resposta se não tiver outra vaga) e o pedido de troca pendente
-- dessa vaga perde efeito (FR-014, FR-032).
create function public.salvar_vaga(
  p_escala uuid, p_vaga uuid, p_funcao uuid, p_rotulo text, p_perfil uuid, p_ciente boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_escala public.escalas;
  v_antiga public.vagas_escala;
  v_vaga public.vagas_escala;
  v_rotulo text := btrim(coalesce(p_rotulo, ''));
  v_funcao uuid;
  v_mudou_funcao boolean;
  v_mudou_pessoa boolean;
  v_avisos jsonb := '[]'::jsonb;
begin
  v_escala := public.exigir_gestor_escala(p_escala);
  perform public.exigir_escala_editavel(v_escala);

  if char_length(v_rotulo) > 40 then
    raise exception 'evento_invalido';
  end if;

  if p_vaga is null then
    if (select count(*) from public.vagas_escala where escala_id = p_escala) >= 50 then
      raise exception 'limite_vagas';
    end if;
    v_funcao := p_funcao;
    v_mudou_funcao := true;
    v_mudou_pessoa := p_perfil is not null;
  else
    select * into v_antiga from public.vagas_escala where id = p_vaga and escala_id = p_escala for update;
    if not found then
      raise exception 'nao_encontrado';
    end if;
    v_funcao := coalesce(p_funcao, v_antiga.funcao_id);
    v_mudou_funcao := v_funcao <> v_antiga.funcao_id;
    v_mudou_pessoa := p_perfil is distinct from v_antiga.perfil_id;
  end if;

  -- Vaga nova (ou troca de função) só com função ATIVA deste ministério (FR-003). Uma vaga que já
  -- existe com função depois desativada continua editável, desde que a função não mude.
  if v_mudou_funcao and not exists (
    select 1 from public.funcoes_ministerio f
     where f.id = v_funcao and f.ministerio_id = v_escala.ministerio_id and f.ativa
  ) then
    raise exception 'funcao_invalida';
  end if;

  -- Só participantes do ministério, com conta aprovada, podem ser escalados (FR-009).
  if v_mudou_pessoa and p_perfil is not null and not exists (
    select 1
      from public.participacoes_ministerio pm
      join public.perfis p on p.id = pm.perfil_id and p.situacao = 'aprovado'
     where pm.ministerio_id = v_escala.ministerio_id and pm.perfil_id = p_perfil
  ) then
    raise exception 'nao_participante';
  end if;

  if p_perfil is not null and (v_mudou_pessoa or v_mudou_funcao) then
    v_avisos := public.avisos_para_vaga(p_escala, p_perfil, v_funcao);
    if jsonb_array_length(v_avisos) > 0 and not coalesce(p_ciente, false) then
      return jsonb_build_object('salvo', false, 'avisos', v_avisos);
    end if;
  end if;

  if p_vaga is null then
    insert into public.vagas_escala (escala_id, funcao_id, rotulo, perfil_id, ordem)
    values (
      p_escala, v_funcao, v_rotulo, p_perfil,
      coalesce((select max(ordem) from public.vagas_escala where escala_id = p_escala), 0) + 1
    )
    returning * into v_vaga;
  else
    update public.vagas_escala
       set funcao_id = v_funcao, rotulo = v_rotulo, perfil_id = p_perfil
     where id = p_vaga
    returning * into v_vaga;

    if v_mudou_pessoa then
      perform public.encerrar_pedidos_pendentes(p_escala, p_vaga);
      if v_antiga.perfil_id is not null then
        perform public.soltar_pessoa_da_escala(p_escala, v_antiga.perfil_id);
      end if;
    end if;
  end if;

  update public.escalas set atualizada_em = now() where id = p_escala;
  return jsonb_build_object('salvo', true, 'avisos', v_avisos, 'vaga', to_jsonb(v_vaga));
end;
$$;

-- Remove uma vaga. Os pedidos de troca dela somem junto (cascata) e a pessoa, se ficar sem vagas
-- na escala, perde a resposta.
create function public.remover_vaga(p_vaga uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_escala_id uuid;
  v_escala public.escalas;
  v_vaga public.vagas_escala;
begin
  select escala_id into v_escala_id from public.vagas_escala where id = p_vaga;
  if not found then
    -- Mesma regra de não revelar o que existe: administrador é avisado, os demais veem sem_permissao.
    raise exception using message =
      case when coalesce(public.papel_aprovado_atual() = 'administrador', false)
           then 'nao_encontrado' else 'sem_permissao' end;
  end if;

  v_escala := public.exigir_gestor_escala(v_escala_id);
  perform public.exigir_escala_editavel(v_escala);

  delete from public.vagas_escala where id = p_vaga returning * into v_vaga;
  if v_vaga.perfil_id is not null then
    perform public.soltar_pessoa_da_escala(v_escala_id, v_vaga.perfil_id);
  end if;
  update public.escalas set atualizada_em = now() where id = v_escala_id;
end;
$$;

-- Publica o rascunho. Pode ter vagas em aberto (aparecem como "em aberto"), mas não pode ser uma
-- escala sem nenhuma vaga (FR-011). Idempotente: publicar uma já publicada devolve o registro.
create function public.publicar_escala(p_escala uuid)
returns public.escalas
language plpgsql
security definer
set search_path = public
as $$
declare
  v_escala public.escalas;
begin
  v_escala := public.exigir_gestor_escala(p_escala);
  perform public.exigir_escala_editavel(v_escala);
  if v_escala.situacao = 'publicada' then
    return v_escala;
  end if;
  if not exists (select 1 from public.vagas_escala where escala_id = p_escala) then
    raise exception 'escala_sem_vagas';
  end if;
  update public.escalas set situacao = 'publicada', atualizada_em = now()
   where id = p_escala returning * into v_escala;
  return v_escala;
end;
$$;

-- Cancela a escala: ela NÃO é apagada (continua visível a quem estava escalado, marcada como
-- cancelada). As respostas ficam gravadas, mas perdem efeito (as telas não deixam responder), e os
-- pedidos de troca pendentes perdem efeito (FR-013). Idempotente.
create function public.cancelar_escala(p_escala uuid)
returns public.escalas
language plpgsql
security definer
set search_path = public
as $$
declare
  v_escala public.escalas;
begin
  v_escala := public.exigir_gestor_escala(p_escala);
  if v_escala.situacao = 'cancelada' then
    return v_escala;
  end if;
  if public.hoje_sp() > v_escala.data then
    raise exception 'escala_somente_leitura';
  end if;
  update public.escalas
     set situacao = 'cancelada', cancelada_em = now(), atualizada_em = now()
   where id = p_escala returning * into v_escala;
  perform public.encerrar_pedidos_pendentes(p_escala);
  return v_escala;
end;
$$;

-- Pessoas que o líder pode escalar: participantes aprovados do ministério, com as funções ativas
-- em que são aptas. Só nome (nunca email).
create function public.listar_candidatos_escala(p_escala uuid)
returns table (id uuid, nome text, apta_para jsonb)
language plpgsql
stable
security definer
set search_path = public
as $$
#variable_conflict use_column
declare
  v_ministerio uuid;
begin
  if auth.uid() is null then
    return;
  end if;
  select ministerio_id into v_ministerio from public.escalas where escalas.id = p_escala;
  if not found or not public.eh_gestor_de(v_ministerio) then
    return;
  end if;
  return query
    select p.id, p.nome,
           coalesce((
             select jsonb_agg(a.funcao_id)
               from public.aptidoes a
               join public.funcoes_ministerio f on f.id = a.funcao_id and f.ministerio_id = v_ministerio and f.ativa
              where a.perfil_id = p.id
           ), '[]'::jsonb)
      from public.participacoes_ministerio pm
      join public.perfis p on p.id = pm.perfil_id and p.situacao = 'aprovado'
     where pm.ministerio_id = v_ministerio
     order by p.nome;
end;
$$;

revoke execute on function public.criar_escala(uuid, text, date, time, text) from public, anon;
grant execute on function public.criar_escala(uuid, text, date, time, text) to authenticated;
revoke execute on function public.editar_escala(uuid, text, date, time, text) from public, anon;
grant execute on function public.editar_escala(uuid, text, date, time, text) to authenticated;
revoke execute on function public.salvar_vaga(uuid, uuid, uuid, text, uuid, boolean) from public, anon;
grant execute on function public.salvar_vaga(uuid, uuid, uuid, text, uuid, boolean) to authenticated;
revoke execute on function public.remover_vaga(uuid) from public, anon;
grant execute on function public.remover_vaga(uuid) to authenticated;
revoke execute on function public.publicar_escala(uuid) from public, anon;
grant execute on function public.publicar_escala(uuid) to authenticated;
revoke execute on function public.cancelar_escala(uuid) from public, anon;
grant execute on function public.cancelar_escala(uuid) to authenticated;
revoke execute on function public.listar_candidatos_escala(uuid) from public, anon;
grant execute on function public.listar_candidatos_escala(uuid) to authenticated;
