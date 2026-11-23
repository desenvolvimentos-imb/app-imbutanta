-- T039: "Minhas escalas" e o contador de pendências (FR-021). Relógio: 10/12/2026 09:00 (São Paulo).
begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

create or replace function public.agora_sp() returns timestamptz language sql stable as
  $$ select '2026-12-10 12:00:00+00'::timestamptz $$;

insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role)
select ('00000000-0000-0000-0000-0000000029' || lpad(n::text, 2, '0'))::uuid, 'u' || n || '.29@exemplo.com', now(),
       jsonb_build_object('nome', 'Pessoa 29 ' || n), 'authenticated', 'authenticated'
  from unnest(array[2, 11, 12, 13]) as n;
update public.perfis set situacao = 'aprovado' where id::text like '00000000-0000-0000-0000-0000000029%';
insert into public.ministerios (id, nome, descricao) values
  ('00000000-0000-0000-0000-00000029000a', 'Teste Minhas 29 A', ''),
  ('00000000-0000-0000-0000-00000029000b', 'Teste Minhas 29 B', '');
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel)
select m, ('00000000-0000-0000-0000-0000000029' || lpad(n::text, 2, '0'))::uuid,
       case when n = 2 then 'lider'::public.papel_ministerio else 'participante'::public.papel_ministerio end
  from unnest(array[2, 11, 12, 13]) as n,
       unnest(array['00000000-0000-0000-0000-00000029000a'::uuid, '00000000-0000-0000-0000-00000029000b'::uuid]) as m;
insert into public.funcoes_ministerio (id, ministerio_id, nome) values
  ('00000000-0000-0000-0000-00000029f001', '00000000-0000-0000-0000-00000029000a', 'Vocal'),
  ('00000000-0000-0000-0000-00000029f002', '00000000-0000-0000-0000-00000029000a', 'Violão'),
  ('00000000-0000-0000-0000-00000029f003', '00000000-0000-0000-0000-00000029000b', 'Recepção');
insert into public.escalas (id, ministerio_id, evento, data, horario, situacao) values
  ('00000000-0000-0000-0000-00000029e001', '00000000-0000-0000-0000-00000029000a', 'Domingo 20/12', '2026-12-20', '09:00', 'publicada'),
  ('00000000-0000-0000-0000-00000029e002', '00000000-0000-0000-0000-00000029000a', 'Sábado 12/12', '2026-12-12', '19:00', 'publicada'),
  ('00000000-0000-0000-0000-00000029e003', '00000000-0000-0000-0000-00000029000b', 'Rascunho 13/12', '2026-12-13', '10:00', 'rascunho'),
  ('00000000-0000-0000-0000-00000029e004', '00000000-0000-0000-0000-00000029000b', 'Cancelada 14/12', '2026-12-14', '10:00', 'cancelada'),
  ('00000000-0000-0000-0000-00000029e005', '00000000-0000-0000-0000-00000029000a', 'Passada 01/12', '2026-12-01', '09:00', 'publicada'),
  ('00000000-0000-0000-0000-00000029e006', '00000000-0000-0000-0000-00000029000a', 'Hoje cedo', '2026-12-10', '08:00', 'publicada');
-- P1 (2911): duas vagas no domingo 20/12, uma no sábado, rascunho, cancelada, passada e a de hoje cedo
insert into public.vagas_escala (escala_id, funcao_id, perfil_id) values
  ('00000000-0000-0000-0000-00000029e001', '00000000-0000-0000-0000-00000029f001', '00000000-0000-0000-0000-000000002911'),
  ('00000000-0000-0000-0000-00000029e001', '00000000-0000-0000-0000-00000029f002', '00000000-0000-0000-0000-000000002911'),
  ('00000000-0000-0000-0000-00000029e002', '00000000-0000-0000-0000-00000029f001', '00000000-0000-0000-0000-000000002911'),
  ('00000000-0000-0000-0000-00000029e003', '00000000-0000-0000-0000-00000029f003', '00000000-0000-0000-0000-000000002911'),
  ('00000000-0000-0000-0000-00000029e004', '00000000-0000-0000-0000-00000029f003', '00000000-0000-0000-0000-000000002911'),
  ('00000000-0000-0000-0000-00000029e005', '00000000-0000-0000-0000-00000029f001', '00000000-0000-0000-0000-000000002911'),
  ('00000000-0000-0000-0000-00000029e006', '00000000-0000-0000-0000-00000029f001', '00000000-0000-0000-0000-000000002911'),
  ('00000000-0000-0000-0000-00000029e001', '00000000-0000-0000-0000-00000029f001', '00000000-0000-0000-0000-000000002912');
insert into public.respostas_escala (escala_id, perfil_id, resposta, motivo) values
  ('00000000-0000-0000-0000-00000029e001', '00000000-0000-0000-0000-000000002911', 'recusado', 'Viagem'),
  ('00000000-0000-0000-0000-00000029e005', '00000000-0000-0000-0000-000000002911', 'confirmado', '');

select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002911", "role": "authenticated"}', true);
set local role authenticated;

-- ===== Próximas =====
select is((select count(*) from public.minhas_escalas(false)), 4::bigint, 'próximas: publicadas e a cancelada em que estou escalado (rascunho nunca aparece)');
select is((select array_agg(evento order by data, horario) from public.minhas_escalas(false)),
          array['Hoje cedo', 'Sábado 12/12', 'Cancelada 14/12', 'Domingo 20/12'], 'em ordem de data');
select is((select funcoes from public.minhas_escalas(false) where evento = 'Domingo 20/12'), array['Vocal', 'Violão'],
          'duas vagas na mesma escala: um só item, com as duas funções');
select is((select minha_resposta || '/' || motivo from public.minhas_escalas(false) where evento = 'Domingo 20/12'), 'recusado/Viagem', 'mostra a minha resposta e o motivo');
select is((select minha_resposta from public.minhas_escalas(false) where evento = 'Sábado 12/12'), 'pendente', 'sem resposta = pendente');
select is((select count(*) from public.minhas_escalas(false) where pode_responder), 2::bigint, 'só posso responder as publicadas que ainda não começaram (sábado e domingo)');
select is((select pode_responder from public.minhas_escalas(false) where evento = 'Hoje cedo'), false, 'hoje cedo já começou: não responde');
select is((select pode_responder from public.minhas_escalas(false) where evento = 'Cancelada 14/12'), false, 'cancelada: não responde');

-- ===== Passadas =====
select is((select minha_resposta from public.minhas_escalas(true)), 'confirmado', 'passadas: só a do dia 1, com a minha resposta');

-- ===== Pendências do início =====
select is((select (public.contar_pendencias_escala() ->> 'sem_resposta')::int), 1, 'uma escala futura publicada ainda sem resposta (sábado)');
reset role;

-- ===== Outras pessoas =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002912", "role": "authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.minhas_escalas(false)), 1::bigint, 'P2 vê só a própria escala, não as do P1');
select is((select (public.contar_pendencias_escala() ->> 'sem_resposta')::int), 1, 'P2 tem uma pendência');
reset role;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002913", "role": "authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.minhas_escalas(false)) + (select count(*) from public.minhas_escalas(true)), 0::bigint, 'quem não está escalado não vê nada');
reset role;
set local role anon;
select throws_ok($$ select * from public.minhas_escalas(false) $$, '42501', null, 'anônimo não executa minhas_escalas');
reset role;

select * from finish();
rollback;
