-- T042: ler_consulta_gestor (grade). Relógio: 10/12/2026.
begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

create or replace function public.agora_sp() returns timestamptz language sql stable as
  $$ select '2026-12-10 12:00:00+00'::timestamptz $$;

-- 5001 líder A, 5002 P1 (respondeu tudo), 5003 P2 (parcial), 5004 P3 (nada), 5005 saiu, 5006 admin, 5007 líder B
insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role)
select ('00000000-0000-0000-0000-0000000050' || lpad(n::text, 2, '0'))::uuid, 'u' || n || '.50@exemplo.com', now(),
       jsonb_build_object('nome', case n when 1 then 'Lider' when 2 then 'Ana' when 3 then 'Bia' when 4 then 'Caio' when 5 then 'Saiu' when 6 then 'Admin' else 'LiderB' end),
       'authenticated', 'authenticated'
  from unnest(array[1, 2, 3, 4, 5, 6, 7]) as n;
update public.perfis set situacao = 'aprovado' where id::text like '00000000-0000-0000-0000-0000000050%';
update public.perfis set papel = 'administrador' where id = '00000000-0000-0000-0000-000000005006';
insert into public.ministerios (id, nome, descricao) values
  ('00000000-0000-0000-0000-00000050000a', 'Teste Grade 50 A', ''),
  ('00000000-0000-0000-0000-00000050000b', 'Teste Grade 50 B', '');
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel) values
  ('00000000-0000-0000-0000-00000050000a', '00000000-0000-0000-0000-000000005001', 'lider'),
  ('00000000-0000-0000-0000-00000050000a', '00000000-0000-0000-0000-000000005002', 'participante'),
  ('00000000-0000-0000-0000-00000050000a', '00000000-0000-0000-0000-000000005003', 'participante'),
  ('00000000-0000-0000-0000-00000050000a', '00000000-0000-0000-0000-000000005004', 'participante'),
  ('00000000-0000-0000-0000-00000050000b', '00000000-0000-0000-0000-000000005007', 'lider');
insert into public.consultas_disponibilidade (id, ministerio_id, titulo, prazo) values
  ('00000000-0000-0000-0000-00000050c001', '00000000-0000-0000-0000-00000050000a', 'Dezembro', '2026-12-30');
insert into public.datas_consulta (id, consulta_id, ministerio_id, data, rotulo) values
  ('00000000-0000-0000-0000-00000050d001', '00000000-0000-0000-0000-00000050c001', '00000000-0000-0000-0000-00000050000a', '2026-12-13', 'Culto especial'),
  ('00000000-0000-0000-0000-00000050d002', '00000000-0000-0000-0000-00000050c001', '00000000-0000-0000-0000-00000050000a', '2026-12-20', ''),
  ('00000000-0000-0000-0000-00000050d003', '00000000-0000-0000-0000-00000050c001', '00000000-0000-0000-0000-00000050000a', '2026-12-06', '');
insert into public.respostas_disponibilidade (data_id, perfil_id, resposta, preenchida_por) values
  ('00000000-0000-0000-0000-00000050d001', '00000000-0000-0000-0000-000000005002', 'disponivel', null),
  ('00000000-0000-0000-0000-00000050d002', '00000000-0000-0000-0000-000000005002', 'indisponivel', null),
  ('00000000-0000-0000-0000-00000050d003', '00000000-0000-0000-0000-000000005002', 'disponivel', null),
  ('00000000-0000-0000-0000-00000050d001', '00000000-0000-0000-0000-000000005003', 'disponivel', '00000000-0000-0000-0000-000000005001'),
  ('00000000-0000-0000-0000-00000050d001', '00000000-0000-0000-0000-000000005005', 'disponivel', null);
insert into public.observacoes_disponibilidade (consulta_id, perfil_id, texto) values
  ('00000000-0000-0000-0000-00000050c001', '00000000-0000-0000-0000-000000005002', 'Posso se for preciso');

select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000005001", "role": "authenticated"}', true);
set local role authenticated;
select is(jsonb_array_length(public.ler_consulta_gestor('00000000-0000-0000-0000-00000050c001') -> 'participantes'), 4, 'linhas: líder, Ana, Bia e Caio (quem saiu não entra)');
select is(public.ler_consulta_gestor('00000000-0000-0000-0000-00000050c001') -> 'participantes' -> 0 ->> 'nome', 'Ana', 'ordenado por nome');
select is(public.ler_consulta_gestor('00000000-0000-0000-0000-00000050c001') -> 'datas' -> 0 ->> 'data', '2026-12-06', 'datas em ordem');
select is((public.ler_consulta_gestor('00000000-0000-0000-0000-00000050c001') -> 'datas' -> 1 ->> 'disponiveis')::int, 2, '13/12: 2 disponíveis (Ana e Bia; quem saiu não conta)');
select is((public.ler_consulta_gestor('00000000-0000-0000-0000-00000050c001') -> 'datas' -> 1 ->> 'sem_resposta')::int, 2, '13/12: 2 sem resposta (líder e Caio), sem misturar com indisponível');
select is((public.ler_consulta_gestor('00000000-0000-0000-0000-00000050c001') -> 'datas' -> 1 ->> 'indisponiveis')::int, 0, '13/12: nenhuma indisponível');
select is((public.ler_consulta_gestor('00000000-0000-0000-0000-00000050c001') -> 'datas' -> 2 ->> 'indisponiveis')::int, 1, '20/12: 1 indisponível');
select is((public.ler_consulta_gestor('00000000-0000-0000-0000-00000050c001') -> 'datas' -> 0 ->> 'passada'), 'true', '06/12 já passou');
select is(public.ler_consulta_gestor('00000000-0000-0000-0000-00000050c001') -> 'participantes' -> 3 ->> 'nao_respondeu', 'true', 'Caio não respondeu nada: destaque');
select is(public.ler_consulta_gestor('00000000-0000-0000-0000-00000050c001') -> 'participantes' -> 0 ->> 'nao_respondeu', 'false', 'Ana respondeu');
select is(public.ler_consulta_gestor('00000000-0000-0000-0000-00000050c001') -> 'participantes' -> 0 ->> 'observacao', 'Posso se for preciso', 'observação da Ana aparece');
select is(public.ler_consulta_gestor('00000000-0000-0000-0000-00000050c001') -> 'participantes' -> 1 -> 'respostas' -> '00000000-0000-0000-0000-00000050d001' ->> 'preenchida_pelo_lider', 'true', 'resposta da Bia veio do líder');
select is(public.ler_consulta_gestor('00000000-0000-0000-0000-00000050c001') -> 'consulta' ->> 'aberta', 'true', 'consulta aberta');
reset role;

-- Quem saiu volta com as respostas preservadas
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel) values
  ('00000000-0000-0000-0000-00000050000a', '00000000-0000-0000-0000-000000005005', 'participante');
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000005001", "role": "authenticated"}', true);
set local role authenticated;
select is((public.ler_consulta_gestor('00000000-0000-0000-0000-00000050c001') -> 'datas' -> 1 ->> 'disponiveis')::int, 3, 'ao voltar, a resposta de quem saiu reaparece');
reset role;

-- Administrador lê qualquer ministério; consulta fechada continua legível; sem permissão => nulo
update public.consultas_disponibilidade set fechada = true where id = '00000000-0000-0000-0000-00000050c001';
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000005006", "role": "authenticated"}', true);
set local role authenticated;
select is(public.ler_consulta_gestor('00000000-0000-0000-0000-00000050c001') -> 'consulta' ->> 'motivo_fechada', 'lider', 'administrador lê consulta fechada, com o motivo');
reset role;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000005007", "role": "authenticated"}', true);
set local role authenticated;
select is(public.ler_consulta_gestor('00000000-0000-0000-0000-00000050c001'), null::jsonb, 'líder de outro ministério recebe nulo');
reset role;

select * from finish();
rollback;
