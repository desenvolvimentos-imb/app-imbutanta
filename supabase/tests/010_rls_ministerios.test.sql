-- T004: regras de leitura e escrita das tabelas de ministérios (RLS + permissões).
-- Usa ids próprios, pois o seed local também cria ministérios.
begin;
create extension if not exists pgtap with schema extensions;
select plan(21);

insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role) values
  ('00000000-0000-0000-0000-000000000b11', 'adm.m@exemplo.com', now(), '{"nome":"Adm M"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000b12', 'mem1.m@exemplo.com', now(), '{"nome":"Mem Um M"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000b13', 'mem2.m@exemplo.com', now(), '{"nome":"Mem Dois M"}', 'authenticated', 'authenticated');
update public.perfis set situacao = 'aprovado', papel = 'administrador' where id = '00000000-0000-0000-0000-000000000b11';
update public.perfis set situacao = 'aprovado' where id in
  ('00000000-0000-0000-0000-000000000b12', '00000000-0000-0000-0000-000000000b13');

insert into public.ministerios (id, nome, descricao, ativo) values
  ('00000000-0000-0000-0000-00000000aa01', 'Ministério Teste Ativo', 'descrição', true),
  ('00000000-0000-0000-0000-00000000aa02', 'Ministério Teste Inativo', 'descrição', false);
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel) values
  ('00000000-0000-0000-0000-00000000aa01', '00000000-0000-0000-0000-000000000b12', 'lider'),
  ('00000000-0000-0000-0000-00000000aa01', '00000000-0000-0000-0000-000000000b13', 'participante');
insert into public.pedidos_entrada_ministerio (ministerio_id, perfil_id) values
  ('00000000-0000-0000-0000-00000000aa01', '00000000-0000-0000-0000-000000000b12'),
  ('00000000-0000-0000-0000-00000000aa01', '00000000-0000-0000-0000-000000000b13');

-- ===== Visitante (sem login) =====
set local role anon;
select is((select count(*) from public.ministerios
            where id in ('00000000-0000-0000-0000-00000000aa01', '00000000-0000-0000-0000-00000000aa02')),
          1::bigint, 'visitante vê só ministério ATIVO (para o cadastro)');
select throws_ok($$ select criado_em from public.ministerios $$,
                 '42501', null, 'visitante só lê as colunas públicas (nome, descrição)');
select throws_ok($$ select * from public.participacoes_ministerio $$,
                 '42501', null, 'visitante não lê participações');
select throws_ok($$ select * from public.pedidos_entrada_ministerio $$,
                 '42501', null, 'visitante não lê pedidos');
select throws_ok($$ insert into public.ministerios (nome, descricao) values ('Invasor', 'x') $$,
                 '42501', null, 'visitante não cria ministério');
reset role;

-- ===== Membro (líder do ministério, mas só enxerga o que é seu) =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000b12", "role": "authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.ministerios
            where id in ('00000000-0000-0000-0000-00000000aa01', '00000000-0000-0000-0000-00000000aa02')),
          1::bigint, 'pessoa logada vê só ministérios ativos');
select is((select count(*) from public.participacoes_ministerio where perfil_id = '00000000-0000-0000-0000-000000000b12'),
          1::bigint, 'lê a própria participação');
select is((select count(*) from public.participacoes_ministerio where perfil_id = '00000000-0000-0000-0000-000000000b13'),
          0::bigint, 'NÃO lê a participação de outra pessoa direto na tabela (só por função)');
select is((select count(*) from public.pedidos_entrada_ministerio where perfil_id = '00000000-0000-0000-0000-000000000b12'),
          1::bigint, 'lê o próprio pedido');
select is((select count(*) from public.pedidos_entrada_ministerio where perfil_id = '00000000-0000-0000-0000-000000000b13'),
          0::bigint, 'NÃO lê o pedido de outra pessoa direto na tabela');
select throws_ok($$ insert into public.ministerios (nome, descricao) values ('Invasor', 'x') $$,
                 '42501', null, 'não cria ministério direto pela API');
select throws_ok($$ update public.ministerios set nome = 'Trocado' where id = '00000000-0000-0000-0000-00000000aa01' $$,
                 '42501', null, 'não edita ministério direto pela API');
select throws_ok($$ delete from public.ministerios where id = '00000000-0000-0000-0000-00000000aa01' $$,
                 '42501', null, 'não apaga ministério direto pela API');
select throws_ok($$ insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel)
                    values ('00000000-0000-0000-0000-00000000aa01', '00000000-0000-0000-0000-000000000b12', 'lider') $$,
                 '42501', null, 'não cria participação direto pela API');
select throws_ok($$ update public.participacoes_ministerio set papel = 'lider'
                     where perfil_id = '00000000-0000-0000-0000-000000000b13' $$,
                 '42501', null, 'não altera participação direto pela API');
select throws_ok($$ insert into public.pedidos_entrada_ministerio (ministerio_id, perfil_id)
                    values ('00000000-0000-0000-0000-00000000aa01', '00000000-0000-0000-0000-000000000b12') $$,
                 '42501', null, 'não cria pedido direto pela API');
select throws_ok($$ update public.pedidos_entrada_ministerio set situacao = 'aceito' $$,
                 '42501', null, 'não decide pedido direto pela API');
reset role;

-- ===== Administrador =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000b11", "role": "authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.ministerios
            where id in ('00000000-0000-0000-0000-00000000aa01', '00000000-0000-0000-0000-00000000aa02')),
          2::bigint, 'administrador vê ministérios ativos e desativados');
select is((select count(*) from public.participacoes_ministerio
            where ministerio_id = '00000000-0000-0000-0000-00000000aa01'),
          2::bigint, 'administrador lê todas as participações');
select is((select count(*) from public.pedidos_entrada_ministerio
            where ministerio_id = '00000000-0000-0000-0000-00000000aa01'),
          2::bigint, 'administrador lê todos os pedidos');
reset role;

-- ===== A política antiga de líder global saiu de perfis =====
select is((select count(*) from pg_policies where tablename = 'perfis' and policyname = 'perfis_ler_fila_lider'),
          0::bigint, 'a política perfis_ler_fila_lider foi removida');

select * from finish();
rollback;
