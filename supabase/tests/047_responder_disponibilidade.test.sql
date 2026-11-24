-- T030: responder_disponibilidade. Relógio: 10/12/2026.
begin;
create extension if not exists pgtap with schema extensions;
select plan(24);

create or replace function public.agora_sp() returns timestamptz language sql stable as
  $$ select '2026-12-10 12:00:00+00'::timestamptz $$;

-- 4701 líder A, 4702 P1, 4703 P2, 4704 estranho, 4705 saiu do ministério
insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role)
select ('00000000-0000-0000-0000-0000000047' || lpad(n::text, 2, '0'))::uuid, 'u' || n || '.47@exemplo.com', now(),
       jsonb_build_object('nome', 'Pessoa 47 ' || n), 'authenticated', 'authenticated'
  from unnest(array[1, 2, 3, 4, 5]) as n;
update public.perfis set situacao = 'aprovado' where id::text like '00000000-0000-0000-0000-0000000047%';
insert into public.ministerios (id, nome, descricao) values
  ('00000000-0000-0000-0000-00000047000a', 'Teste Resp 47 A', ''),
  ('00000000-0000-0000-0000-00000047000b', 'Teste Resp 47 B', '');
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel) values
  ('00000000-0000-0000-0000-00000047000a', '00000000-0000-0000-0000-000000004701', 'lider'),
  ('00000000-0000-0000-0000-00000047000a', '00000000-0000-0000-0000-000000004702', 'participante'),
  ('00000000-0000-0000-0000-00000047000a', '00000000-0000-0000-0000-000000004703', 'participante');
insert into public.consultas_disponibilidade (id, ministerio_id, titulo, prazo, fechada) values
  ('00000000-0000-0000-0000-00000047c001', '00000000-0000-0000-0000-00000047000a', 'Aberta', null, false),
  ('00000000-0000-0000-0000-00000047c002', '00000000-0000-0000-0000-00000047000a', 'Fechada pelo líder', null, true),
  ('00000000-0000-0000-0000-00000047c003', '00000000-0000-0000-0000-00000047000a', 'Prazo vencido', '2026-12-09', false),
  ('00000000-0000-0000-0000-00000047c00b', '00000000-0000-0000-0000-00000047000b', 'De outro ministério', null, false);
insert into public.datas_consulta (id, consulta_id, ministerio_id, data) values
  ('00000000-0000-0000-0000-00000047d001', '00000000-0000-0000-0000-00000047c001', '00000000-0000-0000-0000-00000047000a', '2026-12-13'),
  ('00000000-0000-0000-0000-00000047d002', '00000000-0000-0000-0000-00000047c001', '00000000-0000-0000-0000-00000047000a', '2026-12-20'),
  ('00000000-0000-0000-0000-00000047d003', '00000000-0000-0000-0000-00000047c001', '00000000-0000-0000-0000-00000047000a', '2026-12-27'),
  ('00000000-0000-0000-0000-00000047d004', '00000000-0000-0000-0000-00000047c001', '00000000-0000-0000-0000-00000047000a', '2026-12-06'),
  ('00000000-0000-0000-0000-00000047d005', '00000000-0000-0000-0000-00000047c002', '00000000-0000-0000-0000-00000047000a', '2027-01-03'),
  ('00000000-0000-0000-0000-00000047d006', '00000000-0000-0000-0000-00000047c003', '00000000-0000-0000-0000-00000047000a', '2027-01-10'),
  ('00000000-0000-0000-0000-00000047d00b', '00000000-0000-0000-0000-00000047c00b', '00000000-0000-0000-0000-00000047000b', '2026-12-13');

-- ===== P1 responde (parcial) =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000004702", "role": "authenticated"}', true);
set local role authenticated;
select is(public.responder_disponibilidade('00000000-0000-0000-0000-00000047c001',
  '[{"data_id":"00000000-0000-0000-0000-00000047d001","resposta":"disponivel"},{"data_id":"00000000-0000-0000-0000-00000047d002","resposta":"indisponivel"}]'::jsonb,
  'Prefiro a manhã') ->> 'sem_resposta', '1', 'salva parcial: sobra 1 data que ainda aceita resposta (a de 06/12 já passou)');
reset role;
select is((select count(*) from public.respostas_disponibilidade where perfil_id = '00000000-0000-0000-0000-000000004702'), 2::bigint, 'só as duas datas marcadas têm linha');
select is((select count(*) from public.respostas_disponibilidade where perfil_id = '00000000-0000-0000-0000-000000004702' and data_id = '00000000-0000-0000-0000-00000047d003'),
          0::bigint, '"sem resposta" continua sem linha (NÃO vira indisponível)');
select is((select texto from public.observacoes_disponibilidade where perfil_id = '00000000-0000-0000-0000-000000004702'), 'Prefiro a manhã', 'observação salva');

set local role authenticated;
-- altera, limpa e mantém a observação quando nula
select lives_ok($$ select public.responder_disponibilidade('00000000-0000-0000-0000-00000047c001',
  '[{"data_id":"00000000-0000-0000-0000-00000047d001","resposta":"indisponivel"},{"data_id":"00000000-0000-0000-0000-00000047d002","resposta":null}]'::jsonb, null) $$,
  'altera uma resposta e limpa outra');
reset role;
select is((select resposta::text from public.respostas_disponibilidade where perfil_id = '00000000-0000-0000-0000-000000004702' and data_id = '00000000-0000-0000-0000-00000047d001'), 'indisponivel', 'alteração valeu');
select is((select count(*) from public.respostas_disponibilidade where perfil_id = '00000000-0000-0000-0000-000000004702' and data_id = '00000000-0000-0000-0000-00000047d002'), 0::bigint, 'resposta nula voltou a "sem resposta"');
select is((select texto from public.observacoes_disponibilidade where perfil_id = '00000000-0000-0000-0000-000000004702'), 'Prefiro a manhã', 'observação nula mantém a atual');
set local role authenticated;
select lives_ok($$ select public.responder_disponibilidade('00000000-0000-0000-0000-00000047c001', '[]'::jsonb, repeat('x', 300)) $$, 'observação de 300 passa');
select throws_ok($$ select public.responder_disponibilidade('00000000-0000-0000-0000-00000047c001', '[]'::jsonb, repeat('x', 301)) $$, 'P0001', 'consulta_invalida', 'observação de 301 é recusada');
select lives_ok($$ select public.responder_disponibilidade('00000000-0000-0000-0000-00000047c001', '[]'::jsonb, '  ') $$, 'observação vazia apaga');
reset role;
select is((select count(*) from public.observacoes_disponibilidade where perfil_id = '00000000-0000-0000-0000-000000004702'), 0::bigint, 'observação apagada');

-- ===== Consulta fechada / prazo / data passada / tudo ou nada =====
set local role authenticated;
select throws_ok($$ select public.responder_disponibilidade('00000000-0000-0000-0000-00000047c002', '[{"data_id":"00000000-0000-0000-0000-00000047d005","resposta":"disponivel"}]') $$, 'P0001', 'consulta_fechada', 'fechada pelo líder');
select throws_ok($$ select public.responder_disponibilidade('00000000-0000-0000-0000-00000047c003', '[{"data_id":"00000000-0000-0000-0000-00000047d006","resposta":"disponivel"}]') $$, 'P0001', 'consulta_fechada', 'prazo vencido vale como fechada');
select throws_ok($$ select public.responder_disponibilidade('00000000-0000-0000-0000-00000047c001', '[{"data_id":"00000000-0000-0000-0000-00000047d004","resposta":"disponivel"}]') $$, 'P0001', 'data_encerrada', 'data que já passou');
select throws_ok($$ select public.responder_disponibilidade('00000000-0000-0000-0000-00000047c001',
  '[{"data_id":"00000000-0000-0000-0000-00000047d003","resposta":"disponivel"},{"data_id":"00000000-0000-0000-0000-00000047d00b","resposta":"disponivel"}]') $$, 'P0001', 'resposta_invalida', 'data de outra consulta');
select throws_ok($$ select public.responder_disponibilidade('00000000-0000-0000-0000-00000047c001', '[{"data_id":"00000000-0000-0000-0000-00000047d003","resposta":"talvez"}]') $$, 'P0001', 'resposta_invalida', 'valor desconhecido');
reset role;
select is((select count(*) from public.respostas_disponibilidade where data_id = '00000000-0000-0000-0000-00000047d003'), 0::bigint, 'tudo ou nada: o item válido do lote recusado não ficou gravado');
select is((select count(*) from public.respostas_disponibilidade where perfil_id = '00000000-0000-0000-0000-000000004702' and data_id = '00000000-0000-0000-0000-00000047d001'), 1::bigint, 'respostas anteriores continuam intactas');

-- ===== Quem não participa =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000004704", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.responder_disponibilidade('00000000-0000-0000-0000-00000047c001', '[]') $$, 'P0001', 'sem_permissao', 'estranho não responde');
reset role;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000004705", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.responder_disponibilidade('00000000-0000-0000-0000-00000047c001', '[]') $$, 'P0001', 'sem_permissao', 'quem saiu (nunca entrou) não responde');
reset role;

-- ===== Entra depois da abertura e responde; a própria resposta zera preenchida_por =====
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel) values
  ('00000000-0000-0000-0000-00000047000a', '00000000-0000-0000-0000-000000004705', 'participante');
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000004705", "role": "authenticated"}', true);
set local role authenticated;
select lives_ok($$ select public.responder_disponibilidade('00000000-0000-0000-0000-00000047c001', '[{"data_id":"00000000-0000-0000-0000-00000047d003","resposta":"disponivel"}]') $$, 'quem entra depois da abertura também responde');
reset role;
update public.respostas_disponibilidade set preenchida_por = '00000000-0000-0000-0000-000000004701'
 where perfil_id = '00000000-0000-0000-0000-000000004705';
set local role authenticated;
select lives_ok($$ select public.responder_disponibilidade('00000000-0000-0000-0000-00000047c001', '[{"data_id":"00000000-0000-0000-0000-00000047d003","resposta":"indisponivel"}]') $$, 'a pessoa altera uma resposta que o líder preencheu');
reset role;
select is((select preenchida_por from public.respostas_disponibilidade where perfil_id = '00000000-0000-0000-0000-000000004705'), null::uuid, 'a própria resposta zera preenchida_por');

select * from finish();
rollback;
