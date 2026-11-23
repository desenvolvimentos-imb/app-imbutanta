-- T026: criar e editar escala (FR-005 a FR-007, FR-014/FR-015 na parte de data e horário).
-- Relógio fixado em 10/12/2026 09:00 (São Paulo), redefinindo agora_sp() dentro da transação.
begin;
create extension if not exists pgtap with schema extensions;
select plan(25);

create or replace function public.agora_sp() returns timestamptz language sql stable as
  $$ select '2026-12-10 12:00:00+00'::timestamptz $$;

insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role) values
  ('00000000-0000-0000-0000-000000002501', 'adm.25@exemplo.com',  now(), '{"nome":"Adm 25"}',     'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000002502', 'la.25@exemplo.com',   now(), '{"nome":"Lider A 25"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000002503', 'lb.25@exemplo.com',   now(), '{"nome":"Lider B 25"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000002504', 'pa.25@exemplo.com',   now(), '{"nome":"Part A 25"}',  'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000002505', 'fora.25@exemplo.com', now(), '{"nome":"Fora 25"}',    'authenticated', 'authenticated');
update public.perfis set situacao = 'aprovado' where id::text like '00000000-0000-0000-0000-0000000025%';
update public.perfis set papel = 'administrador' where id = '00000000-0000-0000-0000-000000002501';

insert into public.ministerios (id, nome, descricao, ativo, desativado_em) values
  ('00000000-0000-0000-0000-00000025000a', 'Teste Escala 25 A', '', true, null),
  ('00000000-0000-0000-0000-00000025000b', 'Teste Escala 25 B', '', true, null),
  ('00000000-0000-0000-0000-00000025000c', 'Teste Escala 25 Inativo', '', false, now());
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel) values
  ('00000000-0000-0000-0000-00000025000a', '00000000-0000-0000-0000-000000002502', 'lider'),
  ('00000000-0000-0000-0000-00000025000b', '00000000-0000-0000-0000-000000002503', 'lider'),
  ('00000000-0000-0000-0000-00000025000c', '00000000-0000-0000-0000-000000002503', 'lider'),
  ('00000000-0000-0000-0000-00000025000a', '00000000-0000-0000-0000-000000002504', 'participante');

-- ===== Anônimo =====
set local role anon;
select throws_ok($$ select public.criar_escala('00000000-0000-0000-0000-00000025000a', 'Culto', '2026-12-20', '09:00') $$, '42501', null, 'anônimo não executa criar_escala');
reset role;

-- ===== Líder do A cria =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002502", "role": "authenticated"}', true);
set local role authenticated;
select is((select (public.criar_escala('00000000-0000-0000-0000-00000025000a', '  Culto de hoje ', '2026-12-10', '19:00')).situacao::text), 'rascunho', 'cria escala de HOJE como rascunho');
select lives_ok($$ select public.criar_escala('00000000-0000-0000-0000-00000025000a', 'Culto de amanhã', '2026-12-11', '09:00', 'Trazer partitura') $$, 'cria escala futura com observação');
select throws_ok($$ select public.criar_escala('00000000-0000-0000-0000-00000025000a', 'Culto de ontem', '2026-12-09', '09:00') $$, 'P0001', 'data_passada', 'data anterior a hoje é recusada');
select throws_ok($$ select public.criar_escala('00000000-0000-0000-0000-00000025000a', '', '2026-12-20', '09:00') $$, 'P0001', 'evento_invalido', 'evento em branco');
select throws_ok($$ select public.criar_escala('00000000-0000-0000-0000-00000025000a', 'X', '2026-12-20', '09:00') $$, 'P0001', 'evento_invalido', 'evento curto demais');
select throws_ok($$ select public.criar_escala('00000000-0000-0000-0000-00000025000a', repeat('x', 81), '2026-12-20', '09:00') $$, 'P0001', 'evento_invalido', 'evento longo demais');
select throws_ok($$ select public.criar_escala('00000000-0000-0000-0000-00000025000a', 'Culto', '2026-12-20', '09:00', repeat('x', 301)) $$, 'P0001', 'evento_invalido', 'observação longa demais');
select throws_ok($$ select public.criar_escala('00000000-0000-0000-0000-00000025000a', 'Culto', null, '09:00') $$, 'P0001', 'evento_invalido', 'data obrigatória');
select throws_ok($$ select public.criar_escala('00000000-0000-0000-0000-00000025000b', 'Culto', '2026-12-20', '09:00') $$, 'P0001', 'sem_permissao', 'líder do A não cria escala no B');
reset role;

-- ===== Quem não é gestor =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002504", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.criar_escala('00000000-0000-0000-0000-00000025000a', 'Culto', '2026-12-20', '09:00') $$, 'P0001', 'sem_permissao', 'participante comum não cria escala');
reset role;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002505", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.criar_escala('00000000-0000-0000-0000-00000025000a', 'Culto', '2026-12-20', '09:00') $$, 'P0001', 'sem_permissao', 'estranho não cria escala');
reset role;

-- ===== Administrador: qualquer ministério ativo; inativo recusa escrita =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002501", "role": "authenticated"}', true);
set local role authenticated;
select lives_ok($$ select public.criar_escala('00000000-0000-0000-0000-00000025000b', 'Culto do B', '2026-12-20', '09:00') $$, 'administrador cria em qualquer ministério');
select throws_ok($$ select public.criar_escala('00000000-0000-0000-0000-00000025000c', 'Culto', '2026-12-20', '09:00') $$, 'P0001', 'ministerio_inativo', 'ministério desativado recusa escrita, até do administrador');
select throws_ok($$ select public.editar_escala('99999999-9999-9999-9999-999999999999', 'Culto', '2026-12-20', '09:00', '') $$, 'P0001', 'nao_encontrado', 'administrador é avisado de escala inexistente');
reset role;

-- ===== Edição: preparar escalas em vários estados (como superusuário) =====
insert into public.funcoes_ministerio (id, ministerio_id, nome) values
  ('00000000-0000-0000-0000-00000025f001', '00000000-0000-0000-0000-00000025000a', 'Vocal');
insert into public.escalas (id, ministerio_id, evento, data, horario, situacao) values
  ('00000000-0000-0000-0000-00000025e001', '00000000-0000-0000-0000-00000025000a', 'Publicada futura', '2026-12-15', '09:00', 'publicada'),
  ('00000000-0000-0000-0000-00000025e002', '00000000-0000-0000-0000-00000025000a', 'Cancelada', '2026-12-15', '09:00', 'cancelada'),
  ('00000000-0000-0000-0000-00000025e003', '00000000-0000-0000-0000-00000025000a', 'Ontem', '2026-12-09', '09:00', 'publicada');
insert into public.vagas_escala (id, escala_id, funcao_id, perfil_id) values
  ('00000000-0000-0000-0000-00000025a001', '00000000-0000-0000-0000-00000025e001', '00000000-0000-0000-0000-00000025f001', '00000000-0000-0000-0000-000000002504');
insert into public.respostas_escala (escala_id, perfil_id, resposta) values
  ('00000000-0000-0000-0000-00000025e001', '00000000-0000-0000-0000-000000002504', 'confirmado');
insert into public.pedidos_troca (id, vaga_id, escala_id, solicitante_id, indicada_id) values
  ('00000000-0000-0000-0000-00000025b001', '00000000-0000-0000-0000-00000025a001', '00000000-0000-0000-0000-00000025e001',
   '00000000-0000-0000-0000-000000002504', '00000000-0000-0000-0000-000000002502');

select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002502", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.editar_escala('00000000-0000-0000-0000-00000025e002', 'Novo', '2026-12-16', '09:00', '') $$, 'P0001', 'escala_cancelada', 'escala cancelada não é editada');
select throws_ok($$ select public.editar_escala('00000000-0000-0000-0000-00000025e003', 'Novo', '2026-12-20', '09:00', '') $$, 'P0001', 'escala_somente_leitura', 'a partir do dia seguinte a escala é somente leitura');
select throws_ok($$ select public.editar_escala('00000000-0000-0000-0000-00000025e001', 'Novo', '2026-12-09', '09:00', '') $$, 'P0001', 'data_passada', 'nova data anterior a hoje');
select throws_ok($$ select public.editar_escala('99999999-9999-9999-9999-999999999999', 'Novo', '2026-12-20', '09:00', '') $$, 'P0001', 'sem_permissao', 'escala inexistente: líder recebe sem_permissao');

-- Mudar só evento e observação NÃO limpa respostas nem pedidos
select lives_ok($$ select public.editar_escala('00000000-0000-0000-0000-00000025e001', 'Publicada renomeada', '2026-12-15', '09:00', 'nova obs') $$, 'edita evento e observação');
reset role;
select is((select count(*) from public.respostas_escala where escala_id = '00000000-0000-0000-0000-00000025e001'), 1::bigint, 'mudar só o evento/observação mantém as respostas');
select is((select situacao::text from public.pedidos_troca where id = '00000000-0000-0000-0000-00000025b001'), 'aguardando_indicada', 'e mantém o pedido de troca pendente');

-- Mudar o horário (ou a data) de escala publicada: respostas voltam a pendente e pedidos perdem efeito
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002502", "role": "authenticated"}', true);
set local role authenticated;
select lives_ok($$ select public.editar_escala('00000000-0000-0000-0000-00000025e001', 'Publicada renomeada', '2026-12-15', '10:00', 'nova obs') $$, 'muda o horário');
reset role;
select is((select count(*) from public.respostas_escala where escala_id = '00000000-0000-0000-0000-00000025e001'), 0::bigint, 'mudar o horário apaga todas as respostas (voltam a pendente)');
select is((select situacao::text from public.pedidos_troca where id = '00000000-0000-0000-0000-00000025b001'), 'sem_efeito', 'mudar o horário encerra os pedidos de troca pendentes');

select * from finish();
rollback;
