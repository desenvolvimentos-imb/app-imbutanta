-- T070: visibilidade por papel e ministério desativado (FR-022 a FR-025). Relógio: 10/12/2026 09:00.
begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

create or replace function public.agora_sp() returns timestamptz language sql stable as
  $$ select '2026-12-10 12:00:00+00'::timestamptz $$;

-- Adm (3801), L (3802, líder A), P1 (3811, escalado), P2 (3812, participante sem vaga), X (3820, estranho)
insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role)
select ('00000000-0000-0000-0000-0000000038' || lpad(n::text, 2, '0'))::uuid, 'u' || n || '.38@exemplo.com', now(),
       jsonb_build_object('nome', 'Pessoa 38 ' || n), 'authenticated', 'authenticated'
  from unnest(array[1, 2, 11, 12, 20]) as n;
update public.perfis set situacao = 'aprovado' where id::text like '00000000-0000-0000-0000-0000000038%';
update public.perfis set papel = 'administrador' where id = '00000000-0000-0000-0000-000000003801';
insert into public.ministerios (id, nome, descricao, ativo, desativado_em) values
  ('00000000-0000-0000-0000-00000038000a', 'Teste Visib 38 A', '', true, null),
  ('00000000-0000-0000-0000-00000038000c', 'Teste Visib 38 Inativo', '', false, now());
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel) values
  ('00000000-0000-0000-0000-00000038000a', '00000000-0000-0000-0000-000000003802', 'lider'),
  ('00000000-0000-0000-0000-00000038000a', '00000000-0000-0000-0000-000000003811', 'participante'),
  ('00000000-0000-0000-0000-00000038000a', '00000000-0000-0000-0000-000000003812', 'participante'),
  ('00000000-0000-0000-0000-00000038000c', '00000000-0000-0000-0000-000000003802', 'lider'),
  ('00000000-0000-0000-0000-00000038000c', '00000000-0000-0000-0000-000000003811', 'participante');
insert into public.funcoes_ministerio (id, ministerio_id, nome) values
  ('00000000-0000-0000-0000-00000038f00a', '00000000-0000-0000-0000-00000038000a', 'Vocal'),
  ('00000000-0000-0000-0000-00000038f00c', '00000000-0000-0000-0000-00000038000c', 'Vocal');
insert into public.escalas (id, ministerio_id, evento, data, horario, situacao) values
  ('00000000-0000-0000-0000-00000038e001', '00000000-0000-0000-0000-00000038000a', 'Publicada', '2026-12-15', '09:00', 'publicada'),
  ('00000000-0000-0000-0000-00000038e002', '00000000-0000-0000-0000-00000038000a', 'Rascunho', '2026-12-16', '09:00', 'rascunho'),
  ('00000000-0000-0000-0000-00000038e00c', '00000000-0000-0000-0000-00000038000c', 'Do ministério desativado', '2026-12-18', '09:00', 'cancelada');
insert into public.vagas_escala (id, escala_id, funcao_id, perfil_id) values
  ('00000000-0000-0000-0000-00000038a001', '00000000-0000-0000-0000-00000038e001', '00000000-0000-0000-0000-00000038f00a', '00000000-0000-0000-0000-000000003811'),
  ('00000000-0000-0000-0000-00000038a002', '00000000-0000-0000-0000-00000038e002', '00000000-0000-0000-0000-00000038f00a', '00000000-0000-0000-0000-000000003811'),
  ('00000000-0000-0000-0000-00000038a00c', '00000000-0000-0000-0000-00000038e00c', '00000000-0000-0000-0000-00000038f00c', '00000000-0000-0000-0000-000000003811');
insert into public.respostas_escala (escala_id, perfil_id, resposta, motivo) values
  ('00000000-0000-0000-0000-00000038e001', '00000000-0000-0000-0000-000000003811', 'recusado', 'Motivo');

-- ===== Administrador vê tudo, inclusive rascunho, respostas e motivos =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003801", "role": "authenticated"}', true);
set local role authenticated;
select is((public.ler_escala('00000000-0000-0000-0000-00000038e002') ->> 'papel'), 'gestor', 'administrador lê o rascunho de qualquer ministério');
select ok((public.ler_escala('00000000-0000-0000-0000-00000038e001')::text like '%Motivo%'), 'administrador vê o motivo de recusa');
select is((select count(*) from public.listar_escalas_ministerio('00000000-0000-0000-0000-00000038000a')), 2::bigint, 'administrador lista rascunho e publicada');

-- ===== Ministério desativado: toda escrita é recusada, até para o administrador =====
select throws_ok($$ select public.criar_escala('00000000-0000-0000-0000-00000038000c', 'X', '2026-12-30', '09:00') $$, 'P0001', 'ministerio_inativo', 'criar escala no desativado');
select throws_ok($$ select public.salvar_vaga('00000000-0000-0000-0000-00000038e00c', null, '00000000-0000-0000-0000-00000038f00c', '', null) $$, 'P0001', 'ministerio_inativo', 'salvar vaga no desativado');
select throws_ok($$ select public.publicar_escala('00000000-0000-0000-0000-00000038e00c') $$, 'P0001', 'ministerio_inativo', 'publicar no desativado');
select throws_ok($$ select public.criar_funcao('00000000-0000-0000-0000-00000038000c', 'Nova') $$, 'P0001', 'ministerio_inativo', 'criar função no desativado');
select isnt(public.ler_escala('00000000-0000-0000-0000-00000038e00c'), null, 'mas o administrador ainda LÊ a escala do ministério desativado');
reset role;

-- ===== Participante escalado, no ministério desativado: ainda vê a escala cancelada =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003811", "role": "authenticated"}', true);
set local role authenticated;
select is((public.ler_escala('00000000-0000-0000-0000-00000038e00c') -> 'escala' ->> 'situacao'), 'cancelada', 'quem estava escalado continua vendo a escala cancelada do ministério desativado');
select is((select count(*) from public.minhas_escalas(false) where situacao = 'cancelada'), 1::bigint, 'e ela aparece em Minhas escalas como cancelada');
select is((public.ler_escala('00000000-0000-0000-0000-00000038e001') -> 'minha_resposta' ->> 'resposta'), 'recusado', 'vê a própria resposta');
reset role;

-- ===== Participante sem vaga e estranho =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003812", "role": "authenticated"}', true);
set local role authenticated;
select is(public.ler_escala('00000000-0000-0000-0000-00000038e00c'), null, 'participante do A (sem vaga) não vê escala do ministério desativado');
reset role;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003820", "role": "authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.listar_escalas_ministerio('00000000-0000-0000-0000-00000038000a')), 0::bigint, 'estranho não lista nenhuma escala');
reset role;

select * from finish();
rollback;
