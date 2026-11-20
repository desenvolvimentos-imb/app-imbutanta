-- DADOS DE TESTE: APENAS AMBIENTE LOCAL (`npx supabase db reset`).
-- Nunca rodar em desenvolvimento online ou produção: as senhas abaixo são públicas.
--
-- Todas as contas usam a senha:  Senha1234
--
--   admin@teste.local      administrador (nasce assim pelo mecanismo de administrador inicial);
--                          também lidera o ministério "Recepção"
--   lider@teste.local      membro que lidera o ministério "Louvor" (liderança é por ministério)
--   membro@teste.local     membro aprovado, participante do "Louvor"
--   pendente@teste.local   aguardando aprovação (email verificado) com pedido pendente para o "Louvor"
--   recusado@teste.local   cadastro recusado
--
-- Ministérios de teste: "Louvor" e "Recepção" (ativos) e "Teatro" (desativado, com histórico).

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
update public.perfis set situacao = 'aprovado', papel = 'membro'
 where id = '11111111-1111-1111-1111-111111111102';
update public.perfis set situacao = 'aprovado', papel = 'membro'
 where id = '11111111-1111-1111-1111-111111111103';
update public.perfis set situacao = 'recusado'
 where id = '11111111-1111-1111-1111-111111111105';

-- Ministérios de teste (specs/002-ministerios-participantes). "Teatro" está desativado para
-- validar que o histórico é preservado.
insert into public.ministerios (id, nome, descricao, ativo, desativado_em) values
  ('22222222-2222-2222-2222-222222222201', 'Louvor',   'Música e adoração nos cultos.', true,  null),
  ('22222222-2222-2222-2222-222222222202', 'Recepção', 'Acolhe as pessoas na chegada.', true,  null),
  ('22222222-2222-2222-2222-222222222203', 'Teatro',   'Ministério encerrado (histórico).', false, now());

insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel) values
  ('22222222-2222-2222-2222-222222222201', '11111111-1111-1111-1111-111111111102', 'lider'),
  ('22222222-2222-2222-2222-222222222201', '11111111-1111-1111-1111-111111111103', 'participante'),
  ('22222222-2222-2222-2222-222222222202', '11111111-1111-1111-1111-111111111101', 'lider'),
  ('22222222-2222-2222-2222-222222222203', '11111111-1111-1111-1111-111111111102', 'lider'),
  ('22222222-2222-2222-2222-222222222203', '11111111-1111-1111-1111-111111111103', 'participante');

-- A pessoa pendente pediu o Louvor no cadastro: o líder do Louvor pode aceitar e ativar a conta.
insert into public.pedidos_entrada_ministerio (ministerio_id, perfil_id, origem_cadastro) values
  ('22222222-2222-2222-2222-222222222201', '11111111-1111-1111-1111-111111111104', true);
