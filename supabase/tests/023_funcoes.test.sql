-- T017: funções do ministério: criar, editar, desativar, reativar e listar (FR-001 a FR-003).
begin;
create extension if not exists pgtap with schema extensions;
select plan(28);

insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role) values
  ('00000000-0000-0000-0000-000000002301', 'adm.23@exemplo.com',  now(), '{"nome":"Adm 23"}',     'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000002302', 'la.23@exemplo.com',   now(), '{"nome":"Lider A 23"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000002303', 'lb.23@exemplo.com',   now(), '{"nome":"Lider B 23"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000002304', 'pa.23@exemplo.com',   now(), '{"nome":"Part A 23"}',  'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000002305', 'fora.23@exemplo.com', now(), '{"nome":"Fora 23"}',    'authenticated', 'authenticated');
update public.perfis set situacao = 'aprovado' where id::text like '00000000-0000-0000-0000-0000000023%';
update public.perfis set papel = 'administrador' where id = '00000000-0000-0000-0000-000000002301';

insert into public.ministerios (id, nome, descricao, ativo, desativado_em) values
  ('00000000-0000-0000-0000-00000023000a', 'Teste Funções A', '', true, null),
  ('00000000-0000-0000-0000-00000023000b', 'Teste Funções B', '', true, null),
  ('00000000-0000-0000-0000-00000023000c', 'Teste Funções Inativo', '', false, now());
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel) values
  ('00000000-0000-0000-0000-00000023000a', '00000000-0000-0000-0000-000000002302', 'lider'),
  ('00000000-0000-0000-0000-00000023000b', '00000000-0000-0000-0000-000000002303', 'lider'),
  ('00000000-0000-0000-0000-00000023000c', '00000000-0000-0000-0000-000000002303', 'lider'),
  ('00000000-0000-0000-0000-00000023000a', '00000000-0000-0000-0000-000000002304', 'participante');

-- ===== Anônimo: a função nem é executável =====
set local role anon;
select throws_ok($$ select public.criar_funcao('00000000-0000-0000-0000-00000023000a', 'Vocal') $$, '42501', null, 'anônimo não executa criar_funcao');
reset role;

-- ===== Líder do A =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002302", "role": "authenticated"}', true);
set local role authenticated;
select is((select (public.criar_funcao('00000000-0000-0000-0000-00000023000a', '  Vocal ')).nome), 'Vocal', 'líder cria a função (nome sem espaços nas pontas)');
select throws_ok($$ select public.criar_funcao('00000000-0000-0000-0000-00000023000a', 'vocal') $$, 'P0001', 'funcao_duplicada', 'nome repetido (caixa) entre ativas');
select lives_ok($$ select public.criar_funcao('00000000-0000-0000-0000-00000023000a', 'Violão') $$, 'cria outra função');
select throws_ok($$ select public.criar_funcao('00000000-0000-0000-0000-00000023000a', 'VIOLAO') $$, 'P0001', 'funcao_duplicada', 'nome repetido (sem acento)');
select throws_ok($$ select public.criar_funcao('00000000-0000-0000-0000-00000023000a', 'A') $$, 'P0001', 'funcao_invalida', 'nome curto demais');
select throws_ok($$ select public.criar_funcao('00000000-0000-0000-0000-00000023000a', repeat('x', 41)) $$, 'P0001', 'funcao_invalida', 'nome longo demais');
select throws_ok($$ select public.criar_funcao('00000000-0000-0000-0000-00000023000b', 'Vocal') $$, 'P0001', 'sem_permissao', 'líder do A não cria função no B');

-- Editar
select is((select (public.editar_funcao((select id from public.funcoes_ministerio where nome = 'Violão' and ministerio_id = '00000000-0000-0000-0000-00000023000a'), 'Violão Solo')).nome),
          'Violão Solo', 'líder renomeia a função');
select throws_ok($$ select public.editar_funcao((select id from public.funcoes_ministerio where nome = 'Violão Solo'), 'vocal') $$,
                 'P0001', 'funcao_duplicada', 'renomear para nome de função ativa');
select throws_ok($$ select public.editar_funcao('99999999-9999-9999-9999-999999999999', 'Qualquer') $$,
                 'P0001', 'sem_permissao', 'função inexistente: líder recebe sem_permissao (não revela o que existe)');

-- Vaga existente usa a função; desativar NÃO mexe nela (FR-003)
reset role;
insert into public.escalas (id, ministerio_id, evento, data, horario) values
  ('00000000-0000-0000-0000-00000023e001', '00000000-0000-0000-0000-00000023000a', 'Culto', current_date + 5, '09:00');
insert into public.vagas_escala (id, escala_id, funcao_id, perfil_id) values
  ('00000000-0000-0000-0000-00000023a001', '00000000-0000-0000-0000-00000023e001',
   (select id from public.funcoes_ministerio where nome = 'Vocal' and ministerio_id = '00000000-0000-0000-0000-00000023000a'),
   '00000000-0000-0000-0000-000000002304');
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002302", "role": "authenticated"}', true);
set local role authenticated;

select is((select (public.desativar_funcao((select id from public.funcoes_ministerio where nome = 'Vocal'))).ativa), false, 'desativar a função');
select lives_ok($$ select public.desativar_funcao((select id from public.funcoes_ministerio where nome = 'Vocal' and not ativa)) $$, 'desativar é idempotente');
reset role;
select is((select funcao_id from public.vagas_escala where id = '00000000-0000-0000-0000-00000023a001'),
          (select id from public.funcoes_ministerio where nome = 'Vocal' and not ativa),
          'a vaga existente continua com a função desativada');
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002302", "role": "authenticated"}', true);
set local role authenticated;
select lives_ok($$ select public.criar_funcao('00000000-0000-0000-0000-00000023000a', 'Vocal') $$, 'nome de função desativada pode ser reutilizado');
select throws_ok($$ select public.reativar_funcao((select id from public.funcoes_ministerio where nome = 'Vocal' and not ativa)) $$,
                 'P0001', 'funcao_duplicada', 'reativar com o nome já usado por função ativa');
select is((select (public.desativar_funcao((select id from public.funcoes_ministerio where nome = 'Vocal' and ativa))).ativa), false, 'desativa a nova');
select is((select (public.reativar_funcao((select id from public.funcoes_ministerio where nome = 'Vocal' and not ativa order by criada_em limit 1))).ativa), true,
          'reativar quando o nome está livre');

-- Listar
select is((select count(*) from public.listar_funcoes('00000000-0000-0000-0000-00000023000a', false)), 2::bigint, 'lista só as ativas (Vocal e Violão Solo)');
select ok((select count(*) from public.listar_funcoes('00000000-0000-0000-0000-00000023000a', true)) > 2, 'gestor pode incluir as desativadas');
reset role;

-- ===== Participante comum =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002304", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.criar_funcao('00000000-0000-0000-0000-00000023000a', 'Hack') $$, 'P0001', 'sem_permissao', 'participante não cria função');
select throws_ok($$ select public.desativar_funcao((select id from public.funcoes_ministerio where ativa limit 1)) $$, 'P0001', 'sem_permissao', 'participante não desativa função');
select is((select count(*) from public.listar_funcoes('00000000-0000-0000-0000-00000023000a', true)),
          (select count(*) from public.listar_funcoes('00000000-0000-0000-0000-00000023000a', false)),
          'participante, mesmo pedindo inativas, só vê as ativas');
reset role;

-- ===== Estranho =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002305", "role": "authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.listar_funcoes('00000000-0000-0000-0000-00000023000a', true)), 0::bigint, 'quem não participa não lista funções');
select throws_ok($$ select public.criar_funcao('00000000-0000-0000-0000-00000023000a', 'Hack') $$, 'P0001', 'sem_permissao', 'estranho não cria função');
reset role;

-- ===== Administrador: tudo, mas ministério inativo recusa escrita =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002301", "role": "authenticated"}', true);
set local role authenticated;
select lives_ok($$ select public.criar_funcao('00000000-0000-0000-0000-00000023000b', 'Recepção') $$, 'administrador cria função em qualquer ministério');
select throws_ok($$ select public.criar_funcao('00000000-0000-0000-0000-00000023000c', 'Recepção') $$, 'P0001', 'ministerio_inativo', 'ministério desativado recusa escrita, até do administrador');
select throws_ok($$ select public.editar_funcao('99999999-9999-9999-9999-999999999999', 'Qualquer') $$, 'P0001', 'nao_encontrado', 'administrador é avisado de função inexistente');

select * from finish();
rollback;
