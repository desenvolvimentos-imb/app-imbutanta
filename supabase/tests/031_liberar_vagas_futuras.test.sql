-- T048: saída do ministério ou perda de acesso libera as vagas FUTURAS (FR-019). Relógio: 10/12/2026.
begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

create or replace function public.agora_sp() returns timestamptz language sql stable as
  $$ select '2026-12-10 12:00:00+00'::timestamptz $$;

insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role)
select ('00000000-0000-0000-0000-0000000031' || lpad(n::text, 2, '0'))::uuid, 'u' || n || '.31@exemplo.com', now(),
       jsonb_build_object('nome', 'Pessoa 31 ' || n), 'authenticated', 'authenticated'
  from unnest(array[2, 3, 11, 12, 13]) as n;
update public.perfis set situacao = 'aprovado' where id::text like '00000000-0000-0000-0000-0000000031%';
insert into public.ministerios (id, nome, descricao) values
  ('00000000-0000-0000-0000-00000031000a', 'Teste Liberar 31 A', ''),
  ('00000000-0000-0000-0000-00000031000b', 'Teste Liberar 31 B', '');
-- P1 (3111) em A e B; P2 (3112) em A e B; P3 (3113) em A. Líderes: 3102 (A) e 3103 (B)
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel) values
  ('00000000-0000-0000-0000-00000031000a', '00000000-0000-0000-0000-000000003102', 'lider'),
  ('00000000-0000-0000-0000-00000031000b', '00000000-0000-0000-0000-000000003103', 'lider'),
  ('00000000-0000-0000-0000-00000031000a', '00000000-0000-0000-0000-000000003111', 'participante'),
  ('00000000-0000-0000-0000-00000031000b', '00000000-0000-0000-0000-000000003111', 'participante'),
  ('00000000-0000-0000-0000-00000031000a', '00000000-0000-0000-0000-000000003112', 'participante'),
  ('00000000-0000-0000-0000-00000031000b', '00000000-0000-0000-0000-000000003112', 'participante'),
  ('00000000-0000-0000-0000-00000031000a', '00000000-0000-0000-0000-000000003113', 'participante');
insert into public.funcoes_ministerio (id, ministerio_id, nome) values
  ('00000000-0000-0000-0000-00000031f00a', '00000000-0000-0000-0000-00000031000a', 'Vocal'),
  ('00000000-0000-0000-0000-00000031f00b', '00000000-0000-0000-0000-00000031000b', 'Recepção');
insert into public.escalas (id, ministerio_id, evento, data, horario, situacao) values
  ('00000000-0000-0000-0000-00000031e0a1', '00000000-0000-0000-0000-00000031000a', 'A futura publicada', '2026-12-15', '09:00', 'publicada'),
  ('00000000-0000-0000-0000-00000031e0a2', '00000000-0000-0000-0000-00000031000a', 'A futura rascunho', '2026-12-16', '09:00', 'rascunho'),
  ('00000000-0000-0000-0000-00000031e0a3', '00000000-0000-0000-0000-00000031000a', 'A passada', '2026-12-05', '09:00', 'publicada'),
  ('00000000-0000-0000-0000-00000031e0a4', '00000000-0000-0000-0000-00000031000a', 'A cancelada', '2026-12-17', '09:00', 'cancelada'),
  ('00000000-0000-0000-0000-00000031e0b1', '00000000-0000-0000-0000-00000031000b', 'B futura', '2026-12-15', '09:00', 'publicada');
insert into public.vagas_escala (id, escala_id, funcao_id, perfil_id) values
  ('00000000-0000-0000-0000-00000031a001', '00000000-0000-0000-0000-00000031e0a1', '00000000-0000-0000-0000-00000031f00a', '00000000-0000-0000-0000-000000003111'),
  ('00000000-0000-0000-0000-00000031a002', '00000000-0000-0000-0000-00000031e0a2', '00000000-0000-0000-0000-00000031f00a', '00000000-0000-0000-0000-000000003111'),
  ('00000000-0000-0000-0000-00000031a003', '00000000-0000-0000-0000-00000031e0a3', '00000000-0000-0000-0000-00000031f00a', '00000000-0000-0000-0000-000000003111'),
  ('00000000-0000-0000-0000-00000031a004', '00000000-0000-0000-0000-00000031e0a4', '00000000-0000-0000-0000-00000031f00a', '00000000-0000-0000-0000-000000003111'),
  ('00000000-0000-0000-0000-00000031a005', '00000000-0000-0000-0000-00000031e0b1', '00000000-0000-0000-0000-00000031f00b', '00000000-0000-0000-0000-000000003111'),
  ('00000000-0000-0000-0000-00000031a006', '00000000-0000-0000-0000-00000031e0a1', '00000000-0000-0000-0000-00000031f00a', '00000000-0000-0000-0000-000000003112'),
  ('00000000-0000-0000-0000-00000031a007', '00000000-0000-0000-0000-00000031e0b1', '00000000-0000-0000-0000-00000031f00b', '00000000-0000-0000-0000-000000003112');
insert into public.respostas_escala (escala_id, perfil_id, resposta) values
  ('00000000-0000-0000-0000-00000031e0a1', '00000000-0000-0000-0000-000000003111', 'confirmado'),
  ('00000000-0000-0000-0000-00000031e0a3', '00000000-0000-0000-0000-000000003111', 'confirmado'),
  ('00000000-0000-0000-0000-00000031e0b1', '00000000-0000-0000-0000-000000003111', 'confirmado'),
  ('00000000-0000-0000-0000-00000031e0a1', '00000000-0000-0000-0000-000000003112', 'confirmado'),
  ('00000000-0000-0000-0000-00000031e0b1', '00000000-0000-0000-0000-000000003112', 'confirmado');
-- Pedidos pendentes: P1 pede (vaga a001) indicando P3; P3 pede (vaga a006 é do P2: usa P2 pedindo indicando P1) e um no B
insert into public.pedidos_troca (id, vaga_id, escala_id, solicitante_id, indicada_id) values
  ('00000000-0000-0000-0000-00000031b001', '00000000-0000-0000-0000-00000031a001', '00000000-0000-0000-0000-00000031e0a1', '00000000-0000-0000-0000-000000003111', '00000000-0000-0000-0000-000000003113'),
  ('00000000-0000-0000-0000-00000031b002', '00000000-0000-0000-0000-00000031a006', '00000000-0000-0000-0000-00000031e0a1', '00000000-0000-0000-0000-000000003112', '00000000-0000-0000-0000-000000003113'),
  ('00000000-0000-0000-0000-00000031b003', '00000000-0000-0000-0000-00000031a005', '00000000-0000-0000-0000-00000031e0b1', '00000000-0000-0000-0000-000000003111', '00000000-0000-0000-0000-000000003103');

-- ===== P1 sai do ministério A =====
delete from public.participacoes_ministerio
 where ministerio_id = '00000000-0000-0000-0000-00000031000a' and perfil_id = '00000000-0000-0000-0000-000000003111';
select is((select perfil_id from public.vagas_escala where id = '00000000-0000-0000-0000-00000031a001'), null::uuid, 'vaga futura publicada do A fica em aberto');
select is((select perfil_id from public.vagas_escala where id = '00000000-0000-0000-0000-00000031a002'), null::uuid, 'vaga futura de rascunho do A também');
select is((select perfil_id from public.vagas_escala where id = '00000000-0000-0000-0000-00000031a003'), '00000000-0000-0000-0000-000000003111'::uuid, 'vaga de escala PASSADA continua com ele');
select is((select perfil_id from public.vagas_escala where id = '00000000-0000-0000-0000-00000031a004'), '00000000-0000-0000-0000-000000003111'::uuid, 'escala cancelada não é mexida');
select is((select perfil_id from public.vagas_escala where id = '00000000-0000-0000-0000-00000031a005'), '00000000-0000-0000-0000-000000003111'::uuid, 'vaga de OUTRO ministério continua com ele');
select is((select array_agg(escala_id::text order by escala_id) from public.respostas_escala where perfil_id = '00000000-0000-0000-0000-000000003111'),
          array['00000000-0000-0000-0000-00000031e0a3', '00000000-0000-0000-0000-00000031e0b1'], 'só as respostas das escalas futuras do A somem');
select is((select situacao::text from public.pedidos_troca where id = '00000000-0000-0000-0000-00000031b001'), 'sem_efeito', 'pedido feito por ele no A perde efeito');
select is((select situacao::text from public.pedidos_troca where id = '00000000-0000-0000-0000-00000031b003'), 'aguardando_indicada', 'pedido dele no B continua');
select is((select situacao::text from public.pedidos_troca where id = '00000000-0000-0000-0000-00000031b002'), 'aguardando_indicada', 'pedido de outra pessoa não é afetado');

-- ===== P3 (indicada do pedido b002) sai do A: pedidos em que ela é a indicada perdem efeito =====
delete from public.participacoes_ministerio
 where ministerio_id = '00000000-0000-0000-0000-00000031000a' and perfil_id = '00000000-0000-0000-0000-000000003113';
select is((select situacao::text from public.pedidos_troca where id = '00000000-0000-0000-0000-00000031b002'), 'sem_efeito', 'pedido em que ela era a indicada perde efeito');

-- ===== Perda de acesso: libera as vagas futuras de TODOS os ministérios =====
update public.perfis set situacao = 'acesso_removido' where id = '00000000-0000-0000-0000-000000003112';
select is((select count(*) from public.vagas_escala where perfil_id = '00000000-0000-0000-0000-000000003112'), 0::bigint, 'quem perdeu o acesso deixa todas as vagas futuras (A e B)');
select is((select count(*) from public.respostas_escala where perfil_id = '00000000-0000-0000-0000-000000003112'), 0::bigint, 'e as respostas dessas escalas somem');
update public.perfis set situacao = 'aprovado' where id = '00000000-0000-0000-0000-000000003112';
select is((select count(*) from public.vagas_escala where perfil_id = '00000000-0000-0000-0000-000000003112'), 0::bigint, 'reaprovar a conta não devolve as vagas (o líder reorganiza)');

-- ===== Exclusão de conta =====
delete from auth.users where id = '00000000-0000-0000-0000-000000003111';
select is((select count(*) from public.vagas_escala where perfil_id = '00000000-0000-0000-0000-000000003111'), 0::bigint, 'exclusão de conta: nenhuma vaga fica com a pessoa');

select * from finish();
rollback;
