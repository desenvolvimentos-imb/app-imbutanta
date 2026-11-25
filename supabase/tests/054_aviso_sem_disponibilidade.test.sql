-- T057: aviso `sem_disponibilidade` em salvar_vaga. Relógio: 10/12/2026.
begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

create or replace function public.agora_sp() returns timestamptz language sql stable as
  $$ select '2026-12-10 12:00:00+00'::timestamptz $$;

-- 5401 líder A, 5402 Ana (disponível), 5403 Bia (indisponível), 5404 Caio (sem resposta), 5405 Dani (sem resposta)
insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role)
select ('00000000-0000-0000-0000-0000000054' || lpad(n::text, 2, '0'))::uuid, 'u' || n || '.54@exemplo.com', now(),
       jsonb_build_object('nome', 'Pessoa 54 ' || n), 'authenticated', 'authenticated'
  from unnest(array[1, 2, 3, 4, 5]) as n;
update public.perfis set situacao = 'aprovado' where id::text like '00000000-0000-0000-0000-0000000054%';
insert into public.ministerios (id, nome, descricao) values
  ('00000000-0000-0000-0000-00000054000a', 'Teste Aviso 54 A', ''),
  ('00000000-0000-0000-0000-00000054000b', 'Teste Aviso 54 B', '');
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel) values
  ('00000000-0000-0000-0000-00000054000a', '00000000-0000-0000-0000-000000005401', 'lider'),
  ('00000000-0000-0000-0000-00000054000a', '00000000-0000-0000-0000-000000005402', 'participante'),
  ('00000000-0000-0000-0000-00000054000a', '00000000-0000-0000-0000-000000005403', 'participante'),
  ('00000000-0000-0000-0000-00000054000a', '00000000-0000-0000-0000-000000005404', 'participante'),
  ('00000000-0000-0000-0000-00000054000a', '00000000-0000-0000-0000-000000005405', 'participante');
insert into public.funcoes_ministerio (id, ministerio_id, nome) values
  ('00000000-0000-0000-0000-00000054f001', '00000000-0000-0000-0000-00000054000a', 'Vocal');
-- Todos aptos, para isolar o aviso novo do de aptidão.
insert into public.aptidoes (funcao_id, perfil_id, tipo)
select '00000000-0000-0000-0000-00000054f001', ('00000000-0000-0000-0000-0000000054' || lpad(n::text, 2, '0'))::uuid, 'principal'
  from unnest(array[2, 3, 4, 5]) n;
insert into public.consultas_disponibilidade (id, ministerio_id, titulo) values
  ('00000000-0000-0000-0000-00000054c001', '00000000-0000-0000-0000-00000054000a', 'Dezembro');
insert into public.datas_consulta (id, consulta_id, ministerio_id, data) values
  ('00000000-0000-0000-0000-00000054d001', '00000000-0000-0000-0000-00000054c001', '00000000-0000-0000-0000-00000054000a', '2026-12-13');
insert into public.respostas_disponibilidade (data_id, perfil_id, resposta) values
  ('00000000-0000-0000-0000-00000054d001', '00000000-0000-0000-0000-000000005402', 'disponivel'),
  ('00000000-0000-0000-0000-00000054d001', '00000000-0000-0000-0000-000000005403', 'indisponivel');
insert into public.escalas (id, ministerio_id, evento, data, horario, situacao) values
  ('00000000-0000-0000-0000-00000054e001', '00000000-0000-0000-0000-00000054000a', 'Na data da consulta', '2026-12-13', '09:00', 'rascunho'),
  ('00000000-0000-0000-0000-00000054e002', '00000000-0000-0000-0000-00000054000a', 'Fora de consulta', '2026-12-27', '09:00', 'rascunho');

select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000005401", "role": "authenticated"}', true);
set local role authenticated;
select is(jsonb_array_length(public.salvar_vaga('00000000-0000-0000-0000-00000054e001', null, '00000000-0000-0000-0000-00000054f001', '', '00000000-0000-0000-0000-000000005402') -> 'avisos'), 0, 'disponível: sem aviso');
select is(public.salvar_vaga('00000000-0000-0000-0000-00000054e001', null, '00000000-0000-0000-0000-00000054f001', '', '00000000-0000-0000-0000-000000005403') -> 'avisos' -> 0 ->> 'tipo', 'sem_disponibilidade', 'indisponível: aviso');
select is(public.salvar_vaga('00000000-0000-0000-0000-00000054e001', null, '00000000-0000-0000-0000-00000054f001', '', '00000000-0000-0000-0000-000000005403') -> 'avisos' -> 0 ->> 'resposta', 'indisponivel', 'o aviso diz "indisponivel"');
select is(public.salvar_vaga('00000000-0000-0000-0000-00000054e001', null, '00000000-0000-0000-0000-00000054f001', '', '00000000-0000-0000-0000-000000005404') -> 'avisos' -> 0 ->> 'resposta', 'sem_resposta', 'sem resposta: aviso "sem_resposta"');
select is(public.salvar_vaga('00000000-0000-0000-0000-00000054e001', null, '00000000-0000-0000-0000-00000054f001', '', '00000000-0000-0000-0000-000000005404') ->> 'salvo', 'false', 'com aviso e sem ciência, NADA é gravado');
reset role;
select is((select count(*) from public.vagas_escala where escala_id = '00000000-0000-0000-0000-00000054e001'), 1::bigint, 'só a vaga da Ana (disponível) foi gravada');
set local role authenticated;
select is(public.salvar_vaga('00000000-0000-0000-0000-00000054e001', null, '00000000-0000-0000-0000-00000054f001', '', '00000000-0000-0000-0000-000000005404', true) ->> 'salvo', 'true', 'com ciência do líder, grava');
-- Pessoa já escalada nesta escala: não recebe o aviso de novo
select is(jsonb_array_length(public.salvar_vaga('00000000-0000-0000-0000-00000054e001', null, '00000000-0000-0000-0000-00000054f001', 'Vocal 2', '00000000-0000-0000-0000-000000005404') -> 'avisos'), 0, 'quem já ocupa outra vaga da escala não gera o aviso de novo');
-- Data fora de consulta
select is(jsonb_array_length(public.salvar_vaga('00000000-0000-0000-0000-00000054e002', null, '00000000-0000-0000-0000-00000054f001', '', '00000000-0000-0000-0000-000000005405') -> 'avisos'), 0, 'data sem consulta: nenhum aviso');
reset role;

-- Consulta do OUTRO ministério com a mesma data não conta
insert into public.consultas_disponibilidade (id, ministerio_id, titulo) values
  ('00000000-0000-0000-0000-00000054c00b', '00000000-0000-0000-0000-00000054000b', 'Do B');
insert into public.datas_consulta (consulta_id, ministerio_id, data) values
  ('00000000-0000-0000-0000-00000054c00b', '00000000-0000-0000-0000-00000054000b', '2026-12-27');
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000005401", "role": "authenticated"}', true);
set local role authenticated;
select is(jsonb_array_length(public.salvar_vaga('00000000-0000-0000-0000-00000054e002', null, '00000000-0000-0000-0000-00000054f001', '', '00000000-0000-0000-0000-000000005403') -> 'avisos'), 0, 'consulta de outro ministério na mesma data é ignorada');
reset role;

-- Ordem dos avisos: o novo vem depois de sem_aptidao (os existentes não mudam)
delete from public.aptidoes where perfil_id = '00000000-0000-0000-0000-000000005403';
set local role authenticated;
select is(public.salvar_vaga('00000000-0000-0000-0000-00000054e001', null, '00000000-0000-0000-0000-00000054f001', '', '00000000-0000-0000-0000-000000005403') -> 'avisos' -> 0 ->> 'tipo', 'sem_aptidao', 'avisos existentes mantêm a posição (sem_aptidao primeiro)');
select is(public.salvar_vaga('00000000-0000-0000-0000-00000054e001', null, '00000000-0000-0000-0000-00000054f001', '', '00000000-0000-0000-0000-000000005403') -> 'avisos' -> 1 ->> 'tipo', 'sem_disponibilidade', 'e o novo aviso vem em seguida');
reset role;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000005402", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.salvar_vaga('00000000-0000-0000-0000-00000054e001', null, '00000000-0000-0000-0000-00000054f001', '', null) $$, 'P0001', 'sem_permissao', 'participante comum continua sem poder escalar');
reset role;

select * from finish();
rollback;
