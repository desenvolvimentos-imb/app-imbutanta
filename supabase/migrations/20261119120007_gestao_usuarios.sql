-- Gestão de usuários pelo administrador (RF-021, RF-022).
-- Contrato: specs/001-login-papeis-acesso/contracts/banco-rpc.md
--
-- Erros (a mensagem é o código): sem_permissao, conflito_situacao, transicao_invalida,
-- nao_encontrado e ultimo_administrador (este vem do gatilho de 0004).

-- Descobre por que um update não afetou nenhuma linha, para dar o erro certo.
create function public.explicar_falha_gestao(p_perfil uuid, p_situacao_esperada public.situacao_conta)
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_atual public.situacao_conta;
begin
  select situacao into v_atual from public.perfis where id = p_perfil;
  if not found then
    raise exception 'nao_encontrado';
  elsif v_atual <> p_situacao_esperada then
    raise exception 'conflito_situacao';
  end if;
  raise exception 'transicao_invalida';
end;
$$;

revoke execute on function public.explicar_falha_gestao(uuid, public.situacao_conta) from public, anon, authenticated;

-- Altera o papel de uma pessoa APROVADA.
create function public.alterar_papel(
  p_perfil uuid,
  p_papel public.papel_usuario,
  p_situacao_esperada public.situacao_conta
)
returns public.perfis
language plpgsql
security definer
set search_path = public
as $$
declare
  v_resultado public.perfis;
begin
  if auth.uid() is null or public.papel_aprovado_atual() is distinct from 'administrador' then
    raise exception 'sem_permissao';
  end if;

  -- Papel só tem efeito para quem está aprovado.
  if p_situacao_esperada <> 'aprovado' then
    raise exception 'transicao_invalida';
  end if;

  -- Se for o único administrador sendo rebaixado, o gatilho levanta 'ultimo_administrador'.
  update public.perfis
     set papel = p_papel, decidido_por = auth.uid(), decidido_em = now()
   where id = p_perfil and situacao = p_situacao_esperada
  returning * into v_resultado;

  if not found then
    perform public.explicar_falha_gestao(p_perfil, p_situacao_esperada);
  end if;
  return v_resultado;
end;
$$;

-- Remove ou restaura acesso e reabre cadastros recusados. Transições permitidas:
--   aprovado -> acesso_removido | acesso_removido -> aprovado | recusado -> aprovado
-- Quem volta a ser aprovado retorna como membro (papel mais restrito, por segurança).
create function public.alterar_situacao(
  p_perfil uuid,
  p_nova public.situacao_conta,
  p_situacao_esperada public.situacao_conta
)
returns public.perfis
language plpgsql
security definer
set search_path = public
as $$
declare
  v_resultado public.perfis;
begin
  if auth.uid() is null or public.papel_aprovado_atual() is distinct from 'administrador' then
    raise exception 'sem_permissao';
  end if;

  if not (
       (p_situacao_esperada = 'aprovado'        and p_nova = 'acesso_removido')
    or (p_situacao_esperada = 'acesso_removido' and p_nova = 'aprovado')
    or (p_situacao_esperada = 'recusado'        and p_nova = 'aprovado')
  ) then
    raise exception 'transicao_invalida';
  end if;

  -- Se for o único administrador perdendo o acesso, o gatilho levanta 'ultimo_administrador'.
  update public.perfis
     set situacao = p_nova,
         papel = case when p_nova = 'aprovado' then 'membro' else papel end,
         decidido_por = auth.uid(),
         decidido_em = now()
   where id = p_perfil and situacao = p_situacao_esperada
  returning * into v_resultado;

  if not found then
    perform public.explicar_falha_gestao(p_perfil, p_situacao_esperada);
  end if;
  return v_resultado;
end;
$$;

revoke execute on function public.alterar_papel(uuid, public.papel_usuario, public.situacao_conta) from public, anon;
grant execute on function public.alterar_papel(uuid, public.papel_usuario, public.situacao_conta) to authenticated;
revoke execute on function public.alterar_situacao(uuid, public.situacao_conta, public.situacao_conta) from public, anon;
grant execute on function public.alterar_situacao(uuid, public.situacao_conta, public.situacao_conta) to authenticated;
