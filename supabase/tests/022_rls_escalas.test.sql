-- T009: as tabelas de escalas não são lidas nem escritas direto; funções do ministério são lidas só
-- por quem participa, lidera ou administra; auxiliares de permissão.
begin;
create extension if not exists pgtap with schema extensions;
select plan(21);

insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role) values
  ('00000000-0000-0000-0000-000000002201', 'adm.22@exemplo.com',  now(), '{"nome":"Adm 22"}',   'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000002202', 'la.22@exemplo.com',   now(), '{"nome":"Lider A 22"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000002203', 'lb.22@exemplo.com',   now(), '{"nome":"Lider B 22"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000002204', 'pa.22@exemplo.com',   now(), '{"nome":"Part A 22"}',  'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000002205', 'fora.22@exemplo.com', now(), '{"nome":"Fora 22"}',    'authenticated', 'authenticated');
update public.perfis set situacao = 'aprovado' where id::text like '00000000-0000-0000-0000-0000000022%';
update public.perfis set papel = 'administrador' where id = '00000000-0000-0000-0000-000000002201';

insert into public.ministerios (id, nome, descricao) values
  ('00000000-0000-0000-0000-00000022000a', 'Teste RLS Escalas A', ''),
  ('00000000-0000-0000-0000-00000022000b', 'Teste RLS Escalas B', '');
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel) values
  ('00000000-0000-0000-0000-00000022000a', '00000000-0000-0000-0000-000000002202', 'lider'),
  ('00000000-0000-0000-0000-00000022000b', '00000000-0000-0000-0000-000000002203', 'lider'),
  ('00000000-0000-0000-0000-00000022000a', '00000000-0000-0000-0000-000000002204', 'participante');
insert into public.funcoes_ministerio (id, ministerio_id, nome) values
  ('00000000-0000-0000-0000-00000022f00a', '00000000-0000-0000-0000-00000022000a', 'Vocal A'),
  ('00000000-0000-0000-0000-00000022f00b', '00000000-0000-0000-0000-00000022000b', 'Vocal B');
insert into public.escalas (id, ministerio_id, evento, data, horario) values
  ('00000000-0000-0000-0000-00000022e00a', '00000000-0000-0000-0000-00000022000a', 'Culto', current_date + 3, '09:00');

-- ===== Anônimo =====
set local role anon;
select throws_ok($$ select * from public.funcoes_ministerio $$, '42501', null, 'anônimo não lê funções');
select throws_ok($$ select * from public.escalas $$, '42501', null, 'anônimo não lê escalas');
select throws_ok($$ select * from public.vagas_escala $$, '42501', null, 'anônimo não lê vagas');
select throws_ok($$ select * from public.respostas_escala $$, '42501', null, 'anônimo não lê respostas');
select throws_ok($$ select * from public.pedidos_troca $$, '42501', null, 'anônimo não lê pedidos de troca');
select throws_ok($$ select * from public.aptidoes $$, '42501', null, 'anônimo não lê aptidões');
reset role;

-- ===== Participante (conta comum) =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002204", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select * from public.escalas $$, '42501', null, 'participante não lê a tabela de escalas direto');
select throws_ok($$ select * from public.vagas_escala $$, '42501', null, 'participante não lê vagas direto');
select throws_ok($$ select * from public.respostas_escala $$, '42501', null, 'participante não lê respostas direto');
select throws_ok($$ select * from public.pedidos_troca $$, '42501', null, 'participante não lê pedidos direto');
select throws_ok($$ select * from public.aptidoes $$, '42501', null, 'participante não lê aptidões direto');
select throws_ok($$ insert into public.funcoes_ministerio (ministerio_id, nome) values ('00000000-0000-0000-0000-00000022000a', 'Hack') $$,
                 '42501', null, 'participante não escreve funções direto');
select throws_ok($$ insert into public.escalas (ministerio_id, evento, data, horario) values ('00000000-0000-0000-0000-00000022000a', 'Hack', current_date, '09:00') $$,
                 '42501', null, 'participante não cria escala direto');
select is((select count(*) from public.funcoes_ministerio), 1::bigint, 'participante do A vê só as funções do A');
select ok(public.eh_participante_de('00000000-0000-0000-0000-00000022000a'), 'eh_participante_de: participante do A');
select ok(not public.eh_participante_de('00000000-0000-0000-0000-00000022000b'), 'eh_participante_de: não é do B');
select ok(not public.eh_gestor_de('00000000-0000-0000-0000-00000022000a'), 'eh_gestor_de: participante comum não é gestor');
reset role;

-- ===== Líder do B =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002203", "role": "authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.funcoes_ministerio where ministerio_id = '00000000-0000-0000-0000-00000022000a'), 0::bigint,
          'líder do B não vê funções do A');
select ok(public.eh_gestor_de('00000000-0000-0000-0000-00000022000b') and not public.eh_gestor_de('00000000-0000-0000-0000-00000022000a'),
          'eh_gestor_de: líder do B gere o B e não o A');
reset role;

-- ===== Estranho e administrador =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002205", "role": "authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.funcoes_ministerio), 0::bigint, 'quem não participa de nada não vê funções');
reset role;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002201", "role": "authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.funcoes_ministerio where nome like 'Vocal %'), 2::bigint, 'administrador vê as funções de todos os ministérios');
reset role;

select * from finish();
rollback;
