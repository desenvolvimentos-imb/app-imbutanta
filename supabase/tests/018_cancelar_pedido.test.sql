-- T053: cancelar o próprio pedido pendente e pedir de novo depois (RF-017, RF-020).
begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role) values
  ('00000000-0000-0000-0000-000000004a01', 'u1.k@exemplo.com', now(), '{"nome":"Pessoa K1"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000004a02', 'u2.k@exemplo.com', now(), '{"nome":"Pessoa K2"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000004a03', 'u3.k@exemplo.com', now(), '{"nome":"Pendente K3"}', 'authenticated', 'authenticated');
update public.perfis set situacao = 'aprovado' where id in
  ('00000000-0000-0000-0000-000000004a01', '00000000-0000-0000-0000-000000004a02');

insert into public.ministerios (id, nome, descricao) values
  ('00000000-0000-0000-0000-00000000ba0a', 'Teste Cancelar A', ''),
  ('00000000-0000-0000-0000-00000000ba0b', 'Teste Cancelar B', ''),
  ('00000000-0000-0000-0000-00000000ba0c', 'Teste Cancelar C', '');

insert into public.pedidos_entrada_ministerio (id, ministerio_id, perfil_id, situacao) values
  ('00000000-0000-0000-0000-0000000ba101', '00000000-0000-0000-0000-00000000ba0a', '00000000-0000-0000-0000-000000004a01', 'pendente'),
  ('00000000-0000-0000-0000-0000000ba102', '00000000-0000-0000-0000-00000000ba0b', '00000000-0000-0000-0000-000000004a01', 'recusado'),
  ('00000000-0000-0000-0000-0000000ba103', '00000000-0000-0000-0000-00000000ba0a', '00000000-0000-0000-0000-000000004a02', 'pendente'),
  ('00000000-0000-0000-0000-0000000ba104', '00000000-0000-0000-0000-00000000ba0c', '00000000-0000-0000-0000-000000004a01', 'aceito'),
  ('00000000-0000-0000-0000-0000000ba105', '00000000-0000-0000-0000-00000000ba0b', '00000000-0000-0000-0000-000000004a03', 'pendente');

select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000004a01", "role": "authenticated"}', true);
set local role authenticated;
select lives_ok($$ select public.cancelar_pedido_entrada('00000000-0000-0000-0000-0000000ba101') $$,
                'a pessoa cancela o próprio pedido pendente');
select throws_ok($$ select public.cancelar_pedido_entrada('00000000-0000-0000-0000-0000000ba101') $$,
                 'P0001', 'conflito_pedido', 'cancelar de novo (já cancelado)');
select throws_ok($$ select public.cancelar_pedido_entrada('00000000-0000-0000-0000-0000000ba102') $$,
                 'P0001', 'conflito_pedido', 'não cancela pedido já recusado');
select throws_ok($$ select public.cancelar_pedido_entrada('00000000-0000-0000-0000-0000000ba104') $$,
                 'P0001', 'conflito_pedido', 'não cancela pedido já aceito');
select throws_ok($$ select public.cancelar_pedido_entrada('00000000-0000-0000-0000-0000000ba103') $$,
                 'P0001', 'nao_encontrado', 'não cancela o pedido de outra pessoa');
select throws_ok($$ select public.cancelar_pedido_entrada('99999999-9999-9999-9999-999999999999') $$,
                 'P0001', 'nao_encontrado', 'pedido inexistente');

-- Depois de cancelado ou recusado, pedir de novo é permitido (RF-020)
select lives_ok($$ select public.pedir_entrada_ministerio('00000000-0000-0000-0000-00000000ba0a') $$,
                'depois de cancelar, a pessoa pede de novo');
select lives_ok($$ select public.pedir_entrada_ministerio('00000000-0000-0000-0000-00000000ba0b') $$,
                'depois de recusado, a pessoa pede de novo');
reset role;

select is((select situacao::text from public.pedidos_entrada_ministerio where id = '00000000-0000-0000-0000-0000000ba101'),
          'cancelado', 'o pedido ficou cancelado');
select isnt((select decidido_em from public.pedidos_entrada_ministerio where id = '00000000-0000-0000-0000-0000000ba101'),
            null, 'registra quando foi cancelado');
select is((select situacao::text from public.pedidos_entrada_ministerio where id = '00000000-0000-0000-0000-0000000ba103'),
          'pendente', 'o pedido da outra pessoa não foi afetado');

-- Conta pendente também cancela o próprio pedido
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000004a03", "role": "authenticated"}', true);
set local role authenticated;
select lives_ok($$ select public.cancelar_pedido_entrada('00000000-0000-0000-0000-0000000ba105') $$,
                'conta pendente cancela o próprio pedido');
reset role;

set local role anon;
select throws_ok($$ select public.cancelar_pedido_entrada('00000000-0000-0000-0000-0000000ba103') $$,
                 '42501', null, 'visitante não executa cancelar_pedido_entrada');
reset role;

select * from finish();
rollback;
