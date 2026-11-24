-- T058: a pessoa indicada aceita ou recusa (passo 1). Relógio: 10/12/2026 09:00 (São Paulo).
begin;
create extension if not exists pgtap with schema extensions;
select plan(11);

create or replace function public.agora_sp() returns timestamptz language sql stable as
  $$ select '2026-12-10 12:00:00+00'::timestamptz $$;

insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role)
select ('00000000-0000-0000-0000-0000000034' || lpad(n::text, 2, '0'))::uuid, 'u' || n || '.34@exemplo.com', now(),
       jsonb_build_object('nome', 'Pessoa 34 ' || n), 'authenticated', 'authenticated'
  from unnest(array[2, 11, 12, 13, 14, 15]) as n;
update public.perfis set situacao = 'aprovado' where id::text like '00000000-0000-0000-0000-0000000034%';
insert into public.ministerios (id, nome, descricao) values ('00000000-0000-0000-0000-00000034000a', 'Teste Resp Troca 34', '');
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel)
select '00000000-0000-0000-0000-00000034000a', ('00000000-0000-0000-0000-0000000034' || lpad(n::text, 2, '0'))::uuid,
       case when n = 2 then 'lider'::public.papel_ministerio else 'participante'::public.papel_ministerio end
  from unnest(array[2, 11, 12, 13, 14, 15]) as n;
insert into public.funcoes_ministerio (id, ministerio_id, nome) values ('00000000-0000-0000-0000-00000034f001', '00000000-0000-0000-0000-00000034000a', 'Vocal');
insert into public.escalas (id, ministerio_id, evento, data, horario, situacao) values
  ('00000000-0000-0000-0000-00000034e001', '00000000-0000-0000-0000-00000034000a', 'Publicada', '2026-12-15', '09:00', 'publicada'),
  ('00000000-0000-0000-0000-00000034e003', '00000000-0000-0000-0000-00000034000a', 'Cancelada', '2026-12-17', '09:00', 'cancelada'),
  ('00000000-0000-0000-0000-00000034e004', '00000000-0000-0000-0000-00000034000a', 'Hoje cedo', '2026-12-10', '08:00', 'publicada');
insert into public.vagas_escala (id, escala_id, funcao_id, perfil_id) values
  ('00000000-0000-0000-0000-00000034a001', '00000000-0000-0000-0000-00000034e001', '00000000-0000-0000-0000-00000034f001', '00000000-0000-0000-0000-000000003411'),
  ('00000000-0000-0000-0000-00000034a002', '00000000-0000-0000-0000-00000034e001', '00000000-0000-0000-0000-00000034f001', '00000000-0000-0000-0000-000000003412'),
  ('00000000-0000-0000-0000-00000034a003', '00000000-0000-0000-0000-00000034e001', '00000000-0000-0000-0000-00000034f001', '00000000-0000-0000-0000-000000003411'),
  ('00000000-0000-0000-0000-00000034a004', '00000000-0000-0000-0000-00000034e003', '00000000-0000-0000-0000-00000034f001', '00000000-0000-0000-0000-000000003411'),
  ('00000000-0000-0000-0000-00000034a005', '00000000-0000-0000-0000-00000034e004', '00000000-0000-0000-0000-00000034f001', '00000000-0000-0000-0000-000000003411');
insert into public.pedidos_troca (id, vaga_id, escala_id, solicitante_id, indicada_id) values
  ('00000000-0000-0000-0000-00000034b001', '00000000-0000-0000-0000-00000034a001', '00000000-0000-0000-0000-00000034e001', '00000000-0000-0000-0000-000000003411', '00000000-0000-0000-0000-000000003413'),
  ('00000000-0000-0000-0000-00000034b002', '00000000-0000-0000-0000-00000034a002', '00000000-0000-0000-0000-00000034e001', '00000000-0000-0000-0000-000000003412', '00000000-0000-0000-0000-000000003414'),
  ('00000000-0000-0000-0000-00000034b003', '00000000-0000-0000-0000-00000034a003', '00000000-0000-0000-0000-00000034e001', '00000000-0000-0000-0000-000000003411', '00000000-0000-0000-0000-000000003415'),
  ('00000000-0000-0000-0000-00000034b004', '00000000-0000-0000-0000-00000034a004', '00000000-0000-0000-0000-00000034e003', '00000000-0000-0000-0000-000000003411', '00000000-0000-0000-0000-000000003413'),
  ('00000000-0000-0000-0000-00000034b005', '00000000-0000-0000-0000-00000034a005', '00000000-0000-0000-0000-00000034e004', '00000000-0000-0000-0000-000000003411', '00000000-0000-0000-0000-000000003413');

set local role anon;
select throws_ok($$ select public.responder_pedido_troca('00000000-0000-0000-0000-00000034b001', true) $$, '42501', null, 'anônimo não executa responder_pedido_troca');
reset role;

-- Quem pediu não responde pelo outro
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003411", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.responder_pedido_troca('00000000-0000-0000-0000-00000034b001', true) $$, 'P0001', 'sem_permissao', 'quem pediu não aceita no lugar da indicada');
reset role;

-- A indicada (P3) aceita
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003413", "role": "authenticated"}', true);
set local role authenticated;
select is((select (public.responder_pedido_troca('00000000-0000-0000-0000-00000034b001', true)).situacao::text), 'aguardando_lider', 'aceitar leva o pedido para o líder');
select throws_ok($$ select public.responder_pedido_troca('00000000-0000-0000-0000-00000034b001', false) $$, 'P0001', 'conflito_troca', 'depois de respondido, não se responde de novo');
select throws_ok($$ select public.responder_pedido_troca('00000000-0000-0000-0000-00000034b004', true) $$, 'P0001', 'escala_cancelada', 'escala cancelada não aceita resposta');
select throws_ok($$ select public.responder_pedido_troca('00000000-0000-0000-0000-00000034b005', true) $$, 'P0001', 'evento_iniciado', 'depois do horário de início');
select throws_ok($$ select public.responder_pedido_troca('99999999-9999-9999-9999-999999999999', true) $$, 'P0001', 'sem_permissao', 'pedido inexistente');
reset role;
select isnt((select respondido_em from public.pedidos_troca where id = '00000000-0000-0000-0000-00000034b001'), null, 'a data da resposta fica registrada');

-- A indicada (P4) recusa
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003414", "role": "authenticated"}', true);
set local role authenticated;
select is((select (public.responder_pedido_troca('00000000-0000-0000-0000-00000034b002', false)).situacao::text), 'recusado_indicada', 'recusar encerra o pedido');
reset role;
select is((select perfil_id from public.vagas_escala where id = '00000000-0000-0000-0000-00000034a002'), '00000000-0000-0000-0000-000000003412'::uuid, 'a vaga continua com quem pediu');

-- A indicada (P5) foi escalada nesta escala por outro caminho antes de aceitar: o pedido perde efeito
insert into public.vagas_escala (escala_id, funcao_id, perfil_id) values
  ('00000000-0000-0000-0000-00000034e001', '00000000-0000-0000-0000-00000034f001', '00000000-0000-0000-0000-000000003415');
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003415", "role": "authenticated"}', true);
set local role authenticated;
select is((select (public.responder_pedido_troca('00000000-0000-0000-0000-00000034b003', true)).situacao::text), 'sem_efeito', 'indicada já escalada: o pedido perde efeito (não vira aguardando o líder)');
reset role;

select * from finish();
rollback;
