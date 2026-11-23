-- T038: confirmar e recusar (FR-026 a FR-028). Relógio fixado em 10/12/2026 09:00 (São Paulo).
begin;
create extension if not exists pgtap with schema extensions;
select plan(18);

create or replace function public.agora_sp() returns timestamptz language sql stable as
  $$ select '2026-12-10 12:00:00+00'::timestamptz $$;

insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role)
select ('00000000-0000-0000-0000-0000000028' || lpad(n::text, 2, '0'))::uuid, 'u' || n || '.28@exemplo.com', now(),
       jsonb_build_object('nome', 'Pessoa 28 ' || n), 'authenticated', 'authenticated'
  from unnest(array[2, 11, 12, 13, 14]) as n;
update public.perfis set situacao = 'aprovado' where id::text like '00000000-0000-0000-0000-0000000028%';
insert into public.ministerios (id, nome, descricao) values ('00000000-0000-0000-0000-00000028000a', 'Teste Responder 28', '');
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel)
select '00000000-0000-0000-0000-00000028000a', ('00000000-0000-0000-0000-0000000028' || lpad(n::text, 2, '0'))::uuid,
       case when n = 2 then 'lider'::public.papel_ministerio else 'participante'::public.papel_ministerio end
  from unnest(array[2, 11, 12, 13, 14]) as n;
insert into public.funcoes_ministerio (id, ministerio_id, nome) values
  ('00000000-0000-0000-0000-00000028f001', '00000000-0000-0000-0000-00000028000a', 'Vocal'),
  ('00000000-0000-0000-0000-00000028f002', '00000000-0000-0000-0000-00000028000a', 'Violão');
insert into public.escalas (id, ministerio_id, evento, data, horario, situacao) values
  ('00000000-0000-0000-0000-00000028e001', '00000000-0000-0000-0000-00000028000a', 'Futura', '2026-12-15', '09:00', 'publicada'),
  ('00000000-0000-0000-0000-00000028e002', '00000000-0000-0000-0000-00000028000a', 'Rascunho', '2026-12-15', '09:00', 'rascunho'),
  ('00000000-0000-0000-0000-00000028e003', '00000000-0000-0000-0000-00000028000a', 'Cancelada', '2026-12-15', '09:00', 'cancelada'),
  ('00000000-0000-0000-0000-00000028e004', '00000000-0000-0000-0000-00000028000a', 'Hoje cedo', '2026-12-10', '08:00', 'publicada'),
  ('00000000-0000-0000-0000-00000028e005', '00000000-0000-0000-0000-00000028000a', 'Hoje à noite', '2026-12-10', '19:00', 'publicada');
-- P1 (2811) ocupa DUAS vagas na escala futura; P2 (2812) uma; P3 (2813) está em todas as outras
insert into public.vagas_escala (escala_id, funcao_id, perfil_id) values
  ('00000000-0000-0000-0000-00000028e001', '00000000-0000-0000-0000-00000028f001', '00000000-0000-0000-0000-000000002811'),
  ('00000000-0000-0000-0000-00000028e001', '00000000-0000-0000-0000-00000028f002', '00000000-0000-0000-0000-000000002811'),
  ('00000000-0000-0000-0000-00000028e001', '00000000-0000-0000-0000-00000028f001', '00000000-0000-0000-0000-000000002812'),
  ('00000000-0000-0000-0000-00000028e002', '00000000-0000-0000-0000-00000028f001', '00000000-0000-0000-0000-000000002813'),
  ('00000000-0000-0000-0000-00000028e003', '00000000-0000-0000-0000-00000028f001', '00000000-0000-0000-0000-000000002813'),
  ('00000000-0000-0000-0000-00000028e004', '00000000-0000-0000-0000-00000028f001', '00000000-0000-0000-0000-000000002813'),
  ('00000000-0000-0000-0000-00000028e005', '00000000-0000-0000-0000-00000028f001', '00000000-0000-0000-0000-000000002813');

-- ===== Anônimo =====
set local role anon;
select throws_ok($$ select public.responder_escala('00000000-0000-0000-0000-00000028e001', 'confirmado') $$, '42501', null, 'anônimo não executa responder_escala');
reset role;

-- ===== P1 (duas vagas) =====
select is((select count(*) from public.respostas_escala where escala_id = '00000000-0000-0000-0000-00000028e001'), 0::bigint, 'antes de responder, ninguém tem linha (todos pendentes)');
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002811", "role": "authenticated"}', true);
set local role authenticated;
select lives_ok($$ select public.responder_escala('00000000-0000-0000-0000-00000028e001', 'confirmado') $$, 'confirma');
reset role;
select is((select count(*) from public.respostas_escala where escala_id = '00000000-0000-0000-0000-00000028e001' and perfil_id = '00000000-0000-0000-0000-000000002811'), 1::bigint, 'uma resposta por pessoa por escala, valendo para as duas vagas');
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002811", "role": "authenticated"}', true);
set local role authenticated;
select lives_ok($$ select public.responder_escala('00000000-0000-0000-0000-00000028e001', 'recusado', '  Viagem de trabalho ') $$, 'muda para recusado, com motivo');
reset role;
select is((select resposta::text || '/' || motivo from public.respostas_escala where escala_id = '00000000-0000-0000-0000-00000028e001' and perfil_id = '00000000-0000-0000-0000-000000002811'), 'recusado/Viagem de trabalho', 'a recusa guarda o motivo (sem espaços nas pontas)');
select is((select count(*) from public.vagas_escala where escala_id = '00000000-0000-0000-0000-00000028e001' and perfil_id = '00000000-0000-0000-0000-000000002811'), 2::bigint, 'as vagas recusadas continuam com a pessoa');
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002811", "role": "authenticated"}', true);
set local role authenticated;
select lives_ok($$ select public.responder_escala('00000000-0000-0000-0000-00000028e001', 'confirmado', 'motivo que deve ser ignorado') $$, 'volta a confirmar');
reset role;
select is((select resposta::text || '/' || motivo from public.respostas_escala where escala_id = '00000000-0000-0000-0000-00000028e001' and perfil_id = '00000000-0000-0000-0000-000000002811'), 'confirmado/', 'ao confirmar, o motivo anterior é limpo');
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002811", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.responder_escala('00000000-0000-0000-0000-00000028e001', 'recusado', repeat('x', 201)) $$, 'P0001', 'motivo_invalido', 'motivo com mais de 200 caracteres');
reset role;

-- ===== P2: resposta própria não afeta a do P1 =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002812", "role": "authenticated"}', true);
set local role authenticated;
select lives_ok($$ select public.responder_escala('00000000-0000-0000-0000-00000028e001', 'recusado') $$, 'P2 recusa sem motivo');
reset role;
select is((select count(*) from public.respostas_escala where escala_id = '00000000-0000-0000-0000-00000028e001'), 2::bigint, 'cada pessoa tem a sua linha');

-- ===== Quem não está escalado, e situações da escala =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002814", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.responder_escala('00000000-0000-0000-0000-00000028e001', 'confirmado') $$, 'P0001', 'nao_escalado', 'quem não ocupa vaga não responde');
select throws_ok($$ select public.responder_escala('99999999-9999-9999-9999-999999999999', 'confirmado') $$, 'P0001', 'nao_escalado', 'escala inexistente: mesma resposta (não revela o que existe)');
reset role;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002813", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.responder_escala('00000000-0000-0000-0000-00000028e002', 'confirmado') $$, 'P0001', 'escala_nao_publicada', 'rascunho não recebe resposta');
select throws_ok($$ select public.responder_escala('00000000-0000-0000-0000-00000028e003', 'confirmado') $$, 'P0001', 'escala_cancelada', 'escala cancelada não recebe resposta');
select throws_ok($$ select public.responder_escala('00000000-0000-0000-0000-00000028e004', 'confirmado') $$, 'P0001', 'evento_iniciado', 'depois do horário de início, no mesmo dia, não responde');
select lives_ok($$ select public.responder_escala('00000000-0000-0000-0000-00000028e005', 'confirmado') $$, 'no mesmo dia, antes do horário de início, responde');
reset role;

select * from finish();
rollback;
