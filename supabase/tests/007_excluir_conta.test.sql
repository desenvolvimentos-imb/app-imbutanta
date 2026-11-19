-- T056: excluir a própria conta (RF-030, RF-031, CS-006).
begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role) values
  ('00000000-0000-0000-0000-000000000a01', 'adm.x@exemplo.com', now(), '{"nome":"Adm X"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000a02', 'mem.x@exemplo.com', now(), '{"nome":"Mem X"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000a03', 'pen.x@exemplo.com', now(), '{"nome":"Pen X"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000a04', 'rec.x@exemplo.com', now(), '{"nome":"Rec X"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000a05', 'rem.x@exemplo.com', now(), '{"nome":"Rem X"}', 'authenticated', 'authenticated');
-- Identidade do Google ligada ao membro: precisa sumir junto com a conta.
insert into auth.identities (id, user_id, provider_id, identity_data, provider)
values (gen_random_uuid(), '00000000-0000-0000-0000-000000000a02', 'google-x',
        '{"sub": "google-x", "email": "mem.x@exemplo.com"}', 'google');

update public.perfis set situacao = 'aprovado', papel = 'administrador' where id = '00000000-0000-0000-0000-000000000a01';
update public.perfis set situacao = 'aprovado', papel = 'membro'        where id = '00000000-0000-0000-0000-000000000a02';
update public.perfis set situacao = 'recusado'                          where id = '00000000-0000-0000-0000-000000000a04';
update public.perfis set situacao = 'acesso_removido'                   where id = '00000000-0000-0000-0000-000000000a05';

-- O seed local tem outro administrador, então o "a01" não é o único. Para testar o caso do
-- único administrador, desligamos o gatilho só para rebaixar os demais (desfeito no rollback).
alter table public.perfis disable trigger trg_proteger_ultimo_administrador;
update public.perfis set papel = 'membro'
 where papel = 'administrador' and id <> '00000000-0000-0000-0000-000000000a01';
alter table public.perfis enable trigger trg_proteger_ultimo_administrador;

-- ===== Único administrador não pode se excluir =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000a01", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.excluir_minha_conta() $$, 'P0001', 'ultimo_administrador',
                 'único administrador não consegue excluir a própria conta');
reset role;
select is((select count(*) from auth.users where id = '00000000-0000-0000-0000-000000000a01'),
          1::bigint, 'a conta do único administrador continua existindo');

-- ===== Membro (com identidade Google) =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000a02", "role": "authenticated"}', true);
set local role authenticated;
select lives_ok($$ select public.excluir_minha_conta() $$, 'membro exclui a própria conta');
reset role;
select is((select count(*) from auth.users where id = '00000000-0000-0000-0000-000000000a02'), 0::bigint, 'usuário do Auth removido');
select is((select count(*) from public.perfis where id = '00000000-0000-0000-0000-000000000a02'), 0::bigint, 'perfil removido (nome e email)');
select is((select count(*) from auth.identities where user_id = '00000000-0000-0000-0000-000000000a02'), 0::bigint, 'identidade do Google removida');

-- ===== Pendente, recusado e acesso removido também podem (direito da LGPD) =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000a03", "role": "authenticated"}', true);
set local role authenticated;
select lives_ok($$ select public.excluir_minha_conta() $$, 'pendente exclui a própria conta');
reset role;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000a04", "role": "authenticated"}', true);
set local role authenticated;
select lives_ok($$ select public.excluir_minha_conta() $$, 'recusado exclui a própria conta');
reset role;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000a05", "role": "authenticated"}', true);
set local role authenticated;
select lives_ok($$ select public.excluir_minha_conta() $$, 'quem teve o acesso removido exclui a própria conta');
reset role;
select is((select count(*) from public.perfis where id in
            ('00000000-0000-0000-0000-000000000a03', '00000000-0000-0000-0000-000000000a04',
             '00000000-0000-0000-0000-000000000a05')),
          0::bigint, 'os três perfis foram removidos');

-- Só a própria conta: a de outra pessoa não foi tocada.
select is((select count(*) from public.perfis where id = '00000000-0000-0000-0000-000000000a01'),
          1::bigint, 'a conta de outra pessoa não é afetada');

-- Sem login: nada.
set local role anon;
select throws_ok($$ select public.excluir_minha_conta() $$, '42501', null, 'anônimo não executa a função');
reset role;

-- Depois de excluída, uma nova conta com o mesmo email começa pendente.
insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role)
values (gen_random_uuid(), 'mem.x@exemplo.com', now(), '{"nome":"Mem X Novo"}', 'authenticated', 'authenticated');
select is((select situacao::text from public.perfis where email = 'mem.x@exemplo.com'),
          'pendente', 'novo cadastro com o mesmo email começa como pendente');

select * from finish();
rollback;
