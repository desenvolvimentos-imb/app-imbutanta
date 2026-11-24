-- Disponibilidade: respostas dos participantes e leituras da própria pessoa (RF-014 a RF-020).
-- Contrato: specs/004-disponibilidade-participantes/contracts/banco-rpc.md.

-- Interna: grava (ou limpa) as respostas de UMA pessoa numa consulta. Usada pela própria pessoa
-- (`responder_disponibilidade`) e pelo líder (`preencher_disponibilidade`, migração seguinte).
-- Tudo ou nada: qualquer item inválido levanta exceção e a transação inteira é desfeita
-- (research.md, decisão 7).
--  * resposta nula = voltar a "sem resposta" (apaga a linha);
--  * `p_preenchida_por` nulo = a própria pessoa respondeu; com valor = o líder que preencheu (RF-021);
--  * `p_permitir_passadas`: só o líder corrige data que já passou; o participante recebe data_encerrada.
create function public.gravar_respostas_disponibilidade(
  p_consulta uuid, p_perfil uuid, p_respostas jsonb, p_preenchida_por uuid, p_permitir_passadas boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item jsonb;
  v_data_id uuid;
  v_data date;
  v_resposta text;
begin
  if p_respostas is null or jsonb_typeof(p_respostas) <> 'array' then
    raise exception 'resposta_invalida';
  end if;

  for v_item in select * from jsonb_array_elements(p_respostas) loop
    if jsonb_typeof(v_item) <> 'object' or jsonb_typeof(v_item -> 'data_id') <> 'string' then
      raise exception 'resposta_invalida';
    end if;
    begin
      v_data_id := (v_item ->> 'data_id')::uuid;
    exception when others then
      raise exception 'resposta_invalida';
    end;
    select d.data into v_data from public.datas_consulta d where d.id = v_data_id and d.consulta_id = p_consulta;
    if not found then
      raise exception 'resposta_invalida';
    end if;
    if v_data < public.hoje_sp() and not p_permitir_passadas then
      raise exception 'data_encerrada';
    end if;

    if jsonb_typeof(v_item -> 'resposta') = 'null' or not (v_item ? 'resposta') then
      delete from public.respostas_disponibilidade where data_id = v_data_id and perfil_id = p_perfil;
    else
      v_resposta := v_item ->> 'resposta';
      if v_resposta not in ('disponivel', 'indisponivel') then
        raise exception 'resposta_invalida';
      end if;
      insert into public.respostas_disponibilidade (data_id, perfil_id, resposta, preenchida_por, atualizada_em)
      values (v_data_id, p_perfil, v_resposta::public.resposta_disponibilidade, p_preenchida_por, now())
      on conflict (data_id, perfil_id) do update
        set resposta = excluded.resposta, preenchida_por = excluded.preenchida_por, atualizada_em = now();
    end if;
  end loop;
end;
$$;
revoke execute on function public.gravar_respostas_disponibilidade(uuid, uuid, jsonb, uuid, boolean) from public, anon, authenticated;

-- A própria pessoa responde (parcial ou completo) e, se quiser, deixa uma observação. Só em consulta
-- aberta (RF-014, RF-016, RF-018). `p_observacao` nula mantém a atual; texto vazio a apaga.
create function public.responder_disponibilidade(p_consulta uuid, p_respostas jsonb, p_observacao text default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_consulta public.consultas_disponibilidade;
  v_obs text;
begin
  v_consulta := public.exigir_participante_consulta(p_consulta);
  if not public.consulta_esta_aberta(v_consulta) then
    raise exception 'consulta_fechada';
  end if;

  if p_observacao is not null then
    v_obs := btrim(p_observacao);
    if char_length(v_obs) > 300 then
      raise exception 'consulta_invalida';
    end if;
  end if;

  perform public.gravar_respostas_disponibilidade(p_consulta, auth.uid(), p_respostas, null, false);

  if p_observacao is not null then
    if v_obs = '' then
      delete from public.observacoes_disponibilidade where consulta_id = p_consulta and perfil_id = auth.uid();
    else
      insert into public.observacoes_disponibilidade (consulta_id, perfil_id, texto, atualizada_em)
      values (p_consulta, auth.uid(), v_obs, now())
      on conflict (consulta_id, perfil_id) do update set texto = excluded.texto, atualizada_em = now();
    end if;
  end if;

  return jsonb_build_object(
    'salvo', true,
    'sem_resposta', (
      select count(*) from public.datas_consulta d
       where d.consulta_id = p_consulta and d.data >= public.hoje_sp()
         and not exists (select 1 from public.respostas_disponibilidade r where r.data_id = d.id and r.perfil_id = auth.uid()))
  );
end;
$$;

-- Interna: a consulta como a PRÓPRIA pessoa a vê (só as respostas e a observação dela).
create function public.montar_consulta_participante(p_consulta public.consultas_disponibilidade, p_perfil uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'id', p_consulta.id,
    'ministerio_id', p_consulta.ministerio_id,
    'ministerio', m.nome,
    'titulo', p_consulta.titulo,
    'mensagem', p_consulta.mensagem,
    'prazo', p_consulta.prazo,
    'aberta', public.consulta_esta_aberta(p_consulta),
    'motivo_fechada', case
      when public.consulta_esta_aberta(p_consulta) then null
      when not m.ativo then 'ministerio_desativado'
      when p_consulta.fechada then 'lider'
      else 'prazo' end,
    'pode_responder', public.consulta_esta_aberta(p_consulta),
    'datas', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', d.id, 'data', d.data, 'rotulo', d.rotulo,
               'passada', d.data < public.hoje_sp(),
               'resposta', r.resposta) order by d.data)
        from public.datas_consulta d
        left join public.respostas_disponibilidade r on r.data_id = d.id and r.perfil_id = p_perfil
       where d.consulta_id = p_consulta.id), '[]'::jsonb),
    'observacao', coalesce((select o.texto from public.observacoes_disponibilidade o
                             where o.consulta_id = p_consulta.id and o.perfil_id = p_perfil), ''),
    'sem_resposta', (
      select count(*) from public.datas_consulta d
       where d.consulta_id = p_consulta.id and d.data >= public.hoje_sp()
         and not exists (select 1 from public.respostas_disponibilidade r where r.data_id = d.id and r.perfil_id = p_perfil))
  )
  from public.ministerios m where m.id = p_consulta.ministerio_id;
$$;
revoke execute on function public.montar_consulta_participante(public.consultas_disponibilidade, uuid) from public, anon, authenticated;

-- Consultas abertas dos ministérios em que a pessoa participa, mais as fechadas recentemente
-- (últimos 60 dias, só leitura). Só o que é DELA (RF-015, RF-020).
create function public.minhas_consultas()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    return jsonb_build_object('abertas', '[]'::jsonb, 'fechadas_recentes', '[]'::jsonb);
  end if;

  return (
    with minhas as (
      select c.*
        from public.consultas_disponibilidade c
        join public.participacoes_ministerio pm on pm.ministerio_id = c.ministerio_id and pm.perfil_id = v_uid
        join public.perfis p on p.id = v_uid and p.situacao = 'aprovado'
    )
    select jsonb_build_object(
      'abertas', coalesce((
        select jsonb_agg(public.montar_consulta_participante(m, v_uid) order by m.criada_em desc)
          from minhas m where public.consulta_esta_aberta(m)), '[]'::jsonb),
      'fechadas_recentes', coalesce((
        select jsonb_agg(public.montar_consulta_participante(m, v_uid) order by m.criada_em desc)
          from minhas m
         where not public.consulta_esta_aberta(m)
           and (select max(d.data) from public.datas_consulta d where d.consulta_id = m.id) >= public.hoje_sp() - 60), '[]'::jsonb)
    )
  );
end;
$$;

-- Uma consulta com as respostas e a observação da PRÓPRIA pessoa; nulo para quem não participa
-- do ministério (não revela se a consulta existe). Serve também para consulta fechada (só leitura).
create function public.ler_consulta_participante(p_consulta uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_consulta public.consultas_disponibilidade;
begin
  if auth.uid() is null then
    return null;
  end if;
  select * into v_consulta from public.consultas_disponibilidade where id = p_consulta;
  if not found or not public.eh_participante_de(v_consulta.ministerio_id) then
    return null;
  end if;
  return public.montar_consulta_participante(v_consulta, auth.uid());
end;
$$;

-- Quantas consultas abertas, de ministérios ativos da pessoa, têm ao menos uma data que ainda aceita
-- resposta e que ela não marcou. Alimenta o aviso da tela inicial (RF-015).
create function public.contar_consultas_pendentes()
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::integer
    from public.consultas_disponibilidade c
    join public.ministerios m on m.id = c.ministerio_id and m.ativo
    join public.participacoes_ministerio pm on pm.ministerio_id = c.ministerio_id and pm.perfil_id = auth.uid()
    join public.perfis p on p.id = pm.perfil_id and p.situacao = 'aprovado'
   where public.consulta_esta_aberta(c)
     and exists (
       select 1 from public.datas_consulta d
        where d.consulta_id = c.id and d.data >= public.hoje_sp()
          and not exists (select 1 from public.respostas_disponibilidade r where r.data_id = d.id and r.perfil_id = pm.perfil_id));
$$;

revoke execute on function public.responder_disponibilidade(uuid, jsonb, text) from public, anon;
grant execute on function public.responder_disponibilidade(uuid, jsonb, text) to authenticated;
revoke execute on function public.minhas_consultas() from public, anon;
grant execute on function public.minhas_consultas() to authenticated;
revoke execute on function public.ler_consulta_participante(uuid) from public, anon;
grant execute on function public.ler_consulta_participante(uuid) to authenticated;
revoke execute on function public.contar_consultas_pendentes() from public, anon;
grant execute on function public.contar_consultas_pendentes() to authenticated;
