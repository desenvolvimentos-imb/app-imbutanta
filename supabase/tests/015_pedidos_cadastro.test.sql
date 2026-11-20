-- T039: pedidos de entrada criados no cadastro e depois dele (RF-015 a RF-018).
begin;
create extension if not exists pgtap with schema extensions;
select plan(24);

insert into public.ministerios (id, nome, descricao, ativo, desativado_em) values
  ('00000000-0000-0000-0000-000000001a0a', 'Teste Cadastro A', '', true,  null),
  ('00000000-0000-0000-0000-000000001a0b', 'Teste Cadastro B', '', true,  null),
  ('00000000-0000-0000-0000-000000001a0c', 'Teste Cadastro Inativo', '', false, now());

-- ===== Pedidos nascem dos metadados do cadastro (email e senha) =====
-- Entradas ruins (id inválido, inexistente, de ministério inativo) são IGNORADAS e nunca
-- impedem a criação da conta.
insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role) values
  ('00000000-0000-0000-0000-000000001b01', 'u1.c@exemplo.com', now(),
   '{"nome":"Cad Um","ministerios":["00000000-0000-0000-0000-000000001a0a","00000000-0000-0000-0000-000000001a0c","99999999-9999-9999-9999-999999999999","lixo; drop table x",42,null,{"a":1}]}',
   'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000001b02', 'u2.c@exemplo.com', now(),
   '{"nome":"Cad Dois","ministerios":"00000000-0000-0000-0000-000000001a0a"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000001b03', 'u3.c@exemplo.com', now(),
   '{"nome":"Cad Tres","ministerios":{"id":"00000000-0000-0000-0000-000000001a0a"}}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000001b04', 'u4.c@exemplo.com', now(),
   '{"nome":"Cad Quatro"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000001b05', 'u5.c@exemplo.com', now(),
   '{"nome":"Cad Cinco","ministerios":["00000000-0000-0000-0000-000000001A0A","00000000-0000-0000-0000-000000001a0a","00000000-0000-0000-0000-000000001a0b"]}',
   'authenticated', 'authenticated');

select is((select count(*) from public.perfis where id::text like '00000000-0000-0000-0000-000000001b0%'), 5::bigint,
          'todas as contas foram criadas, mesmo com metadados ruins');
select is((select count(*) from public.pedidos_entrada_ministerio where perfil_id = '00000000-0000-0000-0000-000000001b01'),
          1::bigint, 'só o ministério ativo e válido virou pedido');
select is((select ministerio_id from public.pedidos_entrada_ministerio where perfil_id = '00000000-0000-0000-0000-000000001b01'),
          '00000000-0000-0000-0000-000000001a0a'::uuid, 'o pedido é para o ministério marcado');
select is((select situacao::text || ',' || origem_cadastro::text from public.pedidos_entrada_ministerio
            where perfil_id = '00000000-0000-0000-0000-000000001b01'),
          'pendente,true', 'o pedido nasce pendente e marcado como vindo do cadastro');
select is((select count(*) from public.participacoes_ministerio where perfil_id = '00000000-0000-0000-0000-000000001b01'),
          0::bigint, 'marcar um ministério NÃO torna a pessoa participante');
select is((select situacao::text from public.perfis where id = '00000000-0000-0000-0000-000000001b01'),
          'pendente', 'a conta continua pendente');
select is((select count(*) from public.pedidos_entrada_ministerio where perfil_id = '00000000-0000-0000-0000-000000001b02'),
          0::bigint, 'metadado "ministerios" que não é lista é ignorado (texto)');
select is((select count(*) from public.pedidos_entrada_ministerio where perfil_id = '00000000-0000-0000-0000-000000001b03'),
          0::bigint, 'metadado "ministerios" que não é lista é ignorado (objeto)');
select is((select count(*) from public.pedidos_entrada_ministerio where perfil_id = '00000000-0000-0000-0000-000000001b04'),
          0::bigint, 'sem ministérios marcados, nenhum pedido (cadastro sem escolha)');
select is((select count(*) from public.pedidos_entrada_ministerio where perfil_id = '00000000-0000-0000-0000-000000001b05'),
          2::bigint, 'repetidos e caixa alta contam uma vez: A e B');

-- Mudar os metadados DEPOIS do cadastro não cria pedidos (só o insert da conta conta).
update auth.users
   set raw_user_meta_data = '{"nome":"Cad Quatro","ministerios":["00000000-0000-0000-0000-000000001a0a"]}',
       email_confirmed_at = now()
 where id = '00000000-0000-0000-0000-000000001b04';
select is((select count(*) from public.pedidos_entrada_ministerio where perfil_id = '00000000-0000-0000-0000-000000001b04'),
          0::bigint, 'alterar metadados depois do cadastro não gera pedidos');

-- Teto técnico de 30 ministérios por cadastro
insert into public.ministerios (nome, descricao)
  select 'Teste Teto ' || n, '' from generate_series(1, 35) n;
insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role)
  select '00000000-0000-0000-0000-000000001b06', 'u6.c@exemplo.com', now(),
         jsonb_build_object('nome', 'Cad Seis',
                            'ministerios', (select jsonb_agg(id) from public.ministerios where nome like 'Teste Teto %')),
         'authenticated', 'authenticated';
select is((select count(*) from public.pedidos_entrada_ministerio where perfil_id = '00000000-0000-0000-0000-000000001b06'),
          30::bigint, 'um cadastro cria no máximo 30 pedidos');

-- ===== pedir_entrada_ministerio =====
insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role) values
  ('00000000-0000-0000-0000-000000001c01', 'pen.c@exemplo.com', now(), '{"nome":"Pendente C"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000001c02', 'mem.c@exemplo.com', now(), '{"nome":"Membro C"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000001c03', 'rec.c@exemplo.com', now(), '{"nome":"Recusado C"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000001c04', 'rem.c@exemplo.com', now(), '{"nome":"Removido C"}', 'authenticated', 'authenticated');
update public.perfis set situacao = 'aprovado' where id = '00000000-0000-0000-0000-000000001c02';
update public.perfis set situacao = 'recusado' where id = '00000000-0000-0000-0000-000000001c03';
update public.perfis set situacao = 'acesso_removido' where id = '00000000-0000-0000-0000-000000001c04';

-- Conta pendente (fluxo do Google): pede na tela de espera
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000001c01", "role": "authenticated"}', true);
set local role authenticated;
select lives_ok($$ select public.pedir_entrada_ministerio('00000000-0000-0000-0000-000000001a0a') $$,
                'conta pendente pede entrada em ministério');
select is((select count(*) from public.pedidos_entrada_ministerio where perfil_id = '00000000-0000-0000-0000-000000001c01'),
          1::bigint, 'a pessoa lê o próprio pedido');
select throws_ok($$ select public.pedir_entrada_ministerio('00000000-0000-0000-0000-000000001a0a') $$,
                 'P0001', 'pedido_duplicado', 'não duplica pedido pendente');
select throws_ok($$ select public.pedir_entrada_ministerio('00000000-0000-0000-0000-000000001a0c') $$,
                 'P0001', 'ministerio_inativo', 'não pede ministério desativado');
select throws_ok($$ select public.pedir_entrada_ministerio('99999999-9999-9999-9999-999999999999') $$,
                 'P0001', 'nao_encontrado', 'ministério inexistente');
reset role;
select is((select origem_cadastro from public.pedidos_entrada_ministerio where perfil_id = '00000000-0000-0000-0000-000000001c01'),
          true, 'pedido de conta pendente é marcado como vindo do cadastro');

-- Conta aprovada
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000001c02", "role": "authenticated"}', true);
set local role authenticated;
select lives_ok($$ select public.pedir_entrada_ministerio('00000000-0000-0000-0000-000000001a0b') $$,
                'conta aprovada pede entrada em ministério');
reset role;
select is((select origem_cadastro from public.pedidos_entrada_ministerio where perfil_id = '00000000-0000-0000-0000-000000001c02'),
          false, 'pedido de conta já aprovada não é "do cadastro"');
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel) values
  ('00000000-0000-0000-0000-000000001a0a', '00000000-0000-0000-0000-000000001c02', 'lider');
set local role authenticated;
select throws_ok($$ select public.pedir_entrada_ministerio('00000000-0000-0000-0000-000000001a0a') $$,
                 'P0001', 'ja_participa', 'quem já participa não pede de novo');
reset role;

-- Contas recusadas ou sem acesso não pedem
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000001c03", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.pedir_entrada_ministerio('00000000-0000-0000-0000-000000001a0a') $$,
                 'P0001', 'sem_permissao', 'conta recusada não pede');
reset role;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000001c04", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.pedir_entrada_ministerio('00000000-0000-0000-0000-000000001a0a') $$,
                 'P0001', 'sem_permissao', 'conta com acesso removido não pede');
reset role;

-- Sem login
set local role anon;
select throws_ok($$ select public.pedir_entrada_ministerio('00000000-0000-0000-0000-000000001a0a') $$,
                 '42501', null, 'visitante não executa pedir_entrada_ministerio');
reset role;

select * from finish();
rollback;
