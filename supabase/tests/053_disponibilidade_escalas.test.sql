-- T056: disponibilidade_da_escala. Relógio: 10/12/2026.
begin;
create extension if not exists pgtap with schema extensions;
select plan(11);

create or replace function public.agora_sp() returns timestamptz language sql stable as
  $$ select '2026-12-10 12:00:00+00'::timestamptz $$;

-- 5301 líder A, 5302 Ana, 5303 Bia, 5304 Caio, 5305 estranho, 5306 saiu
insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role)
select ('00000000-0000-0000-0000-0000000053' || lpad(n::text, 2, '0'))::uuid, 'u' || n || '.53@exemplo.com', now(),
       jsonb_build_object('nome', 'Pessoa 53 ' || n), 'authenticated', 'authenticated'
  from unnest(array[1, 2, 3, 4, 5, 6]) as n;
update public.perfis set situacao = 'aprovado' where id::text like '00000000-0000-0000-0000-0000000053%';
insert into public.ministerios (id, nome, descricao) values
  ('00000000-0000-0000-0000-00000053000a', 'Teste DispEsc 53 A', ''),
  ('00000000-0000-0000-0000-00000053000b', 'Teste DispEsc 53 B', '');
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel) values
  ('00000000-0000-0000-0000-00000053000a', '00000000-0000-0000-0000-000000005301', 'lider'),
  ('00000000-0000-0000-0000-00000053000a', '00000000-0000-0000-0000-000000005302', 'participante'),
  ('00000000-0000-0000-0000-00000053000a', '00000000-0000-0000-0000-000000005303', 'participante'),
  ('00000000-0000-0000-0000-00000053000a', '00000000-0000-0000-0000-000000005304', 'participante');
insert into public.consultas_disponibilidade (id, ministerio_id, titulo, fechada) values
  ('00000000-0000-0000-0000-00000053c001', '00000000-0000-0000-0000-00000053000a', 'Dezembro A', false),
  ('00000000-0000-0000-0000-00000053c00b', '00000000-0000-0000-0000-00000053000b', 'Dezembro B', false);
insert into public.datas_consulta (id, consulta_id, ministerio_id, data) values
  ('00000000-0000-0000-0000-00000053d001', '00000000-0000-0000-0000-00000053c001', '00000000-0000-0000-0000-00000053000a', '2026-12-13'),
  ('00000000-0000-0000-0000-00000053d00b', '00000000-0000-0000-0000-00000053c00b', '00000000-0000-0000-0000-00000053000b', '2026-12-20');
insert into public.respostas_disponibilidade (data_id, perfil_id, resposta) values
  ('00000000-0000-0000-0000-00000053d001', '00000000-0000-0000-0000-000000005302', 'disponivel'),
  ('00000000-0000-0000-0000-00000053d001', '00000000-0000-0000-0000-000000005303', 'indisponivel'),
  ('00000000-0000-0000-0000-00000053d001', '00000000-0000-0000-0000-000000005306', 'indisponivel');
insert into public.escalas (id, ministerio_id, evento, data, horario, situacao) values
  ('00000000-0000-0000-0000-00000053e001', '00000000-0000-0000-0000-00000053000a', 'Culto na data da consulta', '2026-12-13', '09:00', 'rascunho'),
  ('00000000-0000-0000-0000-00000053e002', '00000000-0000-0000-0000-00000053000a', 'Culto fora de consulta', '2026-12-27', '09:00', 'rascunho'),
  ('00000000-0000-0000-0000-00000053e003', '00000000-0000-0000-0000-00000053000a', 'Data só na consulta do B', '2026-12-20', '09:00', 'rascunho');

select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000005301", "role": "authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.disponibilidade_da_escala('00000000-0000-0000-0000-00000053e001')), 4::bigint, 'um resultado por participante ativo (quem saiu não aparece)');
select is((select resposta from public.disponibilidade_da_escala('00000000-0000-0000-0000-00000053e001') where perfil_id = '00000000-0000-0000-0000-000000005302'), 'disponivel', 'Ana: disponível');
select is((select resposta from public.disponibilidade_da_escala('00000000-0000-0000-0000-00000053e001') where perfil_id = '00000000-0000-0000-0000-000000005303'), 'indisponivel', 'Bia: indisponível');
select is((select resposta from public.disponibilidade_da_escala('00000000-0000-0000-0000-00000053e001') where perfil_id = '00000000-0000-0000-0000-000000005304'), 'sem_resposta', 'Caio: sem resposta');
select is((select count(*) from public.disponibilidade_da_escala('00000000-0000-0000-0000-00000053e001') where perfil_id = '00000000-0000-0000-0000-000000005306'), 0::bigint, 'quem saiu do ministério não aparece');
select is((select count(*) from public.disponibilidade_da_escala('00000000-0000-0000-0000-00000053e002')), 0::bigint, 'data da escala sem consulta: nenhuma linha (nada a mostrar)');
select is((select count(*) from public.disponibilidade_da_escala('00000000-0000-0000-0000-00000053e003')), 0::bigint, 'consulta de OUTRO ministério com a mesma data é ignorada');
reset role;

-- Consulta fechada continua valendo para quem escala
update public.consultas_disponibilidade set fechada = true where id = '00000000-0000-0000-0000-00000053c001';
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000005301", "role": "authenticated"}', true);
set local role authenticated;
select is((select resposta from public.disponibilidade_da_escala('00000000-0000-0000-0000-00000053e001') where perfil_id = '00000000-0000-0000-0000-000000005303'), 'indisponivel', 'com a consulta fechada a resposta continua aparecendo');
reset role;

-- Só o gestor
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000005302", "role": "authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.disponibilidade_da_escala('00000000-0000-0000-0000-00000053e001')), 0::bigint, 'participante comum não recebe nada');
reset role;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000005305", "role": "authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.disponibilidade_da_escala('00000000-0000-0000-0000-00000053e001')), 0::bigint, 'estranho não recebe nada');
reset role;
select set_config('request.jwt.claims', '{"role": "anon"}', true);
set local role anon;
select throws_ok($$ select * from public.disponibilidade_da_escala('00000000-0000-0000-0000-00000053e001') $$, '42501', null, 'anônimo não executa');
reset role;

select * from finish();
rollback;
