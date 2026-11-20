-- Funções de ministério, exclusivas do administrador (RF-001 a RF-007).
-- Contrato: specs/002-ministerios-participantes/contracts/banco-rpc.md
--
-- Erros levantados (a mensagem é o código; o app traduz para português):
--   sem_permissao, nome_invalido, nome_duplicado, pessoa_invalida, nao_encontrado, sem_lider

-- Auxiliar interna: só o administrador APROVADO passa. Não é exposta à API.
create function public.exigir_administrador()
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or public.papel_aprovado_atual() is distinct from 'administrador' then
    raise exception 'sem_permissao';
  end if;
end;
$$;

-- Auxiliar interna: nome de 2 a 60 caracteres e descrição de até 200 (RF-006).
create function public.validar_dados_ministerio(p_nome text, p_descricao text)
returns void
language plpgsql
immutable
set search_path = public
as $$
begin
  if p_nome is null or char_length(p_nome) not between 2 and 60 or char_length(coalesce(p_descricao, '')) > 200 then
    raise exception 'nome_invalido';
  end if;
end;
$$;

revoke execute on function public.exigir_administrador() from public, anon, authenticated;
revoke execute on function public.validar_dados_ministerio(text, text) from public, anon, authenticated;

-- Cria o ministério e o líder inicial na MESMA transação: nenhum ministério ativo nasce sem
-- líder (RF-001, RF-012).
create function public.criar_ministerio(p_nome text, p_descricao text, p_lider uuid)
returns public.ministerios
language plpgsql
security definer
set search_path = public
as $$
declare
  v_nome      text := btrim(coalesce(p_nome, ''));
  v_descricao text := btrim(coalesce(p_descricao, ''));
  v_ministerio public.ministerios;
begin
  perform public.exigir_administrador();
  perform public.validar_dados_ministerio(v_nome, v_descricao);

  -- O líder inicial precisa existir e ter conta aprovada.
  if p_lider is null
     or not exists (select 1 from public.perfis where id = p_lider and situacao = 'aprovado') then
    raise exception 'pessoa_invalida';
  end if;

  begin
    insert into public.ministerios (nome, descricao)
    values (v_nome, v_descricao)
    returning * into v_ministerio;
  exception when unique_violation then
    -- Índice único parcial: já existe ministério ATIVO com esse nome (RF-005).
    raise exception 'nome_duplicado';
  end;

  insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel, adicionado_por)
  values (v_ministerio.id, p_lider, 'lider', auth.uid());

  return v_ministerio;
end;
$$;

create function public.editar_ministerio(p_id uuid, p_nome text, p_descricao text)
returns public.ministerios
language plpgsql
security definer
set search_path = public
as $$
declare
  v_nome      text := btrim(coalesce(p_nome, ''));
  v_descricao text := btrim(coalesce(p_descricao, ''));
  v_ministerio public.ministerios;
begin
  perform public.exigir_administrador();
  perform public.validar_dados_ministerio(v_nome, v_descricao);

  begin
    update public.ministerios
       set nome = v_nome, descricao = v_descricao
     where id = p_id
    returning * into v_ministerio;
  exception when unique_violation then
    raise exception 'nome_duplicado';
  end;

  if not found then
    raise exception 'nao_encontrado';
  end if;
  return v_ministerio;
end;
$$;

-- Desativar NÃO apaga nada: participações e pedidos ficam como histórico (RF-003). Quem depende
-- do ministério (pedir entrada, decidir pedidos, liderar) passa a exigir `ativo`.
create function public.desativar_ministerio(p_id uuid)
returns public.ministerios
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ministerio public.ministerios;
begin
  perform public.exigir_administrador();

  update public.ministerios
     set ativo = false, desativado_em = coalesce(desativado_em, now())
   where id = p_id
  returning * into v_ministerio;

  if not found then
    raise exception 'nao_encontrado';
  end if;
  return v_ministerio;
end;
$$;

-- Reativar exige nome livre entre os ativos e pelo menos um líder válido; se não houver,
-- o administrador informa um (que vira líder) na própria reativação.
create function public.reativar_ministerio(p_id uuid, p_lider uuid default null)
returns public.ministerios
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ministerio public.ministerios;
begin
  perform public.exigir_administrador();

  select * into v_ministerio from public.ministerios where id = p_id for update;
  if not found then
    raise exception 'nao_encontrado';
  end if;
  if v_ministerio.ativo then
    return v_ministerio; -- já está ativo: nada a fazer
  end if;

  if not exists (
    select 1
      from public.participacoes_ministerio pm
      join public.perfis p on p.id = pm.perfil_id and p.situacao = 'aprovado'
     where pm.ministerio_id = p_id and pm.papel = 'lider'
  ) then
    if p_lider is null then
      raise exception 'sem_lider';
    end if;
    if not exists (select 1 from public.perfis where id = p_lider and situacao = 'aprovado') then
      raise exception 'pessoa_invalida';
    end if;
    insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel, adicionado_por)
    values (p_id, p_lider, 'lider', auth.uid())
    on conflict (ministerio_id, perfil_id) do update set papel = 'lider';
  end if;

  begin
    update public.ministerios
       set ativo = true, desativado_em = null
     where id = p_id
    returning * into v_ministerio;
  exception when unique_violation then
    -- Outro ministério ativo já usa o nome: a transação inteira é desfeita.
    raise exception 'nome_duplicado';
  end;

  return v_ministerio;
end;
$$;

revoke execute on function public.criar_ministerio(text, text, uuid) from public, anon;
grant execute on function public.criar_ministerio(text, text, uuid) to authenticated;
revoke execute on function public.editar_ministerio(uuid, text, text) from public, anon;
grant execute on function public.editar_ministerio(uuid, text, text) to authenticated;
revoke execute on function public.desativar_ministerio(uuid) from public, anon;
grant execute on function public.desativar_ministerio(uuid) to authenticated;
revoke execute on function public.reativar_ministerio(uuid, uuid) from public, anon;
grant execute on function public.reativar_ministerio(uuid, uuid) to authenticated;
