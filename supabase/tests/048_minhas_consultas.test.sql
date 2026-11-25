-- T031: minhas_consultas, ler_consulta_participante e contar_consultas_pendentes. Relógio: 10/12/2026.
begin;
create extension if not exists pgtap with schema extensions;
select plan(19);

create or replace function public.agora_sp() returns timestamptz language sql stable as
  $$ select '2026-12-10 12:00:00+00'::timestamptz $$;

-- 4801 P1 (A), 4802 P2 (A), 4803 estranho, 4804 P3 (inativo B)
insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role)
select ('00000000-0000-0000-0000-0000000048' || lpad(n::text, 2, '0'))::uuid, 'u' || n || '.48@exemplo.com', now(),
       jsonb_build_object('nome', 'Pessoa 48 ' || n), 'authenticated', 'authenticated'
  from unnest(array[1, 2, 3, 4]) as n;
update public.perfis set situacao = 'aprovado' where id::text like '00000000-0000-0000-0000-0000000048%';
insert into public.ministerios (id, nome, descricao) values
  ('00000000-0000-0000-0000-00000048000a', 'Teste Min 48 A', ''),
  ('00000000-0000-0000-0000-00000048000b', 'Teste Min 48 B', '');
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel) values
  ('00000000-0000-0000-0000-00000048000a', '00000000-0000-0000-0000-000000004801', 'participante'),
  ('00000000-0000-0000-0000-00000048000a', '00000000-0000-0000-0000-000000004802', 'participante'),
  ('00000000-0000-0000-0000-00000048000b', '00000000-0000-0000-0000-000000004804', 'participante');
insert into public.consultas_disponibilidade (id, ministerio_id, titulo, mensagem, prazo, fechada, criada_em) values
  ('00000000-0000-0000-0000-00000048c001', '00000000-0000-0000-0000-00000048000a', 'Aberta A', 'Marque', null, false, '2026-12-01'),
  ('00000000-0000-0000-0000-00000048c002', '00000000-0000-0000-0000-00000048000a', 'Fechada recente', '', null, true, '2026-11-20'),
  ('00000000-0000-0000-0000-00000048c003', '00000000-0000-0000-0000-00000048000a', 'Fechada antiga', '', null, true, '2026-08-01'),
  ('00000000-0000-0000-0000-00000048c00b', '00000000-0000-0000-0000-00000048000b', 'Do B', '', null, false, '2026-12-02');
insert into public.datas_consulta (id, consulta_id, ministerio_id, data) values
  ('00000000-0000-0000-0000-00000048d001', '00000000-0000-0000-0000-00000048c001', '00000000-0000-0000-0000-00000048000a', '2026-12-13'),
  ('00000000-0000-0000-0000-00000048d002', '00000000-0000-0000-0000-00000048c001', '00000000-0000-0000-0000-00000048000a', '2026-12-20'),
  ('00000000-0000-0000-0000-00000048d003', '00000000-0000-0000-0000-00000048c002', '00000000-0000-0000-0000-00000048000a', '2026-12-06'),
  ('00000000-0000-0000-0000-00000048d004', '00000000-0000-0000-0000-00000048c003', '00000000-0000-0000-0000-00000048000a', '2026-08-09'),
  ('00000000-0000-0000-0000-00000048d00b', '00000000-0000-0000-0000-00000048c00b', '00000000-0000-0000-0000-00000048000b', '2026-12-13');
insert into public.respostas_disponibilidade (data_id, perfil_id, resposta) values
  ('00000000-0000-0000-0000-00000048d001', '00000000-0000-0000-0000-000000004801', 'disponivel'),
  ('00000000-0000-0000-0000-00000048d001', '00000000-0000-0000-0000-000000004802', 'indisponivel');
-- A resposta do P1 foi preenchida por outra pessoa (líder): a própria pessoa nunca vê esse marcador.
update public.respostas_disponibilidade set preenchida_por = '00000000-0000-0000-0000-000000004802'
 where perfil_id = '00000000-0000-0000-0000-000000004801';
insert into public.observacoes_disponibilidade (consulta_id, perfil_id, texto) values
  ('00000000-0000-0000-0000-00000048c001', '00000000-0000-0000-0000-000000004802', 'Segredo do P2');

select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000004801", "role": "authenticated"}', true);
set local role authenticated;
select is(jsonb_array_length(public.minhas_consultas() -> 'abertas'), 1, 'P1 vê 1 consulta aberta (a do ministério dele)');
select is(public.minhas_consultas() -> 'abertas' -> 0 ->> 'titulo', 'Aberta A', 'é a do A');
select is((public.minhas_consultas() -> 'abertas' -> 0 ->> 'sem_resposta')::int, 1, 'falta 1 data a responder');
select is(public.minhas_consultas() -> 'abertas' -> 0 -> 'datas' -> 0 ->> 'resposta', 'disponivel', 'vê a própria resposta');
select is(public.minhas_consultas() -> 'abertas' -> 0 -> 'datas' -> 1 ->> 'resposta', null, 'data sem resposta vem como nulo');
select is(jsonb_array_length(public.minhas_consultas() -> 'fechadas_recentes'), 1, 'fechadas recentes: só a dos últimos 60 dias');
select is(public.minhas_consultas() -> 'fechadas_recentes' -> 0 ->> 'pode_responder', 'false', 'fechada: não pode responder');
select ok(public.minhas_consultas()::text not like '%Segredo do P2%' and public.minhas_consultas()::text not like '%u2.48%', 'não traz observação nem dados do colega');
select ok(public.minhas_consultas()::text not like '%preenchida%', 'minhas_consultas não traz quem preencheu nem o marcador do líder');
select ok(public.ler_consulta_participante('00000000-0000-0000-0000-00000048c001')::text not like '%preenchida%', 'ler_consulta_participante também não');
select is(public.ler_consulta_participante('00000000-0000-0000-0000-00000048c001') ->> 'titulo', 'Aberta A', 'ler_consulta_participante devolve a consulta');
select is(public.ler_consulta_participante('00000000-0000-0000-0000-00000048c002') ->> 'pode_responder', 'false', 'consulta fechada abre só para leitura');
select is(public.ler_consulta_participante('00000000-0000-0000-0000-00000048c00b'), null::jsonb, 'consulta de outro ministério: nulo');
select is(public.contar_consultas_pendentes(), 1, 'pendentes: 1 consulta aberta com data sem resposta');
reset role;

-- Responder tudo zera o aviso
insert into public.respostas_disponibilidade (data_id, perfil_id, resposta) values
  ('00000000-0000-0000-0000-00000048d002', '00000000-0000-0000-0000-000000004801', 'indisponivel');
set local role authenticated;
select is(public.contar_consultas_pendentes(), 0, 'respondeu tudo: nenhuma pendente');
reset role;

-- Estranho e ministério desativado
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000004803", "role": "authenticated"}', true);
set local role authenticated;
select is(jsonb_array_length(public.minhas_consultas() -> 'abertas') + public.contar_consultas_pendentes(), 0, 'quem não participa de nada não vê nem conta nada');
reset role;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000004804", "role": "authenticated"}', true);
set local role authenticated;
select is(public.contar_consultas_pendentes(), 1, 'P3 tem 1 pendente no ministério B ativo');
reset role;
update public.ministerios set ativo = false where id = '00000000-0000-0000-0000-00000048000b';
set local role authenticated;
select is(public.contar_consultas_pendentes(), 0, 'ministério desativado não conta como pendente');
reset role;
select set_config('request.jwt.claims', '{"role": "anon"}', true);
set local role anon;
select throws_ok($$ select public.minhas_consultas() $$, '42501', null, 'anônimo não executa');
reset role;

select * from finish();
rollback;
