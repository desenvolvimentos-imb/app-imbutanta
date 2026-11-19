-- O app nunca pode ficar sem administrador (RF-022, CS-008). Gatilho no banco, para valer
-- até contra alteração direta (rebaixar, remover acesso ou apagar a conta do último).
--
-- Observação: a proteção de campos (usuário só edita o próprio `nome`) já está nas
-- permissões por coluna de 0003_rls_perfis.sql; não é preciso um gatilho para isso.

create function public.proteger_ultimo_administrador()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Só interessa se a linha ANTES era de um administrador aprovado.
  if old.situacao = 'aprovado' and old.papel = 'administrador' then
    -- ... e se, depois, deixa de ser (rebaixado, acesso removido ou apagado).
    if tg_op = 'DELETE'
       or not (new.situacao = 'aprovado' and new.papel = 'administrador') then
      -- Trava os administradores atuais para que duas operações simultâneas
      -- não removam os dois ao mesmo tempo.
      perform 1 from public.perfis
        where situacao = 'aprovado' and papel = 'administrador'
        for update;

      if not exists (
        select 1 from public.perfis
         where id <> old.id and situacao = 'aprovado' and papel = 'administrador'
      ) then
        raise exception 'ultimo_administrador' using errcode = 'P0001';
      end if;
    end if;
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create trigger trg_proteger_ultimo_administrador
before update or delete on public.perfis
for each row execute function public.proteger_ultimo_administrador();
