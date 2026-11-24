-- T018: aptidões dos participantes (FR-004).
begin;
create extension if not exists pgtap with schema extensions;
select plan(15);

insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role) values
  ('00000000-0000-0000-0000-000000002402', 'la.24@exemplo.com',   now(), '{"nome":"Lider A 24"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000002403', 'lb.24@exemplo.com',   now(), '{"nome":"Lider B 24"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000002404', 'pa.24@exemplo.com',   now(), '{"nome":"Part A 24"}',  'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000002405', 'fora.24@exemplo.com', now(), '{"nome":"Fora 24"}',    'authenticated', 'authenticated');
update public.perfis set situacao = 'aprovado' where id::text like '00000000-0000-0000-0000-0000000024%';

insert into public.ministerios (id, nome, descricao) values
  ('00000000-0000-0000-0000-00000024000a', 'Teste Aptidões A', ''),
  ('00000000-0000-0000-0000-00000024000b', 'Teste Aptidões B', '');
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel) values
  ('00000000-0000-0000-0000-00000024000a', '00000000-0000-0000-0000-000000002402', 'lider'),
  ('00000000-0000-0000-0000-00000024000b', '00000000-0000-0000-0000-000000002403', 'lider'),
  ('00000000-0000-0000-0000-00000024000a', '00000000-0000-0000-0000-000000002404', 'participante');
insert into public.funcoes_ministerio (id, ministerio_id, nome, ativa) values
  ('00000000-0000-0000-0000-00000024f001', '00000000-0000-0000-0000-00000024000a', 'Vocal', true),
  ('00000000-0000-0000-0000-00000024f002', '00000000-0000-0000-0000-00000024000a', 'Violão', true),
  ('00000000-0000-0000-0000-00000024f003', '00000000-0000-0000-0000-00000024000a', 'Bateria', false),
  ('00000000-0000-0000-0000-00000024f004', '00000000-0000-0000-0000-00000024000b', 'Recepção', true);

-- ===== Líder do A =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002402", "role": "authenticated"}', true);
set local role authenticated;
select lives_ok($$ select public.definir_aptidoes('00000000-0000-0000-0000-00000024000a', '00000000-0000-0000-0000-000000002404',
  '[{"funcao":"00000000-0000-0000-0000-00000024f001","tipo":"principal"},{"funcao":"00000000-0000-0000-0000-00000024f002","tipo":"secundaria"}]'::jsonb) $$,
  'líder cadastra aptidões principal e secundária');
select is((select count(*) from public.listar_aptidoes('00000000-0000-0000-0000-00000024000a')), 2::bigint, 'listar_aptidoes devolve as duas');
select is((select tipo::text from public.listar_aptidoes('00000000-0000-0000-0000-00000024000a') where funcao_id = '00000000-0000-0000-0000-00000024f002'), 'secundaria', 'o tipo fica registrado');

-- A lista enviada é a lista COMPLETA da pessoa: o que não estiver nela é removido.
select lives_ok($$ select public.definir_aptidoes('00000000-0000-0000-0000-00000024000a', '00000000-0000-0000-0000-000000002404',
  '[{"funcao":"00000000-0000-0000-0000-00000024f001","tipo":"secundaria"}]'::jsonb) $$, 'substitui a lista');
select is((select count(*) from public.listar_aptidoes('00000000-0000-0000-0000-00000024000a')), 1::bigint, 'ficou só uma aptidão');
select is((select tipo::text from public.listar_aptidoes('00000000-0000-0000-0000-00000024000a')), 'secundaria', 'e o tipo foi atualizado');

-- Validações
select throws_ok($$ select public.definir_aptidoes('00000000-0000-0000-0000-00000024000a', '00000000-0000-0000-0000-000000002405',
  '[]'::jsonb) $$, 'P0001', 'nao_participante', 'só participantes do ministério têm aptidões');
select throws_ok($$ select public.definir_aptidoes('00000000-0000-0000-0000-00000024000a', '00000000-0000-0000-0000-000000002404',
  '[{"funcao":"00000000-0000-0000-0000-00000024f004","tipo":"principal"}]'::jsonb) $$, 'P0001', 'funcao_invalida', 'função de outro ministério');
select throws_ok($$ select public.definir_aptidoes('00000000-0000-0000-0000-00000024000a', '00000000-0000-0000-0000-000000002404',
  '[{"funcao":"00000000-0000-0000-0000-00000024f003","tipo":"principal"}]'::jsonb) $$, 'P0001', 'funcao_invalida', 'função desativada não pode ser adicionada');
select throws_ok($$ select public.definir_aptidoes('00000000-0000-0000-0000-00000024000a', '00000000-0000-0000-0000-000000002404',
  '[{"funcao":"00000000-0000-0000-0000-00000024f001","tipo":"terciaria"}]'::jsonb) $$, 'P0001', 'funcao_invalida', 'tipo inválido');
select throws_ok($$ select public.definir_aptidoes('00000000-0000-0000-0000-00000024000b', '00000000-0000-0000-0000-000000002404',
  '[]'::jsonb) $$, 'P0001', 'sem_permissao', 'líder do A não define aptidões no B');
reset role;

-- Função que já estava na lista e foi desativada depois PODE permanecer na lista.
insert into public.aptidoes (funcao_id, perfil_id, tipo) values ('00000000-0000-0000-0000-00000024f003', '00000000-0000-0000-0000-000000002404', 'principal');
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002402", "role": "authenticated"}', true);
set local role authenticated;
select lives_ok($$ select public.definir_aptidoes('00000000-0000-0000-0000-00000024000a', '00000000-0000-0000-0000-000000002404',
  '[{"funcao":"00000000-0000-0000-0000-00000024f003","tipo":"secundaria"},{"funcao":"00000000-0000-0000-0000-00000024f001","tipo":"principal"}]'::jsonb) $$,
  'função desativada que já estava na lista pode permanecer');
reset role;

-- ===== Participante: vê só as próprias, não lista as dos outros, não define =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002404", "role": "authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.minhas_aptidoes('00000000-0000-0000-0000-00000024000a')), 1::bigint, 'minhas_aptidoes mostra só as funções ativas da própria pessoa');
select is((select count(*) from public.listar_aptidoes('00000000-0000-0000-0000-00000024000a')), 0::bigint, 'participante comum não lista aptidões');
select throws_ok($$ select public.definir_aptidoes('00000000-0000-0000-0000-00000024000a', '00000000-0000-0000-0000-000000002404', '[]'::jsonb) $$,
                 'P0001', 'sem_permissao', 'participante não define aptidões');
reset role;

select * from finish();
rollback;
