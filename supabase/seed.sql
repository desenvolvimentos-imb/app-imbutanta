-- DADOS DE TESTE: APENAS AMBIENTE LOCAL (`npx supabase db reset`).
-- Nunca rodar em desenvolvimento online ou produção: as senhas abaixo são públicas.
--
-- Todas as contas usam a senha:  Senha1234
--
--   admin@teste.local      administrador (nasce assim pelo mecanismo de administrador inicial)
--   lider@teste.local      líder de ministério
--   membro@teste.local     membro aprovado
--   pendente@teste.local   aguardando aprovação (email verificado, aparece na fila)
--   recusado@teste.local   cadastro recusado

-- O administrador entra pelo mesmo caminho do dono do projeto em produção:
-- email na lista de iniciais + email confirmado.
insert into public.administradores_iniciais (email) values ('admin@teste.local');

-- Cria um usuário no Auth já com identidade de email/senha (como o Supabase faria).
create function pg_temp.criar_usuario(p_id uuid, p_email text, p_nome text)
returns void
language plpgsql
as $$
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) values (
    '00000000-0000-0000-0000-000000000000', p_id, 'authenticated', 'authenticated',
    p_email, extensions.crypt('Senha1234', extensions.gen_salt('bf')), now(),
    '{"provider": "email", "providers": ["email"]}',
    jsonb_build_object('nome', p_nome, 'email_verified', true),
    now(), now(), '', '', '', ''
  );

  insert into auth.identities (
    id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at
  ) values (
    gen_random_uuid(), p_id, p_id::text,
    jsonb_build_object('sub', p_id::text, 'email', p_email, 'email_verified', true),
    'email', now(), now(), now()
  );
end;
$$;

select pg_temp.criar_usuario('11111111-1111-1111-1111-111111111101', 'admin@teste.local',    'Ana Administradora');
select pg_temp.criar_usuario('11111111-1111-1111-1111-111111111102', 'lider@teste.local',    'Lucas Líder');
select pg_temp.criar_usuario('11111111-1111-1111-1111-111111111103', 'membro@teste.local',   'Marta Membro');
select pg_temp.criar_usuario('11111111-1111-1111-1111-111111111104', 'pendente@teste.local', 'Paulo Pendente');
select pg_temp.criar_usuario('11111111-1111-1111-1111-111111111105', 'recusado@teste.local', 'Rita Recusada');

-- O gatilho já criou os perfis (pendentes); ajustamos os demais.
update public.perfis set situacao = 'aprovado', papel = 'lider'
 where id = '11111111-1111-1111-1111-111111111102';
update public.perfis set situacao = 'aprovado', papel = 'membro'
 where id = '11111111-1111-1111-1111-111111111103';
update public.perfis set situacao = 'recusado'
 where id = '11111111-1111-1111-1111-111111111105';
