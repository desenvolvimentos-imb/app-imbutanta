-- Escalas: leitura (FR-012, FR-021 a FR-025). Tudo por funções, nunca pelas tabelas, para que:
--  * os nomes das pessoas saiam sem abrir `perfis` (nunca email);
--  * respostas e motivos de recusa só cheguem ao gestor e à própria pessoa.
-- Quem não pode ver uma escala recebe lista vazia / nulo (não um erro que revele que ela existe).

-- Lista as escalas de um ministério: as próximas (data de hoje em diante) ou as passadas.
--  * gestor (administrador ou líder): todas, inclusive rascunhos, com as contagens de atenção;
--  * participante: as publicadas (e as canceladas em que está escalado), sem respostas dos outros;
--  * quem não participa: nada.
-- `recusadas` e `sem_resposta` só vêm para o gestor (nulo para os demais). "Sem resposta" só conta
-- em escala publicada: rascunho ainda não foi mostrado a ninguém.
create function public.listar_escalas_ministerio(p_ministerio uuid, p_passadas boolean default false)
returns table (
  id uuid, evento text, data date, horario time, situacao public.situacao_escala,
  total_vagas integer, vagas_abertas integer, recusadas integer, sem_resposta integer
)
language plpgsql
stable
security definer
set search_path = public
as $$
#variable_conflict use_column
declare
  v_gestor boolean;
  v_hoje date := public.hoje_sp();
  v_sentido integer := case when coalesce(p_passadas, false) then -1 else 1 end;
begin
  if auth.uid() is null then
    return;
  end if;
  v_gestor := public.eh_gestor_de(p_ministerio);
  if not (v_gestor or public.eh_participante_de(p_ministerio)) then
    return;
  end if;

  return query
    select e.id, e.evento, e.data, e.horario, e.situacao,
           (select count(*)::integer from public.vagas_escala v where v.escala_id = e.id),
           (select count(*)::integer from public.vagas_escala v where v.escala_id = e.id and v.perfil_id is null),
           case when v_gestor then
             (select count(*)::integer
                from public.vagas_escala v
                join public.respostas_escala r on r.escala_id = e.id and r.perfil_id = v.perfil_id and r.resposta = 'recusado'
               where v.escala_id = e.id)
           end,
           case when v_gestor then
             case when e.situacao = 'publicada' then
               (select count(*)::integer
                  from public.vagas_escala v
                 where v.escala_id = e.id and v.perfil_id is not null
                   and not exists (select 1 from public.respostas_escala r where r.escala_id = e.id and r.perfil_id = v.perfil_id))
             else 0 end
           end
      from public.escalas e
     where e.ministerio_id = p_ministerio
       and (case when coalesce(p_passadas, false) then e.data < v_hoje else e.data >= v_hoje end)
       and (
         v_gestor
         or e.situacao = 'publicada'
         or (e.situacao = 'cancelada'
             and exists (select 1 from public.vagas_escala v where v.escala_id = e.id and v.perfil_id = auth.uid()))
       )
     order by (e.data - date '2000-01-01') * v_sentido,
              (extract(epoch from e.horario)::integer) * v_sentido,
              e.evento;
end;
$$;

-- Uma escala completa, em um só retorno (jsonb), para a tela de detalhe. Nulo se a pessoa não pode ver.
-- Visível para: o gestor (qualquer situação); participante (publicada); quem está escalado
-- (publicada ou cancelada, mesmo que tenha saído do ministério depois).
-- Respostas e motivos de recusa: só o gestor recebe os de todos; os demais recebem só a PRÓPRIA.
create function public.ler_escala(p_escala uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_e public.escalas;
  v_m public.ministerios;
  v_gestor boolean;
  v_tem_vaga boolean;
  v_iniciada boolean;
  v_vagas jsonb;
  v_minhas jsonb;
  v_respostas jsonb := null;
  v_minha jsonb := null;
  v_pode_agir boolean;
begin
  if v_uid is null then
    return null;
  end if;
  select * into v_e from public.escalas where id = p_escala;
  if not found then
    return null;
  end if;
  select * into v_m from public.ministerios where id = v_e.ministerio_id;

  v_gestor := public.eh_gestor_de(v_e.ministerio_id);
  v_tem_vaga := exists (select 1 from public.vagas_escala v where v.escala_id = p_escala and v.perfil_id = v_uid);
  if not (
    v_gestor
    or (v_e.situacao = 'publicada' and public.eh_participante_de(v_e.ministerio_id))
    or (v_tem_vaga and v_e.situacao in ('publicada', 'cancelada'))
  ) then
    return null;
  end if;

  v_iniciada := public.agora_sp() >= public.inicio_da_escala(v_e.data, v_e.horario);
  -- Responder e pedir troca: só em escala publicada, cujo horário de início ainda não passou.
  v_pode_agir := v_tem_vaga and v_e.situacao = 'publicada' and not v_iniciada;

  select coalesce(jsonb_agg(
           jsonb_build_object(
             'id', v.id, 'funcao_id', v.funcao_id, 'funcao', f.nome, 'funcao_ativa', f.ativa,
             'rotulo', v.rotulo, 'ordem', v.ordem,
             'pessoa', case when v.perfil_id is null then null
                            else jsonb_build_object('id', v.perfil_id, 'nome', p.nome) end,
             'em_aberto', v.perfil_id is null,
             'minha', coalesce(v.perfil_id = v_uid, false)
           ) || case when v_gestor then jsonb_build_object(
             'resposta', case when v.perfil_id is null then null else coalesce(r.resposta::text, 'pendente') end,
             'motivo', r.motivo,
             'precisa_atencao', case
                 when v.perfil_id is null then 'em_aberto'
                 when v_e.situacao <> 'publicada' then null
                 when r.resposta = 'recusado' then 'recusada'
                 when r.resposta is null then 'sem_resposta'
                 else null end
           ) else '{}'::jsonb end
           order by v.ordem, v.id), '[]'::jsonb)
    into v_vagas
    from public.vagas_escala v
    join public.funcoes_ministerio f on f.id = v.funcao_id
    left join public.perfis p on p.id = v.perfil_id
    left join public.respostas_escala r on r.escala_id = v.escala_id and r.perfil_id = v.perfil_id
   where v.escala_id = p_escala;

  select coalesce(jsonb_agg(v.id order by v.ordem, v.id), '[]'::jsonb) into v_minhas
    from public.vagas_escala v where v.escala_id = p_escala and v.perfil_id = v_uid;

  if v_tem_vaga then
    select jsonb_build_object('resposta', coalesce(r.resposta::text, 'pendente'), 'motivo', coalesce(r.motivo, ''))
      into v_minha
      from (select 1) x
      left join public.respostas_escala r on r.escala_id = p_escala and r.perfil_id = v_uid;
  end if;

  if v_gestor then
    select coalesce(jsonb_agg(jsonb_build_object(
             'perfil_id', q.perfil_id, 'nome', q.nome,
             'resposta', coalesce(q.resposta::text, 'pendente'), 'motivo', coalesce(q.motivo, '')
           ) order by q.nome), '[]'::jsonb)
      into v_respostas
      from (
        select distinct v.perfil_id, p.nome, r.resposta, r.motivo
          from public.vagas_escala v
          join public.perfis p on p.id = v.perfil_id
          left join public.respostas_escala r on r.escala_id = v.escala_id and r.perfil_id = v.perfil_id
         where v.escala_id = p_escala and v.perfil_id is not null
      ) q;
  end if;

  return jsonb_build_object(
    'escala', jsonb_build_object(
      'id', v_e.id, 'ministerio_id', v_e.ministerio_id, 'ministerio', v_m.nome, 'ministerio_ativo', v_m.ativo,
      'evento', v_e.evento, 'data', v_e.data, 'horario', v_e.horario,
      'observacao', v_e.observacao, 'situacao', v_e.situacao
    ),
    'papel', case when v_gestor then 'gestor' else 'participante' end,
    'somente_leitura', public.hoje_sp() > v_e.data,
    'iniciada', v_iniciada,
    'vagas', v_vagas,
    'minhas_vagas', v_minhas,
    'minha_resposta', v_minha,
    'pode_responder', v_pode_agir,
    'pode_pedir_troca', v_pode_agir,
    'respostas', v_respostas
  );
end;
$$;

-- Quantas escalas futuras (não canceladas) ainda têm vaga em aberto: o aviso do líder na página
-- do ministério, sem notificações (FR-019).
create function public.contar_escalas_com_vagas_abertas(p_ministerio uuid)
returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or not public.eh_gestor_de(p_ministerio) then
    return 0;
  end if;
  return (
    select count(*)::integer
      from public.escalas e
     where e.ministerio_id = p_ministerio
       and e.situacao <> 'cancelada'
       and e.data >= public.hoje_sp()
       and exists (select 1 from public.vagas_escala v where v.escala_id = e.id and v.perfil_id is null)
  );
end;
$$;

revoke execute on function public.listar_escalas_ministerio(uuid, boolean) from public, anon;
grant execute on function public.listar_escalas_ministerio(uuid, boolean) to authenticated;
revoke execute on function public.ler_escala(uuid) from public, anon;
grant execute on function public.ler_escala(uuid) to authenticated;
revoke execute on function public.contar_escalas_com_vagas_abertas(uuid) from public, anon;
grant execute on function public.contar_escalas_com_vagas_abertas(uuid) to authenticated;
