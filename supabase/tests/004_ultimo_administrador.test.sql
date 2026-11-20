-- T012: o app nunca pode ficar sem administrador (RF-022, CS-008), mesmo por alteração
-- direta no banco. O seed local já tem um administrador, então o teste o desliga
-- temporariamente (tudo é desfeito pelo rollback no fim).
begin;
create extension if not exists pgtap with schema extensions;
select plan(7);

alter table public.perfis disable trigger trg_proteger_ultimo_administrador;
update public.perfis set papel = 'membro' where papel = 'administrador';
alter table public.perfis enable trigger trg_proteger_ultimo_administrador;

insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role) values
  ('00000000-0000-0000-0000-0000000000d1', 'adm1.t@exemplo.com', now(), '{"nome":"Adm Um"}',   'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000000d2', 'adm2.t@exemplo.com', now(), '{"nome":"Adm Dois"}', 'authenticated', 'authenticated');
update public.perfis set situacao = 'aprovado', papel = 'administrador'
 where id = '00000000-0000-0000-0000-0000000000d1';

-- Com um único administrador, nada que o elimine pode passar.
select throws_ok($$ update public.perfis set papel = 'membro' where id = '00000000-0000-0000-0000-0000000000d1' $$,
                 'P0001', 'ultimo_administrador', 'não rebaixa o único administrador');
select throws_ok($$ update public.perfis set situacao = 'acesso_removido' where id = '00000000-0000-0000-0000-0000000000d1' $$,
                 'P0001', 'ultimo_administrador', 'não remove o acesso do único administrador');
select throws_ok($$ delete from auth.users where id = '00000000-0000-0000-0000-0000000000d1' $$,
                 'P0001', 'ultimo_administrador', 'não apaga a conta do único administrador');

-- Com dois administradores, um pode sair; o outro passa a ser o último.
update public.perfis set situacao = 'aprovado', papel = 'administrador'
 where id = '00000000-0000-0000-0000-0000000000d2';
select lives_ok($$ update public.perfis set papel = 'membro' where id = '00000000-0000-0000-0000-0000000000d1' $$,
                'com dois administradores, um pode ser rebaixado');
select throws_ok($$ update public.perfis set papel = 'membro' where id = '00000000-0000-0000-0000-0000000000d2' $$,
                 'P0001', 'ultimo_administrador', 'o que sobrou virou o último e fica protegido');

-- Mudanças que não afetam o administrador continuam livres.
select lives_ok($$ update public.perfis set nome = 'Adm Dois Editado' where id = '00000000-0000-0000-0000-0000000000d2' $$,
                'alterar o nome do último administrador é permitido');
select lives_ok($$ update public.perfis set papel = 'administrador' where id = '00000000-0000-0000-0000-0000000000d1' $$,
                'promover alguém a administrador é permitido');

select * from finish();
rollback;
