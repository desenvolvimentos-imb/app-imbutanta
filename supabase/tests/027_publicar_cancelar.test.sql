-- T028: publicar e cancelar escalas (FR-011 a FR-013).
begin;
create extension if not exists pgtap with schema extensions;
select plan(17);

create or replace function public.agora_sp() returns timestamptz language sql stable as
  $$ select '2026-12-10 12:00:00+00'::timestamptz $$;

insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role) values
  ('00000000-0000-0000-0000-000000002702', 'la.27@exemplo.com',   now(), '{"nome":"Lider A 27"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000002703', 'lb.27@exemplo.com',   now(), '{"nome":"Lider B 27"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000002704', 'pa.27@exemplo.com',   now(), '{"nome":"Part A 27"}',  'authenticated', 'authenticated');
update public.perfis set situacao = 'aprovado' where id::text like '00000000-0000-0000-0000-0000000027%';
insert into public.ministerios (id, nome, descricao) values
  ('00000000-0000-0000-0000-00000027000a', 'Teste Publicar 27 A', ''),
  ('00000000-0000-0000-0000-00000027000b', 'Teste Publicar 27 B', '');
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel) values
  ('00000000-0000-0000-0000-00000027000a', '00000000-0000-0000-0000-000000002702', 'lider'),
  ('00000000-0000-0000-0000-00000027000b', '00000000-0000-0000-0000-000000002703', 'lider'),
  ('00000000-0000-0000-0000-00000027000a', '00000000-0000-0000-0000-000000002704', 'participante');
insert into public.funcoes_ministerio (id, ministerio_id, nome) values
  ('00000000-0000-0000-0000-00000027f001', '00000000-0000-0000-0000-00000027000a', 'Vocal');
insert into public.escalas (id, ministerio_id, evento, data, horario, situacao) values
  ('00000000-0000-0000-0000-00000027e001', '00000000-0000-0000-0000-00000027000a', 'Sem vagas', '2026-12-15', '09:00', 'rascunho'),
  ('00000000-0000-0000-0000-00000027e002', '00000000-0000-0000-0000-00000027000a', 'Com vaga em aberto', '2026-12-15', '09:00', 'rascunho'),
  ('00000000-0000-0000-0000-00000027e003', '00000000-0000-0000-0000-00000027000a', 'Já passou', '2026-12-09', '09:00', 'rascunho'),
  ('00000000-0000-0000-0000-00000027e004', '00000000-0000-0000-0000-00000027000a', 'Para cancelar', '2026-12-15', '09:00', 'publicada');
insert into public.vagas_escala (id, escala_id, funcao_id, perfil_id) values
  ('00000000-0000-0000-0000-00000027a001', '00000000-0000-0000-0000-00000027e002', '00000000-0000-0000-0000-00000027f001', null),
  ('00000000-0000-0000-0000-00000027a002', '00000000-0000-0000-0000-00000027e003', '00000000-0000-0000-0000-00000027f001', null),
  ('00000000-0000-0000-0000-00000027a003', '00000000-0000-0000-0000-00000027e004', '00000000-0000-0000-0000-00000027f001', '00000000-0000-0000-0000-000000002704');
insert into public.respostas_escala (escala_id, perfil_id, resposta) values
  ('00000000-0000-0000-0000-00000027e004', '00000000-0000-0000-0000-000000002704', 'confirmado');
insert into public.pedidos_troca (id, vaga_id, escala_id, solicitante_id, indicada_id) values
  ('00000000-0000-0000-0000-00000027b001', '00000000-0000-0000-0000-00000027a003', '00000000-0000-0000-0000-00000027e004',
   '00000000-0000-0000-0000-000000002704', '00000000-0000-0000-0000-000000002702');

select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002702", "role": "authenticated"}', true);
set local role authenticated;

-- ===== publicar =====
select throws_ok($$ select public.publicar_escala('00000000-0000-0000-0000-00000027e001') $$, 'P0001', 'escala_sem_vagas', 'sem nenhuma vaga não publica');
select is((select (public.publicar_escala('00000000-0000-0000-0000-00000027e002')).situacao::text), 'publicada', 'publica com vaga em aberto');
select is((select (public.publicar_escala('00000000-0000-0000-0000-00000027e002')).situacao::text), 'publicada', 'publicar é idempotente');
select throws_ok($$ select public.publicar_escala('00000000-0000-0000-0000-00000027e003') $$, 'P0001', 'escala_somente_leitura', 'escala que já passou não publica');

-- ===== cancelar =====
select is((select (public.cancelar_escala('00000000-0000-0000-0000-00000027e004')).situacao::text), 'cancelada', 'cancela a escala publicada');
select is((select (public.cancelar_escala('00000000-0000-0000-0000-00000027e004')).situacao::text), 'cancelada', 'cancelar é idempotente');
reset role;
select is((select count(*) from public.escalas where id = '00000000-0000-0000-0000-00000027e004'), 1::bigint, 'a escala cancelada NÃO é apagada');
select is((select count(*) from public.vagas_escala where escala_id = '00000000-0000-0000-0000-00000027e004'), 1::bigint, 'as vagas continuam registradas');
select isnt((select cancelada_em from public.escalas where id = '00000000-0000-0000-0000-00000027e004'), null, 'cancelada_em preenchido');
select is((select situacao::text from public.pedidos_troca where id = '00000000-0000-0000-0000-00000027b001'), 'sem_efeito', 'pedidos de troca pendentes perdem efeito');
select is((select count(*) from public.respostas_escala where escala_id = '00000000-0000-0000-0000-00000027e004'), 1::bigint, 'a resposta continua gravada (só perde efeito: as telas bloqueiam)');

select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002702", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.cancelar_escala('00000000-0000-0000-0000-00000027e003') $$, 'P0001', 'escala_somente_leitura', 'escala que já passou não pode ser cancelada');
select throws_ok($$ select public.publicar_escala('00000000-0000-0000-0000-00000027e004') $$, 'P0001', 'escala_cancelada', 'cancelada não volta a ser publicada');
reset role;

-- ===== permissões =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002703", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.publicar_escala('00000000-0000-0000-0000-00000027e001') $$, 'P0001', 'sem_permissao', 'líder de outro ministério não publica');
select throws_ok($$ select public.cancelar_escala('00000000-0000-0000-0000-00000027e002') $$, 'P0001', 'sem_permissao', 'líder de outro ministério não cancela');
reset role;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002704", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.publicar_escala('00000000-0000-0000-0000-00000027e001') $$, 'P0001', 'sem_permissao', 'participante comum não publica');
select throws_ok($$ select public.cancelar_escala('00000000-0000-0000-0000-00000027e002') $$, 'P0001', 'sem_permissao', 'participante comum não cancela');
reset role;

select * from finish();
rollback;
