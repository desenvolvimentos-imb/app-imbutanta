-- T027: vagas e avisos ao líder (FR-008 a FR-010, FR-014, FR-017, FR-018).
-- Relógio fixado em 10/12/2026 09:00 (São Paulo).
begin;
create extension if not exists pgtap with schema extensions;
select plan(31);

create or replace function public.agora_sp() returns timestamptz language sql stable as
  $$ select '2026-12-10 12:00:00+00'::timestamptz $$;

-- Pessoas: líder A (2602), líder B (2603), P1..P6 (2611..2616), fora (2620)
insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role)
select ('00000000-0000-0000-0000-0000000026' || lpad(n::text, 2, '0'))::uuid, 'u' || n || '.26@exemplo.com', now(),
       jsonb_build_object('nome', 'Pessoa 26 ' || n), 'authenticated', 'authenticated'
  from unnest(array[2, 3, 11, 12, 13, 14, 15, 16, 20]) as n;
update public.perfis set situacao = 'aprovado' where id::text like '00000000-0000-0000-0000-0000000026%';

insert into public.ministerios (id, nome, descricao) values
  ('00000000-0000-0000-0000-00000026000a', 'Teste Vagas 26 A', ''),
  ('00000000-0000-0000-0000-00000026000b', 'Teste Vagas 26 B', '');
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel)
select '00000000-0000-0000-0000-00000026000a', ('00000000-0000-0000-0000-0000000026' || lpad(n::text, 2, '0'))::uuid,
       case when n = 2 then 'lider'::public.papel_ministerio else 'participante'::public.papel_ministerio end
  from unnest(array[2, 11, 12, 13, 14, 15, 16]) as n;
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel)
select '00000000-0000-0000-0000-00000026000b', ('00000000-0000-0000-0000-0000000026' || lpad(n::text, 2, '0'))::uuid,
       case when n = 3 then 'lider'::public.papel_ministerio else 'participante'::public.papel_ministerio end
  from unnest(array[3, 11, 12, 13, 14, 15, 16]) as n;

insert into public.funcoes_ministerio (id, ministerio_id, nome, ativa) values
  ('00000000-0000-0000-0000-00000026f001', '00000000-0000-0000-0000-00000026000a', 'Vocal', true),
  ('00000000-0000-0000-0000-00000026f002', '00000000-0000-0000-0000-00000026000a', 'Violão', true),
  ('00000000-0000-0000-0000-00000026f003', '00000000-0000-0000-0000-00000026000a', 'Bateria', false),
  ('00000000-0000-0000-0000-00000026f004', '00000000-0000-0000-0000-00000026000b', 'Recepção', true);
-- Aptidões: P1 (2611) é apto em Vocal; os demais não têm nenhuma
insert into public.aptidoes (funcao_id, perfil_id, tipo) values
  ('00000000-0000-0000-0000-00000026f001', '00000000-0000-0000-0000-000000002611', 'principal');

-- Escala alvo (A, publicada, hoje) e escalas do B no MESMO dia, em situações diferentes
insert into public.escalas (id, ministerio_id, evento, data, horario, situacao) values
  ('00000000-0000-0000-0000-00000026e00a', '00000000-0000-0000-0000-00000026000a', 'Culto A', '2026-12-10', '19:00', 'rascunho'),
  ('00000000-0000-0000-0000-00000026e0b1', '00000000-0000-0000-0000-00000026000b', 'Culto B publicado', '2026-12-10', '08:00', 'publicada'),
  ('00000000-0000-0000-0000-00000026e0b2', '00000000-0000-0000-0000-00000026000b', 'Rascunho B', '2026-12-10', '08:00', 'rascunho'),
  ('00000000-0000-0000-0000-00000026e0b3', '00000000-0000-0000-0000-00000026000b', 'Cancelada B', '2026-12-10', '08:00', 'cancelada'),
  ('00000000-0000-0000-0000-00000026e0b4', '00000000-0000-0000-0000-00000026000b', 'B outro dia', '2026-12-11', '08:00', 'publicada');
-- P1 confirmou no B publicado (conta); P2 está pendente; P3 recusou; P4 só em rascunho; P5 só em cancelada; P6 em outro dia
insert into public.vagas_escala (escala_id, funcao_id, perfil_id) values
  ('00000000-0000-0000-0000-00000026e0b1', '00000000-0000-0000-0000-00000026f004', '00000000-0000-0000-0000-000000002611'),
  ('00000000-0000-0000-0000-00000026e0b1', '00000000-0000-0000-0000-00000026f004', '00000000-0000-0000-0000-000000002612'),
  ('00000000-0000-0000-0000-00000026e0b1', '00000000-0000-0000-0000-00000026f004', '00000000-0000-0000-0000-000000002613'),
  ('00000000-0000-0000-0000-00000026e0b2', '00000000-0000-0000-0000-00000026f004', '00000000-0000-0000-0000-000000002614'),
  ('00000000-0000-0000-0000-00000026e0b3', '00000000-0000-0000-0000-00000026f004', '00000000-0000-0000-0000-000000002615'),
  ('00000000-0000-0000-0000-00000026e0b4', '00000000-0000-0000-0000-00000026f004', '00000000-0000-0000-0000-000000002616');
insert into public.respostas_escala (escala_id, perfil_id, resposta) values
  ('00000000-0000-0000-0000-00000026e0b1', '00000000-0000-0000-0000-000000002611', 'confirmado'),
  ('00000000-0000-0000-0000-00000026e0b1', '00000000-0000-0000-0000-000000002613', 'recusado'),
  ('00000000-0000-0000-0000-00000026e0b3', '00000000-0000-0000-0000-000000002615', 'confirmado'),
  ('00000000-0000-0000-0000-00000026e0b4', '00000000-0000-0000-0000-000000002616', 'confirmado');

select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002602", "role": "authenticated"}', true);
set local role authenticated;

-- ===== Vagas básicas =====
select is((select (public.salvar_vaga('00000000-0000-0000-0000-00000026e00a', null, '00000000-0000-0000-0000-00000026f001', 'Vocal 1', null)->>'salvo')::boolean),
          true, 'cria vaga em aberto (sem pessoa), com rótulo');
reset role;
select is((select count(*) from public.vagas_escala where escala_id = '00000000-0000-0000-0000-00000026e00a' and perfil_id is null), 1::bigint, 'a vaga ficou em aberto');
set local role authenticated;
select lives_ok($$ select public.salvar_vaga('00000000-0000-0000-0000-00000026e00a', null, '00000000-0000-0000-0000-00000026f001', 'Vocal 2', null) $$, 'várias vagas da mesma função');
select throws_ok($$ select public.salvar_vaga('00000000-0000-0000-0000-00000026e00a', null, '00000000-0000-0000-0000-00000026f003', '', null) $$, 'P0001', 'funcao_invalida', 'função desativada não serve para vaga nova');
select throws_ok($$ select public.salvar_vaga('00000000-0000-0000-0000-00000026e00a', null, '00000000-0000-0000-0000-00000026f004', '', null) $$, 'P0001', 'funcao_invalida', 'função de outro ministério');
select throws_ok($$ select public.salvar_vaga('00000000-0000-0000-0000-00000026e00a', null, '00000000-0000-0000-0000-00000026f001', '', '00000000-0000-0000-0000-000000002620') $$, 'P0001', 'nao_participante', 'pessoa que não participa do ministério');
select throws_ok($$ select public.salvar_vaga('00000000-0000-0000-0000-00000026e00a', null, '00000000-0000-0000-0000-00000026f001', repeat('x', 41), null) $$, 'P0001', 'evento_invalido', 'rótulo longo demais');

-- ===== Avisos: sem aptidão =====
select is((select (public.salvar_vaga('00000000-0000-0000-0000-00000026e00a', null, '00000000-0000-0000-0000-00000026f002', '', '00000000-0000-0000-0000-000000002612')) -> 'avisos' -> 0 ->> 'tipo'),
          'sem_aptidao', 'sem aptidão: devolve o aviso');
select is((select (public.salvar_vaga('00000000-0000-0000-0000-00000026e00a', null, '00000000-0000-0000-0000-00000026f002', '', '00000000-0000-0000-0000-000000002612')->>'salvo')::boolean),
          false, 'e NÃO grava sem a confirmação do líder');
reset role;
select is((select count(*) from public.vagas_escala where perfil_id = '00000000-0000-0000-0000-000000002612' and escala_id = '00000000-0000-0000-0000-00000026e00a'), 0::bigint, 'nada foi gravado');
set local role authenticated;
select is((select (public.salvar_vaga('00000000-0000-0000-0000-00000026e00a', null, '00000000-0000-0000-0000-00000026f002', '', '00000000-0000-0000-0000-000000002612', true)->>'salvo')::boolean),
          true, 'com p_ciente = true, grava mesmo com o aviso');
select is((select (public.salvar_vaga('00000000-0000-0000-0000-00000026e00a', null, '00000000-0000-0000-0000-00000026f001', '', '00000000-0000-0000-0000-000000002611')) -> 'avisos' -> 0 ->> 'tipo'),
          'outro_ministerio', 'P1 (apto) confirmou outra escala no mesmo dia: só o aviso de outro ministério');
select is((select jsonb_array_length((public.salvar_vaga('00000000-0000-0000-0000-00000026e00a', null, '00000000-0000-0000-0000-00000026f001', '', '00000000-0000-0000-0000-000000002611')) -> 'avisos')),
          1, 'apto na função: nenhum aviso de aptidão');
select is((select (public.salvar_vaga('00000000-0000-0000-0000-00000026e00a', null, '00000000-0000-0000-0000-00000026f001', '', '00000000-0000-0000-0000-000000002611')) -> 'avisos' -> 0 ->> 'ministerio'),
          'Teste Vagas 26 B', 'o aviso mostra o ministério da outra escala');
select is((select (public.salvar_vaga('00000000-0000-0000-0000-00000026e00a', null, '00000000-0000-0000-0000-00000026f001', '', '00000000-0000-0000-0000-000000002611')) -> 'avisos' -> 0 ->> 'evento'),
          'Culto B publicado', 'o aviso mostra o evento da outra escala');
select is((select (public.salvar_vaga('00000000-0000-0000-0000-00000026e00a', null, '00000000-0000-0000-0000-00000026f001', '', '00000000-0000-0000-0000-000000002611')) -> 'avisos' -> 0 ->> 'horario'),
          '08:00', 'o aviso mostra o horário de início da outra escala (sem compará-lo)');

-- ===== Avisos de outro ministério: só publicada + confirmada, no mesmo dia =====
select is((select jsonb_array_length((public.salvar_vaga('00000000-0000-0000-0000-00000026e00a', null, '00000000-0000-0000-0000-00000026f001', '', '00000000-0000-0000-0000-000000002612', true)) -> 'avisos')),
          1, 'P2 (resposta pendente no B): só o aviso de aptidão, sem aviso de outro ministério');
select is((select (public.salvar_vaga('00000000-0000-0000-0000-00000026e00a', null, '00000000-0000-0000-0000-00000026f001', '', '00000000-0000-0000-0000-000000002613')) -> 'avisos' -> 0 ->> 'tipo'),
          'sem_aptidao', 'P3 (recusou no B): sem aviso de outro ministério');
select is((select jsonb_array_length((public.salvar_vaga('00000000-0000-0000-0000-00000026e00a', null, '00000000-0000-0000-0000-00000026f001', '', '00000000-0000-0000-0000-000000002614')) -> 'avisos')),
          1, 'P4 (só em rascunho no B): sem aviso de outro ministério');
select is((select jsonb_array_length((public.salvar_vaga('00000000-0000-0000-0000-00000026e00a', null, '00000000-0000-0000-0000-00000026f001', '', '00000000-0000-0000-0000-000000002615')) -> 'avisos')),
          1, 'P5 (escala cancelada no B): sem aviso de outro ministério');
select is((select jsonb_array_length((public.salvar_vaga('00000000-0000-0000-0000-00000026e00a', null, '00000000-0000-0000-0000-00000026f001', '', '00000000-0000-0000-0000-000000002616')) -> 'avisos')),
          1, 'P6 (confirmou no B, mas em OUTRO dia): sem aviso de outro ministério');

-- ===== Mesma pessoa em duas vagas da mesma escala; mesmo ministério não gera aviso =====
select is((select (public.salvar_vaga('00000000-0000-0000-0000-00000026e00a', null, '00000000-0000-0000-0000-00000026f001', 'Vocal 3', '00000000-0000-0000-0000-000000002611', true)->>'salvo')::boolean),
          true, 'P1 ocupa a primeira vaga (com ciência do aviso)');
select is((select jsonb_array_length((public.salvar_vaga('00000000-0000-0000-0000-00000026e00a', null, '00000000-0000-0000-0000-00000026f001', 'Vocal 4', '00000000-0000-0000-0000-000000002611')) -> 'avisos')),
          0, 'segunda vaga da mesma pessoa na mesma escala: sem aviso novo (o líder já o viu na primeira)');
reset role;
select is((select count(distinct perfil_id) from public.vagas_escala where escala_id = '00000000-0000-0000-0000-00000026e00a' and perfil_id = '00000000-0000-0000-0000-000000002611'), 1::bigint, 'conta como uma pessoa só');
set local role authenticated;

-- ===== Limite de 50 vagas =====
reset role;
insert into public.vagas_escala (escala_id, funcao_id)
select '00000000-0000-0000-0000-00000026e0b4', '00000000-0000-0000-0000-00000026f004' from generate_series(1, 49);
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002603", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.salvar_vaga('00000000-0000-0000-0000-00000026e0b4', null, '00000000-0000-0000-0000-00000026f004', '', null) $$, 'P0001', 'limite_vagas', 'a 51ª vaga é recusada');
reset role;

-- ===== Escala publicada: trocar a pessoa de uma vaga (FR-014) =====
-- Os ids das vagas são lidos como superusuário (a tabela não é legível direto pela API).
select set_config('t.vaga_p2', (select id::text from public.vagas_escala where escala_id = '00000000-0000-0000-0000-00000026e0b1' and perfil_id = '00000000-0000-0000-0000-000000002612'), true);
select set_config('t.vaga_p1', (select id::text from public.vagas_escala where escala_id = '00000000-0000-0000-0000-00000026e0b1' and perfil_id = '00000000-0000-0000-0000-000000002611'), true);
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002603", "role": "authenticated"}', true);
set local role authenticated;
select lives_ok($$ select public.salvar_vaga('00000000-0000-0000-0000-00000026e0b1',
   current_setting('t.vaga_p2')::uuid,
   '00000000-0000-0000-0000-00000026f004', '', '00000000-0000-0000-0000-000000002614', true) $$, 'líder troca a pessoa de uma vaga publicada (com ciência do aviso de aptidão)');
reset role;
select is((select count(*) from public.vagas_escala where escala_id = '00000000-0000-0000-0000-00000026e0b1' and perfil_id = '00000000-0000-0000-0000-000000002614'), 1::bigint, 'a nova pessoa ocupa a vaga');
select is((select count(*) from public.vagas_escala where escala_id = '00000000-0000-0000-0000-00000026e0b1' and perfil_id = '00000000-0000-0000-0000-000000002612'), 0::bigint, 'a anterior deixou de estar escalada');
select is((select count(*) from public.respostas_escala where escala_id = '00000000-0000-0000-0000-00000026e0b1' and perfil_id = '00000000-0000-0000-0000-000000002614'), 0::bigint, 'a nova pessoa está pendente (sem resposta)');

-- ===== remover_vaga =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002603", "role": "authenticated"}', true);
set local role authenticated;
select lives_ok($$ select public.remover_vaga(current_setting('t.vaga_p1')::uuid) $$, 'remove uma vaga');
reset role;
select is((select count(*) from public.respostas_escala where escala_id = '00000000-0000-0000-0000-00000026e0b1' and perfil_id = '00000000-0000-0000-0000-000000002611'), 0::bigint, 'a resposta de quem ficou sem vagas some junto');

select * from finish();
rollback;
