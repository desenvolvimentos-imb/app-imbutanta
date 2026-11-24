-- Responder a uma escala e "Minhas escalas" (FR-021, FR-026 a FR-028).
-- Erros levantados: sem_permissao, nao_escalado, escala_nao_publicada, escala_cancelada,
--   evento_iniciado, motivo_invalido.

-- Confirmar ou recusar. A resposta é UMA por pessoa por escala e vale para todas as vagas dela
-- (FR-026). Pendente é a ausência de linha. Pode mudar até o horário de início do evento (FR-027).
-- Uma vaga recusada continua com a pessoa (FR-028): quem reorganiza é o líder.
-- A pessoa que não ocupa vaga (ou a escala que não existe) recebe sempre nao_escalado: o app não
-- revela o que existe.
create function public.responder_escala(p_escala uuid, p_resposta public.resposta_escala, p_motivo text default '')
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_escala public.escalas;
  v_motivo text := btrim(coalesce(p_motivo, ''));
begin
  if v_uid is null or public.papel_aprovado_atual() is null then
    raise exception 'sem_permissao';
  end if;
  if p_resposta is null then
    raise exception 'transicao_invalida';
  end if;
  if char_length(v_motivo) > 200 then
    raise exception 'motivo_invalido';
  end if;

  if not exists (select 1 from public.vagas_escala v where v.escala_id = p_escala and v.perfil_id = v_uid) then
    raise exception 'nao_escalado';
  end if;

  -- Trava a escala: a resposta não se mistura com uma troca de pessoa ou mudança de horário.
  select * into v_escala from public.escalas where id = p_escala for update;
  if v_escala.situacao = 'cancelada' then
    raise exception 'escala_cancelada';
  end if;
  if v_escala.situacao <> 'publicada' then
    raise exception 'escala_nao_publicada';
  end if;
  if public.agora_sp() >= public.inicio_da_escala(v_escala.data, v_escala.horario) then
    raise exception 'evento_iniciado';
  end if;
  -- Pode ter sido trocada pelo líder enquanto esperava a trava.
  if not exists (select 1 from public.vagas_escala v where v.escala_id = p_escala and v.perfil_id = v_uid) then
    raise exception 'nao_escalado';
  end if;

  insert into public.respostas_escala (escala_id, perfil_id, resposta, motivo)
  values (p_escala, v_uid, p_resposta, case when p_resposta = 'recusado' then v_motivo else '' end)
  on conflict (escala_id, perfil_id)
  do update set resposta = excluded.resposta, motivo = excluded.motivo, respondida_em = now();
end;
$$;

-- "Minhas escalas": as escalas PUBLICADAS (ou canceladas) em que a pessoa ocupa vaga, em ordem de
-- data. Uma escala por linha, com todas as funções dela e a situação da resposta.
-- Próximas = de hoje em diante (ordem crescente); passadas = antes de hoje (mais recentes primeiro).
create function public.minhas_escalas(p_passadas boolean default false)
returns table (
  escala_id uuid, ministerio_id uuid, ministerio text, evento text, funcoes text[],
  data date, horario time, situacao public.situacao_escala,
  minha_resposta text, motivo text, pode_responder boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
#variable_conflict use_column
declare
  v_uid uuid := auth.uid();
  v_hoje date := public.hoje_sp();
  v_agora timestamptz := public.agora_sp();
  v_sentido integer := case when coalesce(p_passadas, false) then -1 else 1 end;
begin
  if v_uid is null or public.papel_aprovado_atual() is null then
    return;
  end if;
  return query
    select e.id, e.ministerio_id, m.nome, e.evento,
           (select array_agg(f.nome order by v.ordem, v.id)
              from public.vagas_escala v
              join public.funcoes_ministerio f on f.id = v.funcao_id
             where v.escala_id = e.id and v.perfil_id = v_uid),
           e.data, e.horario, e.situacao,
           coalesce(r.resposta::text, 'pendente'), coalesce(r.motivo, ''),
           e.situacao = 'publicada' and v_agora < public.inicio_da_escala(e.data, e.horario)
      from public.escalas e
      join public.ministerios m on m.id = e.ministerio_id
      left join public.respostas_escala r on r.escala_id = e.id and r.perfil_id = v_uid
     where e.situacao in ('publicada', 'cancelada')
       and exists (select 1 from public.vagas_escala v where v.escala_id = e.id and v.perfil_id = v_uid)
       and (case when coalesce(p_passadas, false) then e.data < v_hoje else e.data >= v_hoje end)
     order by (e.data - date '2000-01-01') * v_sentido,
              (extract(epoch from e.horario)::integer) * v_sentido,
              e.evento;
end;
$$;

-- Números para a tela inicial. Por ora só as escalas sem resposta (publicadas, que ainda não
-- começaram); os contadores de troca entram com os pedidos de troca.
create function public.contar_pendencias_escala()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_sem_resposta integer := 0;
begin
  if v_uid is not null and public.papel_aprovado_atual() is not null then
    select count(*)::integer into v_sem_resposta
      from public.escalas e
     where e.situacao = 'publicada'
       and public.agora_sp() < public.inicio_da_escala(e.data, e.horario)
       and exists (select 1 from public.vagas_escala v where v.escala_id = e.id and v.perfil_id = v_uid)
       and not exists (select 1 from public.respostas_escala r where r.escala_id = e.id and r.perfil_id = v_uid);
  end if;
  return jsonb_build_object('sem_resposta', v_sem_resposta, 'trocas_recebidas', 0, 'trocas_para_aprovar', 0);
end;
$$;

revoke execute on function public.responder_escala(uuid, public.resposta_escala, text) from public, anon;
grant execute on function public.responder_escala(uuid, public.resposta_escala, text) to authenticated;
revoke execute on function public.minhas_escalas(boolean) from public, anon;
grant execute on function public.minhas_escalas(boolean) to authenticated;
revoke execute on function public.contar_pendencias_escala() from public, anon;
grant execute on function public.contar_pendencias_escala() to authenticated;
