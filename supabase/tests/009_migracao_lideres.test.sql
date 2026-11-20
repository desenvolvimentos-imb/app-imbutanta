-- T003: o papel global "líder" deixa de existir (RF-027). A liderança passa a ser por ministério.
-- Confere a constraint, a recusa em alterar_papel e a conversão dos dados antigos.
begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role) values
  ('00000000-0000-0000-0000-000000000a01', 'adm.a@exemplo.com', now(), '{"nome":"Adm A"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000a02', 'mem.a@exemplo.com', now(), '{"nome":"Mem A"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000a03', 'lid.a@exemplo.com', now(), '{"nome":"Lid A"}', 'authenticated', 'authenticated');
update public.perfis set situacao = 'aprovado', papel = 'administrador' where id = '00000000-0000-0000-0000-000000000a01';
update public.perfis set situacao = 'aprovado', papel = 'membro'        where id in
  ('00000000-0000-0000-0000-000000000a02', '00000000-0000-0000-0000-000000000a03');

-- ===== A constraint barra o valor 'lider' =====
select throws_ok($$ update public.perfis set papel = 'lider' where id = '00000000-0000-0000-0000-000000000a02' $$,
                 '23514', null, 'o banco não aceita mais papel global "lider"');

-- ===== alterar_papel recusa 'lider' com um erro claro =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000a01", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.alterar_papel('00000000-0000-0000-0000-000000000a02', 'lider', 'aprovado') $$,
                 'P0001', 'transicao_invalida', 'alterar_papel não promove a "lider"');
select lives_ok($$ select public.alterar_papel('00000000-0000-0000-0000-000000000a02', 'administrador', 'aprovado') $$,
                'continua possível promover a administrador');
reset role;

-- ===== Conversão dos dados antigos =====
-- Simula um banco que ainda tinha um líder global: remove a constraint, grava o líder e
-- roda o MESMO update da migração. Depois recria a constraint (tudo desfeito no rollback).
alter table public.perfis drop constraint perfis_papel_sem_lider;
update public.perfis set papel = 'lider' where id = '00000000-0000-0000-0000-000000000a03';
update public.perfis set papel = 'membro' where papel = 'lider';
alter table public.perfis add constraint perfis_papel_sem_lider check (papel <> 'lider');

select is((select papel::text from public.perfis where id = '00000000-0000-0000-0000-000000000a03'),
          'membro', 'o líder global antigo virou membro');
select is((select situacao::text from public.perfis where id = '00000000-0000-0000-0000-000000000a03'),
          'aprovado', 'a conta continua aprovada');
select is((select nome from public.perfis where id = '00000000-0000-0000-0000-000000000a03'),
          'Lid A', 'nenhum outro dado foi perdido');
select is((select count(*) from public.perfis where papel = 'lider'), 0::bigint,
          'nenhum perfil com papel "lider" sobra');
select is((select papel::text from public.perfis where id = '00000000-0000-0000-0000-000000000a01'),
          'administrador', 'administradores não são afetados');

select * from finish();
rollback;
