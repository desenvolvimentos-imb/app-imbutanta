-- Pedidos de troca de vaga (FR-029 a FR-036).
-- Fluxo: 1) a pessoa indicada aceita ou recusa; 2) se aceitar, o líder (ou administrador) aprova ou
-- recusa; 3) só depois da aprovação a vaga passa para a indicada, com resposta "confirmado".
-- Enquanto o pedido está pendente, nada muda na escala. Toda função trava a escala antes de decidir
-- (research.md, decisão 4), e a aprovação é tudo ou nada (FR-035).
--
-- Erros levantados: sem_permissao, nao_encontrado, nao_escalado, escala_cancelada,
--   escala_nao_publicada, evento_iniciado, ministerio_inativo, troca_invalida, ja_escalada,
--   troca_duplicada, conflito_troca.

-- A situação "de verdade" de um pedido: um pedido ainda pendente de uma escala que foi cancelada
-- ou já começou vale como "sem efeito", mesmo sem ninguém ter atualizado a linha (o tempo é
-- calculado na leitura, sem tarefa agendada; research.md, decisão 2).
create function public.situacao_efetiva_troca(p_situacao public.situacao_troca, p_escala public.escalas)
returns public.situacao_troca
language sql
stable
set search_path = public
as $$
  select case
    when p_situacao in ('aguardando_indicada', 'aguardando_lider')
         and (p_escala.situacao <> 'publicada'
              or public.agora_sp() >= public.inicio_da_escala(p_escala.data, p_escala.horario))
    then 'sem_efeito'::public.situacao_troca
    else p_situacao
  end;
$$;
revoke execute on function public.situacao_efetiva_troca(public.situacao_troca, public.escalas) from public, anon, authenticated;

-- Quem pode ser indicada: participante do ministério com conta aprovada.
create function public.eh_participante_aprovado(p_ministerio uuid, p_perfil uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.participacoes_ministerio pm
      join public.perfis p on p.id = pm.perfil_id and p.situacao = 'aprovado'
     where pm.ministerio_id = p_ministerio and pm.perfil_id = p_perfil
  );
$$;
revoke execute on function public.eh_participante_aprovado(uuid, uuid) from public, anon, authenticated;

-- Confere que a escala aceita ações de troca agora: publicada e ainda não iniciada.
create function public.exigir_escala_aberta_para_troca(p_escala public.escalas)
returns void
language plpgsql
stable
set search_path = public
as $$
begin
  if p_escala.situacao = 'cancelada' then
    raise exception 'escala_cancelada';
  end if;
  if p_escala.situacao <> 'publicada' then
    raise exception 'escala_nao_publicada';
  end if;
  if public.agora_sp() >= public.inicio_da_escala(p_escala.data, p_escala.horario) then
    raise exception 'evento_iniciado';
  end if;
end;
$$;
revoke execute on function public.exigir_escala_aberta_para_troca(public.escalas) from public, anon, authenticated;

-- A pessoa que ocupa a vaga pede que outra participante a assuma. Nada muda na escala (FR-031).
create function public.pedir_troca(p_vaga uuid, p_indicada uuid)
returns public.pedidos_troca
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_vaga public.vagas_escala;
  v_escala public.escalas;
  v_pedido public.pedidos_troca;
begin
  if v_uid is null or public.papel_aprovado_atual() is null then
    raise exception 'sem_permissao';
  end if;

  select * into v_vaga from public.vagas_escala where id = p_vaga;
  if not found or v_vaga.perfil_id is distinct from v_uid then
    raise exception 'nao_escalado';  -- não revela vagas alheias
  end if;

  select * into v_escala from public.escalas where id = v_vaga.escala_id for update;
  perform public.exigir_escala_aberta_para_troca(v_escala);
  if not exists (select 1 from public.ministerios m where m.id = v_escala.ministerio_id and m.ativo) then
    raise exception 'ministerio_inativo';
  end if;
  -- A vaga pode ter sido trocada pelo líder enquanto esperava a trava.
  if not exists (select 1 from public.vagas_escala v where v.id = p_vaga and v.perfil_id = v_uid) then
    raise exception 'nao_escalado';
  end if;

  if p_indicada is null or p_indicada = v_uid
     or not public.eh_participante_aprovado(v_escala.ministerio_id, p_indicada) then
    raise exception 'troca_invalida';
  end if;
  if exists (select 1 from public.vagas_escala v where v.escala_id = v_escala.id and v.perfil_id = p_indicada) then
    raise exception 'ja_escalada';
  end if;

  begin
    insert into public.pedidos_troca (vaga_id, escala_id, solicitante_id, indicada_id)
    values (p_vaga, v_escala.id, v_uid, p_indicada)
    returning * into v_pedido;
  exception when unique_violation then
    raise exception 'troca_duplicada';
  end;
  return v_pedido;
end;
$$;

-- A pessoa indicada aceita ou recusa o pedido (passo 1). Se aceitar, ele passa a aguardar o líder.
-- Se, no meio do caminho, a indicada já foi escalada nesta escala por outro caminho (ou quem pediu
-- já não ocupa a vaga), o pedido perde efeito e é devolvido como "sem_efeito".
create function public.responder_pedido_troca(p_pedido uuid, p_aceita boolean)
returns public.pedidos_troca
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_pedido public.pedidos_troca;
  v_escala public.escalas;
begin
  if v_uid is null or public.papel_aprovado_atual() is null then
    raise exception 'sem_permissao';
  end if;
  if p_aceita is null then
    raise exception 'transicao_invalida';
  end if;

  select * into v_pedido from public.pedidos_troca where id = p_pedido;
  if not found or v_pedido.indicada_id <> v_uid then
    raise exception 'sem_permissao';
  end if;

  select * into v_escala from public.escalas where id = v_pedido.escala_id for update;
  select * into v_pedido from public.pedidos_troca where id = p_pedido for update;
  if v_pedido.situacao <> 'aguardando_indicada' then
    raise exception 'conflito_troca';
  end if;
  perform public.exigir_escala_aberta_para_troca(v_escala);

  if exists (select 1 from public.vagas_escala v where v.escala_id = v_escala.id and v.perfil_id = v_uid)
     or not exists (select 1 from public.vagas_escala v where v.id = v_pedido.vaga_id and v.perfil_id = v_pedido.solicitante_id) then
    update public.pedidos_troca set situacao = 'sem_efeito', decidido_em = now()
     where id = p_pedido returning * into v_pedido;
    return v_pedido;
  end if;

  if p_aceita then
    update public.pedidos_troca set situacao = 'aguardando_lider', respondido_em = now()
     where id = p_pedido returning * into v_pedido;
  else
    update public.pedidos_troca set situacao = 'recusado_indicada', respondido_em = now(), decidido_em = now()
     where id = p_pedido returning * into v_pedido;
  end if;
  return v_pedido;
end;
$$;

-- O líder (ou administrador) aprova ou recusa o pedido já aceito pela indicada (passo 2).
-- Ao aprovar, devolve avisos (indicada sem aptidão para a função; já confirmada em outro ministério
-- no mesmo dia) e só grava com `p_ciente` verdadeiro (FR-034). A aprovação é atômica (FR-035):
-- a vaga passa por inteiro à indicada, com resposta "confirmado", ou nada muda. Quem pediu deixa só
-- ESSA vaga (as outras dela na escala permanecem; sem nenhuma, a resposta dela some).
create function public.decidir_troca_lider(p_pedido uuid, p_aprova boolean, p_ciente boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pedido public.pedidos_troca;
  v_escala public.escalas;
  v_vaga public.vagas_escala;
  v_avisos jsonb := '[]'::jsonb;
begin
  if auth.uid() is null then
    raise exception 'sem_permissao';
  end if;
  if p_aprova is null then
    raise exception 'transicao_invalida';
  end if;

  select * into v_pedido from public.pedidos_troca where id = p_pedido;
  if not found then
    raise exception using message =
      case when coalesce(public.papel_aprovado_atual() = 'administrador', false)
           then 'nao_encontrado' else 'sem_permissao' end;
  end if;

  -- Confere que é gestor do ministério (antes da trava) e trava a escala.
  v_escala := public.exigir_gestor_escala(v_pedido.escala_id);
  select * into v_pedido from public.pedidos_troca where id = p_pedido for update;
  if v_pedido.situacao <> 'aguardando_lider' then
    raise exception 'conflito_troca';
  end if;
  perform public.exigir_escala_aberta_para_troca(v_escala);

  if not p_aprova then
    update public.pedidos_troca
       set situacao = 'recusado_lider', decidido_por = auth.uid(), decidido_em = now()
     where id = p_pedido returning * into v_pedido;
    return jsonb_build_object('decidido', true, 'avisos', v_avisos, 'pedido', to_jsonb(v_pedido));
  end if;

  select * into v_vaga from public.vagas_escala where id = v_pedido.vaga_id for update;
  if not found or v_vaga.perfil_id is distinct from v_pedido.solicitante_id then
    raise exception 'conflito_troca';  -- a vaga mudou: o pedido deveria ter perdido efeito
  end if;
  if not public.eh_participante_aprovado(v_escala.ministerio_id, v_pedido.indicada_id) then
    raise exception 'troca_invalida';
  end if;
  if exists (select 1 from public.vagas_escala v where v.escala_id = v_escala.id and v.perfil_id = v_pedido.indicada_id) then
    raise exception 'ja_escalada';
  end if;

  v_avisos := public.avisos_para_vaga(v_escala.id, v_pedido.indicada_id, v_vaga.funcao_id);
  if jsonb_array_length(v_avisos) > 0 and not coalesce(p_ciente, false) then
    return jsonb_build_object('decidido', false, 'avisos', v_avisos);
  end if;

  -- A troca em si (tudo na mesma transação).
  update public.vagas_escala set perfil_id = v_pedido.indicada_id where id = v_vaga.id;

  insert into public.respostas_escala (escala_id, perfil_id, resposta, motivo)
  values (v_escala.id, v_pedido.indicada_id, 'confirmado', '')
  on conflict (escala_id, perfil_id)
  do update set resposta = 'confirmado', motivo = '', respondida_em = now();

  perform public.soltar_pessoa_da_escala(v_escala.id, v_pedido.solicitante_id);

  update public.pedidos_troca
     set situacao = 'aprovado', decidido_por = auth.uid(), decidido_em = now()
   where id = p_pedido returning * into v_pedido;

  -- Outros pedidos pendentes que dependiam de a indicada ainda não estar escalada perdem efeito.
  update public.pedidos_troca
     set situacao = 'sem_efeito', decidido_em = now()
   where escala_id = v_escala.id
     and id <> p_pedido
     and situacao in ('aguardando_indicada', 'aguardando_lider')
     and (indicada_id = v_pedido.indicada_id or vaga_id = v_vaga.id);

  update public.escalas set atualizada_em = now() where id = v_escala.id;
  return jsonb_build_object('decidido', true, 'avisos', v_avisos, 'pedido', to_jsonb(v_pedido));
end;
$$;

-- Quem pediu e o líder (ou administrador) podem cancelar a qualquer momento antes da aprovação.
create function public.cancelar_pedido_troca(p_pedido uuid)
returns public.pedidos_troca
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_pedido public.pedidos_troca;
  v_ministerio uuid;
begin
  if v_uid is null or public.papel_aprovado_atual() is null then
    raise exception 'sem_permissao';
  end if;

  select * into v_pedido from public.pedidos_troca where id = p_pedido;
  if not found then
    raise exception 'sem_permissao';
  end if;
  select ministerio_id into v_ministerio from public.escalas where id = v_pedido.escala_id;
  if not (v_pedido.solicitante_id = v_uid or public.eh_gestor_de(v_ministerio)) then
    raise exception 'sem_permissao';
  end if;

  perform 1 from public.escalas where id = v_pedido.escala_id for update;
  select * into v_pedido from public.pedidos_troca where id = p_pedido for update;
  if v_pedido.situacao not in ('aguardando_indicada', 'aguardando_lider') then
    raise exception 'conflito_troca';
  end if;

  update public.pedidos_troca
     set situacao = 'cancelado', decidido_por = v_uid, decidido_em = now()
   where id = p_pedido returning * into v_pedido;
  return v_pedido;
end;
$$;

-- "Pedidos de troca": os que a pessoa fez, os que recebeu e, para quem gere ministérios, os que
-- aguardam a sua aprovação. Nunca devolve email. `situacao` é a situação EFETIVA (pedido pendente de
-- escala cancelada ou já iniciada aparece como sem_efeito). As colunas `pode_*` dizem o que a pessoa
-- pode fazer agora, para a tela só mostrar os botões certos.
create function public.listar_pedidos_troca()
returns table (
  id uuid, papel_na_lista text, situacao text,
  ministerio_id uuid, ministerio text, escala_id uuid, evento text, data date, horario time,
  vaga_id uuid, funcao text, rotulo text,
  solicitante_id uuid, solicitante text, indicada_id uuid, indicada text,
  criado_em timestamptz, pode_responder boolean, pode_decidir boolean, pode_cancelar boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
#variable_conflict use_column
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null or public.papel_aprovado_atual() is null then
    return;
  end if;
  return query
    with base as (
      select t.id as pid, t.solicitante_id as sol_id, t.indicada_id as ind_id, t.vaga_id as vid, t.criado_em as criado,
             e.id as eid, e.ministerio_id as mid, e.evento as nome_evento, e.data as dia, e.horario as hora,
             m.nome as nome_ministerio, f.nome as nome_funcao, v.rotulo as rotulo_vaga,
             ps.nome as nome_solicitante, pi.nome as nome_indicada,
             public.situacao_efetiva_troca(t.situacao, e) as efetiva,
             public.eh_gestor_de(e.ministerio_id) as gestor
        from public.pedidos_troca t
        join public.escalas e on e.id = t.escala_id
        join public.ministerios m on m.id = e.ministerio_id
        join public.vagas_escala v on v.id = t.vaga_id
        join public.funcoes_ministerio f on f.id = v.funcao_id
        join public.perfis ps on ps.id = t.solicitante_id
        join public.perfis pi on pi.id = t.indicada_id
    )
    select b.pid,
           case when b.sol_id = v_uid then 'solicitante'
                when b.ind_id = v_uid then 'indicada'
                else 'gestor' end,
           b.efetiva::text,
           b.mid, b.nome_ministerio, b.eid, b.nome_evento, b.dia, b.hora,
           b.vid, b.nome_funcao, b.rotulo_vaga,
           b.sol_id, b.nome_solicitante, b.ind_id, b.nome_indicada,
           b.criado,
           b.ind_id = v_uid and b.efetiva = 'aguardando_indicada',
           b.gestor and b.efetiva = 'aguardando_lider',
           (b.sol_id = v_uid or b.gestor) and b.efetiva in ('aguardando_indicada', 'aguardando_lider')
      from base b
     where b.sol_id = v_uid
        or b.ind_id = v_uid
        or (b.gestor and b.efetiva = 'aguardando_lider')
     order by b.criado desc;
end;
$$;

-- Pedidos pendentes de UMA escala que a pessoa pode ver: os próprios (feitos ou recebidos) e, para o
-- gestor, todos. A tela da escala usa para mostrar "pedido de troca em andamento" na vaga.
create function public.listar_pedidos_da_escala(p_escala uuid)
returns table (id uuid, vaga_id uuid, situacao text, solicitante_id uuid, solicitante text, indicada_id uuid, indicada text)
language plpgsql
stable
security definer
set search_path = public
as $$
#variable_conflict use_column
declare
  v_uid uuid := auth.uid();
  v_escala public.escalas;
  v_gestor boolean;
begin
  if v_uid is null or public.papel_aprovado_atual() is null then
    return;
  end if;
  select * into v_escala from public.escalas where escalas.id = p_escala;
  if not found then
    return;
  end if;
  v_gestor := public.eh_gestor_de(v_escala.ministerio_id);
  return query
    select t.id, t.vaga_id, public.situacao_efetiva_troca(t.situacao, v_escala)::text,
           t.solicitante_id, ps.nome, t.indicada_id, pi.nome
      from public.pedidos_troca t
      join public.perfis ps on ps.id = t.solicitante_id
      join public.perfis pi on pi.id = t.indicada_id
     where t.escala_id = p_escala
       and t.situacao in ('aguardando_indicada', 'aguardando_lider')
       and public.situacao_efetiva_troca(t.situacao, v_escala) in ('aguardando_indicada', 'aguardando_lider')
       and (v_gestor or t.solicitante_id = v_uid or t.indicada_id = v_uid)
     order by t.criado_em;
end;
$$;

-- Quem pode ser indicada para a vaga: participantes do ministério, aprovadas, ainda não escaladas
-- nesta escala e diferentes de quem pede. Só nome (nunca email). Vazio se a vaga não é de quem chama
-- ou se a escala não aceita mais pedidos.
create function public.listar_candidatas_troca(p_vaga uuid)
returns table (id uuid, nome text)
language plpgsql
stable
security definer
set search_path = public
as $$
#variable_conflict use_column
declare
  v_uid uuid := auth.uid();
  v_vaga public.vagas_escala;
  v_escala public.escalas;
begin
  if v_uid is null or public.papel_aprovado_atual() is null then
    return;
  end if;
  select * into v_vaga from public.vagas_escala where vagas_escala.id = p_vaga;
  if not found or v_vaga.perfil_id is distinct from v_uid then
    return;
  end if;
  select * into v_escala from public.escalas where escalas.id = v_vaga.escala_id;
  if v_escala.situacao <> 'publicada'
     or public.agora_sp() >= public.inicio_da_escala(v_escala.data, v_escala.horario) then
    return;
  end if;
  return query
    select p.id, p.nome
      from public.participacoes_ministerio pm
      join public.perfis p on p.id = pm.perfil_id and p.situacao = 'aprovado'
     where pm.ministerio_id = v_escala.ministerio_id
       and p.id <> v_uid
       and not exists (select 1 from public.vagas_escala v where v.escala_id = v_escala.id and v.perfil_id = p.id)
     order by p.nome;
end;
$$;

-- Contadores da tela inicial: agora com os pedidos de troca (recebidos e a aprovar).
create or replace function public.contar_pendencias_escala()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_sem_resposta integer := 0;
  v_recebidas integer := 0;
  v_a_aprovar integer := 0;
begin
  if v_uid is not null and public.papel_aprovado_atual() is not null then
    select count(*)::integer into v_sem_resposta
      from public.escalas e
     where e.situacao = 'publicada'
       and public.agora_sp() < public.inicio_da_escala(e.data, e.horario)
       and exists (select 1 from public.vagas_escala v where v.escala_id = e.id and v.perfil_id = v_uid)
       and not exists (select 1 from public.respostas_escala r where r.escala_id = e.id and r.perfil_id = v_uid);

    select count(*) filter (where t.situacao = 'aguardando_indicada' and t.indicada_id = v_uid),
           count(*) filter (where t.situacao = 'aguardando_lider' and public.eh_gestor_de(e.ministerio_id))
      into v_recebidas, v_a_aprovar
      from public.pedidos_troca t
      join public.escalas e on e.id = t.escala_id
     where t.situacao in ('aguardando_indicada', 'aguardando_lider')
       and e.situacao = 'publicada'
       and public.agora_sp() < public.inicio_da_escala(e.data, e.horario);
  end if;
  return jsonb_build_object('sem_resposta', v_sem_resposta, 'trocas_recebidas', v_recebidas, 'trocas_para_aprovar', v_a_aprovar);
end;
$$;

revoke execute on function public.pedir_troca(uuid, uuid) from public, anon;
grant execute on function public.pedir_troca(uuid, uuid) to authenticated;
revoke execute on function public.responder_pedido_troca(uuid, boolean) from public, anon;
grant execute on function public.responder_pedido_troca(uuid, boolean) to authenticated;
revoke execute on function public.decidir_troca_lider(uuid, boolean, boolean) from public, anon;
grant execute on function public.decidir_troca_lider(uuid, boolean, boolean) to authenticated;
revoke execute on function public.cancelar_pedido_troca(uuid) from public, anon;
grant execute on function public.cancelar_pedido_troca(uuid) to authenticated;
revoke execute on function public.listar_pedidos_troca() from public, anon;
grant execute on function public.listar_pedidos_troca() to authenticated;
revoke execute on function public.listar_pedidos_da_escala(uuid) from public, anon;
grant execute on function public.listar_pedidos_da_escala(uuid) to authenticated;
revoke execute on function public.listar_candidatas_troca(uuid) from public, anon;
grant execute on function public.listar_candidatas_troca(uuid) to authenticated;
