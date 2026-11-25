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

-- ===== Escalas (specs/003-escalas-ministerios) =====
-- Ana (líder da Recepção) CONFIRMOU a escala da Recepção no mesmo dia da escala publicada do Louvor.
-- Para ver o aviso "participante já escalado em outro ministério neste mesmo dia", adicione a Ana como
-- participante do Louvor (pela tela do ministério) e escale-a numa vaga do Louvor desse dia.
-- (Ela não é participante do Louvor no seed para não alterar os testes das funcionalidades 001 e 002.)

insert into public.funcoes_ministerio (id, ministerio_id, nome) values
  ('33333333-3333-3333-3333-333333333301', '22222222-2222-2222-2222-222222222201', 'Vocal'),
  ('33333333-3333-3333-3333-333333333302', '22222222-2222-2222-2222-222222222201', 'Violão'),
  ('33333333-3333-3333-3333-333333333303', '22222222-2222-2222-2222-222222222201', 'Bateria'),
  ('33333333-3333-3333-3333-333333333304', '22222222-2222-2222-2222-222222222202', 'Recepção');

-- Marta é apta em Vocal (principal) e Violão (secundária); Lucas em Bateria (principal).
insert into public.aptidoes (funcao_id, perfil_id, tipo) values
  ('33333333-3333-3333-3333-333333333301', '11111111-1111-1111-1111-111111111103', 'principal'),
  ('33333333-3333-3333-3333-333333333302', '11111111-1111-1111-1111-111111111103', 'secundaria'),
  ('33333333-3333-3333-3333-333333333303', '11111111-1111-1111-1111-111111111102', 'principal');

-- Louvor: uma escala PUBLICADA daqui a 7 dias (vagas preenchidas e uma em aberto) e um rascunho
-- daqui a 14. Recepção: escala publicada no MESMO dia da do Louvor, com a Ana confirmada.
insert into public.escalas (id, ministerio_id, evento, data, horario, observacao, situacao) values
  ('44444444-4444-4444-4444-444444444401', '22222222-2222-2222-2222-222222222201', 'Culto de domingo', current_date + 7, '09:00', 'Ensaio às 08h.', 'publicada'),
  ('44444444-4444-4444-4444-444444444402', '22222222-2222-2222-2222-222222222201', 'Culto de celebração', current_date + 14, '19:00', '', 'rascunho'),
  ('44444444-4444-4444-4444-444444444403', '22222222-2222-2222-2222-222222222202', 'Recepção do culto', current_date + 7, '08:30', '', 'publicada');

insert into public.vagas_escala (id, escala_id, funcao_id, rotulo, perfil_id, ordem) values
  ('55555555-5555-5555-5555-555555555501', '44444444-4444-4444-4444-444444444401', '33333333-3333-3333-3333-333333333301', 'Vocal 1', '11111111-1111-1111-1111-111111111103', 1),
  ('55555555-5555-5555-5555-555555555502', '44444444-4444-4444-4444-444444444401', '33333333-3333-3333-3333-333333333302', '', '11111111-1111-1111-1111-111111111103', 2),
  ('55555555-5555-5555-5555-555555555503', '44444444-4444-4444-4444-444444444401', '33333333-3333-3333-3333-333333333303', '', '11111111-1111-1111-1111-111111111102', 3),
  ('55555555-5555-5555-5555-555555555504', '44444444-4444-4444-4444-444444444401', '33333333-3333-3333-3333-333333333301', 'Vocal 2', null, 4),
  ('55555555-5555-5555-5555-555555555505', '44444444-4444-4444-4444-444444444402', '33333333-3333-3333-3333-333333333301', '', null, 1),
  ('55555555-5555-5555-5555-555555555506', '44444444-4444-4444-4444-444444444403', '33333333-3333-3333-3333-333333333304', '', '11111111-1111-1111-1111-111111111101', 1);

-- Lucas já confirmou; Marta ainda não respondeu (pendente); Ana confirmou a Recepção.
insert into public.respostas_escala (escala_id, perfil_id, resposta, motivo) values
  ('44444444-4444-4444-4444-444444444401', '11111111-1111-1111-1111-111111111102', 'confirmado', ''),
  ('44444444-4444-4444-4444-444444444403', '11111111-1111-1111-1111-111111111101', 'confirmado', '');

-- ===== Disponibilidade (specs/004-disponibilidade-participantes) =====
-- Louvor: consulta ABERTA "Escala de dezembro" com 4 datas (a primeira coincide com a escala publicada
-- de exemplo, para validar o aviso ao escalar, e traz o rótulo "Culto especial") e prazo daqui a
-- alguns dias. Marta respondeu parte (a segunda resposta foi preenchida pelo líder), Lucas ainda não
-- respondeu nada. Mais uma consulta FECHADA, no histórico.
insert into public.consultas_disponibilidade (id, ministerio_id, titulo, mensagem, prazo, fechada, criada_por) values
  ('66666666-6666-6666-6666-666666666601', '22222222-2222-2222-2222-222222222201', 'Escala de dezembro',
   'Marquem as datas em que podem servir.', current_date + 5, false, '11111111-1111-1111-1111-111111111102'),
  ('66666666-6666-6666-6666-666666666602', '22222222-2222-2222-2222-222222222201', 'Escala de novembro',
   '', null, true, '11111111-1111-1111-1111-111111111102');
insert into public.datas_consulta (id, consulta_id, ministerio_id, data, rotulo) values
  ('77777777-7777-7777-7777-777777777701', '66666666-6666-6666-6666-666666666601', '22222222-2222-2222-2222-222222222201', current_date + 7, 'Culto especial'),
  ('77777777-7777-7777-7777-777777777702', '66666666-6666-6666-6666-666666666601', '22222222-2222-2222-2222-222222222201', current_date + 14, ''),
  ('77777777-7777-7777-7777-777777777703', '66666666-6666-6666-6666-666666666601', '22222222-2222-2222-2222-222222222201', current_date + 21, ''),
  ('77777777-7777-7777-7777-777777777704', '66666666-6666-6666-6666-666666666601', '22222222-2222-2222-2222-222222222201', current_date + 28, ''),
  ('77777777-7777-7777-7777-777777777705', '66666666-6666-6666-6666-666666666602', '22222222-2222-2222-2222-222222222201', current_date - 20, ''),
  ('77777777-7777-7777-7777-777777777706', '66666666-6666-6666-6666-666666666602', '22222222-2222-2222-2222-222222222201', current_date - 13, '');
insert into public.respostas_disponibilidade (data_id, perfil_id, resposta, preenchida_por) values
  ('77777777-7777-7777-7777-777777777701', '11111111-1111-1111-1111-111111111103', 'indisponivel', null),
  ('77777777-7777-7777-7777-777777777702', '11111111-1111-1111-1111-111111111103', 'disponivel', '11111111-1111-1111-1111-111111111102'),
  ('77777777-7777-7777-7777-777777777705', '11111111-1111-1111-1111-111111111103', 'disponivel', null),
  ('77777777-7777-7777-7777-777777777705', '11111111-1111-1111-1111-111111111102', 'disponivel', null),
  ('77777777-7777-7777-7777-777777777706', '11111111-1111-1111-1111-111111111102', 'indisponivel', null);
insert into public.observacoes_disponibilidade (consulta_id, perfil_id, texto) values
  ('66666666-6666-6666-6666-666666666601', '11111111-1111-1111-1111-111111111103', 'Posso estar nesse dia se for preciso, mas prefiro não.');
