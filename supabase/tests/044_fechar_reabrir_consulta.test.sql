-- T016: fechar_consulta e reabrir_consulta, com relógio fixo (10/12/2026).
begin;
create extension if not exists pgtap with schema extensions;
select plan(17);

create or replace function public.agora_sp() returns timestamptz language sql stable as
  $$ select '2026-12-10 12:00:00+00'::timestamptz $$;

-- 4401 adm, 4402 líder A, 4403 participante A, 4404 líder B
insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role)
select ('00000000-0000-0000-0000-0000000044' || lpad(n::text, 2, '0'))::uuid, 'u' || n || '.44@exemplo.com', now(),
       jsonb_build_object('nome', 'Pessoa 44 ' || n), 'authenticated', 'authenticated'
  from unnest(array[1, 2, 3, 4]) as n;
update public.perfis set situacao = 'aprovado' where id::text like '00000000-0000-0000-0000-0000000044%';
update public.perfis set papel = 'administrador' where id = '00000000-0000-0000-0000-000000004401';
insert into public.ministerios (id, nome, descricao) values
  ('00000000-0000-0000-0000-00000044000a', 'Teste Fechar 44 A', ''),
  ('00000000-0000-0000-0000-00000044000b', 'Teste Fechar 44 B', '');
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel) values
  ('00000000-0000-0000-0000-00000044000a', '00000000-0000-0000-0000-000000004402', 'lider'),
  ('00000000-0000-0000-0000-00000044000a', '00000000-0000-0000-0000-000000004403', 'participante'),
  ('00000000-0000-0000-0000-00000044000b', '00000000-0000-0000-0000-000000004404', 'lider');
insert into public.consultas_disponibilidade (id, ministerio_id, titulo, prazo, fechada) values
  ('00000000-0000-0000-0000-00000044c001', '00000000-0000-0000-0000-00000044000a', 'Aberta sem prazo', null, false),
  ('00000000-0000-0000-0000-00000044c002', '00000000-0000-0000-0000-00000044000a', 'Fechada pelo líder', null, true),
  ('00000000-0000-0000-0000-00000044c003', '00000000-0000-0000-0000-00000044000a', 'Prazo vencido', '2026-12-09', false),
  ('00000000-0000-0000-0000-00000044c004', '00000000-0000-0000-0000-00000044000a', 'Prazo hoje', '2026-12-10', false),
  ('00000000-0000-0000-0000-00000044c005', '00000000-0000-0000-0000-00000044000a', 'Fechada com prazo vencido', '2026-12-01', true);

select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000004402", "role": "authenticated"}', true);
set local role authenticated;

-- ===== fechar =====
select is((public.fechar_consulta('00000000-0000-0000-0000-00000044c001')).fechada, true, 'líder fecha a consulta');
select is((public.fechar_consulta('00000000-0000-0000-0000-00000044c001')).fechada, true, 'fechar é idempotente');

-- ===== reabrir =====
select is((public.reabrir_consulta('00000000-0000-0000-0000-00000044c001')).fechada, false, 'reabre consulta fechada pelo líder (prazo não venceu)');
select throws_ok($$ select public.reabrir_consulta('00000000-0000-0000-0000-00000044c001') $$, 'P0001', 'consulta_ja_aberta', 'já aberta');
-- Prazo vencido vale como fechada: reabrir sem novo prazo é recusado.
select throws_ok($$ select public.reabrir_consulta('00000000-0000-0000-0000-00000044c003') $$, 'P0001', 'prazo_vencido', 'prazo vencido: reabrir sem mudar o prazo é recusado');
select throws_ok($$ select public.reabrir_consulta('00000000-0000-0000-0000-00000044c005') $$, 'P0001', 'prazo_vencido', 'fechada pelo líder e com prazo vencido: exige novo prazo');
select throws_ok($$ select public.reabrir_consulta('00000000-0000-0000-0000-00000044c003', '2026-12-09') $$, 'P0001', 'prazo_invalido', 'novo prazo no passado');
select is((public.reabrir_consulta('00000000-0000-0000-0000-00000044c003', '2026-12-10')).prazo, date '2026-12-10', 'novo prazo de hoje reabre');
select is((public.reabrir_consulta('00000000-0000-0000-0000-00000044c005', null, true)).prazo, null::date, 'remover o prazo também reabre');
select is((public.reabrir_consulta('00000000-0000-0000-0000-00000044c002')).fechada, false, 'sem prazo: reabre direto');
select throws_ok($$ select public.reabrir_consulta('00000000-0000-0000-0000-00000044c004') $$, 'P0001', 'consulta_ja_aberta', 'prazo é hoje: ainda aberta');
select throws_ok($$ select public.fechar_consulta('00000000-0000-0000-0000-00000044c999') $$, 'P0001', 'sem_permissao', 'consulta inexistente: líder recebe sem_permissao');
reset role;

-- Prazo vencido com relógio no dia seguinte: a consulta de prazo hoje passa a fechada sem ação alguma.
create or replace function public.agora_sp() returns timestamptz language sql stable as
  $$ select '2026-12-11 12:00:00+00'::timestamptz $$;
select ok(not public.consulta_esta_aberta((select c from public.consultas_disponibilidade c where id = '00000000-0000-0000-0000-00000044c004')),
          'no dia seguinte ao prazo a consulta vale como fechada, sem ninguém ter feito nada');

-- Permissões
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000004404", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.fechar_consulta('00000000-0000-0000-0000-00000044c004') $$, 'P0001', 'sem_permissao', 'líder de outro ministério não fecha');
reset role;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000004403", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.reabrir_consulta('00000000-0000-0000-0000-00000044c004') $$, 'P0001', 'sem_permissao', 'participante comum não reabre');
reset role;

-- Ministério inativo e nenhuma função de exclusão
update public.ministerios set ativo = false where id = '00000000-0000-0000-0000-00000044000a';
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000004401", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.reabrir_consulta('00000000-0000-0000-0000-00000044c004') $$, 'P0001', 'ministerio_inativo', 'ministério desativado: nem o administrador reabre');
reset role;
select is((select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public' and p.proname ~ '(apagar|excluir|remover)_consulta'), 0::bigint,
          'não existe função que apague consultas');

select * from finish();
rollback;
