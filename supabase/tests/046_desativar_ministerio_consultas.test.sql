-- T018: desativar_ministerio fecha as consultas abertas (RF-013).
begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

create or replace function public.agora_sp() returns timestamptz language sql stable as
  $$ select '2026-12-10 12:00:00+00'::timestamptz $$;

-- 4601 adm, 4602 líder A, 4603 part A
insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role)
select ('00000000-0000-0000-0000-0000000046' || lpad(n::text, 2, '0'))::uuid, 'u' || n || '.46@exemplo.com', now(),
       jsonb_build_object('nome', 'Pessoa 46 ' || n), 'authenticated', 'authenticated'
  from unnest(array[1, 2, 3]) as n;
update public.perfis set situacao = 'aprovado' where id::text like '00000000-0000-0000-0000-0000000046%';
update public.perfis set papel = 'administrador' where id = '00000000-0000-0000-0000-000000004601';
insert into public.ministerios (id, nome, descricao) values
  ('00000000-0000-0000-0000-00000046000a', 'Teste Desat 46 A', ''),
  ('00000000-0000-0000-0000-00000046000b', 'Teste Desat 46 B', '');
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel) values
  ('00000000-0000-0000-0000-00000046000a', '00000000-0000-0000-0000-000000004602', 'lider'),
  ('00000000-0000-0000-0000-00000046000a', '00000000-0000-0000-0000-000000004603', 'participante'),
  ('00000000-0000-0000-0000-00000046000b', '00000000-0000-0000-0000-000000004602', 'lider');
insert into public.consultas_disponibilidade (id, ministerio_id, titulo, fechada) values
  ('00000000-0000-0000-0000-00000046c001', '00000000-0000-0000-0000-00000046000a', 'Aberta A', false),
  ('00000000-0000-0000-0000-00000046c002', '00000000-0000-0000-0000-00000046000a', 'Já fechada A', true),
  ('00000000-0000-0000-0000-00000046c00b', '00000000-0000-0000-0000-00000046000b', 'Aberta B', false);
insert into public.datas_consulta (id, consulta_id, ministerio_id, data) values
  ('00000000-0000-0000-0000-00000046d001', '00000000-0000-0000-0000-00000046c001', '00000000-0000-0000-0000-00000046000a', '2026-12-13'),
  ('00000000-0000-0000-0000-00000046d00b', '00000000-0000-0000-0000-00000046c00b', '00000000-0000-0000-0000-00000046000b', '2026-12-13');
insert into public.respostas_disponibilidade (data_id, perfil_id, resposta) values
  ('00000000-0000-0000-0000-00000046d001', '00000000-0000-0000-0000-000000004603', 'disponivel');

select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000004601", "role": "authenticated"}', true);
set local role authenticated;
select lives_ok($$ select public.desativar_ministerio('00000000-0000-0000-0000-00000046000a') $$, 'administrador desativa o ministério A');
reset role;
select is((select fechada from public.consultas_disponibilidade where id = '00000000-0000-0000-0000-00000046c001'), true, 'a consulta aberta do A passou a fechada');
select is((select fechada from public.consultas_disponibilidade where id = '00000000-0000-0000-0000-00000046c002'), true, 'a já fechada continua fechada');
select is((select fechada from public.consultas_disponibilidade where id = '00000000-0000-0000-0000-00000046c00b'), false, 'consulta de outro ministério não muda');
select is((select count(*) from public.respostas_disponibilidade where data_id = '00000000-0000-0000-0000-00000046d001'), 1::bigint, 'nada é apagado: a resposta continua gravada');
select is((select count(*) from public.consultas_disponibilidade where ministerio_id = '00000000-0000-0000-0000-00000046000a'), 2::bigint, 'as consultas continuam no histórico');
select ok(not public.consulta_esta_aberta((select c from public.consultas_disponibilidade c where id = '00000000-0000-0000-0000-00000046c001')), 'a consulta já não vale como aberta');
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000004601", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.reabrir_consulta('00000000-0000-0000-0000-00000046c001') $$, 'P0001', 'ministerio_inativo', 'reabrir com o ministério desativado é recusado');
reset role;

select * from finish();
rollback;
