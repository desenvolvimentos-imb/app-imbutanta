-- Integração da disponibilidade com as escalas (RF-028 a RF-030).
--  1) `avisos_para_vaga` (003) ganha o aviso `sem_disponibilidade`; os avisos já existentes e a ordem
--     entre eles NÃO mudam (o novo vem por último).
--  2) `disponibilidade_da_escala` devolve a resposta de cada participante na data da escala, para a
--     tela mostrar ao lado de cada pessoa e na hora de escolher quem escalar.
-- Só consultas DO MESMO MINISTÉRIO contam; se a data da escala não está em nenhuma, nada é devolvido.

-- Interna: situação de uma pessoa numa data do ministério. Nulo = a data não está em nenhuma
-- consulta do ministério (então não há o que mostrar). A consulta pode estar aberta ou fechada: a
-- resposta existente continua valendo para quem escala.
create function public.situacao_disponibilidade(p_ministerio uuid, p_data date, p_perfil uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select case when r.resposta is null then 'sem_resposta' else r.resposta::text end
    from public.datas_consulta d
    left join public.respostas_disponibilidade r on r.data_id = d.id and r.perfil_id = p_perfil
   where d.ministerio_id = p_ministerio and d.data = p_data;
$$;
revoke execute on function public.situacao_disponibilidade(uuid, date, uuid) from public, anon, authenticated;

-- Mesma função da 003 (avisos que NÃO bloqueiam), com um aviso a mais no fim:
--  * sem_disponibilidade: a data da escala está numa consulta do mesmo ministério e a pessoa marcou
--    "indisponível" ou ainda não respondeu. Como o aviso de outro ministério, só vale para quem ainda
--    não ocupa outra vaga NESTA escala (o líder já o viu ao escalar a primeira).
create or replace function public.avisos_para_vaga(p_escala uuid, p_perfil uuid, p_funcao uuid)
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
  v_ja_na_escala boolean;
  v_disponibilidade text;
begin
  select * into v_escala from public.escalas where id = p_escala;

  v_ja_na_escala := exists (
    select 1 from public.vagas_escala v where v.escala_id = p_escala and v.perfil_id = p_perfil
  );

  if not v_ja_na_escala then
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

  if not v_ja_na_escala then
    v_disponibilidade := public.situacao_disponibilidade(v_escala.ministerio_id, v_escala.data, p_perfil);
    if v_disponibilidade in ('indisponivel', 'sem_resposta') then
      v_avisos := v_avisos || jsonb_build_array(jsonb_build_object(
        'tipo', 'sem_disponibilidade', 'resposta', v_disponibilidade));
    end if;
  end if;

  return v_avisos;
end;
$$;
revoke execute on function public.avisos_para_vaga(uuid, uuid, uuid) from public, anon, authenticated;

-- Resposta de cada participante ativo do ministério na data da escala. Só líder do ministério ou
-- administrador. Zero linhas quando a data da escala não pertence a nenhuma consulta do ministério.
create function public.disponibilidade_da_escala(p_escala uuid)
returns table (perfil_id uuid, resposta text)
language plpgsql
stable
security definer
set search_path = public
as $$
#variable_conflict use_column
declare
  v_escala public.escalas;
begin
  if auth.uid() is null then
    return;
  end if;
  select * into v_escala from public.escalas where id = p_escala;
  if not found or not public.eh_gestor_de(v_escala.ministerio_id) then
    return;
  end if;
  if not exists (
    select 1 from public.datas_consulta d where d.ministerio_id = v_escala.ministerio_id and d.data = v_escala.data
  ) then
    return;
  end if;

  return query
    select p.id, public.situacao_disponibilidade(v_escala.ministerio_id, v_escala.data, p.id)
      from public.participacoes_ministerio pm
      join public.perfis p on p.id = pm.perfil_id and p.situacao = 'aprovado'
     where pm.ministerio_id = v_escala.ministerio_id;
end;
$$;
revoke execute on function public.disponibilidade_da_escala(uuid) from public, anon;
grant execute on function public.disponibilidade_da_escala(uuid) to authenticated;
