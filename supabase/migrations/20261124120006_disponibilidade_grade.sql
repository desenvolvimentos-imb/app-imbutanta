-- Disponibilidade: a grade do líder (RF-022 a RF-027). Uma chamada devolve tudo o que as duas visões
-- da tela precisam (tabela e visão por data). Só líderes do ministério e administradores a leem;
-- ninguém recebe email (ADR 0006).

-- Participantes ATIVOS do ministério (conta aprovada). Quem saiu não entra: as respostas dele ficam
-- gravadas, mas somem da grade e das contagens, e voltam se ele retornar (RF-019, decisão 8).
create function public.ler_consulta_gestor(p_consulta uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_c public.consultas_disponibilidade;
  v_m public.ministerios;
  v_total integer;
begin
  if auth.uid() is null then
    return null;
  end if;
  select * into v_c from public.consultas_disponibilidade where id = p_consulta;
  if not found or not public.eh_gestor_de(v_c.ministerio_id) then
    return null;
  end if;
  select * into v_m from public.ministerios where id = v_c.ministerio_id;

  select count(*) into v_total
    from public.participacoes_ministerio pm
    join public.perfis p on p.id = pm.perfil_id and p.situacao = 'aprovado'
   where pm.ministerio_id = v_c.ministerio_id;

  return jsonb_build_object(
    'consulta', jsonb_build_object(
      'id', v_c.id, 'ministerio_id', v_c.ministerio_id, 'ministerio', v_m.nome, 'ministerio_ativo', v_m.ativo,
      'titulo', v_c.titulo, 'mensagem', v_c.mensagem, 'prazo', v_c.prazo,
      'aberta', public.consulta_esta_aberta(v_c),
      'motivo_fechada', case
        when public.consulta_esta_aberta(v_c) then null
        when not v_m.ativo then 'ministerio_desativado'
        when v_c.fechada then 'lider'
        else 'prazo' end),
    'tem_funcoes', exists (select 1 from public.funcoes_ministerio f where f.ministerio_id = v_c.ministerio_id and f.ativa),
    'datas', coalesce((
      select jsonb_agg(jsonb_build_object(
          'id', d.id, 'data', d.data, 'rotulo', d.rotulo, 'passada', d.data < public.hoje_sp(),
          'disponiveis', t.disp, 'indisponiveis', t.indisp, 'sem_resposta', v_total - t.disp - t.indisp,
          'por_funcao', coalesce((
            select jsonb_agg(jsonb_build_object(
                     'funcao_id', f.id, 'funcao', f.nome, 'disponiveis', q.n, 'faltando', q.n = 0) order by f.nome)
              from public.funcoes_ministerio f
              cross join lateral (
                select count(*) as n
                  from public.respostas_disponibilidade r
                  join public.participacoes_ministerio pm on pm.perfil_id = r.perfil_id and pm.ministerio_id = v_c.ministerio_id
                  join public.perfis p on p.id = pm.perfil_id and p.situacao = 'aprovado'
                  join public.aptidoes a on a.perfil_id = r.perfil_id and a.funcao_id = f.id
                 where r.data_id = d.id and r.resposta = 'disponivel') q
             where f.ministerio_id = v_c.ministerio_id and f.ativa), '[]'::jsonb))
        order by d.data)
        from public.datas_consulta d
        cross join lateral (
          select count(*) filter (where r.resposta = 'disponivel') as disp,
                 count(*) filter (where r.resposta = 'indisponivel') as indisp
            from public.respostas_disponibilidade r
            join public.participacoes_ministerio pm on pm.perfil_id = r.perfil_id and pm.ministerio_id = v_c.ministerio_id
            join public.perfis p on p.id = pm.perfil_id and p.situacao = 'aprovado'
           where r.data_id = d.id) t
       where d.consulta_id = v_c.id), '[]'::jsonb),
    'participantes', coalesce((
      select jsonb_agg(jsonb_build_object(
          'perfil_id', p.id, 'nome', p.nome,
          'nao_respondeu', not exists (
            select 1 from public.respostas_disponibilidade r join public.datas_consulta d on d.id = r.data_id
             where d.consulta_id = v_c.id and r.perfil_id = p.id),
          'observacao', coalesce((select o.texto from public.observacoes_disponibilidade o
                                   where o.consulta_id = v_c.id and o.perfil_id = p.id), ''),
          'respostas', coalesce((
            select jsonb_object_agg(r.data_id, jsonb_build_object(
                     'resposta', r.resposta, 'preenchida_pelo_lider', r.preenchida_por is not null))
              from public.respostas_disponibilidade r join public.datas_consulta d on d.id = r.data_id
             where d.consulta_id = v_c.id and r.perfil_id = p.id), '{}'::jsonb))
        order by p.nome, p.id)
        from public.participacoes_ministerio pm
        join public.perfis p on p.id = pm.perfil_id and p.situacao = 'aprovado'
       where pm.ministerio_id = v_c.ministerio_id), '[]'::jsonb)
  );
end;
$$;
revoke execute on function public.ler_consulta_gestor(uuid) from public, anon;
grant execute on function public.ler_consulta_gestor(uuid) to authenticated;
