-- T058: quem vê quem faz parte de um ministério (RF-029 a RF-031). Nome e papel, nunca email.
begin;
create extension if not exists pgtap with schema extensions;
select plan(18);

insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role) values
  ('00000000-0000-0000-0000-000000005a01', 'adm.v@exemplo.com', now(), '{"nome":"Adm V"}',      'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000005a02', 'l1.v@exemplo.com',  now(), '{"nome":"Lider V1"}',   'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000005a03', 'p1.v@exemplo.com',  now(), '{"nome":"Partic V1"}',  'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000005a04', 'pr.v@exemplo.com',  now(), '{"nome":"Lider V2"}',   'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000005a05', 'nn.v@exemplo.com',  now(), '{"nome":"Sem Min V"}',  'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000005a06', 'rc.v@exemplo.com',  now(), '{"nome":"Recusado V"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000005a07', 'rm.v@exemplo.com',  now(), '{"nome":"Removido V"}', 'authenticated', 'authenticated');
update public.perfis set situacao = 'aprovado', papel = 'administrador' where id = '00000000-0000-0000-0000-000000005a01';
update public.perfis set situacao = 'aprovado' where id::text between '00000000-0000-0000-0000-000000005a02' and '00000000-0000-0000-0000-000000005a07';

insert into public.ministerios (id, nome, descricao, ativo, desativado_em) values
  ('00000000-0000-0000-0000-00000000ea0a', 'Teste Visib A', '', true,  null),
  ('00000000-0000-0000-0000-00000000ea0b', 'Teste Visib B', '', true,  null),
  ('00000000-0000-0000-0000-00000000ea0c', 'Teste Visib Inativo', '', false, now());
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel) values
  ('00000000-0000-0000-0000-00000000ea0a', '00000000-0000-0000-0000-000000005a02', 'lider'),
  ('00000000-0000-0000-0000-00000000ea0a', '00000000-0000-0000-0000-000000005a03', 'participante'),
  ('00000000-0000-0000-0000-00000000ea0a', '00000000-0000-0000-0000-000000005a06', 'participante'),
  ('00000000-0000-0000-0000-00000000ea0a', '00000000-0000-0000-0000-000000005a07', 'participante'),
  ('00000000-0000-0000-0000-00000000ea0b', '00000000-0000-0000-0000-000000005a04', 'lider'),
  ('00000000-0000-0000-0000-00000000ea0c', '00000000-0000-0000-0000-000000005a02', 'lider');
-- Duas pessoas perdem o acesso DEPOIS de entrar no ministério: continuam registradas, mas não aparecem.
update public.perfis set situacao = 'recusado' where id = '00000000-0000-0000-0000-000000005a06';
update public.perfis set situacao = 'acesso_removido' where id = '00000000-0000-0000-0000-000000005a07';

-- ===== Administrador =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000005a01", "role": "authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.listar_participantes('00000000-0000-0000-0000-00000000ea0a')),
          2::bigint, 'administrador vê só as contas aprovadas do ministério (líder e participante)');
select is((select count(*) from public.listar_participantes('00000000-0000-0000-0000-00000000ea0a')
            where perfil_id in ('00000000-0000-0000-0000-000000005a06', '00000000-0000-0000-0000-000000005a07')),
          0::bigint, 'conta recusada e conta sem acesso não aparecem');
select is((select count(*) from public.listar_participantes('00000000-0000-0000-0000-00000000ea0c')),
          1::bigint, 'administrador vê também ministério desativado');
select is((select papel::text from public.listar_participantes('00000000-0000-0000-0000-00000000ea0a') limit 1),
          'lider', 'a lista traz os líderes primeiro');
select is((select count(*) from public.listar_participantes('99999999-9999-9999-9999-999999999999')),
          0::bigint, 'ministério inexistente devolve lista vazia');
reset role;

-- ===== Líder do A =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000005a02", "role": "authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.listar_participantes('00000000-0000-0000-0000-00000000ea0a')),
          2::bigint, 'líder vê os participantes do próprio ministério');
select is((select count(*) from public.listar_participantes('00000000-0000-0000-0000-00000000ea0b')),
          0::bigint, 'líder do A NÃO vê os participantes do B');
select is((select count(*) from public.listar_participantes('00000000-0000-0000-0000-00000000ea0c')),
          0::bigint, 'ministério desativado: nem o líder vê (só o administrador)');
reset role;

-- ===== Participante do A =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000005a03", "role": "authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.listar_participantes('00000000-0000-0000-0000-00000000ea0a')),
          2::bigint, 'participante vê quem faz parte do próprio ministério');
select is((select count(*) from public.listar_participantes('00000000-0000-0000-0000-00000000ea0b')),
          0::bigint, 'participante do A NÃO vê os participantes do B');
reset role;

-- ===== Líder do B, e quem não participa de nada =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000005a04", "role": "authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.listar_participantes('00000000-0000-0000-0000-00000000ea0a')),
          0::bigint, 'líder do B NÃO vê os participantes do A');
reset role;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000005a05", "role": "authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.listar_participantes('00000000-0000-0000-0000-00000000ea0a')),
          0::bigint, 'quem não participa de nenhum ministério não vê participantes');
reset role;

-- Quem perdeu o acesso não vê a lista do próprio ministério
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000005a07", "role": "authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.listar_participantes('00000000-0000-0000-0000-00000000ea0a')),
          0::bigint, 'conta sem acesso não lê a lista (mesmo constando como participante)');
reset role;

-- Reaprovar a conta faz o vínculo voltar a valer
update public.perfis set situacao = 'aprovado' where id = '00000000-0000-0000-0000-000000005a06';
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000005a01", "role": "authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.listar_participantes('00000000-0000-0000-0000-00000000ea0a')),
          3::bigint, 'conta reaprovada volta a aparecer, com o vínculo que tinha');
reset role;

-- ===== Nunca devolvem email (constituição V) =====
select ok(not ('email' = any (coalesce((select proargnames from pg_proc where proname = 'listar_participantes'), '{}'))),
          'listar_participantes não devolve email');
select ok(not ('email' = any (coalesce((select proargnames from pg_proc where proname = 'buscar_pessoas'), '{}'))),
          'buscar_pessoas não devolve email');
select ok(not ('email' = any (coalesce((select proargnames from pg_proc where proname = 'ministerios_que_lidero'), '{}'))),
          'ministerios_que_lidero não devolve email');

-- ===== Visitante =====
set local role anon;
select throws_ok($$ select * from public.listar_participantes('00000000-0000-0000-0000-00000000ea0a') $$,
                 '42501', null, 'visitante não executa listar_participantes');
reset role;

select * from finish();
rollback;
