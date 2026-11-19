-- T031: quem não está aprovado (pendente, recusado, acesso removido) não tem acesso a nada
-- além do próprio perfil, e não consegue se auto-aprovar (RF-008, CS-004).
begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role) values
  ('00000000-0000-0000-0000-0000000000e1', 'pen.e@exemplo.com', now(), '{"nome":"Pen E"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000000e2', 'rec.e@exemplo.com', now(), '{"nome":"Rec E"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000000e3', 'rem.e@exemplo.com', now(), '{"nome":"Rem E"}', 'authenticated', 'authenticated');
update public.perfis set situacao = 'recusado' where id = '00000000-0000-0000-0000-0000000000e2';
-- Mesmo com papel de administrador gravado, sem aprovação o papel não vale de nada.
update public.perfis set situacao = 'acesso_removido', papel = 'administrador'
 where id = '00000000-0000-0000-0000-0000000000e3';

-- ===== Pendente =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-0000000000e1", "role": "authenticated"}', true);
set local role authenticated;
select is(public.papel_aprovado_atual()::text, null, 'pendente: não tem papel válido');
select is((select count(*) from public.perfis), 1::bigint, 'pendente: só enxerga o próprio perfil');
select throws_ok($$ update public.perfis set situacao = 'aprovado' where id = '00000000-0000-0000-0000-0000000000e1' $$,
                 '42501', null, 'pendente: não consegue se auto-aprovar');
select throws_ok($$ update public.perfis set papel = 'administrador' where id = '00000000-0000-0000-0000-0000000000e1' $$,
                 '42501', null, 'pendente: não consegue se promover');
reset role;

-- ===== Recusado =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-0000000000e2", "role": "authenticated"}', true);
set local role authenticated;
select is(public.papel_aprovado_atual()::text, null, 'recusado: não tem papel válido');
select is((select count(*) from public.perfis), 1::bigint, 'recusado: só enxerga o próprio perfil');
select throws_ok($$ update public.perfis set situacao = 'aprovado' where id = '00000000-0000-0000-0000-0000000000e2' $$,
                 '42501', null, 'recusado: não consegue burlar a recusa');
reset role;

-- ===== Acesso removido (mesmo com papel gravado) =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-0000000000e3", "role": "authenticated"}', true);
set local role authenticated;
select is(public.papel_aprovado_atual()::text, null, 'acesso removido: papel gravado não vale');
select is((select count(*) from public.perfis where id <> '00000000-0000-0000-0000-0000000000e3'),
          0::bigint, 'acesso removido: não enxerga perfis alheios, mesmo com "administrador" gravado');
reset role;

-- ===== Sem login =====
set local role anon;
select throws_ok($$ select public.papel_aprovado_atual() $$, '42501', null, 'anônimo não executa a função de papel');
reset role;

-- Recusado que tenta se cadastrar de novo com o mesmo email cai na mesma conta (email único).
select throws_ok($$ insert into auth.users (id, email, aud, role)
                    values (gen_random_uuid(), 'rec.e@exemplo.com', 'authenticated', 'authenticated') $$,
                 '23505', null, 'mesmo email não cria segunda conta (não burla a recusa)');

select is((select situacao::text from public.perfis where id = '00000000-0000-0000-0000-0000000000e2'),
          'recusado', 'a situação do recusado segue intacta');

select * from finish();
rollback;
