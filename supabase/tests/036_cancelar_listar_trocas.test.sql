-- T060: cancelar pedidos e listar "Pedidos de troca" (FR-031, FR-032, FR-036). Relógio: 10/12/2026 09:00.
begin;
create extension if not exists pgtap with schema extensions;
select plan(20);

create or replace function public.agora_sp() returns timestamptz language sql stable as
  $$ select '2026-12-10 12:00:00+00'::timestamptz $$;

-- L (3602, líder A), LB (3603, líder B), P1..P4 (3611..3614), X (3620, só participa de B)
insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role)
select ('00000000-0000-0000-0000-0000000036' || lpad(n::text, 2, '0'))::uuid, 'u' || n || '.36@exemplo.com', now(),
       jsonb_build_object('nome', 'Pessoa 36 ' || n), 'authenticated', 'authenticated'
  from unnest(array[2, 3, 11, 12, 13, 14, 20]) as n;
update public.perfis set situacao = 'aprovado' where id::text like '00000000-0000-0000-0000-0000000036%';
insert into public.ministerios (id, nome, descricao) values
  ('00000000-0000-0000-0000-00000036000a', 'Teste Listar Troca 36 A', ''),
  ('00000000-0000-0000-0000-00000036000b', 'Teste Listar Troca 36 B', '');
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel)
select '00000000-0000-0000-0000-00000036000a', ('00000000-0000-0000-0000-0000000036' || lpad(n::text, 2, '0'))::uuid,
       case when n = 2 then 'lider'::public.papel_ministerio else 'participante'::public.papel_ministerio end
  from unnest(array[2, 11, 12, 13, 14]) as n;
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel) values
  ('00000000-0000-0000-0000-00000036000b', '00000000-0000-0000-0000-000000003603', 'lider'),
  ('00000000-0000-0000-0000-00000036000b', '00000000-0000-0000-0000-000000003620', 'participante');
insert into public.funcoes_ministerio (id, ministerio_id, nome) values
  ('00000000-0000-0000-0000-00000036f00a', '00000000-0000-0000-0000-00000036000a', 'Vocal'),
  ('00000000-0000-0000-0000-00000036f00b', '00000000-0000-0000-0000-00000036000b', 'Recepção');
insert into public.escalas (id, ministerio_id, evento, data, horario, situacao) values
  ('00000000-0000-0000-0000-00000036e001', '00000000-0000-0000-0000-00000036000a', 'Publicada', '2026-12-15', '09:00', 'publicada'),
  ('00000000-0000-0000-0000-00000036e002', '00000000-0000-0000-0000-00000036000a', 'Cancelada depois', '2026-12-16', '09:00', 'cancelada'),
  ('00000000-0000-0000-0000-00000036e003', '00000000-0000-0000-0000-00000036000a', 'Já começou', '2026-12-10', '08:00', 'publicada'),
  ('00000000-0000-0000-0000-00000036e0b1', '00000000-0000-0000-0000-00000036000b', 'Do B', '2026-12-15', '09:00', 'publicada');
insert into public.vagas_escala (id, escala_id, funcao_id, perfil_id) values
  ('00000000-0000-0000-0000-00000036a001', '00000000-0000-0000-0000-00000036e001', '00000000-0000-0000-0000-00000036f00a', '00000000-0000-0000-0000-000000003611'),
  ('00000000-0000-0000-0000-00000036a002', '00000000-0000-0000-0000-00000036e001', '00000000-0000-0000-0000-00000036f00a', '00000000-0000-0000-0000-000000003612'),
  ('00000000-0000-0000-0000-00000036a003', '00000000-0000-0000-0000-00000036e001', '00000000-0000-0000-0000-00000036f00a', '00000000-0000-0000-0000-000000003611'),
  ('00000000-0000-0000-0000-00000036a004', '00000000-0000-0000-0000-00000036e002', '00000000-0000-0000-0000-00000036f00a', '00000000-0000-0000-0000-000000003611'),
  ('00000000-0000-0000-0000-00000036a005', '00000000-0000-0000-0000-00000036e003', '00000000-0000-0000-0000-00000036f00a', '00000000-0000-0000-0000-000000003611'),
  ('00000000-0000-0000-0000-00000036a0b1', '00000000-0000-0000-0000-00000036e0b1', '00000000-0000-0000-0000-00000036f00b', '00000000-0000-0000-0000-000000003620');
insert into public.pedidos_troca (id, vaga_id, escala_id, solicitante_id, indicada_id, situacao) values
  ('00000000-0000-0000-0000-00000036b001', '00000000-0000-0000-0000-00000036a001', '00000000-0000-0000-0000-00000036e001', '00000000-0000-0000-0000-000000003611', '00000000-0000-0000-0000-000000003613', 'aguardando_indicada'),
  ('00000000-0000-0000-0000-00000036b002', '00000000-0000-0000-0000-00000036a002', '00000000-0000-0000-0000-00000036e001', '00000000-0000-0000-0000-000000003612', '00000000-0000-0000-0000-000000003613', 'aguardando_lider'),
  ('00000000-0000-0000-0000-00000036b003', '00000000-0000-0000-0000-00000036a003', '00000000-0000-0000-0000-00000036e001', '00000000-0000-0000-0000-000000003611', '00000000-0000-0000-0000-000000003614', 'recusado_indicada'),
  ('00000000-0000-0000-0000-00000036b004', '00000000-0000-0000-0000-00000036a004', '00000000-0000-0000-0000-00000036e002', '00000000-0000-0000-0000-000000003611', '00000000-0000-0000-0000-000000003613', 'aguardando_lider'),
  ('00000000-0000-0000-0000-00000036b005', '00000000-0000-0000-0000-00000036a005', '00000000-0000-0000-0000-00000036e003', '00000000-0000-0000-0000-000000003611', '00000000-0000-0000-0000-000000003613', 'aguardando_indicada'),
  ('00000000-0000-0000-0000-00000036b0b1', '00000000-0000-0000-0000-00000036a0b1', '00000000-0000-0000-0000-00000036e0b1', '00000000-0000-0000-0000-000000003620', '00000000-0000-0000-0000-000000003603', 'aguardando_lider');

-- ===== Cancelar =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003612", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.cancelar_pedido_troca('00000000-0000-0000-0000-00000036b001') $$, 'P0001', 'sem_permissao', 'terceiro não cancela o pedido dos outros');
reset role;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003611", "role": "authenticated"}', true);
set local role authenticated;
select is((select (public.cancelar_pedido_troca('00000000-0000-0000-0000-00000036b001')).situacao::text), 'cancelado', 'quem pediu cancela');
select throws_ok($$ select public.cancelar_pedido_troca('00000000-0000-0000-0000-00000036b001') $$, 'P0001', 'conflito_troca', 'cancelar de novo: já não está pendente');
select throws_ok($$ select public.cancelar_pedido_troca('00000000-0000-0000-0000-00000036b003') $$, 'P0001', 'conflito_troca', 'pedido já recusado não é cancelado');
reset role;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003602", "role": "authenticated"}', true);
set local role authenticated;
select is((select (public.cancelar_pedido_troca('00000000-0000-0000-0000-00000036b002')).situacao::text), 'cancelado', 'o líder cancela o pedido aguardando a aprovação dele');
select throws_ok($$ select public.cancelar_pedido_troca('00000000-0000-0000-0000-00000036b0b1') $$, 'P0001', 'sem_permissao', 'líder do A não cancela pedido do B');
reset role;
select is((select perfil_id from public.vagas_escala where id = '00000000-0000-0000-0000-00000036a001'), '00000000-0000-0000-0000-000000003611'::uuid, 'cancelar não muda a escala');

-- Reabre os pedidos para os testes de listagem
update public.pedidos_troca set situacao = 'aguardando_indicada', decidido_em = null where id = '00000000-0000-0000-0000-00000036b001';
update public.pedidos_troca set situacao = 'aguardando_lider', decidido_em = null where id = '00000000-0000-0000-0000-00000036b002';

-- ===== Listar: quem pediu (P1) =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003611", "role": "authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.listar_pedidos_troca()), 4::bigint, 'P1 vê os 4 pedidos que fez (qualquer situação)');
select is((select count(*) from public.listar_pedidos_troca() where papel_na_lista = 'solicitante'), 4::bigint, 'todos como solicitante');
select is((select situacao from public.listar_pedidos_troca() where id = '00000000-0000-0000-0000-00000036b004'), 'sem_efeito', 'pedido pendente de escala CANCELADA aparece como sem efeito');
select is((select situacao from public.listar_pedidos_troca() where id = '00000000-0000-0000-0000-00000036b005'), 'sem_efeito', 'pedido pendente de escala que JÁ COMEÇOU aparece como sem efeito');
select is((select pode_cancelar from public.listar_pedidos_troca() where id = '00000000-0000-0000-0000-00000036b001'), true, 'pode cancelar o pendente');
select is((select pode_cancelar from public.listar_pedidos_troca() where id = '00000000-0000-0000-0000-00000036b004'), false, 'não oferece cancelar o que perdeu efeito');
select ok(position('email' in pg_get_function_result('public.listar_pedidos_troca()'::regprocedure)) = 0, 'a listagem não devolve email');
reset role;

-- ===== Listar: a indicada (P3) =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003613", "role": "authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.listar_pedidos_troca() where papel_na_lista = 'indicada'), 4::bigint, 'P3 vê os pedidos que recebeu');
select is((select pode_responder from public.listar_pedidos_troca() where id = '00000000-0000-0000-0000-00000036b001'), true, 'e pode responder ao que aguarda por ela');
select is((select (public.contar_pendencias_escala() ->> 'trocas_recebidas')::int), 1, 'contador: 1 pedido recebido aguardando a resposta dela (os outros perderam efeito ou aguardam o líder)');
reset role;

-- ===== Listar: o líder do A =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003602", "role": "authenticated"}', true);
set local role authenticated;
select is((select array_agg(id::text order by id) from public.listar_pedidos_troca() where pode_decidir),
          array['00000000-0000-0000-0000-00000036b002'], 'o líder vê só o que aguarda a aprovação dele (não o que aguarda a indicada)');
select is((select (public.contar_pendencias_escala() ->> 'trocas_para_aprovar')::int), 1, 'contador: 1 pedido a aprovar');
reset role;

-- ===== Estranho =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003614", "role": "authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.listar_pedidos_troca() where papel_na_lista = 'gestor'), 0::bigint, 'quem não gere nada não vê pedidos de terceiros');
reset role;

select * from finish();
rollback;
