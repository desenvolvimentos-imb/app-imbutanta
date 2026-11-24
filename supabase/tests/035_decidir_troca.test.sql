-- T059: o líder aprova ou recusa (passo 2) e a troca é atômica (FR-030, FR-034, FR-035).
-- Relógio: 10/12/2026 09:00 (São Paulo).
begin;
create extension if not exists pgtap with schema extensions;
select plan(21);

create or replace function public.agora_sp() returns timestamptz language sql stable as
  $$ select '2026-12-10 12:00:00+00'::timestamptz $$;

-- Adm (3501), L (3502, líder A), LB (3503, líder B), P1 (3511), P2 (3512), P3 (3513), P4 (3514)
insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role)
select ('00000000-0000-0000-0000-0000000035' || lpad(n::text, 2, '0'))::uuid, 'u' || n || '.35@exemplo.com', now(),
       jsonb_build_object('nome', 'Pessoa 35 ' || n), 'authenticated', 'authenticated'
  from unnest(array[1, 2, 3, 11, 12, 13, 14]) as n;
update public.perfis set situacao = 'aprovado' where id::text like '00000000-0000-0000-0000-0000000035%';
update public.perfis set papel = 'administrador' where id = '00000000-0000-0000-0000-000000003501';
insert into public.ministerios (id, nome, descricao) values
  ('00000000-0000-0000-0000-00000035000a', 'Teste Decidir 35 A', ''),
  ('00000000-0000-0000-0000-00000035000b', 'Teste Decidir 35 B', '');
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel)
select '00000000-0000-0000-0000-00000035000a', ('00000000-0000-0000-0000-0000000035' || lpad(n::text, 2, '0'))::uuid,
       case when n = 2 then 'lider'::public.papel_ministerio else 'participante'::public.papel_ministerio end
  from unnest(array[2, 11, 12, 13, 14]) as n;
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel) values
  ('00000000-0000-0000-0000-00000035000b', '00000000-0000-0000-0000-000000003503', 'lider'),
  ('00000000-0000-0000-0000-00000035000b', '00000000-0000-0000-0000-000000003513', 'participante');
insert into public.funcoes_ministerio (id, ministerio_id, nome) values
  ('00000000-0000-0000-0000-00000035f001', '00000000-0000-0000-0000-00000035000a', 'Vocal'),
  ('00000000-0000-0000-0000-00000035f002', '00000000-0000-0000-0000-00000035000a', 'Violão'),
  ('00000000-0000-0000-0000-00000035f00b', '00000000-0000-0000-0000-00000035000b', 'Recepção');
-- P3 é apto em Vocal e em Violão; P4 não é apto em nada
insert into public.aptidoes (funcao_id, perfil_id, tipo) values
  ('00000000-0000-0000-0000-00000035f001', '00000000-0000-0000-0000-000000003513', 'principal'),
  ('00000000-0000-0000-0000-00000035f002', '00000000-0000-0000-0000-000000003513', 'principal');
insert into public.escalas (id, ministerio_id, evento, data, horario, situacao) values
  ('00000000-0000-0000-0000-00000035e001', '00000000-0000-0000-0000-00000035000a', 'Publicada', '2026-12-15', '09:00', 'publicada'),
  ('00000000-0000-0000-0000-00000035e0b1', '00000000-0000-0000-0000-00000035000b', 'Culto B', '2026-12-15', '08:00', 'publicada');
-- V1 e V2 (P1: Vocal e Violão), V3 (P2: Vocal), V4 (P1... não: P2 também tem V5), vaga do B para o aviso de conflito
insert into public.vagas_escala (id, escala_id, funcao_id, perfil_id, ordem) values
  ('00000000-0000-0000-0000-00000035a001', '00000000-0000-0000-0000-00000035e001', '00000000-0000-0000-0000-00000035f001', '00000000-0000-0000-0000-000000003511', 1),
  ('00000000-0000-0000-0000-00000035a002', '00000000-0000-0000-0000-00000035e001', '00000000-0000-0000-0000-00000035f002', '00000000-0000-0000-0000-000000003511', 2),
  ('00000000-0000-0000-0000-00000035a003', '00000000-0000-0000-0000-00000035e001', '00000000-0000-0000-0000-00000035f001', '00000000-0000-0000-0000-000000003512', 3),
  ('00000000-0000-0000-0000-00000035a004', '00000000-0000-0000-0000-00000035e001', '00000000-0000-0000-0000-00000035f001', '00000000-0000-0000-0000-000000003512', 4),
  ('00000000-0000-0000-0000-00000035a0b1', '00000000-0000-0000-0000-00000035e0b1', '00000000-0000-0000-0000-00000035f00b', '00000000-0000-0000-0000-000000003513', 1);
insert into public.respostas_escala (escala_id, perfil_id, resposta, motivo) values
  ('00000000-0000-0000-0000-00000035e001', '00000000-0000-0000-0000-000000003511', 'confirmado', ''),
  ('00000000-0000-0000-0000-00000035e001', '00000000-0000-0000-0000-000000003512', 'recusado', 'Viagem');
insert into public.pedidos_troca (id, vaga_id, escala_id, solicitante_id, indicada_id, situacao) values
  ('00000000-0000-0000-0000-00000035b001', '00000000-0000-0000-0000-00000035a001', '00000000-0000-0000-0000-00000035e001', '00000000-0000-0000-0000-000000003511', '00000000-0000-0000-0000-000000003513', 'aguardando_lider'),
  ('00000000-0000-0000-0000-00000035b002', '00000000-0000-0000-0000-00000035a003', '00000000-0000-0000-0000-00000035e001', '00000000-0000-0000-0000-000000003512', '00000000-0000-0000-0000-000000003514', 'aguardando_lider'),
  ('00000000-0000-0000-0000-00000035b003', '00000000-0000-0000-0000-00000035a002', '00000000-0000-0000-0000-00000035e001', '00000000-0000-0000-0000-000000003511', '00000000-0000-0000-0000-000000003513', 'aguardando_lider'),
  ('00000000-0000-0000-0000-00000035b004', '00000000-0000-0000-0000-00000035a004', '00000000-0000-0000-0000-00000035e001', '00000000-0000-0000-0000-000000003512', '00000000-0000-0000-0000-000000003514', 'aguardando_indicada');
-- (b002 e b004 são da mesma pessoa mas de vagas diferentes: V3 e V4)

-- ===== Quem não gere o ministério =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003511", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.decidir_troca_lider('00000000-0000-0000-0000-00000035b001', true, true) $$, 'P0001', 'sem_permissao', 'participante comum não aprova');
reset role;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003503", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.decidir_troca_lider('00000000-0000-0000-0000-00000035b001', true, true) $$, 'P0001', 'sem_permissao', 'líder de outro ministério não aprova');
reset role;
set local role anon;
select throws_ok($$ select public.decidir_troca_lider('00000000-0000-0000-0000-00000035b001', true, true) $$, '42501', null, 'anônimo não executa decidir_troca_lider');
reset role;

select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003502", "role": "authenticated"}', true);
set local role authenticated;

-- ===== Estados errados =====
select throws_ok($$ select public.decidir_troca_lider('00000000-0000-0000-0000-00000035b004', true, true) $$, 'P0001', 'conflito_troca', 'pedido que ainda aguarda a indicada não é decidido pelo líder');
select throws_ok($$ select public.decidir_troca_lider('99999999-9999-9999-9999-999999999999', true, true) $$, 'P0001', 'sem_permissao', 'pedido inexistente: o líder recebe sem_permissao');

-- ===== Aprovar b001 (P1 → P3, Vocal): P3 é apta em Vocal e confirmada em outro ministério no mesmo dia? (não confirmou) =====
select is((public.decidir_troca_lider('00000000-0000-0000-0000-00000035b001', true) ->> 'decidido')::boolean, true, 'aprova sem avisos (P3 é apta e não confirmou outra escala no dia)');
reset role;
select is((select perfil_id from public.vagas_escala where id = '00000000-0000-0000-0000-00000035a001'), '00000000-0000-0000-0000-000000003513'::uuid, 'a vaga passa para a indicada');
select is((select resposta::text from public.respostas_escala where escala_id = '00000000-0000-0000-0000-00000035e001' and perfil_id = '00000000-0000-0000-0000-000000003513'), 'confirmado', 'com resposta "confirmado"');
select is((select perfil_id from public.vagas_escala where id = '00000000-0000-0000-0000-00000035a002'), '00000000-0000-0000-0000-000000003511'::uuid, 'quem pediu mantém as OUTRAS vagas dele na escala');
select is((select resposta::text from public.respostas_escala where escala_id = '00000000-0000-0000-0000-00000035e001' and perfil_id = '00000000-0000-0000-0000-000000003511'), 'confirmado', 'e a resposta dele continua');
select is((select situacao::text from public.pedidos_troca where id = '00000000-0000-0000-0000-00000035b001'), 'aprovado', 'pedido aprovado');
select is((select decidido_por from public.pedidos_troca where id = '00000000-0000-0000-0000-00000035b001'), '00000000-0000-0000-0000-000000003502'::uuid, 'registra quem decidiu');
select is((select situacao::text from public.pedidos_troca where id = '00000000-0000-0000-0000-00000035b003'), 'sem_efeito', 'outro pedido pendente para a mesma indicada perde efeito (ela agora está escalada)');

-- ===== Aprovar b002 (P2 → P4, Vocal): P4 não é apto => aviso, sem gravar nada =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003502", "role": "authenticated"}', true);
set local role authenticated;
select is((public.decidir_troca_lider('00000000-0000-0000-0000-00000035b002', true) -> 'avisos' -> 0 ->> 'tipo'), 'sem_aptidao', 'indicada sem aptidão: devolve o aviso');
select is((public.decidir_troca_lider('00000000-0000-0000-0000-00000035b002', true) ->> 'decidido')::boolean, false, 'e não decide sem a confirmação do líder');
reset role;
select is((select situacao::text from public.pedidos_troca where id = '00000000-0000-0000-0000-00000035b002'), 'aguardando_lider', 'o pedido continua aguardando');

-- ===== Atomicidade: uma falha no meio da aprovação desfaz TUDO =====
create function public.t_falha_forcada() returns trigger language plpgsql as $f$ begin raise exception 'falha_forcada'; end $f$;
create trigger t_falha_forcada before insert on public.respostas_escala
  for each row when (new.perfil_id = '00000000-0000-0000-0000-000000003514') execute function public.t_falha_forcada();
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003502", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.decidir_troca_lider('00000000-0000-0000-0000-00000035b002', true, true) $$, 'P0001', 'falha_forcada', 'falha no meio da aprovação');
reset role;
select is((select perfil_id from public.vagas_escala where id = '00000000-0000-0000-0000-00000035a003'), '00000000-0000-0000-0000-000000003512'::uuid, 'ATOMICIDADE: a vaga continua com quem pediu');
select is((select situacao::text from public.pedidos_troca where id = '00000000-0000-0000-0000-00000035b002'), 'aguardando_lider', 'e o pedido continua como estava');
drop trigger t_falha_forcada on public.respostas_escala;

-- ===== Agora sem falha, com ciência: aprova, e a resposta de quem pediu (sem outras vagas?) =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003502", "role": "authenticated"}', true);
set local role authenticated;
select is((public.decidir_troca_lider('00000000-0000-0000-0000-00000035b002', true, true) ->> 'decidido')::boolean, true, 'com ciência do aviso, aprova');
reset role;
select is((select count(*) from public.respostas_escala where perfil_id = '00000000-0000-0000-0000-000000003512'), 1::bigint, 'P2 ainda tem a vaga 4: a resposta dele continua (só perdeu a vaga 3)');

select * from finish();
rollback;
