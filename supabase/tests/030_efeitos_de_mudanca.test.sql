-- T047: o que acontece com respostas e pedidos quando o líder muda a escala (FR-014, FR-015).
-- Relógio: 10/12/2026 09:00 (São Paulo).
begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

create or replace function public.agora_sp() returns timestamptz language sql stable as
  $$ select '2026-12-10 12:00:00+00'::timestamptz $$;

insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role)
select ('00000000-0000-0000-0000-0000000030' || lpad(n::text, 2, '0'))::uuid, 'u' || n || '.30@exemplo.com', now(),
       jsonb_build_object('nome', 'Pessoa 30 ' || n), 'authenticated', 'authenticated'
  from unnest(array[2, 11, 12, 13, 14]) as n;
update public.perfis set situacao = 'aprovado' where id::text like '00000000-0000-0000-0000-0000000030%';
insert into public.ministerios (id, nome, descricao) values ('00000000-0000-0000-0000-00000030000a', 'Teste Efeitos 30', '');
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel)
select '00000000-0000-0000-0000-00000030000a', ('00000000-0000-0000-0000-0000000030' || lpad(n::text, 2, '0'))::uuid,
       case when n = 2 then 'lider'::public.papel_ministerio else 'participante'::public.papel_ministerio end
  from unnest(array[2, 11, 12, 13, 14]) as n;
insert into public.funcoes_ministerio (id, ministerio_id, nome) values
  ('00000000-0000-0000-0000-00000030f001', '00000000-0000-0000-0000-00000030000a', 'Vocal'),
  ('00000000-0000-0000-0000-00000030f002', '00000000-0000-0000-0000-00000030000a', 'Violão');
-- Todos aptos em tudo, para não gerar avisos
insert into public.aptidoes (funcao_id, perfil_id, tipo)
select f, ('00000000-0000-0000-0000-0000000030' || lpad(n::text, 2, '0'))::uuid, 'principal'
  from unnest(array[11, 12, 13, 14]) as n,
       unnest(array['00000000-0000-0000-0000-00000030f001'::uuid, '00000000-0000-0000-0000-00000030f002'::uuid]) as f;
insert into public.escalas (id, ministerio_id, evento, data, horario, situacao) values
  ('00000000-0000-0000-0000-00000030e001', '00000000-0000-0000-0000-00000030000a', 'Publicada', '2026-12-15', '09:00', 'publicada'),
  ('00000000-0000-0000-0000-00000030e002', '00000000-0000-0000-0000-00000030000a', 'Rascunho', '2026-12-16', '09:00', 'rascunho');
-- V1 e V2: P1 (3011). V3: P2 (3012). V4: P3 (3013). Rascunho: V5 com P1
insert into public.vagas_escala (id, escala_id, funcao_id, perfil_id, ordem) values
  ('00000000-0000-0000-0000-00000030a001', '00000000-0000-0000-0000-00000030e001', '00000000-0000-0000-0000-00000030f001', '00000000-0000-0000-0000-000000003011', 1),
  ('00000000-0000-0000-0000-00000030a002', '00000000-0000-0000-0000-00000030e001', '00000000-0000-0000-0000-00000030f002', '00000000-0000-0000-0000-000000003011', 2),
  ('00000000-0000-0000-0000-00000030a003', '00000000-0000-0000-0000-00000030e001', '00000000-0000-0000-0000-00000030f001', '00000000-0000-0000-0000-000000003012', 3),
  ('00000000-0000-0000-0000-00000030a004', '00000000-0000-0000-0000-00000030e001', '00000000-0000-0000-0000-00000030f001', '00000000-0000-0000-0000-000000003013', 4),
  ('00000000-0000-0000-0000-00000030a005', '00000000-0000-0000-0000-00000030e002', '00000000-0000-0000-0000-00000030f001', '00000000-0000-0000-0000-000000003011', 1);
insert into public.respostas_escala (escala_id, perfil_id, resposta, motivo) values
  ('00000000-0000-0000-0000-00000030e001', '00000000-0000-0000-0000-000000003011', 'confirmado', ''),
  ('00000000-0000-0000-0000-00000030e001', '00000000-0000-0000-0000-000000003012', 'recusado', 'Viagem'),
  ('00000000-0000-0000-0000-00000030e001', '00000000-0000-0000-0000-000000003013', 'confirmado', '');
insert into public.pedidos_troca (id, vaga_id, escala_id, solicitante_id, indicada_id) values
  ('00000000-0000-0000-0000-00000030b001', '00000000-0000-0000-0000-00000030a003', '00000000-0000-0000-0000-00000030e001',
   '00000000-0000-0000-0000-000000003012', '00000000-0000-0000-0000-000000003014');

select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003002", "role": "authenticated"}', true);
set local role authenticated;

-- ===== Trocar a pessoa de uma vaga (P2 → P4) =====
select lives_ok($$ select public.salvar_vaga('00000000-0000-0000-0000-00000030e001', '00000000-0000-0000-0000-00000030a003',
  '00000000-0000-0000-0000-00000030f001', '', '00000000-0000-0000-0000-000000003014') $$, 'líder troca a pessoa da vaga 3');
reset role;
select is((select perfil_id from public.vagas_escala where id = '00000000-0000-0000-0000-00000030a003'), '00000000-0000-0000-0000-000000003014'::uuid, 'a nova pessoa ocupa a vaga');
select is((select count(*) from public.respostas_escala where perfil_id = '00000000-0000-0000-0000-000000003012'), 0::bigint, 'a anterior deixou de estar escalada: a resposta dela some');
select is((select count(*) from public.respostas_escala where perfil_id = '00000000-0000-0000-0000-000000003014'), 0::bigint, 'a nova pessoa está pendente (sem resposta)');
select is((select situacao::text from public.pedidos_troca where id = '00000000-0000-0000-0000-00000030b001'), 'sem_efeito', 'o pedido de troca pendente da vaga perde efeito');

-- ===== Trocar a pessoa de uma vaga quando ela tem OUTRA vaga na escala =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003002", "role": "authenticated"}', true);
set local role authenticated;
select lives_ok($$ select public.salvar_vaga('00000000-0000-0000-0000-00000030e001', '00000000-0000-0000-0000-00000030a001',
  '00000000-0000-0000-0000-00000030f001', '', '00000000-0000-0000-0000-000000003013') $$, 'P1 sai da vaga 1 e P3 (que já tinha a vaga 4) entra');
reset role;
select is((select count(*) from public.respostas_escala where perfil_id = '00000000-0000-0000-0000-000000003011'), 1::bigint, 'P1 ainda ocupa a vaga 2: a resposta dele continua');
select is((select resposta::text from public.respostas_escala where perfil_id = '00000000-0000-0000-0000-000000003013'), 'confirmado', 'quem ganha uma segunda vaga mantém a resposta que já tinha (é uma participação só)');

-- ===== Remover a última vaga de alguém =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003002", "role": "authenticated"}', true);
set local role authenticated;
select lives_ok($$ select public.remover_vaga('00000000-0000-0000-0000-00000030a002') $$, 'remove a última vaga do P1');
reset role;
select is((select count(*) from public.respostas_escala where perfil_id = '00000000-0000-0000-0000-000000003011'), 0::bigint, 'sem vagas, a resposta dele some');

-- ===== Rascunho: trocar pessoa não tem respostas nem pedidos para limpar =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003002", "role": "authenticated"}', true);
set local role authenticated;
select lives_ok($$ select public.salvar_vaga('00000000-0000-0000-0000-00000030e002', '00000000-0000-0000-0000-00000030a005',
  '00000000-0000-0000-0000-00000030f001', '', '00000000-0000-0000-0000-000000003012') $$, 'troca de pessoa em rascunho');
reset role;

-- ===== Mudar a data: respostas voltam a pendente e pedidos pendentes perdem efeito =====
insert into public.pedidos_troca (id, vaga_id, escala_id, solicitante_id, indicada_id) values
  ('00000000-0000-0000-0000-00000030b002', '00000000-0000-0000-0000-00000030a004', '00000000-0000-0000-0000-00000030e001',
   '00000000-0000-0000-0000-000000003013', '00000000-0000-0000-0000-000000003012');
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003002", "role": "authenticated"}', true);
set local role authenticated;
select lives_ok($$ select public.editar_escala('00000000-0000-0000-0000-00000030e001', 'Publicada', '2026-12-17', '09:00', '') $$, 'muda a data');
reset role;
select is((select count(*) from public.respostas_escala where escala_id = '00000000-0000-0000-0000-00000030e001'), 0::bigint, 'todas as respostas voltam a pendente');
select is((select situacao::text from public.pedidos_troca where id = '00000000-0000-0000-0000-00000030b002'), 'sem_efeito', 'pedidos pendentes são cancelados');

select * from finish();
rollback;
