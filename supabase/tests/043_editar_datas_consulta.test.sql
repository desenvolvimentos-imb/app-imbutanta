-- T015: editar_consulta, adicionar_datas_consulta e remover_data_consulta. Relógio: 10/12/2026.
begin;
create extension if not exists pgtap with schema extensions;
select plan(22);

create or replace function public.agora_sp() returns timestamptz language sql stable as
  $$ select '2026-12-10 12:00:00+00'::timestamptz $$;

-- 4301 líder A, 4302 líder B, 4303 participante A, 4304 participante A
insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role)
select ('00000000-0000-0000-0000-0000000043' || lpad(n::text, 2, '0'))::uuid, 'u' || n || '.43@exemplo.com', now(),
       jsonb_build_object('nome', 'Pessoa 43 ' || n), 'authenticated', 'authenticated'
  from unnest(array[1, 2, 3, 4]) as n;
update public.perfis set situacao = 'aprovado' where id::text like '00000000-0000-0000-0000-0000000043%';
insert into public.ministerios (id, nome, descricao) values
  ('00000000-0000-0000-0000-00000043000a', 'Teste Datas 43 A', ''),
  ('00000000-0000-0000-0000-00000043000b', 'Teste Datas 43 B', '');
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel) values
  ('00000000-0000-0000-0000-00000043000a', '00000000-0000-0000-0000-000000004301', 'lider'),
  ('00000000-0000-0000-0000-00000043000b', '00000000-0000-0000-0000-000000004302', 'lider'),
  ('00000000-0000-0000-0000-00000043000a', '00000000-0000-0000-0000-000000004303', 'participante'),
  ('00000000-0000-0000-0000-00000043000a', '00000000-0000-0000-0000-000000004304', 'participante');
insert into public.consultas_disponibilidade (id, ministerio_id, titulo, prazo) values
  ('00000000-0000-0000-0000-00000043c001', '00000000-0000-0000-0000-00000043000a', 'Aberta', '2026-12-20'),
  ('00000000-0000-0000-0000-00000043c002', '00000000-0000-0000-0000-00000043000a', 'Fechada', null),
  ('00000000-0000-0000-0000-00000043c003', '00000000-0000-0000-0000-00000043000a', 'Prazo vencido', '2026-12-05'),
  ('00000000-0000-0000-0000-00000043c00b', '00000000-0000-0000-0000-00000043000b', 'Do B', null),
  ('00000000-0000-0000-0000-00000043c006', '00000000-0000-0000-0000-00000043000a', 'Uma data só', null);
update public.consultas_disponibilidade set fechada = true where id = '00000000-0000-0000-0000-00000043c002';
insert into public.datas_consulta (id, consulta_id, ministerio_id, data) values
  ('00000000-0000-0000-0000-00000043d001', '00000000-0000-0000-0000-00000043c001', '00000000-0000-0000-0000-00000043000a', '2026-12-13'),
  ('00000000-0000-0000-0000-00000043d002', '00000000-0000-0000-0000-00000043c001', '00000000-0000-0000-0000-00000043000a', '2026-12-20'),
  ('00000000-0000-0000-0000-00000043d003', '00000000-0000-0000-0000-00000043c002', '00000000-0000-0000-0000-00000043000a', '2027-02-14'),
  ('00000000-0000-0000-0000-00000043d004', '00000000-0000-0000-0000-00000043c003', '00000000-0000-0000-0000-00000043000a', '2027-01-03'),
  ('00000000-0000-0000-0000-00000043d005', '00000000-0000-0000-0000-00000043c001', '00000000-0000-0000-0000-00000043000a', '2027-01-17'),
  ('00000000-0000-0000-0000-00000043d006', '00000000-0000-0000-0000-00000043c006', '00000000-0000-0000-0000-00000043000a', '2027-03-21'),
  ('00000000-0000-0000-0000-00000043d00b', '00000000-0000-0000-0000-00000043c00b', '00000000-0000-0000-0000-00000043000b', '2026-12-13');
insert into public.respostas_disponibilidade (data_id, perfil_id, resposta) values
  ('00000000-0000-0000-0000-00000043d001', '00000000-0000-0000-0000-000000004303', 'disponivel'),
  ('00000000-0000-0000-0000-00000043d001', '00000000-0000-0000-0000-000000004304', 'indisponivel');

select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000004301", "role": "authenticated"}', true);
set local role authenticated;

-- ===== editar_consulta =====
select lives_ok($$ select public.editar_consulta('00000000-0000-0000-0000-00000043c001', ' Novo título ', 'Nova mensagem', null) $$, 'edita título, mensagem e remove o prazo');
reset role;
select is((select titulo || '|' || mensagem || '|' || coalesce(prazo::text, 'sem') from public.consultas_disponibilidade where id = '00000000-0000-0000-0000-00000043c001'),
          'Novo título|Nova mensagem|sem', 'alterações gravadas (prazo nulo remove o prazo)');
set local role authenticated;
select throws_ok($$ select public.editar_consulta('00000000-0000-0000-0000-00000043c001', 'X', '', null) $$, 'P0001', 'consulta_invalida', 'título curto');
select throws_ok($$ select public.editar_consulta('00000000-0000-0000-0000-00000043c001', 'Ok', '', '2026-12-09') $$, 'P0001', 'prazo_invalido', 'prazo no passado');
select throws_ok($$ select public.editar_consulta('00000000-0000-0000-0000-00000043c002', 'Ok', '', null) $$, 'P0001', 'consulta_fechada', 'fechada pelo líder não edita');
select throws_ok($$ select public.editar_consulta('00000000-0000-0000-0000-00000043c003', 'Ok', '', null) $$, 'P0001', 'consulta_fechada', 'prazo vencido vale como fechada: não edita');
select throws_ok($$ select public.editar_consulta('00000000-0000-0000-0000-00000043c00b', 'Ok', '', null) $$, 'P0001', 'sem_permissao', 'líder do A não edita consulta do B');

-- ===== adicionar_datas_consulta =====
select is((select count(*) from public.adicionar_datas_consulta('00000000-0000-0000-0000-00000043c001', '[{"data":"2026-12-27","rotulo":"Natal"}]'::jsonb)),
          1::bigint, 'adiciona uma data');
select throws_ok($$ select * from public.adicionar_datas_consulta('00000000-0000-0000-0000-00000043c001', '[{"data":"2026-12-27"}]') $$, 'P0001', 'data_duplicada', 'data repetida');
select throws_ok($$ select * from public.adicionar_datas_consulta('00000000-0000-0000-0000-00000043c001', '[{"data":"2026-12-01"}]') $$, 'P0001', 'data_passada', 'data passada');
select throws_ok($$ select * from public.adicionar_datas_consulta('00000000-0000-0000-0000-00000043c001', '[]') $$, 'P0001', 'consulta_invalida', 'lista vazia');
select throws_ok($$ select * from public.adicionar_datas_consulta('00000000-0000-0000-0000-00000043c002', '[{"data":"2027-02-07"}]') $$, 'P0001', 'consulta_fechada', 'fechada não recebe datas');
select throws_ok($$ select * from public.adicionar_datas_consulta('00000000-0000-0000-0000-00000043c001',
  (select jsonb_agg(jsonb_build_object('data', (date '2027-03-01' + n)::text)) from generate_series(0, 28) n)) $$, 'P0001', 'consulta_invalida', 'passar de 31 datas no total');
reset role;
select is((select count(*) from public.respostas_disponibilidade where data_id in (select id from public.datas_consulta where data = '2026-12-27' and consulta_id = '00000000-0000-0000-0000-00000043c001')),
          0::bigint, 'a data nova começa sem respostas ("sem resposta" para todos)');

-- ===== remover_data_consulta =====
set local role authenticated;
select is(public.remover_data_consulta('00000000-0000-0000-0000-00000043d001') ->> 'confirmacao_necessaria', 'true', 'data com respostas pede confirmação');
select is((public.remover_data_consulta('00000000-0000-0000-0000-00000043d001') ->> 'respostas')::int, 2, 'informa quantas respostas serão descartadas');
reset role;
select is((select count(*) from public.datas_consulta where id = '00000000-0000-0000-0000-00000043d001') + (select count(*) from public.respostas_disponibilidade where data_id = '00000000-0000-0000-0000-00000043d001'),
          3::bigint, 'sem confirmação NADA é gravado (data e respostas continuam)');
set local role authenticated;
select is(public.remover_data_consulta('00000000-0000-0000-0000-00000043d001', true) ->> 'removida', 'true', 'confirmado: remove');
reset role;
select is((select count(*) from public.datas_consulta where id = '00000000-0000-0000-0000-00000043d001') + (select count(*) from public.respostas_disponibilidade where data_id = '00000000-0000-0000-0000-00000043d001'),
          0::bigint, 'data e respostas foram embora juntas');
set local role authenticated;
select is(public.remover_data_consulta('00000000-0000-0000-0000-00000043d005') ->> 'removida', 'true', 'data sem respostas remove direto');
select throws_ok($$ select public.remover_data_consulta('00000000-0000-0000-0000-00000043d006', true) $$, 'P0001', 'consulta_sem_datas', 'recusa remover a última data');
select throws_ok($$ select public.remover_data_consulta('00000000-0000-0000-0000-00000043d003') $$, 'P0001', 'consulta_fechada', 'consulta fechada não perde datas');
reset role;

select * from finish();
rollback;
