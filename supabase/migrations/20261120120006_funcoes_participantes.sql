-- Participantes e líderes de um ministério (RF-009 a RF-014).
-- Contrato: specs/002-ministerios-participantes/contracts/banco-rpc.md
--
-- Erros levantados (a mensagem é o código; o app traduz para português):
--   sem_permissao, nao_encontrado, ministerio_inativo, pessoa_invalida, ja_participa,
--   transicao_invalida e ultimo_lider (este vem do gatilho de 20261120120004).

-- Auxiliar interna: confere que quem chama pode GERIR este ministério: administrador, ou líder
-- válido dele (ministério ativo, conta aprovada). Devolve o ministério.
--  * ministério inexistente: administrador é avisado (nao_encontrado); os demais recebem
--    sem_permissao, para não revelar quais ministérios existem;
--  * ministério desativado: só o administrador chega até aqui, e recebe ministerio_inativo.
create function public.exigir_gestor_ministerio(p_ministerio uuid)
returns public.ministerios
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_admin boolean;
  v_ministerio public.ministerios;
begin
  if auth.uid() is null then
    raise exception 'sem_permissao';
  end if;
  -- coalesce: para conta pendente, recusada ou sem acesso `papel_aprovado_atual()` é NULL, e um NULL
  -- aqui faria o `if`/`not` abaixo pular a checagem de permissão. Sempre verdadeiro ou falso.
  v_admin := coalesce(public.papel_aprovado_atual() = 'administrador', false);

  select * into v_ministerio from public.ministerios where id = p_ministerio;
  if not found then
    raise exception using message = case when v_admin then 'nao_encontrado' else 'sem_permissao' end;
  end if;

  if not (v_admin or public.eh_lider_de(p_ministerio)) then
    raise exception 'sem_permissao';
  end if;
  if not v_ministerio.ativo then
    raise exception 'ministerio_inativo';
  end if;
  return v_ministerio;
end;
$$;

revoke execute on function public.exigir_gestor_ministerio(uuid) from public, anon, authenticated;

-- Adiciona uma pessoa com conta APROVADA ao ministério (RF-011). Se ela tinha pedido pendente
-- para este ministério, o pedido passa a "aceito" na mesma operação.
create function public.adicionar_participante(
  p_ministerio uuid,
  p_perfil uuid,
  p_papel public.papel_ministerio
)
returns public.participacoes_ministerio
language plpgsql
security definer
set search_path = public
as $$
declare
  v_participacao public.participacoes_ministerio;
begin
  perform public.exigir_gestor_ministerio(p_ministerio);

  if p_papel is null then
    raise exception 'transicao_invalida';
  end if;
  if p_perfil is null
     or not exists (select 1 from public.perfis where id = p_perfil and situacao = 'aprovado') then
    raise exception 'pessoa_invalida';
  end if;

  begin
    insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel, adicionado_por)
    values (p_ministerio, p_perfil, p_papel, auth.uid())
    returning * into v_participacao;
  exception when unique_violation then
    raise exception 'ja_participa';
  end;

  update public.pedidos_entrada_ministerio
     set situacao = 'aceito', decidido_por = auth.uid(), decidido_em = now()
   where ministerio_id = p_ministerio and perfil_id = p_perfil and situacao = 'pendente';

  return v_participacao;
end;
$$;

-- Troca o papel entre participante e líder, só NESTE ministério (RF-010). Rebaixar o último
-- líder válido é barrado pelo gatilho (ultimo_lider).
create function public.alterar_papel_ministerio(
  p_ministerio uuid,
  p_perfil uuid,
  p_papel public.papel_ministerio
)
returns public.participacoes_ministerio
language plpgsql
security definer
set search_path = public
as $$
declare
  v_participacao public.participacoes_ministerio;
begin
  perform public.exigir_gestor_ministerio(p_ministerio);

  if p_papel is null then
    raise exception 'transicao_invalida';
  end if;

  update public.participacoes_ministerio
     set papel = p_papel
   where ministerio_id = p_ministerio and perfil_id = p_perfil
  returning * into v_participacao;

  if not found then
    raise exception 'nao_encontrado';
  end if;
  return v_participacao;
end;
$$;

-- Remove a participação (RF-011). Remover o último líder válido é barrado pelo gatilho.
create function public.remover_participante(p_ministerio uuid, p_perfil uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.exigir_gestor_ministerio(p_ministerio);

  delete from public.participacoes_ministerio
   where ministerio_id = p_ministerio and perfil_id = p_perfil;

  if not found then
    raise exception 'nao_encontrado';
  end if;
end;
$$;

-- Busca pessoas para adicionar: contas aprovadas que AINDA NÃO participam do ministério e cujo
-- nome contém o termo (sem diferenciar acento nem caixa). Devolve só id e nome, nunca email
-- (constituição V). Mínimo de 2 letras e no máximo 20 resultados.
create function public.buscar_pessoas(p_ministerio uuid, p_termo text)
returns table (id uuid, nome text)
language plpgsql
stable
security definer
set search_path = public
as $$
#variable_conflict use_column
declare
  v_termo text := public.normalizar_nome_ministerio(coalesce(p_termo, ''));
begin
  perform public.exigir_gestor_ministerio(p_ministerio);

  if char_length(v_termo) < 2 then
    return;
  end if;
  -- Caracteres especiais do LIKE valem como texto comum.
  v_termo := replace(replace(replace(v_termo, '\', '\\'), '%', '\%'), '_', '\_');

  return query
    select p.id, p.nome
      from public.perfis p
     where p.situacao = 'aprovado'
       and public.normalizar_nome_ministerio(p.nome) like '%' || v_termo || '%'
       and not exists (
         select 1 from public.participacoes_ministerio pm
          where pm.ministerio_id = p_ministerio and pm.perfil_id = p.id
       )
     order by p.nome
     limit 20;
end;
$$;

-- Lista quem faz parte do ministério: nome e papel, nunca email (RF-030, RF-031).
--  * administrador vê qualquer ministério; os demais, só ministério ATIVO de que participam;
--  * quem não pode ver recebe lista VAZIA (não erro), para não revelar o ministério;
--  * só aparecem pessoas com conta aprovada: quem foi recusado, perdeu o acesso ou excluiu a
--    conta não aparece (o vínculo continua registrado e volta se a conta for reaprovada).
create function public.listar_participantes(p_ministerio uuid)
returns table (perfil_id uuid, nome text, papel public.papel_ministerio, desde timestamptz)
language plpgsql
stable
security definer
set search_path = public
as $$
#variable_conflict use_column
declare
  -- coalesce: sem ele, conta não aprovada daria NULL e pularia a checagem de participação abaixo.
  v_admin boolean := coalesce(auth.uid() is not null and public.papel_aprovado_atual() = 'administrador', false);
  v_ativo boolean;
begin
  if auth.uid() is null then
    return;
  end if;

  select m.ativo into v_ativo from public.ministerios m where m.id = p_ministerio;
  if not found then
    return;
  end if;

  if not v_admin then
    if not v_ativo then
      return;
    end if;
    -- Precisa participar (qualquer papel) com a conta aprovada.
    if not exists (
      select 1
        from public.participacoes_ministerio pm
        join public.perfis p on p.id = pm.perfil_id and p.situacao = 'aprovado'
       where pm.ministerio_id = p_ministerio and pm.perfil_id = auth.uid()
    ) then
      return;
    end if;
  end if;

  return query
    select pm.perfil_id, p.nome, pm.papel, pm.desde
      from public.participacoes_ministerio pm
      join public.perfis p on p.id = pm.perfil_id and p.situacao = 'aprovado'
     where pm.ministerio_id = p_ministerio
     order by (pm.papel = 'lider') desc, p.nome;
end;
$$;

revoke execute on function public.adicionar_participante(uuid, uuid, public.papel_ministerio) from public, anon;
grant execute on function public.adicionar_participante(uuid, uuid, public.papel_ministerio) to authenticated;
revoke execute on function public.alterar_papel_ministerio(uuid, uuid, public.papel_ministerio) from public, anon;
grant execute on function public.alterar_papel_ministerio(uuid, uuid, public.papel_ministerio) to authenticated;
revoke execute on function public.remover_participante(uuid, uuid) from public, anon;
grant execute on function public.remover_participante(uuid, uuid) to authenticated;
revoke execute on function public.buscar_pessoas(uuid, text) from public, anon;
grant execute on function public.buscar_pessoas(uuid, text) to authenticated;
revoke execute on function public.listar_participantes(uuid) from public, anon;
grant execute on function public.listar_participantes(uuid) to authenticated;
