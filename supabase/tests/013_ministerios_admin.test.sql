-- T024: funções de ministério do administrador (RF-001 a RF-007).
begin;
create extension if not exists pgtap with schema extensions;
select plan(33);

insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role) values
  ('00000000-0000-0000-0000-000000000e01', 'adm.e@exemplo.com',  now(), '{"nome":"Adm E"}',  'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000e02', 'mem.e@exemplo.com',  now(), '{"nome":"Mem E"}',  'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000e03', 'lid.e@exemplo.com',  now(), '{"nome":"Lid E"}',  'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000e04', 'pen.e@exemplo.com',  now(), '{"nome":"Pen E"}',  'authenticated', 'authenticated');
update public.perfis set situacao = 'aprovado', papel = 'administrador' where id = '00000000-0000-0000-0000-000000000e01';
update public.perfis set situacao = 'aprovado' where id in
  ('00000000-0000-0000-0000-000000000e02', '00000000-0000-0000-0000-000000000e03');

-- Um ministério já existente, liderado por e03, para provar que líder de ministério não administra.
insert into public.ministerios (id, nome, descricao) values
  ('00000000-0000-0000-0000-00000000ee0a', 'Existente E', '');
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel) values
  ('00000000-0000-0000-0000-00000000ee0a', '00000000-0000-0000-0000-000000000e03', 'lider');

-- ===== Quem não é administrador não gerencia ministérios =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000e02", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.criar_ministerio('Novo E', '', '00000000-0000-0000-0000-000000000e02') $$,
                 'P0001', 'sem_permissao', 'membro não cria ministério');
reset role;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000e03", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.criar_ministerio('Novo E', '', '00000000-0000-0000-0000-000000000e03') $$,
                 'P0001', 'sem_permissao', 'líder de ministério não cria ministério');
select throws_ok($$ select public.editar_ministerio('00000000-0000-0000-0000-00000000ee0a', 'Outro nome', '') $$,
                 'P0001', 'sem_permissao', 'líder de ministério não edita nem o próprio ministério');
select throws_ok($$ select public.desativar_ministerio('00000000-0000-0000-0000-00000000ee0a') $$,
                 'P0001', 'sem_permissao', 'líder de ministério não desativa o próprio ministério');
select throws_ok($$ select public.reativar_ministerio('00000000-0000-0000-0000-00000000ee0a', null) $$,
                 'P0001', 'sem_permissao', 'líder de ministério não reativa ministério');
reset role;
set local role anon;
select throws_ok($$ select public.criar_ministerio('Novo E', '', '00000000-0000-0000-0000-000000000e03') $$,
                 '42501', null, 'visitante não executa criar_ministerio');
reset role;

-- ===== Administrador cria =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000e01", "role": "authenticated"}', true);
set local role authenticated;

select lives_ok($$ select public.criar_ministerio('  Música Teste E  ', 'Toca nos cultos', '00000000-0000-0000-0000-000000000e03') $$,
                'administrador cria ministério com líder inicial');
reset role;
select is((select count(*) from public.ministerios where nome = 'Música Teste E' and ativo and descricao = 'Toca nos cultos'),
          1::bigint, 'o ministério nasce ativo, com o nome sem espaços nas pontas');
select is((select count(*) from public.participacoes_ministerio pm join public.ministerios m on m.id = pm.ministerio_id
            where m.nome = 'Música Teste E' and pm.perfil_id = '00000000-0000-0000-0000-000000000e03' and pm.papel = 'lider'),
          1::bigint, 'o líder inicial foi vinculado como líder, na mesma operação');
set local role authenticated;

-- Validações
select throws_ok($$ select public.criar_ministerio('   ', '', '00000000-0000-0000-0000-000000000e03') $$,
                 'P0001', 'nome_invalido', 'nome só com espaços');
select throws_ok($$ select public.criar_ministerio('A', '', '00000000-0000-0000-0000-000000000e03') $$,
                 'P0001', 'nome_invalido', 'nome com menos de 2 letras');
select throws_ok($$ select public.criar_ministerio(repeat('a', 61), '', '00000000-0000-0000-0000-000000000e03') $$,
                 'P0001', 'nome_invalido', 'nome com mais de 60 caracteres');
select throws_ok($$ select public.criar_ministerio('Descrição Longa E', repeat('d', 201), '00000000-0000-0000-0000-000000000e03') $$,
                 'P0001', 'nome_invalido', 'descrição com mais de 200 caracteres');
select throws_ok($$ select public.criar_ministerio(null, '', '00000000-0000-0000-0000-000000000e03') $$,
                 'P0001', 'nome_invalido', 'nome nulo');
select throws_ok($$ select public.criar_ministerio('Sem Líder E', '', null) $$,
                 'P0001', 'pessoa_invalida', 'o líder inicial é obrigatório');
select throws_ok($$ select public.criar_ministerio('Líder Pendente E', '', '00000000-0000-0000-0000-000000000e04') $$,
                 'P0001', 'pessoa_invalida', 'o líder inicial precisa ter conta aprovada');
select throws_ok($$ select public.criar_ministerio('Líder Fantasma E', '', '99999999-9999-9999-9999-999999999999') $$,
                 'P0001', 'pessoa_invalida', 'o líder inicial precisa existir');

-- Nome único entre ativos, ignorando caixa, acento e espaços (RF-005)
select throws_ok($$ select public.criar_ministerio('MUSICA   teste e', '', '00000000-0000-0000-0000-000000000e02') $$,
                 'P0001', 'nome_duplicado', 'mesmo nome ignorando caixa, acento e espaços repetidos');

-- ===== Editar =====
select throws_ok($$ select public.editar_ministerio((select id from public.ministerios where nome = 'Existente E'), 'música teste e', '') $$,
                 'P0001', 'nome_duplicado', 'editar para o nome de outro ministério ativo é barrado');
select lives_ok($$ select public.editar_ministerio((select id from public.ministerios where nome = 'Existente E'), 'EXISTENTE E', 'nova descrição') $$,
                'mudar só a caixa do próprio nome é permitido');
select throws_ok($$ select public.editar_ministerio('99999999-9999-9999-9999-999999999999', 'Qualquer E', '') $$,
                 'P0001', 'nao_encontrado', 'editar ministério inexistente');
select throws_ok($$ select public.editar_ministerio((select id from public.ministerios where nome = 'EXISTENTE E'), 'x', '') $$,
                 'P0001', 'nome_invalido', 'editar com nome inválido');

-- ===== Desativar preserva o histórico (RF-003) =====
reset role;
insert into public.pedidos_entrada_ministerio (ministerio_id, perfil_id) values
  ((select id from public.ministerios where nome = 'Música Teste E'), '00000000-0000-0000-0000-000000000e02');
set local role authenticated;
select lives_ok($$ select public.desativar_ministerio((select id from public.ministerios where nome = 'Música Teste E')) $$,
                'administrador desativa o ministério');
reset role;
select is((select ativo from public.ministerios where nome = 'Música Teste E'), false, 'ficou desativado');
select isnt((select desativado_em from public.ministerios where nome = 'Música Teste E'), null, 'registra quando foi desativado');
select is((select count(*) from public.participacoes_ministerio pm join public.ministerios m on m.id = pm.ministerio_id
            where m.nome = 'Música Teste E'), 1::bigint, 'as participações continuam registradas');
select is((select count(*) from public.pedidos_entrada_ministerio pe join public.ministerios m on m.id = pe.ministerio_id
            where m.nome = 'Música Teste E' and pe.situacao = 'pendente'), 1::bigint, 'os pedidos continuam registrados');
set local role authenticated;

-- Nome de ministério desativado pode ser reaproveitado (RF-004)
select lives_ok($$ select public.criar_ministerio('Música Teste E', 'segunda versão', '00000000-0000-0000-0000-000000000e02') $$,
                'recriar um nome que só existe desativado é permitido');
-- Reativar o antigo agora colide com o novo ativo
select throws_ok($$ select public.reativar_ministerio((select id from public.ministerios where nome = 'Música Teste E' and not ativo), null) $$,
                 'P0001', 'nome_duplicado', 'reativar com nome já em uso por ativo é barrado');

-- ===== Reativar exige líder válido =====
reset role;
insert into public.ministerios (id, nome, descricao, ativo, desativado_em) values
  ('00000000-0000-0000-0000-00000000ee0d', 'Sem Líder Antigo E', '', false, now());
set local role authenticated;
select throws_ok($$ select public.reativar_ministerio('00000000-0000-0000-0000-00000000ee0d', null) $$,
                 'P0001', 'sem_lider', 'reativar sem líder válido exige informar um');
select throws_ok($$ select public.reativar_ministerio('00000000-0000-0000-0000-00000000ee0d', '00000000-0000-0000-0000-000000000e04') $$,
                 'P0001', 'pessoa_invalida', 'o líder informado na reativação precisa ter conta aprovada');
select lives_ok($$ select public.reativar_ministerio('00000000-0000-0000-0000-00000000ee0d', '00000000-0000-0000-0000-000000000e03') $$,
                'reativar informando um líder válido');
reset role;
select is((select ativo from public.ministerios where id = '00000000-0000-0000-0000-00000000ee0d'), true, 'o ministério voltou a ficar ativo');

select * from finish();
rollback;
