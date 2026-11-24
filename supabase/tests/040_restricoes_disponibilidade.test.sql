-- T005: restrições de integridade das tabelas de disponibilidade (data-model.md da 004).
begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role) values
  ('00000000-0000-0000-0000-000000004001', 'lider.40@exemplo.com', now(), '{"nome":"Lider 40"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000004002', 'part.40@exemplo.com',  now(), '{"nome":"Part 40"}',  'authenticated', 'authenticated');
update public.perfis set situacao = 'aprovado' where id::text like '00000000-0000-0000-0000-0000000040%';

insert into public.ministerios (id, nome, descricao) values
  ('00000000-0000-0000-0000-00000040000a', 'Teste Disp 40 A', ''),
  ('00000000-0000-0000-0000-00000040000b', 'Teste Disp 40 B', '');
insert into public.consultas_disponibilidade (id, ministerio_id, titulo, criada_por) values
  ('00000000-0000-0000-0000-00000040c001', '00000000-0000-0000-0000-00000040000a', 'Dezembro A', '00000000-0000-0000-0000-000000004001'),
  ('00000000-0000-0000-0000-00000040c002', '00000000-0000-0000-0000-00000040000a', 'Janeiro A', null),
  ('00000000-0000-0000-0000-00000040c003', '00000000-0000-0000-0000-00000040000b', 'Dezembro B', null);
insert into public.datas_consulta (id, consulta_id, ministerio_id, data) values
  ('00000000-0000-0000-0000-00000040d001', '00000000-0000-0000-0000-00000040c001', '00000000-0000-0000-0000-00000040000a', '2026-12-06');

-- ===== Unicidade da data por ministério =====
select throws_ok($$ insert into public.datas_consulta (consulta_id, ministerio_id, data)
  values ('00000000-0000-0000-0000-00000040c002', '00000000-0000-0000-0000-00000040000a', '2026-12-06') $$,
  '23505', null, 'a mesma data em duas consultas do mesmo ministério é recusada (mesmo por escrita direta)');
select lives_ok($$ insert into public.datas_consulta (consulta_id, ministerio_id, data)
  values ('00000000-0000-0000-0000-00000040c003', '00000000-0000-0000-0000-00000040000b', '2026-12-06') $$,
  'a mesma data em outro ministério é permitida');
select throws_ok($$ insert into public.datas_consulta (consulta_id, ministerio_id, data)
  values ('00000000-0000-0000-0000-00000040c001', '00000000-0000-0000-0000-00000040000b', '2026-12-13') $$,
  '23503', null, 'o ministério da data precisa ser o da consulta');

-- ===== Limites de tamanho =====
select throws_ok($$ insert into public.consultas_disponibilidade (ministerio_id, titulo)
  values ('00000000-0000-0000-0000-00000040000a', 'A') $$, '23514', null, 'título curto demais é recusado');
select throws_ok($$ insert into public.consultas_disponibilidade (ministerio_id, titulo)
  values ('00000000-0000-0000-0000-00000040000a', repeat('x', 81)) $$, '23514', null, 'título longo demais é recusado');
select throws_ok($$ insert into public.consultas_disponibilidade (ministerio_id, titulo, mensagem)
  values ('00000000-0000-0000-0000-00000040000a', 'Ok', repeat('x', 501)) $$, '23514', null, 'mensagem acima de 500 é recusada');
select throws_ok($$ insert into public.datas_consulta (consulta_id, ministerio_id, data, rotulo)
  values ('00000000-0000-0000-0000-00000040c002', '00000000-0000-0000-0000-00000040000a', '2027-01-03', repeat('x', 41)) $$,
  '23514', null, 'rótulo acima de 40 é recusado');

-- ===== Respostas e observações =====
insert into public.respostas_disponibilidade (data_id, perfil_id, resposta) values
  ('00000000-0000-0000-0000-00000040d001', '00000000-0000-0000-0000-000000004002', 'disponivel');
insert into public.observacoes_disponibilidade (consulta_id, perfil_id, texto) values
  ('00000000-0000-0000-0000-00000040c001', '00000000-0000-0000-0000-000000004002', 'Prefiro a manhã');
select throws_ok($$ insert into public.respostas_disponibilidade (data_id, perfil_id, resposta)
  values ('00000000-0000-0000-0000-00000040d001', '00000000-0000-0000-0000-000000004001', 'sem_resposta') $$,
  '22P02', null, '"sem resposta" não é um valor de resposta (é a ausência de linha)');
select throws_ok($$ insert into public.observacoes_disponibilidade (consulta_id, perfil_id, texto)
  values ('00000000-0000-0000-0000-00000040c002', '00000000-0000-0000-0000-000000004002', repeat('x', 301)) $$,
  '23514', null, 'observação acima de 300 é recusada');

-- Excluir uma data apaga as respostas dela.
insert into public.respostas_disponibilidade (data_id, perfil_id, resposta) values
  ('00000000-0000-0000-0000-00000040d001', '00000000-0000-0000-0000-000000004001', 'indisponivel');
delete from public.datas_consulta where id = '00000000-0000-0000-0000-00000040d001';
select is((select count(*) from public.respostas_disponibilidade where data_id = '00000000-0000-0000-0000-00000040d001'),
          0::bigint, 'remover a data descarta as respostas dela');

-- Excluir conta: apaga respostas e observações da pessoa, mantém a consulta (criada_por fica nulo).
insert into public.datas_consulta (id, consulta_id, ministerio_id, data) values
  ('00000000-0000-0000-0000-00000040d002', '00000000-0000-0000-0000-00000040c001', '00000000-0000-0000-0000-00000040000a', '2026-12-20');
insert into public.respostas_disponibilidade (data_id, perfil_id, resposta) values
  ('00000000-0000-0000-0000-00000040d002', '00000000-0000-0000-0000-000000004002', 'disponivel');
delete from auth.users where id = '00000000-0000-0000-0000-000000004002';
select is((select count(*) from public.respostas_disponibilidade where perfil_id = '00000000-0000-0000-0000-000000004002')
          + (select count(*) from public.observacoes_disponibilidade where perfil_id = '00000000-0000-0000-0000-000000004002'),
          0::bigint, 'excluir a conta apaga respostas e observações da pessoa');
delete from auth.users where id = '00000000-0000-0000-0000-000000004001';
select is((select criada_por from public.consultas_disponibilidade where id = '00000000-0000-0000-0000-00000040c001'),
          null::uuid, 'excluir a conta de quem criou mantém a consulta (criada_por fica nulo)');

select * from finish();
rollback;
