-- Excluir a própria conta e os dados pessoais (RF-030, RF-031; LGPD).
--
-- Apaga a linha da pessoa em auth.users; o perfil (nome, email), as identidades (Google) e
-- as sessões saem junto por "on delete cascade". Roda como dono da função (security definer)
-- para não precisar da chave service_role no app (constituição V).
-- Contrato: specs/001-login-papeis-acesso/contracts/banco-rpc.md
--
-- Atua SEMPRE sobre auth.uid(): não recebe id, então ninguém exclui conta alheia.
-- O gatilho do último administrador barra a exclusão do único administrador.

create function public.excluir_minha_conta()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'sem_permissao';
  end if;

  delete from auth.users where id = auth.uid();
end;
$$;

revoke execute on function public.excluir_minha_conta() from public, anon;
grant execute on function public.excluir_minha_conta() to authenticated;
