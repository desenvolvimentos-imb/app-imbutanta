-- Mantém `perfis` sincronizado com `auth.users` e aplica o administrador inicial.

-- Escolhe um nome válido (2 a 100 caracteres) a partir dos metadados do cadastro.
-- O cadastro nunca pode falhar por causa do nome: o app já valida, e aqui só garantimos
-- um valor aceitável (ex.: contas Google trazem `full_name`).
create function public.nome_dos_metadados(p_meta jsonb, p_email text)
returns text
language sql
immutable
set search_path = public
as $$
  select case
    when char_length(n) >= 2 then left(n, 100)
    else 'Usuário'
  end
  from (
    select btrim(coalesce(
      nullif(btrim(p_meta ->> 'nome'), ''),
      nullif(btrim(p_meta ->> 'full_name'), ''),
      nullif(btrim(p_meta ->> 'name'), ''),
      split_part(p_email, '@', 1)
    )) as n
  ) t;
$$;

-- Dispara quando um usuário é criado ou tem email/confirmação alterados no Auth.
create function public.sincronizar_perfil_auth()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email      text := lower(new.email);
  v_verificado boolean := new.email_confirmed_at is not null;
  v_acabou_de_verificar boolean;
begin
  if tg_op = 'INSERT' then
    insert into public.perfis (id, nome, email, email_verificado)
    values (new.id, public.nome_dos_metadados(new.raw_user_meta_data, v_email), v_email, v_verificado);
    v_acabou_de_verificar := v_verificado;
  else
    update public.perfis
       set email = v_email, email_verificado = v_verificado
     where id = new.id;
    v_acabou_de_verificar := v_verificado and old.email_confirmed_at is null;
  end if;

  -- Administrador inicial: só vale com email VERIFICADO, para que um terceiro não vire
  -- administrador criando uma conta com o email do dono do projeto.
  if v_acabou_de_verificar
     and exists (select 1 from public.administradores_iniciais where email = v_email) then
    update public.perfis
       set situacao = 'aprovado', papel = 'administrador'
     where id = new.id;
  end if;

  return new;
end;
$$;

create trigger trg_sincronizar_perfil_auth
after insert or update of email, email_confirmed_at on auth.users
for each row execute function public.sincronizar_perfil_auth();
