-- T007: as tabelas de disponibilidade não são lidas nem escritas direto; auxiliares de acesso e
-- cálculo de "aberta" com relógio fixo.
begin;
create extension if not exists pgtap with schema extensions;
select plan(21);

insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role) values
  ('00000000-0000-0000-0000-000000004101', 'adm.41@exemplo.com',  now(), '{"nome":"Adm 41"}',    'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000004102', 'la.41@exemplo.com',   now(), '{"nome":"Lider A 41"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000004103', 'lb.41@exemplo.com',   now(), '{"nome":"Lider B 41"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000004104', 'pa.41@exemplo.com',   now(), '{"nome":"Part A 41"}',  'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000004105', 'fora.41@exemplo.com', now(), '{"nome":"Fora 41"}',    'authenticated', 'authenticated');
update public.perfis set situacao = 'aprovado' where id::text like '00000000-0000-0000-0000-0000000041%';
update public.perfis set papel = 'administrador' where id = '00000000-0000-0000-0000-000000004101';

insert into public.ministerios (id, nome, descricao) values
  ('00000000-0000-0000-0000-00000041000a', 'Teste RLS Disp A', ''),
  ('00000000-0000-0000-0000-00000041000b', 'Teste RLS Disp B', '');
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel) values
  ('00000000-0000-0000-0000-00000041000a', '00000000-0000-0000-0000-000000004102', 'lider'),
  ('00000000-0000-0000-0000-00000041000b', '00000000-0000-0000-0000-000000004103', 'lider'),
  ('00000000-0000-0000-0000-00000041000a', '00000000-0000-0000-0000-000000004104', 'participante');
insert into public.consultas_disponibilidade (id, ministerio_id, titulo) values
  ('00000000-0000-0000-0000-00000041c00a', '00000000-0000-0000-0000-00000041000a', 'Consulta A');
insert into public.datas_consulta (id, consulta_id, ministerio_id, data) values
  ('00000000-0000-0000-0000-00000041d00a', '00000000-0000-0000-0000-00000041c00a', '00000000-0000-0000-0000-00000041000a', '2026-12-13');
insert into public.respostas_disponibilidade (data_id, perfil_id, resposta) values
  ('00000000-0000-0000-0000-00000041d00a', '00000000-0000-0000-0000-000000004104', 'disponivel');

-- ===== Anônimo =====
set local role anon;
select throws_ok($$ select * from public.consultas_disponibilidade $$, '42501', null, 'anônimo não lê consultas');
select throws_ok($$ select * from public.datas_consulta $$, '42501', null, 'anônimo não lê datas');
select throws_ok($$ select * from public.respostas_disponibilidade $$, '42501', null, 'anônimo não lê respostas');
select throws_ok($$ select * from public.observacoes_disponibilidade $$, '42501', null, 'anônimo não lê observações');
reset role;

-- ===== Participante, líder e administrador: nenhum acesso direto =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000004104", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select * from public.consultas_disponibilidade $$, '42501', null, 'participante não lê consultas direto');
select throws_ok($$ select * from public.respostas_disponibilidade $$, '42501', null, 'participante não lê respostas direto');
select throws_ok($$ insert into public.respostas_disponibilidade (data_id, perfil_id, resposta) values ('00000000-0000-0000-0000-00000041d00a', '00000000-0000-0000-0000-000000004104', 'indisponivel') $$,
                 '42501', null, 'participante não escreve respostas direto');
reset role;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000004102", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select * from public.respostas_disponibilidade $$, '42501', null, 'líder não lê respostas direto');
select throws_ok($$ insert into public.consultas_disponibilidade (ministerio_id, titulo) values ('00000000-0000-0000-0000-00000041000a', 'Hack') $$,
                 '42501', null, 'líder não cria consulta direto');
select throws_ok($$ select * from public.observacoes_disponibilidade $$, '42501', null, 'líder não lê observações direto');
reset role;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000004101", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select * from public.consultas_disponibilidade $$, '42501', null, 'administrador também não lê direto');
select throws_ok($$ delete from public.datas_consulta $$, '42501', null, 'administrador não apaga datas direto');
reset role;

-- ===== consulta_esta_aberta com relógio fixo (10/12/2026) =====
create or replace function public.agora_sp() returns timestamptz language sql stable as $$ select '2026-12-10 09:30-03'::timestamptz $$;
select ok(public.consulta_esta_aberta(row('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'x', '', null, false, null, now(), now())::public.consultas_disponibilidade),
          'sem prazo e não fechada: aberta');
select ok(public.consulta_esta_aberta(row('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'x', '', '2026-12-10', false, null, now(), now())::public.consultas_disponibilidade),
          'prazo é hoje: ainda aberta (vale até o fim do dia)');
select ok(not public.consulta_esta_aberta(row('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'x', '', '2026-12-09', false, null, now(), now())::public.consultas_disponibilidade),
          'prazo foi ontem: fechada');
select ok(not public.consulta_esta_aberta(row('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'x', '', null, true, null, now(), now())::public.consultas_disponibilidade),
          'fechada pelo líder: fechada');

-- ===== Auxiliares de acesso (executadas como o usuário) =====
-- As auxiliares não têm permissão para authenticated; o teste as chama como superusuário, simulando o usuário pelo JWT.
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000004102", "role": "authenticated"}', true);
select is((public.exigir_gestor_consulta('00000000-0000-0000-0000-00000041c00a')).titulo, 'Consulta A', 'líder do A passa em exigir_gestor_consulta');
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000004103", "role": "authenticated"}', true);
select throws_ok($$ select public.exigir_gestor_consulta('00000000-0000-0000-0000-00000041c00a') $$, 'P0001', 'sem_permissao', 'líder do B não passa no A');
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000004104", "role": "authenticated"}', true);
select throws_ok($$ select public.exigir_gestor_consulta('00000000-0000-0000-0000-00000041c00a') $$, 'P0001', 'sem_permissao', 'participante comum não é gestor');
select is((public.exigir_participante_consulta('00000000-0000-0000-0000-00000041c00a')).id, '00000000-0000-0000-0000-00000041c00a'::uuid, 'participante passa em exigir_participante_consulta');
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000004105", "role": "authenticated"}', true);
select throws_ok($$ select public.exigir_participante_consulta('00000000-0000-0000-0000-00000041c00a') $$, 'P0001', 'sem_permissao', 'quem não participa não passa');

select * from finish();
rollback;
