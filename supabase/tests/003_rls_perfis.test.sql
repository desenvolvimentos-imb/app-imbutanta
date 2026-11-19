-- T011: regras de leitura/escrita de `perfis` (RLS + permissões por coluna).
-- Os testes usam ids específicos (e não totais) porque o seed local também tem contas.
begin;
create extension if not exists pgtap with schema extensions;
select plan(15);

-- Cenário: administrador, líder, membro, pendente verificado e pendente não verificado.
insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role) values
  ('00000000-0000-0000-0000-0000000000c1', 'adm.t@exemplo.com',  now(), '{"nome":"Adm T"}',  'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000000c2', 'lid.t@exemplo.com',  now(), '{"nome":"Lid T"}',  'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000000c3', 'mem.t@exemplo.com',  now(), '{"nome":"Mem T"}',  'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000000c4', 'pen.t@exemplo.com',  now(), '{"nome":"Pen T"}',  'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000000c5', 'pnv.t@exemplo.com',  null,  '{"nome":"Pnv T"}',  'authenticated', 'authenticated');
update public.perfis set situacao = 'aprovado', papel = 'administrador' where id = '00000000-0000-0000-0000-0000000000c1';
update public.perfis set situacao = 'aprovado', papel = 'lider'         where id = '00000000-0000-0000-0000-0000000000c2';
update public.perfis set situacao = 'aprovado', papel = 'membro'        where id = '00000000-0000-0000-0000-0000000000c3';

-- ===== Membro =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-0000000000c3", "role": "authenticated"}', true);
set local role authenticated;

select is((select count(*) from public.perfis), 1::bigint, 'membro enxerga apenas o próprio perfil');
select lives_ok($$ update public.perfis set nome = 'Mem Novo' where id = '00000000-0000-0000-0000-0000000000c3' $$,
                'membro pode alterar o próprio nome');
select throws_ok($$ update public.perfis set papel = 'administrador' where id = '00000000-0000-0000-0000-0000000000c3' $$,
                 '42501', null, 'membro NÃO consegue se promover');
select throws_ok($$ update public.perfis set situacao = 'aprovado' where id = '00000000-0000-0000-0000-0000000000c3' $$,
                 '42501', null, 'membro NÃO consegue alterar a própria situação');
select lives_ok($$ update public.perfis set nome = 'Invasor' where id = '00000000-0000-0000-0000-0000000000c4' $$,
                'tentar alterar o perfil de outra pessoa não dá erro, mas não afeta nada');
select throws_ok($$ delete from public.perfis where id = '00000000-0000-0000-0000-0000000000c3' $$,
                 '42501', null, 'ninguém apaga perfil direto pela API');
select throws_ok($$ insert into public.perfis (id, nome, email) values (gen_random_uuid(), 'X Y', 'x@y.com') $$,
                 '42501', null, 'ninguém insere perfil direto pela API');
reset role;

-- ===== Pendente: só vê o próprio =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-0000000000c4", "role": "authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.perfis), 1::bigint, 'pendente enxerga apenas o próprio perfil');
reset role;
select is((select nome from public.perfis where id = '00000000-0000-0000-0000-0000000000c4'),
          'Pen T', 'o nome da pessoa alheia continua intacto (RLS barrou o update)');

-- ===== Líder =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-0000000000c2", "role": "authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.perfis where id = '00000000-0000-0000-0000-0000000000c4'),
          1::bigint, 'líder vê pendente com email verificado');
select is((select count(*) from public.perfis where id = '00000000-0000-0000-0000-0000000000c5'),
          0::bigint, 'líder NÃO vê pendente com email não verificado');
select is((select count(*) from public.perfis where id in
            ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000c3')),
          0::bigint, 'líder NÃO vê administrador nem membro alheios');
select is((select count(*) from public.perfis where id = '00000000-0000-0000-0000-0000000000c2'),
          1::bigint, 'líder vê o próprio perfil');
reset role;

-- ===== Administrador =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-0000000000c1", "role": "authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.perfis where id in
            ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000c2',
             '00000000-0000-0000-0000-0000000000c3', '00000000-0000-0000-0000-0000000000c4',
             '00000000-0000-0000-0000-0000000000c5')),
          5::bigint, 'administrador vê todos os perfis');
reset role;

-- ===== Anônimo (sem login) =====
set local role anon;
select throws_ok($$ select * from public.perfis $$, '42501', null, 'anônimo não lê perfis');
reset role;

select * from finish();
rollback;
