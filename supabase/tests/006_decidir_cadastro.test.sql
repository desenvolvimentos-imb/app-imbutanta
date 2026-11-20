-- T045: função decidir_cadastro (RF-011, RF-012, RF-013).
begin;
create extension if not exists pgtap with schema extensions;
select plan(19);

insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role) values
  ('00000000-0000-0000-0000-0000000000f1', 'adm.f@exemplo.com', now(),  '{"nome":"Adm F"}',  'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000000f2', 'lid.f@exemplo.com', now(),  '{"nome":"Lid F"}',  'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000000f3', 'mem.f@exemplo.com', now(),  '{"nome":"Mem F"}',  'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000000f4', 'pen1.f@exemplo.com', now(), '{"nome":"Pen Um"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000000f5', 'pen2.f@exemplo.com', now(), '{"nome":"Pen Dois"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000000f6', 'pen3.f@exemplo.com', now(), '{"nome":"Pen Tres"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000000f7', 'pnv.f@exemplo.com',  null,  '{"nome":"Pen NV"}',  'authenticated', 'authenticated');
update public.perfis set situacao = 'aprovado', papel = 'administrador' where id = '00000000-0000-0000-0000-0000000000f1';
update public.perfis set situacao = 'aprovado', papel = 'membro'        where id = '00000000-0000-0000-0000-0000000000f2';
-- f2 lidera um ministério; desde a 002 só o administrador decide cadastros (líder decide PEDIDOS).
insert into public.ministerios (id, nome, descricao) values ('00000000-0000-0000-0000-00000000aa06', 'Teste decidir cadastro', '');
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel)
  values ('00000000-0000-0000-0000-00000000aa06', '00000000-0000-0000-0000-0000000000f2', 'lider');
update public.perfis set situacao = 'aprovado', papel = 'membro'        where id = '00000000-0000-0000-0000-0000000000f3';

-- ===== Líder de ministério NÃO decide cadastro (só pedidos) =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-0000000000f2", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.decidir_cadastro('00000000-0000-0000-0000-0000000000f4', 'aprovar', 'pendente') $$,
                 'P0001', 'sem_permissao', 'líder de ministério não aprova cadastro (só o administrador)');
reset role;

-- ===== Administrador aprova =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-0000000000f1", "role": "authenticated"}', true);
set local role authenticated;
select lives_ok($$ select public.decidir_cadastro('00000000-0000-0000-0000-0000000000f4', 'aprovar', 'pendente') $$,
                'administrador aprova um pendente');
reset role;
select is((select situacao::text from public.perfis where id = '00000000-0000-0000-0000-0000000000f4'), 'aprovado', 'aprovado: situação');
select is((select papel::text from public.perfis where id = '00000000-0000-0000-0000-0000000000f4'), 'membro', 'aprovado entra como membro');
select is((select decidido_por from public.perfis where id = '00000000-0000-0000-0000-0000000000f4'),
          '00000000-0000-0000-0000-0000000000f1'::uuid, 'registra quem decidiu');
select isnt((select decidido_em from public.perfis where id = '00000000-0000-0000-0000-0000000000f4'), null, 'registra quando decidiu');

-- ===== Líder: conflito (segunda decisão sobre a mesma pessoa) =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-0000000000f1", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.decidir_cadastro('00000000-0000-0000-0000-0000000000f4', 'recusar', 'pendente') $$,
                 'P0001', 'conflito_situacao', 'segunda decisão sobre a mesma pessoa gera conflito');

-- ===== Líder recusa =====
select lives_ok($$ select public.decidir_cadastro('00000000-0000-0000-0000-0000000000f5', 'recusar', 'pendente') $$,
                'administrador recusa um pendente');
-- ===== Casos inválidos =====
select throws_ok($$ select public.decidir_cadastro('00000000-0000-0000-0000-0000000000f6', 'talvez', 'pendente') $$,
                 'P0001', 'transicao_invalida', 'decisão desconhecida é rejeitada');
select throws_ok($$ select public.decidir_cadastro('00000000-0000-0000-0000-0000000000f5', 'aprovar', 'recusado') $$,
                 'P0001', 'transicao_invalida', 'administrador não reabre recusado (só pela gestão de usuários do administrador)');
select throws_ok($$ select public.decidir_cadastro('00000000-0000-0000-0000-0000000000f7', 'aprovar', 'pendente') $$,
                 'P0001', 'transicao_invalida', 'pendente com email NÃO verificado não pode ser aprovado');
select throws_ok($$ select public.decidir_cadastro('99999999-9999-9999-9999-999999999999', 'aprovar', 'pendente') $$,
                 'P0001', 'nao_encontrado', 'pessoa inexistente');
select throws_ok($$ select public.decidir_cadastro('00000000-0000-0000-0000-0000000000f1', 'aprovar', 'pendente') $$,
                 'P0001', 'sem_permissao', 'ninguém decide sobre si mesmo');
reset role;

-- ===== Administrador também decide =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-0000000000f1", "role": "authenticated"}', true);
set local role authenticated;
select lives_ok($$ select public.decidir_cadastro('00000000-0000-0000-0000-0000000000f6', 'aprovar', 'pendente') $$,
                'administrador aprova um pendente');
reset role;

-- ===== Membro não decide =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-0000000000f3", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.decidir_cadastro('00000000-0000-0000-0000-0000000000f6', 'recusar', 'aprovado') $$,
                 'P0001', 'sem_permissao', 'membro não consegue decidir');
reset role;

-- ===== Pendente e recusado não decidem =====
update public.perfis set situacao = 'pendente' where id = '00000000-0000-0000-0000-0000000000f6';
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-0000000000f6", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.decidir_cadastro('00000000-0000-0000-0000-0000000000f7', 'aprovar', 'pendente') $$,
                 'P0001', 'sem_permissao', 'pendente não consegue decidir');
reset role;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-0000000000f5", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.decidir_cadastro('00000000-0000-0000-0000-0000000000f7', 'aprovar', 'pendente') $$,
                 'P0001', 'sem_permissao', 'recusado não consegue decidir');
reset role;

-- ===== Sem login =====
set local role anon;
select throws_ok($$ select public.decidir_cadastro('00000000-0000-0000-0000-0000000000f6', 'aprovar', 'pendente') $$,
                 '42501', null, 'anônimo não executa a função');
reset role;

select is((select situacao::text from public.perfis where id = '00000000-0000-0000-0000-0000000000f7'),
          'pendente', 'a pessoa de email não verificado seguiu pendente durante todos os testes');

select * from finish();
rollback;
