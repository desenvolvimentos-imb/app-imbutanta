-- Funções do ministério e aptidões dos participantes (FR-001 a FR-004).
-- Contrato: specs/003-escalas-ministerios/contracts/banco-rpc.md
--
-- Erros levantados (a mensagem é o código; o app traduz para português):
--   sem_permissao, nao_encontrado, ministerio_inativo, funcao_duplicada, funcao_invalida,
--   nao_participante.

-- Auxiliar interna: confere que quem chama gere o ministério da função e devolve a função.
--  * função inexistente: administrador é avisado (nao_encontrado); os demais recebem
--    sem_permissao, para não revelar o que existe;
--  * ministério desativado: exigir_gestor_ministerio levanta ministerio_inativo.
create function public.exigir_gestor_funcao(p_funcao uuid)
returns public.funcoes_ministerio
language plpgsql
security definer
set search_path = public
as $$
declare
  v_funcao public.funcoes_ministerio;
begin
  if auth.uid() is null then
    raise exception 'sem_permissao';
  end if;
  select * into v_funcao from public.funcoes_ministerio where id = p_funcao;
  if not found then
    raise exception using message =
      case when coalesce(public.papel_aprovado_atual() = 'administrador', false)
           then 'nao_encontrado' else 'sem_permissao' end;
  end if;
  perform public.exigir_gestor_ministerio(v_funcao.ministerio_id);
  return v_funcao;
end;
$$;
revoke execute on function public.exigir_gestor_funcao(uuid) from public, anon, authenticated;

-- Nome da função: sem espaços nas pontas, de 2 a 40 caracteres.
create function public.validar_nome_funcao(p_nome text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_nome text := btrim(coalesce(p_nome, ''));
begin
  if char_length(v_nome) not between 2 and 40 then
    raise exception 'funcao_invalida';
  end if;
  return v_nome;
end;
$$;
revoke execute on function public.validar_nome_funcao(text) from public, anon, authenticated;

create function public.criar_funcao(p_ministerio uuid, p_nome text)
returns public.funcoes_ministerio
language plpgsql
security definer
set search_path = public
as $$
declare
  v_nome text;
  v_funcao public.funcoes_ministerio;
begin
  perform public.exigir_gestor_ministerio(p_ministerio);
  v_nome := public.validar_nome_funcao(p_nome);
  begin
    insert into public.funcoes_ministerio (ministerio_id, nome)
    values (p_ministerio, v_nome)
    returning * into v_funcao;
  exception when unique_violation then
    raise exception 'funcao_duplicada';
  end;
  return v_funcao;
end;
$$;

-- Renomear não altera as vagas existentes: elas apontam para a função (id), não para o texto.
create function public.editar_funcao(p_funcao uuid, p_nome text)
returns public.funcoes_ministerio
language plpgsql
security definer
set search_path = public
as $$
declare
  v_atual public.funcoes_ministerio;
  v_nome text;
  v_funcao public.funcoes_ministerio;
begin
  v_atual := public.exigir_gestor_funcao(p_funcao);
  v_nome := public.validar_nome_funcao(p_nome);
  begin
    update public.funcoes_ministerio set nome = v_nome where id = v_atual.id
    returning * into v_funcao;
  exception when unique_violation then
    raise exception 'funcao_duplicada';
  end;
  return v_funcao;
end;
$$;

-- Desativar NÃO apaga nem altera vagas e escalas existentes (FR-003): só impede o uso em vagas novas.
-- Idempotente: desativar uma função já desativada devolve o registro.
create function public.desativar_funcao(p_funcao uuid)
returns public.funcoes_ministerio
language plpgsql
security definer
set search_path = public
as $$
declare
  v_atual public.funcoes_ministerio;
  v_funcao public.funcoes_ministerio;
begin
  v_atual := public.exigir_gestor_funcao(p_funcao);
  update public.funcoes_ministerio
     set ativa = false, desativada_em = coalesce(desativada_em, now())
   where id = v_atual.id
  returning * into v_funcao;
  return v_funcao;
end;
$$;

-- Reativar exige que o nome esteja livre entre as funções ativas. Idempotente.
create function public.reativar_funcao(p_funcao uuid)
returns public.funcoes_ministerio
language plpgsql
security definer
set search_path = public
as $$
declare
  v_atual public.funcoes_ministerio;
  v_funcao public.funcoes_ministerio;
begin
  v_atual := public.exigir_gestor_funcao(p_funcao);
  begin
    update public.funcoes_ministerio set ativa = true, desativada_em = null where id = v_atual.id
    returning * into v_funcao;
  exception when unique_violation then
    raise exception 'funcao_duplicada';
  end;
  return v_funcao;
end;
$$;

-- Define a lista COMPLETA de aptidões de uma pessoa neste ministério (FR-004).
-- Entrada: [{ "funcao": uuid, "tipo": "principal" | "secundaria" }, ...]. O que não estiver na
-- lista é removido. Principal e secundária contam igual como "apto" nesta funcionalidade.
create function public.definir_aptidoes(p_ministerio uuid, p_perfil uuid, p_aptidoes jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item jsonb;
  v_funcao uuid;
  v_tipo text;
  v_ativa boolean;
  v_ids uuid[] := '{}';
begin
  perform public.exigir_gestor_ministerio(p_ministerio);

  if p_aptidoes is null or jsonb_typeof(p_aptidoes) <> 'array' then
    raise exception 'funcao_invalida';
  end if;

  -- Só participantes do ministério têm aptidões.
  if not exists (
    select 1 from public.participacoes_ministerio pm
     where pm.ministerio_id = p_ministerio and pm.perfil_id = p_perfil
  ) then
    raise exception 'nao_participante';
  end if;

  for v_item in select * from jsonb_array_elements(p_aptidoes) loop
    begin
      v_funcao := (v_item ->> 'funcao')::uuid;
    exception when invalid_text_representation then
      raise exception 'funcao_invalida';
    end;
    v_tipo := v_item ->> 'tipo';
    if v_tipo is null or v_tipo not in ('principal', 'secundaria') then
      raise exception 'funcao_invalida';
    end if;

    select f.ativa into v_ativa
      from public.funcoes_ministerio f
     where f.id = v_funcao and f.ministerio_id = p_ministerio;
    if not found then
      raise exception 'funcao_invalida';  -- inexistente ou de outro ministério
    end if;
    -- Função desativada não pode ser ADICIONADA; se a pessoa já a tinha, pode permanecer.
    if not v_ativa and not exists (
      select 1 from public.aptidoes a where a.funcao_id = v_funcao and a.perfil_id = p_perfil
    ) then
      raise exception 'funcao_invalida';
    end if;

    v_ids := v_ids || v_funcao;
    insert into public.aptidoes (funcao_id, perfil_id, tipo)
    values (v_funcao, p_perfil, v_tipo::public.tipo_aptidao)
    on conflict (funcao_id, perfil_id) do update set tipo = excluded.tipo;
  end loop;

  delete from public.aptidoes a
   using public.funcoes_ministerio f
   where a.funcao_id = f.id
     and f.ministerio_id = p_ministerio
     and a.perfil_id = p_perfil
     and not (a.funcao_id = any (v_ids));
end;
$$;

-- Funções do ministério. Gestor e participantes leem; quem não participa recebe lista vazia.
-- Só o gestor pode pedir as desativadas (participante comum vê sempre só as ativas).
create function public.listar_funcoes(p_ministerio uuid, p_incluir_inativas boolean default false)
returns table (id uuid, nome text, ativa boolean)
language plpgsql
stable
security definer
set search_path = public
as $$
#variable_conflict use_column
declare
  v_gestor boolean;
begin
  if auth.uid() is null then
    return;
  end if;
  v_gestor := public.eh_gestor_de(p_ministerio);
  if not (v_gestor or public.eh_participante_de(p_ministerio)) then
    return;
  end if;
  return query
    select f.id, f.nome, f.ativa
      from public.funcoes_ministerio f
     where f.ministerio_id = p_ministerio
       and (f.ativa or (v_gestor and coalesce(p_incluir_inativas, false)))
     order by f.ativa desc, lower(f.nome);
end;
$$;

-- Aptidões de todos os participantes (só o gestor; nunca devolve email).
create function public.listar_aptidoes(p_ministerio uuid)
returns table (perfil_id uuid, nome text, funcao_id uuid, tipo public.tipo_aptidao)
language plpgsql
stable
security definer
set search_path = public
as $$
#variable_conflict use_column
begin
  if auth.uid() is null or not public.eh_gestor_de(p_ministerio) then
    return;
  end if;
  return query
    select a.perfil_id, p.nome, a.funcao_id, a.tipo
      from public.aptidoes a
      join public.funcoes_ministerio f on f.id = a.funcao_id and f.ministerio_id = p_ministerio
      join public.participacoes_ministerio pm on pm.ministerio_id = p_ministerio and pm.perfil_id = a.perfil_id
      join public.perfis p on p.id = a.perfil_id and p.situacao = 'aprovado'
     order by p.nome, lower(f.nome);
end;
$$;

-- As funções em que a própria pessoa é apta neste ministério (só as funções ativas).
create function public.minhas_aptidoes(p_ministerio uuid)
returns table (funcao_id uuid, funcao text, tipo public.tipo_aptidao)
language plpgsql
stable
security definer
set search_path = public
as $$
#variable_conflict use_column
begin
  if auth.uid() is null or not public.eh_participante_de(p_ministerio) then
    return;
  end if;
  return query
    select a.funcao_id, f.nome, a.tipo
      from public.aptidoes a
      join public.funcoes_ministerio f on f.id = a.funcao_id and f.ministerio_id = p_ministerio and f.ativa
     where a.perfil_id = auth.uid()
     order by lower(f.nome);
end;
$$;

revoke execute on function public.criar_funcao(uuid, text) from public, anon;
grant execute on function public.criar_funcao(uuid, text) to authenticated;
revoke execute on function public.editar_funcao(uuid, text) from public, anon;
grant execute on function public.editar_funcao(uuid, text) to authenticated;
revoke execute on function public.desativar_funcao(uuid) from public, anon;
grant execute on function public.desativar_funcao(uuid) to authenticated;
revoke execute on function public.reativar_funcao(uuid) from public, anon;
grant execute on function public.reativar_funcao(uuid) to authenticated;
revoke execute on function public.definir_aptidoes(uuid, uuid, jsonb) from public, anon;
grant execute on function public.definir_aptidoes(uuid, uuid, jsonb) to authenticated;
revoke execute on function public.listar_funcoes(uuid, boolean) from public, anon;
grant execute on function public.listar_funcoes(uuid, boolean) to authenticated;
revoke execute on function public.listar_aptidoes(uuid) from public, anon;
grant execute on function public.listar_aptidoes(uuid) to authenticated;
revoke execute on function public.minhas_aptidoes(uuid) from public, anon;
grant execute on function public.minhas_aptidoes(uuid) to authenticated;
