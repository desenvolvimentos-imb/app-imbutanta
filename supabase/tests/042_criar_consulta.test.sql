-- T014: criar_consulta. Relógio fixo: 10/12/2026.
begin;
create extension if not exists pgtap with schema extensions;
select plan(20);

create or replace function public.agora_sp() returns timestamptz language sql stable as
  $$ select '2026-12-10 12:00:00+00'::timestamptz $$;

-- 4201 adm, 4202 líder A, 4203 líder B, 4204 participante A, 4205 estranho
insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role)
select ('00000000-0000-0000-0000-0000000042' || lpad(n::text, 2, '0'))::uuid, 'u' || n || '.42@exemplo.com', now(),
       jsonb_build_object('nome', 'Pessoa 42 ' || n), 'authenticated', 'authenticated'
  from unnest(array[1, 2, 3, 4, 5]) as n;
update public.perfis set situacao = 'aprovado' where id::text like '00000000-0000-0000-0000-0000000042%';
update public.perfis set papel = 'administrador' where id = '00000000-0000-0000-0000-000000004201';
insert into public.ministerios (id, nome, descricao, ativo) values
  ('00000000-0000-0000-0000-00000042000a', 'Teste Consulta 42 A', '', true),
  ('00000000-0000-0000-0000-00000042000b', 'Teste Consulta 42 B', '', true),
  ('00000000-0000-0000-0000-00000042000c', 'Teste Consulta 42 C', '', true);
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel) values
  ('00000000-0000-0000-0000-00000042000a', '00000000-0000-0000-0000-000000004202', 'lider'),
  ('00000000-0000-0000-0000-00000042000b', '00000000-0000-0000-0000-000000004203', 'lider'),
  ('00000000-0000-0000-0000-00000042000a', '00000000-0000-0000-0000-000000004204', 'participante'),
  ('00000000-0000-0000-0000-00000042000c', '00000000-0000-0000-0000-000000004202', 'lider');
update public.ministerios set ativo = false where id = '00000000-0000-0000-0000-00000042000c';

select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000004202", "role": "authenticated"}', true);
set local role authenticated;

select lives_ok($$ select public.criar_consulta('00000000-0000-0000-0000-00000042000a', '  Escala de dezembro ', 'Marque suas datas',
  '2026-12-12', '[{"data":"2026-12-13","rotulo":"Culto especial"},{"data":"2026-12-20"},{"data":"2026-12-10"}]'::jsonb) $$,
  'líder cria consulta com datas (hoje incluído), rótulo e prazo');
reset role;
select is((select count(*) from public.datas_consulta where consulta_id = (select id from public.consultas_disponibilidade where titulo = 'Escala de dezembro' and ministerio_id = '00000000-0000-0000-0000-00000042000a')),
          3::bigint, 'as 3 datas foram gravadas');
select is((select fechada from public.consultas_disponibilidade where titulo = 'Escala de dezembro' and ministerio_id = '00000000-0000-0000-0000-00000042000a'), false, 'a consulta nasce aberta');
select is((select rotulo from public.datas_consulta where data = '2026-12-13' and ministerio_id = '00000000-0000-0000-0000-00000042000a'), 'Culto especial', 'rótulo gravado');
select is((select criada_por from public.consultas_disponibilidade where titulo = 'Escala de dezembro' and ministerio_id = '00000000-0000-0000-0000-00000042000a'), '00000000-0000-0000-0000-000000004202'::uuid, 'criada_por é quem criou');

set local role authenticated;
select throws_ok($$ select public.criar_consulta('00000000-0000-0000-0000-00000042000a', '', '', null, '[{"data":"2026-12-27"}]') $$, 'P0001', 'consulta_invalida', 'título vazio');
select throws_ok($$ select public.criar_consulta('00000000-0000-0000-0000-00000042000a', 'Ok', '', null, '[]') $$, 'P0001', 'consulta_sem_datas', 'sem datas');
select throws_ok($$ select public.criar_consulta('00000000-0000-0000-0000-00000042000a', 'Ok', '', null, null) $$, 'P0001', 'consulta_sem_datas', 'datas nulas');
select throws_ok($$ select public.criar_consulta('00000000-0000-0000-0000-00000042000a', 'Ok', '', null, '[{"data":"2026-12-09"}]') $$, 'P0001', 'data_passada', 'data de ontem');
select throws_ok($$ select public.criar_consulta('00000000-0000-0000-0000-00000042000a', 'Ok', '', '2026-12-09', '[{"data":"2026-12-27"}]') $$, 'P0001', 'prazo_invalido', 'prazo de ontem');
select lives_ok($$ select public.criar_consulta('00000000-0000-0000-0000-00000042000a', 'Prazo hoje', '', '2026-12-10', '[{"data":"2026-12-27"}]') $$, 'prazo de hoje é válido');
select throws_ok($$ select public.criar_consulta('00000000-0000-0000-0000-00000042000a', 'Muitas', '', null,
  (select jsonb_agg(jsonb_build_object('data', (date '2027-01-01' + n)::text)) from generate_series(0, 31) n)) $$, 'P0001', 'consulta_invalida', 'mais de 31 datas');
select throws_ok($$ select public.criar_consulta('00000000-0000-0000-0000-00000042000a', 'Rep', '', null, '[{"data":"2027-02-07"},{"data":"2027-02-07"}]') $$, 'P0001', 'data_duplicada', 'data repetida na própria lista');
select throws_ok($$ select public.criar_consulta('00000000-0000-0000-0000-00000042000a', 'Outra', '', null, '[{"data":"2026-12-20"}]') $$, 'P0001', 'data_duplicada', 'data já em outra consulta do ministério');
reset role;
select is((select count(*) from public.consultas_disponibilidade where titulo in ('Ok','Muitas','Rep','Outra') and ministerio_id = '00000000-0000-0000-0000-00000042000a'), 0::bigint, 'tudo ou nada: nenhuma consulta ficou gravada após erro');

select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000004201", "role": "authenticated"}', true);
set local role authenticated;
select lives_ok($$ select public.criar_consulta('00000000-0000-0000-0000-00000042000b', 'Do B', '', null, '[{"data":"2026-12-20"}]') $$, 'a mesma data em outro ministério é permitida (administrador)');
select throws_ok($$ select public.criar_consulta('00000000-0000-0000-0000-00000042000c', 'Inativo', '', null, '[{"data":"2027-03-07"}]') $$, 'P0001', 'ministerio_inativo', 'ministério desativado');
reset role;

select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000004203", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.criar_consulta('00000000-0000-0000-0000-00000042000a', 'Hack', '', null, '[{"data":"2027-03-14"}]') $$, 'P0001', 'sem_permissao', 'líder do B não cria no A');
reset role;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000004204", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.criar_consulta('00000000-0000-0000-0000-00000042000a', 'Hack', '', null, '[{"data":"2027-03-14"}]') $$, 'P0001', 'sem_permissao', 'participante comum não cria');
reset role;
select set_config('request.jwt.claims', '{"role": "anon"}', true);
set local role anon;
select throws_ok($$ select public.criar_consulta('00000000-0000-0000-0000-00000042000a', 'Hack', '', null, '[{"data":"2027-03-14"}]') $$, '42501', null, 'anônimo não tem permissão de executar');
reset role;

select * from finish();
rollback;
