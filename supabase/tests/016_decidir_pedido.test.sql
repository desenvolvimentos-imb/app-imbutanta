-- T046: o líder (ou o administrador) decide pedidos de entrada; aceitar o pedido de uma conta
-- nova também a ativa (RF-019 a RF-024).
begin;
create extension if not exists pgtap with schema extensions;
select plan(37);

insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role) values
  ('00000000-0000-0000-0000-000000002a01', 'adm.d@exemplo.com',  now(),  '{"nome":"Adm D"}',     'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000002a02', 'l1.d@exemplo.com',   now(),  '{"nome":"Lider D1"}',  'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000002a03', 'l2.d@exemplo.com',   now(),  '{"nome":"Lider D2"}',  'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000002a04', 'p1.d@exemplo.com',   now(),  '{"nome":"Pend D1"}',   'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000002a05', 'p2.d@exemplo.com',   null,   '{"nome":"Pend D2 NV"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000002a06', 'p3.d@exemplo.com',   now(),  '{"nome":"Pend D3"}',   'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000002a07', 'm1.d@exemplo.com',   now(),  '{"nome":"Membro D1"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000002a08', 'm2.d@exemplo.com',   now(),  '{"nome":"Membro D2"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000002a09', 'm3.d@exemplo.com',   now(),  '{"nome":"Membro D3"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000002a0a', 'rc.d@exemplo.com',   now(),  '{"nome":"Recusada D"}', 'authenticated', 'authenticated');
update public.perfis set situacao = 'aprovado', papel = 'administrador' where id = '00000000-0000-0000-0000-000000002a01';
update public.perfis set situacao = 'aprovado' where id in
  ('00000000-0000-0000-0000-000000002a02', '00000000-0000-0000-0000-000000002a03', '00000000-0000-0000-0000-000000002a07',
   '00000000-0000-0000-0000-000000002a08', '00000000-0000-0000-0000-000000002a09');
update public.perfis set situacao = 'recusado' where id = '00000000-0000-0000-0000-000000002a0a';

insert into public.ministerios (id, nome, descricao, ativo, desativado_em) values
  ('00000000-0000-0000-0000-00000000da0a', 'Teste Decidir A', '', true,  null),
  ('00000000-0000-0000-0000-00000000da0b', 'Teste Decidir B', '', true,  null),
  ('00000000-0000-0000-0000-00000000da0c', 'Teste Decidir Inativo', '', false, now());
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel) values
  ('00000000-0000-0000-0000-00000000da0a', '00000000-0000-0000-0000-000000002a02', 'lider'),
  ('00000000-0000-0000-0000-00000000da0b', '00000000-0000-0000-0000-000000002a03', 'lider'),
  ('00000000-0000-0000-0000-00000000da0c', '00000000-0000-0000-0000-000000002a03', 'lider');

-- Pedidos (ids fixos para referenciar nos testes)
insert into public.pedidos_entrada_ministerio (id, ministerio_id, perfil_id) values
  ('00000000-0000-0000-0000-0000000da101', '00000000-0000-0000-0000-00000000da0a', '00000000-0000-0000-0000-000000002a04'), -- p1 -> A
  ('00000000-0000-0000-0000-0000000da102', '00000000-0000-0000-0000-00000000da0b', '00000000-0000-0000-0000-000000002a04'), -- p1 -> B
  ('00000000-0000-0000-0000-0000000da103', '00000000-0000-0000-0000-00000000da0a', '00000000-0000-0000-0000-000000002a05'), -- p2 (email não confirmado) -> A
  ('00000000-0000-0000-0000-0000000da104', '00000000-0000-0000-0000-00000000da0a', '00000000-0000-0000-0000-000000002a06'), -- p3 -> A
  ('00000000-0000-0000-0000-0000000da105', '00000000-0000-0000-0000-00000000da0a', '00000000-0000-0000-0000-000000002a07'), -- m1 (já aprovado) -> A
  ('00000000-0000-0000-0000-0000000da106', '00000000-0000-0000-0000-00000000da0c', '00000000-0000-0000-0000-000000002a08'), -- m2 -> inativo
  ('00000000-0000-0000-0000-0000000da107', '00000000-0000-0000-0000-00000000da0b', '00000000-0000-0000-0000-000000002a09'), -- m3 -> B
  ('00000000-0000-0000-0000-0000000da108', '00000000-0000-0000-0000-00000000da0a', '00000000-0000-0000-0000-000000002a01'); -- admin -> A (o próprio)
-- Conta recusada com pedido pendente "órfão" (inserido direto, sem passar pelo cancelamento automático)
insert into public.pedidos_entrada_ministerio (id, ministerio_id, perfil_id) values
  ('00000000-0000-0000-0000-0000000da109', '00000000-0000-0000-0000-00000000da0a', '00000000-0000-0000-0000-000000002a0a');

-- Pedido novo do administrador (para provar que ninguém decide o próprio pedido)
insert into public.pedidos_entrada_ministerio (id, ministerio_id, perfil_id) values
  ('00000000-0000-0000-0000-0000000da10a', '00000000-0000-0000-0000-00000000da0b', '00000000-0000-0000-0000-000000002a01');

-- ===== Líder do A aceita o pedido de uma conta pendente: a conta é ativada =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002a02", "role": "authenticated"}', true);
set local role authenticated;
select lives_ok($$ select public.decidir_pedido_entrada('00000000-0000-0000-0000-0000000da101', 'aceitar', 'pendente') $$,
                'líder aceita o pedido de uma conta pendente');
reset role;
select is((select situacao::text from public.perfis where id = '00000000-0000-0000-0000-000000002a04'),
          'aprovado', 'a conta ficou aprovada');
select is((select papel::text from public.perfis where id = '00000000-0000-0000-0000-000000002a04'),
          'membro', 'e entrou como membro');
select is((select decidido_por from public.perfis where id = '00000000-0000-0000-0000-000000002a04'),
          '00000000-0000-0000-0000-000000002a02'::uuid, 'registra quem aprovou a conta');
select isnt((select decidido_em from public.perfis where id = '00000000-0000-0000-0000-000000002a04'), null,
            'registra quando aprovou a conta');
select is((select papel::text from public.participacoes_ministerio where ministerio_id = '00000000-0000-0000-0000-00000000da0a'
            and perfil_id = '00000000-0000-0000-0000-000000002a04'), 'participante', 'virou participante do A');
select is((select adicionado_por from public.participacoes_ministerio where ministerio_id = '00000000-0000-0000-0000-00000000da0a'
            and perfil_id = '00000000-0000-0000-0000-000000002a04'),
          '00000000-0000-0000-0000-000000002a02'::uuid, 'a participação registra quem aceitou');
select is((select situacao::text || ',' || (decidido_por = '00000000-0000-0000-0000-000000002a02')::text
             from public.pedidos_entrada_ministerio where id = '00000000-0000-0000-0000-0000000da101'),
          'aceito,true', 'o pedido ficou aceito, com o decisor');
select is((select situacao::text from public.pedidos_entrada_ministerio where id = '00000000-0000-0000-0000-0000000da102'),
          'pendente', 'o pedido da mesma pessoa ao ministério B continua pendente');

set local role authenticated;
select throws_ok($$ select public.decidir_pedido_entrada('00000000-0000-0000-0000-0000000da101', 'aceitar', 'pendente') $$,
                 'P0001', 'conflito_pedido', 'decidir de novo um pedido já decidido gera conflito');
select throws_ok($$ select public.decidir_pedido_entrada('00000000-0000-0000-0000-0000000da102', 'aceitar', 'pendente') $$,
                 'P0001', 'sem_permissao', 'líder do A NÃO decide pedido do B');
select throws_ok($$ select public.decidir_pedido_entrada('99999999-9999-9999-9999-999999999999', 'aceitar', 'pendente') $$,
                 'P0001', 'sem_permissao', 'pedido inexistente não é revelado a quem não é administrador');
-- Aceitar o pedido de uma conta que já está aprovada (aqui, a do administrador) só cria a participação.
select lives_ok($$ select public.decidir_pedido_entrada('00000000-0000-0000-0000-0000000da108', 'aceitar', 'pendente') $$,
                'líder aceita o pedido de uma conta já aprovada');
reset role;
select is((select papel::text from public.perfis where id = '00000000-0000-0000-0000-000000002a01'),
          'administrador', 'a conta já aprovada não foi alterada pelo aceite');

-- ===== Recusar NÃO mexe na conta (RF-020, RF-024) =====
set local role authenticated;
select lives_ok($$ select public.decidir_pedido_entrada('00000000-0000-0000-0000-0000000da104', 'recusar', 'pendente') $$,
                'líder recusa um pedido');
reset role;
select is((select situacao::text from public.pedidos_entrada_ministerio where id = '00000000-0000-0000-0000-0000000da104'),
          'recusado', 'o pedido ficou recusado');
select is((select situacao::text from public.perfis where id = '00000000-0000-0000-0000-000000002a06'),
          'pendente', 'a conta continua pendente: recusar pedido não recusa a conta');
select is((select count(*) from public.participacoes_ministerio where perfil_id = '00000000-0000-0000-0000-000000002a06'),
          0::bigint, 'e a pessoa não virou participante');

-- ===== Conta com email não confirmado não é aceita =====
set local role authenticated;
select throws_ok($$ select public.decidir_pedido_entrada('00000000-0000-0000-0000-0000000da103', 'aceitar', 'pendente') $$,
                 'P0001', 'transicao_invalida', 'não aceita pedido de conta com email não confirmado');
reset role;
select is((select situacao::text from public.perfis where id = '00000000-0000-0000-0000-000000002a05'),
          'pendente', 'a conta continua pendente');

-- ===== Conta já aprovada: aceite só cria a participação =====
set local role authenticated;
select lives_ok($$ select public.decidir_pedido_entrada('00000000-0000-0000-0000-0000000da105', 'aceitar', 'pendente') $$,
                'líder aceita o pedido de um membro já aprovado');
reset role;
select is((select count(*) from public.participacoes_ministerio where perfil_id = '00000000-0000-0000-0000-000000002a07'
            and ministerio_id = '00000000-0000-0000-0000-00000000da0a'), 1::bigint, 'o membro virou participante');
select is((select situacao::text || ',' || papel::text from public.perfis where id = '00000000-0000-0000-0000-000000002a07'),
          'aprovado,membro', 'a conta do membro não mudou');

-- ===== Entradas inválidas =====
set local role authenticated;
select throws_ok($$ select public.decidir_pedido_entrada('00000000-0000-0000-0000-0000000da109', 'talvez', 'pendente') $$,
                 'P0001', 'transicao_invalida', 'decisão desconhecida');
select throws_ok($$ select public.decidir_pedido_entrada('00000000-0000-0000-0000-0000000da109', 'aceitar', 'aceito') $$,
                 'P0001', 'transicao_invalida', 'a situação esperada precisa ser pendente');
select throws_ok($$ select public.decidir_pedido_entrada('00000000-0000-0000-0000-0000000da109', 'aceitar', 'pendente') $$,
                 'P0001', 'transicao_invalida', 'conta recusada nunca é ativada por aceite de pedido');
reset role;

-- ===== Líder do B (e de um ministério desativado) =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002a03", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.decidir_pedido_entrada('00000000-0000-0000-0000-0000000da106', 'aceitar', 'pendente') $$,
                 'P0001', 'sem_permissao', 'líder de ministério desativado não decide pedidos dele');
select lives_ok($$ select public.decidir_pedido_entrada('00000000-0000-0000-0000-0000000da102', 'recusar', 'pendente') $$,
                'líder do B recusa o pedido de uma pessoa que já foi aprovada pelo A');
reset role;
select is((select situacao::text from public.perfis where id = '00000000-0000-0000-0000-000000002a04'),
          'aprovado', 'recusar no B não afetou a conta já aprovada');

-- ===== Participante comum não decide =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002a07", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.decidir_pedido_entrada('00000000-0000-0000-0000-0000000da107', 'aceitar', 'pendente') $$,
                 'P0001', 'sem_permissao', 'participante comum não decide pedidos');
reset role;

-- ===== Administrador =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002a01", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.decidir_pedido_entrada('00000000-0000-0000-0000-0000000da106', 'aceitar', 'pendente') $$,
                 'P0001', 'ministerio_inativo', 'ministério desativado não recebe decisões');
select lives_ok($$ select public.decidir_pedido_entrada('00000000-0000-0000-0000-0000000da107', 'aceitar', 'pendente') $$,
                'administrador decide pedido de qualquer ministério');
select throws_ok($$ select public.decidir_pedido_entrada('00000000-0000-0000-0000-0000000da10a', 'aceitar', 'pendente') $$,
                 'P0001', 'sem_permissao', 'ninguém decide o próprio pedido');
select throws_ok($$ select public.decidir_pedido_entrada('99999999-9999-9999-9999-999999999999', 'aceitar', 'pendente') $$,
                 'P0001', 'nao_encontrado', 'administrador é avisado de que o pedido não existe');
reset role;

-- ===== Conta pendente ou recusada (sem acesso aprovado) não decide pedidos =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002a05", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.decidir_pedido_entrada('00000000-0000-0000-0000-0000000da107', 'aceitar', 'pendente') $$,
                 'P0001', 'sem_permissao', 'conta pendente não decide pedidos');
reset role;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000002a0a", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.decidir_pedido_entrada('00000000-0000-0000-0000-0000000da107', 'aceitar', 'pendente') $$,
                 'P0001', 'sem_permissao', 'conta recusada não decide pedidos');
reset role;

-- ===== Visitante =====
set local role anon;
select throws_ok($$ select public.decidir_pedido_entrada('00000000-0000-0000-0000-0000000da107', 'aceitar', 'pendente') $$,
                 '42501', null, 'visitante não executa decidir_pedido_entrada');
reset role;

select * from finish();
rollback;
