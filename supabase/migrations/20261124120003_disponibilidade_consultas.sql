-- Disponibilidade: gestão de consultas (RF-001 a RF-012). Toda função trava a consulta com
-- `for update` (via `exigir_gestor_consulta`) antes de decidir (research.md, decisão 5), e todas as
-- escritas exigem ministério ativo. Contrato: specs/004-disponibilidade-participantes/contracts/banco-rpc.md.

-- Interna: valida e grava uma lista de datas na consulta. Usada por `criar_consulta` e
-- `adicionar_datas_consulta`. `p_datas` = [{"data": "2026-12-06", "rotulo": "Culto especial"}, ...].
-- Cada data é gravada uma a uma para a violação do índice único (mesma data, mesmo ministério) virar
-- `data_duplicada` com o título da consulta que já a tem no `detail` (research.md, decisão 3).
-- Devolve as datas gravadas.
create function public.inserir_datas_consulta(p_consulta uuid, p_ministerio uuid, p_datas jsonb)
returns setof public.datas_consulta
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item jsonb;
  v_data date;
  v_rotulo text;
  v_titulo text;
  v_nova public.datas_consulta;
begin
  for v_item in select * from jsonb_array_elements(p_datas) loop
    if jsonb_typeof(v_item) <> 'object' or jsonb_typeof(v_item -> 'data') <> 'string' then
      raise exception 'consulta_invalida';
    end if;
    begin
      v_data := (v_item ->> 'data')::date;
    exception when others then
      raise exception 'consulta_invalida';
    end;
    if v_data < public.hoje_sp() then
      raise exception 'data_passada';
    end if;
    v_rotulo := btrim(coalesce(v_item ->> 'rotulo', ''));
    if char_length(v_rotulo) > 40 then
      raise exception 'consulta_invalida';
    end if;

    begin
      insert into public.datas_consulta (consulta_id, ministerio_id, data, rotulo)
      values (p_consulta, p_ministerio, v_data, v_rotulo)
      returning * into v_nova;
    exception when unique_violation then
      select c.titulo into v_titulo
        from public.datas_consulta d
        join public.consultas_disponibilidade c on c.id = d.consulta_id
       where d.ministerio_id = p_ministerio and d.data = v_data;
      raise exception using message = 'data_duplicada', detail = coalesce(v_titulo, '');
    end;
    return next v_nova;
  end loop;
end;
$$;
revoke execute on function public.inserir_datas_consulta(uuid, uuid, jsonb) from public, anon, authenticated;

-- Cria a consulta (aberta) e todas as datas na mesma transação: ou tudo, ou nada (constitution III).
create function public.criar_consulta(
  p_ministerio uuid, p_titulo text, p_mensagem text, p_prazo date, p_datas jsonb
)
returns public.consultas_disponibilidade
language plpgsql
security definer
set search_path = public
as $$
declare
  v_titulo text := btrim(coalesce(p_titulo, ''));
  v_mensagem text := btrim(coalesce(p_mensagem, ''));
  v_consulta public.consultas_disponibilidade;
begin
  perform public.exigir_gestor_ministerio(p_ministerio);

  if char_length(v_titulo) not between 2 and 80 or char_length(v_mensagem) > 500 then
    raise exception 'consulta_invalida';
  end if;
  if p_datas is null or jsonb_typeof(p_datas) <> 'array' or jsonb_array_length(p_datas) = 0 then
    raise exception 'consulta_sem_datas';
  end if;
  if jsonb_array_length(p_datas) > 31 then
    raise exception 'consulta_invalida';
  end if;
  if p_prazo is not null and p_prazo < public.hoje_sp() then
    raise exception 'prazo_invalido';
  end if;

  insert into public.consultas_disponibilidade (ministerio_id, titulo, mensagem, prazo, criada_por)
  values (p_ministerio, v_titulo, v_mensagem, p_prazo, auth.uid())
  returning * into v_consulta;

  perform public.inserir_datas_consulta(v_consulta.id, p_ministerio, p_datas);
  return v_consulta;
end;
$$;

-- Altera título, mensagem e prazo (prazo nulo remove o prazo). Só em consulta aberta: numa fechada
-- (inclusive por prazo vencido) a única ação é reabrir (RF-011).
create function public.editar_consulta(p_consulta uuid, p_titulo text, p_mensagem text, p_prazo date)
returns public.consultas_disponibilidade
language plpgsql
security definer
set search_path = public
as $$
declare
  v_consulta public.consultas_disponibilidade;
  v_titulo text := btrim(coalesce(p_titulo, ''));
  v_mensagem text := btrim(coalesce(p_mensagem, ''));
begin
  v_consulta := public.exigir_gestor_consulta(p_consulta);
  if not public.consulta_esta_aberta(v_consulta) then
    raise exception 'consulta_fechada';
  end if;
  if char_length(v_titulo) not between 2 and 80 or char_length(v_mensagem) > 500 then
    raise exception 'consulta_invalida';
  end if;
  if p_prazo is not null and p_prazo < public.hoje_sp() then
    raise exception 'prazo_invalido';
  end if;

  update public.consultas_disponibilidade
     set titulo = v_titulo, mensagem = v_mensagem, prazo = p_prazo, atualizada_em = now()
   where id = p_consulta
  returning * into v_consulta;
  return v_consulta;
end;
$$;

-- Acrescenta datas a uma consulta aberta. Elas começam "sem resposta" para todos (não há linha).
create function public.adicionar_datas_consulta(p_consulta uuid, p_datas jsonb)
returns setof public.datas_consulta
language plpgsql
security definer
set search_path = public
as $$
declare
  v_consulta public.consultas_disponibilidade;
begin
  v_consulta := public.exigir_gestor_consulta(p_consulta);
  if not public.consulta_esta_aberta(v_consulta) then
    raise exception 'consulta_fechada';
  end if;
  if p_datas is null or jsonb_typeof(p_datas) <> 'array' or jsonb_array_length(p_datas) = 0 then
    raise exception 'consulta_invalida';
  end if;
  if (select count(*) from public.datas_consulta where consulta_id = p_consulta) + jsonb_array_length(p_datas) > 31 then
    raise exception 'consulta_invalida';
  end if;

  return query select * from public.inserir_datas_consulta(p_consulta, v_consulta.ministerio_id, p_datas);
  update public.consultas_disponibilidade set atualizada_em = now() where id = p_consulta;
end;
$$;

-- Remove uma data de consulta aberta. Com respostas, só remove depois da confirmação: sem ela, NÃO
-- grava nada e devolve a contagem para o app pedir confirmação (research.md, decisão 6). Confirmada,
-- as respostas da data somem junto (cascata). Nunca deixa a consulta sem datas.
create function public.remover_data_consulta(p_data uuid, p_confirmado boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_consulta_id uuid;
  v_consulta public.consultas_disponibilidade;
  v_respostas integer;
begin
  if auth.uid() is null then
    raise exception 'sem_permissao';
  end if;
  select consulta_id into v_consulta_id from public.datas_consulta where id = p_data;
  if not found then
    raise exception using message =
      case when coalesce(public.papel_aprovado_atual() = 'administrador', false)
           then 'nao_encontrado' else 'sem_permissao' end;
  end if;

  v_consulta := public.exigir_gestor_consulta(v_consulta_id);
  -- Depois da trava: a data pode ter sido removida por outra pessoa no meio tempo.
  if not exists (select 1 from public.datas_consulta where id = p_data) then
    raise exception 'nao_encontrado';
  end if;
  if not public.consulta_esta_aberta(v_consulta) then
    raise exception 'consulta_fechada';
  end if;
  if (select count(*) from public.datas_consulta where consulta_id = v_consulta_id) <= 1 then
    raise exception 'consulta_sem_datas';
  end if;

  select count(*) into v_respostas from public.respostas_disponibilidade where data_id = p_data;
  if v_respostas > 0 and not coalesce(p_confirmado, false) then
    return jsonb_build_object('removida', false, 'confirmacao_necessaria', true, 'respostas', v_respostas);
  end if;

  delete from public.datas_consulta where id = p_data;
  update public.consultas_disponibilidade set atualizada_em = now() where id = v_consulta_id;
  return jsonb_build_object('removida', true, 'respostas_descartadas', v_respostas);
end;
$$;

-- Fecha a consulta (idempotente). Os participantes deixam de poder responder.
create function public.fechar_consulta(p_consulta uuid)
returns public.consultas_disponibilidade
language plpgsql
security definer
set search_path = public
as $$
declare
  v_consulta public.consultas_disponibilidade;
begin
  perform public.exigir_gestor_consulta(p_consulta);
  update public.consultas_disponibilidade
     set fechada = true, atualizada_em = now()
   where id = p_consulta
  returning * into v_consulta;
  return v_consulta;
end;
$$;

-- Reabre a consulta. Se o prazo já venceu, é preciso um novo prazo (hoje ou depois) ou remover o
-- prazo (RF-008); senão ela reabriria já "fechada pelo prazo".
create function public.reabrir_consulta(
  p_consulta uuid, p_prazo date default null, p_remover_prazo boolean default false
)
returns public.consultas_disponibilidade
language plpgsql
security definer
set search_path = public
as $$
declare
  v_consulta public.consultas_disponibilidade;
  v_prazo date;
begin
  v_consulta := public.exigir_gestor_consulta(p_consulta);
  if public.consulta_esta_aberta(v_consulta) then
    raise exception 'consulta_ja_aberta';
  end if;

  if coalesce(p_remover_prazo, false) then
    v_prazo := null;
  elsif p_prazo is not null then
    if p_prazo < public.hoje_sp() then
      raise exception 'prazo_invalido';
    end if;
    v_prazo := p_prazo;
  else
    v_prazo := v_consulta.prazo;
  end if;
  if v_prazo is not null and v_prazo < public.hoje_sp() then
    raise exception 'prazo_vencido';
  end if;

  update public.consultas_disponibilidade
     set fechada = false, prazo = v_prazo, atualizada_em = now()
   where id = p_consulta
  returning * into v_consulta;
  return v_consulta;
end;
$$;

-- Lista as consultas do ministério para quem o gere (líder ou administrador): abertas primeiro,
-- depois o histórico. Participante comum e estranho recebem lista vazia (não revela nada).
-- Quem saiu do ministério não conta em "sem_resposta_nenhuma" (RF-019).
create function public.listar_consultas_ministerio(p_ministerio uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or not public.eh_gestor_de(p_ministerio) then
    return '[]'::jsonb;
  end if;

  return coalesce((
    select jsonb_agg(item order by aberta desc, criada_em desc)
      from (
        select
          public.consulta_esta_aberta(c) as aberta,
          c.criada_em,
          jsonb_build_object(
            'id', c.id,
            'titulo', c.titulo,
            'prazo', c.prazo,
            'aberta', public.consulta_esta_aberta(c),
            'motivo_fechada', case
              when public.consulta_esta_aberta(c) then null
              when not m.ativo then 'ministerio_desativado'
              when c.fechada then 'lider'
              else 'prazo' end,
            'total_datas', (select count(*) from public.datas_consulta d where d.consulta_id = c.id),
            'sem_resposta_nenhuma', (
              select count(*)
                from public.participacoes_ministerio pm
                join public.perfis p on p.id = pm.perfil_id and p.situacao = 'aprovado'
               where pm.ministerio_id = c.ministerio_id
                 and not exists (
                   select 1 from public.respostas_disponibilidade r
                     join public.datas_consulta d on d.id = r.data_id
                    where d.consulta_id = c.id and r.perfil_id = pm.perfil_id)),
            'primeira_data', (select min(d.data) from public.datas_consulta d where d.consulta_id = c.id)
          ) as item
        from public.consultas_disponibilidade c
        join public.ministerios m on m.id = c.ministerio_id
       where c.ministerio_id = p_ministerio
      ) t
  ), '[]'::jsonb);
end;
$$;

revoke execute on function public.criar_consulta(uuid, text, text, date, jsonb) from public, anon;
grant execute on function public.criar_consulta(uuid, text, text, date, jsonb) to authenticated;
revoke execute on function public.editar_consulta(uuid, text, text, date) from public, anon;
grant execute on function public.editar_consulta(uuid, text, text, date) to authenticated;
revoke execute on function public.adicionar_datas_consulta(uuid, jsonb) from public, anon;
grant execute on function public.adicionar_datas_consulta(uuid, jsonb) to authenticated;
revoke execute on function public.remover_data_consulta(uuid, boolean) from public, anon;
grant execute on function public.remover_data_consulta(uuid, boolean) to authenticated;
revoke execute on function public.fechar_consulta(uuid) from public, anon;
grant execute on function public.fechar_consulta(uuid) to authenticated;
revoke execute on function public.reabrir_consulta(uuid, date, boolean) from public, anon;
grant execute on function public.reabrir_consulta(uuid, date, boolean) to authenticated;
revoke execute on function public.listar_consultas_ministerio(uuid) from public, anon;
grant execute on function public.listar_consultas_ministerio(uuid) to authenticated;
