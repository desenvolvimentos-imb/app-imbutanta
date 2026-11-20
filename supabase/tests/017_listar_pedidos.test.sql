-- T047: quem vê quais pedidos pendentes (RF-025, RF-028). Só nome, nunca email.
begin;
create extension if not exists pgtap with schema extensions;
select plan(18);

insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role) values
  ('00000000-0000-0000-0000-000000003a01', 'adm.l@exemplo.com', now(), '{"nome":"Adm L"}',    'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000003a02', 'l1.l@exemplo.com',  now(), '{"nome":"Lider L1"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000003a03', 'l2.l@exemplo.com',  now(), '{"nome":"Lider L2"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000003a04', 'p1.l@exemplo.com',  now(), '{"nome":"Pend L1"}',  'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000003a05', 'p2.l@exemplo.com',  now(), '{"nome":"Pend L2"}',  'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000003a06', 'p3.l@exemplo.com',  null,  '{"nome":"Pend L3 NV"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000003a07', 'm1.l@exemplo.com',  now(), '{"nome":"Membro L1"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000003a08', 'p5.l@exemplo.com',  now(), '{"nome":"Pend L5"}',  'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000003a09', 'p6.l@exemplo.com',  now(), '{"nome":"Pend L6 sem pedido"}', 'authenticated', 'authenticated');
update public.perfis set situacao = 'aprovado', papel = 'administrador' where id = '00000000-0000-0000-0000-000000003a01';
update public.perfis set situacao = 'aprovado' where id in
  ('00000000-0000-0000-0000-000000003a02', '00000000-0000-0000-0000-000000003a03', '00000000-0000-0000-0000-000000003a07');

insert into public.ministerios (id, nome, descricao, ativo, desativado_em) values
  ('00000000-0000-0000-0000-00000000ca0a', 'Teste Listar A', '', true,  null),
  ('00000000-0000-0000-0000-00000000ca0b', 'Teste Listar B', '', true,  null),
  ('00000000-0000-0000-0000-00000000ca0c', 'Teste Listar Inativo', '', false, now());
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel) values
  ('00000000-0000-0000-0000-00000000ca0a', '00000000-0000-0000-0000-000000003a02', 'lider'),
  ('00000000-0000-0000-0000-00000000ca0b', '00000000-0000-0000-0000-000000003a03', 'lider');

insert into public.pedidos_entrada_ministerio (ministerio_id, perfil_id) values
  ('00000000-0000-0000-0000-00000000ca0a', '00000000-0000-0000-0000-000000003a04'), -- conta pendente -> A
  ('00000000-0000-0000-0000-00000000ca0b', '00000000-0000-0000-0000-000000003a05'), -- conta pendente -> B
  ('00000000-0000-0000-0000-00000000ca0a', '00000000-0000-0000-0000-000000003a06'), -- email NÃO confirmado -> A
  ('00000000-0000-0000-0000-00000000ca0a', '00000000-0000-0000-0000-000000003a07'), -- membro aprovado -> A
  ('00000000-0000-0000-0000-00000000ca0c', '00000000-0000-0000-0000-000000003a08'), -- ministério desativado
  ('00000000-0000-0000-0000-00000000ca0a', '00000000-0000-0000-0000-000000003a01'); -- o próprio administrador -> A
-- (3a09 não tem pedido nenhum)

-- ===== Administrador: todos os pedidos decidíveis, menos o próprio =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003a01", "role": "authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.listar_pedidos_pendentes() where perfil_id in
            ('00000000-0000-0000-0000-000000003a04', '00000000-0000-0000-0000-000000003a05', '00000000-0000-0000-0000-000000003a07')),
          3::bigint, 'administrador vê os pedidos de A e B (conta pendente e aprovada)');
select is((select count(*) from public.listar_pedidos_pendentes() where perfil_id = '00000000-0000-0000-0000-000000003a06'),
          0::bigint, 'pedido de conta com email não confirmado não aparece');
select is((select count(*) from public.listar_pedidos_pendentes() where perfil_id = '00000000-0000-0000-0000-000000003a08'),
          0::bigint, 'pedido de ministério desativado não aparece');
select is((select count(*) from public.listar_pedidos_pendentes() where perfil_id = '00000000-0000-0000-0000-000000003a01'),
          0::bigint, 'o administrador não vê o próprio pedido (não pode decidi-lo)');
select is((select conta_pendente from public.listar_pedidos_pendentes() where perfil_id = '00000000-0000-0000-0000-000000003a04'),
          true, 'conta_pendente indica que aceitar também ativa a conta');
select is((select conta_pendente from public.listar_pedidos_pendentes() where perfil_id = '00000000-0000-0000-0000-000000003a07'),
          false, 'conta já aprovada: conta_pendente é falso');
select is((select ministerio_nome from public.listar_pedidos_pendentes() where perfil_id = '00000000-0000-0000-0000-000000003a04'),
          'Teste Listar A', 'informa qual ministério foi pedido');
select is((select public.contar_pedidos_pendentes()), (select count(*)::integer from public.listar_pedidos_pendentes()),
          'a contagem confere com a lista');
reset role;

-- ===== Líder: só os pedidos dos ministérios que lidera =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003a02", "role": "authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.listar_pedidos_pendentes() where perfil_id in
            ('00000000-0000-0000-0000-000000003a04', '00000000-0000-0000-0000-000000003a07')),
          2::bigint, 'líder do A vê os pedidos pendentes do A');
select is((select count(*) from public.listar_pedidos_pendentes() where perfil_id = '00000000-0000-0000-0000-000000003a05'),
          0::bigint, 'líder do A NÃO vê pedido do B');
select is((select count(*) from public.listar_pedidos_pendentes() where perfil_id = '00000000-0000-0000-0000-000000003a09'),
          0::bigint, 'conta pendente sem nenhum pedido não aparece para líder');
reset role;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003a03", "role": "authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.listar_pedidos_pendentes() where perfil_id = '00000000-0000-0000-0000-000000003a05'),
          1::bigint, 'líder do B vê o pedido do B');
select is((select count(*) from public.listar_pedidos_pendentes() where perfil_id = '00000000-0000-0000-0000-000000003a04'),
          0::bigint, 'líder do B NÃO vê o pedido do A');
reset role;

-- ===== Membro sem liderança: lista vazia =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003a07", "role": "authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.listar_pedidos_pendentes()), 0::bigint, 'membro sem liderança recebe lista vazia');
select is((select public.contar_pedidos_pendentes()), 0, 'e contagem zero');
reset role;

-- ===== Conta pendente (sem acesso aprovado): lista vazia =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003a04", "role": "authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.listar_pedidos_pendentes()), 0::bigint, 'conta pendente não vê pedidos de ninguém');
reset role;

-- ===== Nunca devolve email =====
select ok(not ('email' = any (coalesce((select proargnames from pg_proc where proname = 'listar_pedidos_pendentes'), '{}'))),
          'listar_pedidos_pendentes não devolve email');

-- ===== Visitante =====
set local role anon;
select throws_ok($$ select * from public.listar_pedidos_pendentes() $$, '42501', null, 'visitante não executa listar_pedidos_pendentes');
reset role;

select * from finish();
rollback;
