-- T061: gestão de usuários pelo administrador (RF-021, RF-022).
begin;
create extension if not exists pgtap with schema extensions;
select plan(24);

insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role) values
  ('00000000-0000-0000-0000-000000000b01', 'adm.g@exemplo.com', now(), '{"nome":"Adm G"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000b02', 'lid.g@exemplo.com', now(), '{"nome":"Lid G"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000b03', 'mem.g@exemplo.com', now(), '{"nome":"Mem G"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000b04', 'rec.g@exemplo.com', now(), '{"nome":"Rec G"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000b05', 'rem.g@exemplo.com', now(), '{"nome":"Rem G"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000b06', 'pen.g@exemplo.com', now(), '{"nome":"Pen G"}', 'authenticated', 'authenticated');
update public.perfis set situacao = 'aprovado', papel = 'administrador' where id = '00000000-0000-0000-0000-000000000b01';
update public.perfis set situacao = 'aprovado', papel = 'lider'         where id = '00000000-0000-0000-0000-000000000b02';
update public.perfis set situacao = 'aprovado', papel = 'membro'        where id = '00000000-0000-0000-0000-000000000b03';
update public.perfis set situacao = 'recusado'                          where id = '00000000-0000-0000-0000-000000000b04';
update public.perfis set situacao = 'acesso_removido', papel = 'lider'  where id = '00000000-0000-0000-0000-000000000b05';

-- O seed local tem outro administrador. Para o b01 ser o ÚNICO, desligamos o gatilho só para
-- rebaixar os demais (tudo é desfeito pelo rollback no fim).
alter table public.perfis disable trigger trg_proteger_ultimo_administrador;
update public.perfis set papel = 'membro'
 where papel = 'administrador' and id <> '00000000-0000-0000-0000-000000000b01';
alter table public.perfis enable trigger trg_proteger_ultimo_administrador;

-- ===== Quem não é administrador não gerencia =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000b02", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.alterar_papel('00000000-0000-0000-0000-000000000b03', 'lider', 'aprovado') $$,
                 'P0001', 'sem_permissao', 'líder não altera papéis');
select throws_ok($$ select public.alterar_situacao('00000000-0000-0000-0000-000000000b03', 'acesso_removido', 'aprovado') $$,
                 'P0001', 'sem_permissao', 'líder não remove acesso');
reset role;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000b03", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.alterar_papel('00000000-0000-0000-0000-000000000b03', 'administrador', 'aprovado') $$,
                 'P0001', 'sem_permissao', 'membro não se promove');
reset role;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000b06", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.alterar_papel('00000000-0000-0000-0000-000000000b06', 'administrador', 'aprovado') $$,
                 'P0001', 'sem_permissao', 'pendente não se promove');
reset role;
set local role anon;
select throws_ok($$ select public.alterar_papel('00000000-0000-0000-0000-000000000b03', 'lider', 'aprovado') $$,
                 '42501', null, 'anônimo não executa alterar_papel');
select throws_ok($$ select public.alterar_situacao('00000000-0000-0000-0000-000000000b03', 'acesso_removido', 'aprovado') $$,
                 '42501', null, 'anônimo não executa alterar_situacao');
reset role;

-- ===== Administrador =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000b01", "role": "authenticated"}', true);
set local role authenticated;

select lives_ok($$ select public.alterar_papel('00000000-0000-0000-0000-000000000b03', 'lider', 'aprovado') $$,
                'administrador promove membro a líder');
select is((select papel::text from public.perfis where id = '00000000-0000-0000-0000-000000000b03'),
          'lider', 'o papel foi alterado');
select throws_ok($$ select public.alterar_papel('00000000-0000-0000-0000-000000000b03', 'membro', 'pendente') $$,
                 'P0001', 'transicao_invalida', 'só altera papel de pessoa aprovada (esperada precisa ser aprovado)');
select throws_ok($$ select public.alterar_papel('00000000-0000-0000-0000-000000000b06', 'lider', 'aprovado') $$,
                 'P0001', 'conflito_situacao', 'pendente não recebe papel por aqui (situação difere da esperada)');
select throws_ok($$ select public.alterar_papel('99999999-9999-9999-9999-999999999999', 'lider', 'aprovado') $$,
                 'P0001', 'nao_encontrado', 'pessoa inexistente');

-- Último administrador
select throws_ok($$ select public.alterar_papel('00000000-0000-0000-0000-000000000b01', 'membro', 'aprovado') $$,
                 'P0001', 'ultimo_administrador', 'não rebaixa a si mesmo sendo o único administrador');
select throws_ok($$ select public.alterar_situacao('00000000-0000-0000-0000-000000000b01', 'acesso_removido', 'aprovado') $$,
                 'P0001', 'ultimo_administrador', 'não remove o próprio acesso sendo o único administrador');

-- Situação
select lives_ok($$ select public.alterar_situacao('00000000-0000-0000-0000-000000000b03', 'acesso_removido', 'aprovado') $$,
                'administrador remove o acesso de alguém');
select is((select situacao::text from public.perfis where id = '00000000-0000-0000-0000-000000000b03'),
          'acesso_removido', 'acesso removido');
select lives_ok($$ select public.alterar_situacao('00000000-0000-0000-0000-000000000b03', 'aprovado', 'acesso_removido') $$,
                'administrador restaura o acesso');
select is((select papel::text from public.perfis where id = '00000000-0000-0000-0000-000000000b03'),
          'membro', 'quem volta de acesso removido retorna como membro');
select lives_ok($$ select public.alterar_situacao('00000000-0000-0000-0000-000000000b04', 'aprovado', 'recusado') $$,
                'administrador reabre (reaprova) um cadastro recusado');
select is((select papel::text from public.perfis where id = '00000000-0000-0000-0000-000000000b04'),
          'membro', 'reaprovado entra como membro');
select throws_ok($$ select public.alterar_situacao('00000000-0000-0000-0000-000000000b06', 'aprovado', 'pendente') $$,
                 'P0001', 'transicao_invalida', 'pendente é decidido pela fila (decidir_cadastro), não aqui');
select throws_ok($$ select public.alterar_situacao('00000000-0000-0000-0000-000000000b02', 'recusado', 'aprovado') $$,
                 'P0001', 'transicao_invalida', 'aprovado não vira recusado');
select throws_ok($$ select public.alterar_situacao('00000000-0000-0000-0000-000000000b05', 'aprovado', 'recusado') $$,
                 'P0001', 'conflito_situacao', 'situação diferente da esperada gera conflito');

-- Com outro administrador, o primeiro pode sair.
select lives_ok($$ select public.alterar_papel('00000000-0000-0000-0000-000000000b02', 'administrador', 'aprovado') $$,
                'promove um segundo administrador');
select lives_ok($$ select public.alterar_papel('00000000-0000-0000-0000-000000000b01', 'membro', 'aprovado') $$,
                'com outro administrador, o primeiro pode se rebaixar');
reset role;

select * from finish();
rollback;
