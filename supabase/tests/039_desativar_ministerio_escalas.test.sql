-- T071: desativar ministério cancela as escalas futuras (FR-020). Relógio: 10/12/2026 09:00.
begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

create or replace function public.agora_sp() returns timestamptz language sql stable as
  $$ select '2026-12-10 12:00:00+00'::timestamptz $$;

-- Adm (3901), L (3902, líder A), P1 (3911), P2 (3912)
insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role)
select ('00000000-0000-0000-0000-0000000039' || lpad(n::text, 2, '0'))::uuid, 'u' || n || '.39@exemplo.com', now(),
       jsonb_build_object('nome', 'Pessoa 39 ' || n), 'authenticated', 'authenticated'
  from unnest(array[1, 2, 11, 12]) as n;
update public.perfis set situacao = 'aprovado' where id::text like '00000000-0000-0000-0000-0000000039%';
update public.perfis set papel = 'administrador' where id = '00000000-0000-0000-0000-000000003901';
insert into public.ministerios (id, nome, descricao) values
  ('00000000-0000-0000-0000-00000039000a', 'Teste Desativar 39 A', ''),
  ('00000000-0000-0000-0000-00000039000b', 'Teste Desativar 39 B', '');
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel) values
  ('00000000-0000-0000-0000-00000039000a', '00000000-0000-0000-0000-000000003902', 'lider'),
  ('00000000-0000-0000-0000-00000039000a', '00000000-0000-0000-0000-000000003911', 'participante'),
  ('00000000-0000-0000-0000-00000039000a', '00000000-0000-0000-0000-000000003912', 'participante'),
  ('00000000-0000-0000-0000-00000039000b', '00000000-0000-0000-0000-000000003902', 'lider'),
  ('00000000-0000-0000-0000-00000039000b', '00000000-0000-0000-0000-000000003911', 'participante');
insert into public.funcoes_ministerio (id, ministerio_id, nome) values
  ('00000000-0000-0000-0000-00000039f00a', '00000000-0000-0000-0000-00000039000a', 'Vocal'),
  ('00000000-0000-0000-0000-00000039f00b', '00000000-0000-0000-0000-00000039000b', 'Recepção');
insert into public.escalas (id, ministerio_id, evento, data, horario, situacao, cancelada_em) values
  ('00000000-0000-0000-0000-00000039e001', '00000000-0000-0000-0000-00000039000a', 'Futura publicada', '2026-12-15', '09:00', 'publicada', null),
  ('00000000-0000-0000-0000-00000039e002', '00000000-0000-0000-0000-00000039000a', 'Futura rascunho', '2026-12-16', '09:00', 'rascunho', null),
  ('00000000-0000-0000-0000-00000039e003', '00000000-0000-0000-0000-00000039000a', 'Hoje', '2026-12-10', '19:00', 'publicada', null),
  ('00000000-0000-0000-0000-00000039e004', '00000000-0000-0000-0000-00000039000a', 'Passada', '2026-12-05', '09:00', 'publicada', null),
  ('00000000-0000-0000-0000-00000039e005', '00000000-0000-0000-0000-00000039000a', 'Já cancelada antes', '2026-12-20', '09:00', 'cancelada', '2026-12-01 10:00:00+00'),
  ('00000000-0000-0000-0000-00000039e0b1', '00000000-0000-0000-0000-00000039000b', 'Do B', '2026-12-15', '09:00', 'publicada', null);
insert into public.vagas_escala (id, escala_id, funcao_id, perfil_id) values
  ('00000000-0000-0000-0000-00000039a001', '00000000-0000-0000-0000-00000039e001', '00000000-0000-0000-0000-00000039f00a', '00000000-0000-0000-0000-000000003911'),
  ('00000000-0000-0000-0000-00000039a002', '00000000-0000-0000-0000-00000039e004', '00000000-0000-0000-0000-00000039f00a', '00000000-0000-0000-0000-000000003911'),
  ('00000000-0000-0000-0000-00000039a0b1', '00000000-0000-0000-0000-00000039e0b1', '00000000-0000-0000-0000-00000039f00b', '00000000-0000-0000-0000-000000003911');
insert into public.respostas_escala (escala_id, perfil_id, resposta, motivo) values
  ('00000000-0000-0000-0000-00000039e001', '00000000-0000-0000-0000-000000003911', 'confirmado', '');
insert into public.pedidos_troca (id, vaga_id, escala_id, solicitante_id, indicada_id, situacao) values
  ('00000000-0000-0000-0000-00000039b001', '00000000-0000-0000-0000-00000039a001', '00000000-0000-0000-0000-00000039e001', '00000000-0000-0000-0000-000000003911', '00000000-0000-0000-0000-000000003912', 'aguardando_lider');

-- ===== Contar: só o administrador =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003902", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.contar_escalas_futuras('00000000-0000-0000-0000-00000039000a') $$, 'P0001', 'sem_permissao', 'o líder não conta nem desativa (é do administrador)');
select throws_ok($$ select public.desativar_ministerio('00000000-0000-0000-0000-00000039000a') $$, 'P0001', 'sem_permissao', 'líder não desativa ministério');
reset role;

select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003901", "role": "authenticated"}', true);
set local role authenticated;
select is(public.contar_escalas_futuras('00000000-0000-0000-0000-00000039000a'), 3, 'conta as futuras não canceladas: publicada, rascunho e a de hoje (não a passada nem a já cancelada)');
select is(public.contar_escalas_futuras('00000000-0000-0000-0000-00000039000b'), 1, 'conta por ministério');

-- ===== Desativar =====
select lives_ok($$ select public.desativar_ministerio('00000000-0000-0000-0000-00000039000a') $$, 'administrador desativa o ministério');
reset role;
select is((select count(*) from public.escalas where ministerio_id = '00000000-0000-0000-0000-00000039000a' and situacao = 'cancelada'), 4::bigint, 'as 3 futuras foram canceladas (e a já cancelada continua cancelada)');
select is((select situacao::text from public.escalas where id = '00000000-0000-0000-0000-00000039e004'), 'publicada', 'a escala passada NÃO é tocada');
select is((select cancelada_em from public.escalas where id = '00000000-0000-0000-0000-00000039e005'), '2026-12-01 10:00:00+00'::timestamptz, 'a escala que já estava cancelada mantém a data original do cancelamento');
select isnt((select cancelada_em from public.escalas where id = '00000000-0000-0000-0000-00000039e001'), null, 'as canceladas agora têm a data do cancelamento');
select is((select situacao::text from public.escalas where id = '00000000-0000-0000-0000-00000039e0b1'), 'publicada', 'escalas de outro ministério não são tocadas');
select is((select situacao::text from public.pedidos_troca where id = '00000000-0000-0000-0000-00000039b001'), 'sem_efeito', 'pedidos de troca pendentes perdem efeito');
select is((select perfil_id from public.vagas_escala where id = '00000000-0000-0000-0000-00000039a001'), '00000000-0000-0000-0000-000000003911'::uuid, 'as vagas continuam registradas (a escala é só cancelada)');
select is((select count(*) from public.respostas_escala where escala_id = '00000000-0000-0000-0000-00000039e001'), 1::bigint, 'e as respostas também');
select is((select ativo from public.ministerios where id = '00000000-0000-0000-0000-00000039000a'), false, 'o ministério ficou desativado');

-- ===== Idempotente e sem escalas =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003901", "role": "authenticated"}', true);
set local role authenticated;
select lives_ok($$ select public.desativar_ministerio('00000000-0000-0000-0000-00000039000a') $$, 'desativar de novo é idempotente');
select is(public.contar_escalas_futuras('00000000-0000-0000-0000-00000039000a'), 0, 'depois de desativado, não há escalas futuras para cancelar');
reset role;

select * from finish();
rollback;
