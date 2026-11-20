-- T033: gerir participantes e líderes de um ministério (RF-009 a RF-014).
begin;
create extension if not exists pgtap with schema extensions;
select plan(37);

insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role) values
  ('00000000-0000-0000-0000-000000000f01', 'adm.f1@exemplo.com', now(), '{"nome":"Adm F1"}',  'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000f02', 'l1.f1@exemplo.com',  now(), '{"nome":"Lider F1"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000f03', 'l2.f1@exemplo.com',  now(), '{"nome":"Lider F2"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000f04', 'm1.f1@exemplo.com',  now(), '{"nome":"Membro F1"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000f05', 'm2.f1@exemplo.com',  now(), '{"nome":"Membro F2"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000f06', 'pen.f1@exemplo.com', now(), '{"nome":"Pendente F"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000f07', 'rec.f1@exemplo.com', now(), '{"nome":"Recusada F"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000f08', 'z1.f1@exemplo.com',  now(), '{"nome":"Zélia Busquei"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000f09', 'z2.f1@exemplo.com',  now(), '{"nome":"Zélia Maria Busquei"}', 'authenticated', 'authenticated');
update public.perfis set situacao = 'aprovado', papel = 'administrador' where id = '00000000-0000-0000-0000-000000000f01';
update public.perfis set situacao = 'aprovado' where id::text between '00000000-0000-0000-0000-000000000f02' and '00000000-0000-0000-0000-000000000f05';
update public.perfis set situacao = 'recusado' where id = '00000000-0000-0000-0000-000000000f07';
update public.perfis set situacao = 'aprovado' where id in
  ('00000000-0000-0000-0000-000000000f08', '00000000-0000-0000-0000-000000000f09');

insert into public.ministerios (id, nome, descricao, ativo, desativado_em) values
  ('00000000-0000-0000-0000-00000000ff0a', 'Teste Participantes A', '', true,  null),
  ('00000000-0000-0000-0000-00000000ff0b', 'Teste Participantes B', '', true,  null),
  ('00000000-0000-0000-0000-00000000ff0c', 'Teste Participantes Inativo', '', false, now());
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel) values
  ('00000000-0000-0000-0000-00000000ff0a', '00000000-0000-0000-0000-000000000f02', 'lider'),
  ('00000000-0000-0000-0000-00000000ff0b', '00000000-0000-0000-0000-000000000f03', 'lider'),
  ('00000000-0000-0000-0000-00000000ff0c', '00000000-0000-0000-0000-000000000f03', 'lider');

-- ===== Líder do ministério A (f02) gerencia A =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000f02", "role": "authenticated"}', true);
set local role authenticated;

select lives_ok($$ select public.adicionar_participante('00000000-0000-0000-0000-00000000ff0a', '00000000-0000-0000-0000-000000000f04', 'participante') $$,
                'líder adiciona uma pessoa como participante do próprio ministério');
select throws_ok($$ select public.adicionar_participante('00000000-0000-0000-0000-00000000ff0a', '00000000-0000-0000-0000-000000000f04', 'participante') $$,
                 'P0001', 'ja_participa', 'adicionar quem já participa');
select throws_ok($$ select public.adicionar_participante('00000000-0000-0000-0000-00000000ff0a', '00000000-0000-0000-0000-000000000f06', 'participante') $$,
                 'P0001', 'pessoa_invalida', 'conta pendente não é adicionada diretamente');
select throws_ok($$ select public.adicionar_participante('00000000-0000-0000-0000-00000000ff0a', '00000000-0000-0000-0000-000000000f07', 'participante') $$,
                 'P0001', 'pessoa_invalida', 'conta recusada não é adicionada');
select throws_ok($$ select public.adicionar_participante('00000000-0000-0000-0000-00000000ff0a', '99999999-9999-9999-9999-999999999999', 'participante') $$,
                 'P0001', 'pessoa_invalida', 'pessoa inexistente');
select throws_ok($$ select public.adicionar_participante('00000000-0000-0000-0000-00000000ff0a', '00000000-0000-0000-0000-000000000f05', null) $$,
                 'P0001', 'transicao_invalida', 'papel obrigatório');
select throws_ok($$ select public.adicionar_participante('00000000-0000-0000-0000-00000000ff0b', '00000000-0000-0000-0000-000000000f05', 'participante') $$,
                 'P0001', 'sem_permissao', 'líder do A NÃO gerencia o ministério B');
select throws_ok($$ select public.alterar_papel_ministerio('00000000-0000-0000-0000-00000000ff0b', '00000000-0000-0000-0000-000000000f03', 'participante') $$,
                 'P0001', 'sem_permissao', 'líder do A não altera papéis no B');
select throws_ok($$ select public.remover_participante('00000000-0000-0000-0000-00000000ff0b', '00000000-0000-0000-0000-000000000f03') $$,
                 'P0001', 'sem_permissao', 'líder do A não remove ninguém do B');
select throws_ok($$ select public.adicionar_participante('99999999-9999-9999-9999-999999999999', '00000000-0000-0000-0000-000000000f05', 'participante') $$,
                 'P0001', 'sem_permissao', 'ministério inexistente não é revelado a quem não é administrador');

-- Busca de pessoas para adicionar: só nome, sem acento, mínimo de 2 letras
select is((select count(*) from public.buscar_pessoas('00000000-0000-0000-0000-00000000ff0a', 'zelia')),
          2::bigint, 'busca por nome ignora acento e caixa');
select is((select count(*) from public.buscar_pessoas('00000000-0000-0000-0000-00000000ff0a', 'z')),
          0::bigint, 'busca com menos de 2 letras devolve nada');
select is((select count(*) from public.buscar_pessoas('00000000-0000-0000-0000-00000000ff0a', 'pendente f')),
          0::bigint, 'a busca só lista contas aprovadas');
select is((select count(*) from public.buscar_pessoas('00000000-0000-0000-0000-00000000ff0a', 'membro f1')),
          0::bigint, 'a busca não lista quem já participa do ministério');
select throws_ok($$ select * from public.buscar_pessoas('00000000-0000-0000-0000-00000000ff0b', 'zelia') $$,
                 'P0001', 'sem_permissao', 'líder do A não busca pessoas para o B');

-- Promover e rebaixar valem só neste ministério (RF-010)
select lives_ok($$ select public.alterar_papel_ministerio('00000000-0000-0000-0000-00000000ff0a', '00000000-0000-0000-0000-000000000f04', 'lider') $$,
                'líder promove um participante a líder');
select lives_ok($$ select public.alterar_papel_ministerio('00000000-0000-0000-0000-00000000ff0a', '00000000-0000-0000-0000-000000000f02', 'participante') $$,
                'com outro líder, o primeiro pode ser rebaixado');
select throws_ok($$ select public.alterar_papel_ministerio('00000000-0000-0000-0000-00000000ff0a', '00000000-0000-0000-0000-000000000f05', 'lider') $$,
                 'P0001', 'sem_permissao', 'quem foi rebaixado deixa de poder gerenciar o ministério');
reset role;

select is((select papel::text from public.participacoes_ministerio where ministerio_id = '00000000-0000-0000-0000-00000000ff0a'
            and perfil_id = '00000000-0000-0000-0000-000000000f04'), 'lider', 'm1 é líder do A');
select is((select count(*) from public.participacoes_ministerio where ministerio_id = '00000000-0000-0000-0000-00000000ff0b'
            and perfil_id = '00000000-0000-0000-0000-000000000f04'), 0::bigint, 'e continua sem vínculo com o B');

-- ===== m1 (agora líder do A) é o ÚNICO líder: não pode sair nem ser rebaixado =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000f04", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.alterar_papel_ministerio('00000000-0000-0000-0000-00000000ff0a', '00000000-0000-0000-0000-000000000f04', 'participante') $$,
                 'P0001', 'ultimo_lider', 'não rebaixa o último líder');
select throws_ok($$ select public.remover_participante('00000000-0000-0000-0000-00000000ff0a', '00000000-0000-0000-0000-000000000f04') $$,
                 'P0001', 'ultimo_lider', 'não remove o último líder');
select throws_ok($$ select public.remover_participante('00000000-0000-0000-0000-00000000ff0a', '00000000-0000-0000-0000-000000000f05') $$,
                 'P0001', 'nao_encontrado', 'remover quem não participa');
select lives_ok($$ select public.remover_participante('00000000-0000-0000-0000-00000000ff0a', '00000000-0000-0000-0000-000000000f02') $$,
                'remover um participante comum');

-- Pedido pendente vira aceito quando o líder adiciona a pessoa diretamente
reset role;
insert into public.pedidos_entrada_ministerio (ministerio_id, perfil_id) values
  ('00000000-0000-0000-0000-00000000ff0a', '00000000-0000-0000-0000-000000000f05');
set local role authenticated;
select lives_ok($$ select public.adicionar_participante('00000000-0000-0000-0000-00000000ff0a', '00000000-0000-0000-0000-000000000f05', 'participante') $$,
                'líder adiciona quem tinha pedido pendente');
reset role;
select is((select situacao::text from public.pedidos_entrada_ministerio where ministerio_id = '00000000-0000-0000-0000-00000000ff0a'
            and perfil_id = '00000000-0000-0000-0000-000000000f05'), 'aceito', 'o pedido pendente foi marcado como aceito');

-- ===== Participante comum não gerencia =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000f05", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.adicionar_participante('00000000-0000-0000-0000-00000000ff0a', '00000000-0000-0000-0000-000000000f08', 'participante') $$,
                 'P0001', 'sem_permissao', 'participante comum não adiciona ninguém');
select throws_ok($$ select * from public.buscar_pessoas('00000000-0000-0000-0000-00000000ff0a', 'zelia') $$,
                 'P0001', 'sem_permissao', 'participante comum não busca pessoas');
reset role;

-- ===== Administrador gerencia qualquer ministério =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000f01", "role": "authenticated"}', true);
set local role authenticated;
select lives_ok($$ select public.adicionar_participante('00000000-0000-0000-0000-00000000ff0b', '00000000-0000-0000-0000-000000000f05', 'participante') $$,
                'administrador adiciona em qualquer ministério');
select lives_ok($$ select public.remover_participante('00000000-0000-0000-0000-00000000ff0b', '00000000-0000-0000-0000-000000000f05') $$,
                'administrador remove de qualquer ministério');
select throws_ok($$ select public.adicionar_participante('00000000-0000-0000-0000-00000000ff0c', '00000000-0000-0000-0000-000000000f05', 'participante') $$,
                 'P0001', 'ministerio_inativo', 'ministério desativado não recebe participantes');
select throws_ok($$ select public.adicionar_participante('99999999-9999-9999-9999-999999999999', '00000000-0000-0000-0000-000000000f05', 'participante') $$,
                 'P0001', 'nao_encontrado', 'administrador é avisado de que o ministério não existe');
reset role;
select is((select count(*) from public.participacoes_ministerio where ministerio_id = '00000000-0000-0000-0000-00000000ff0a'
            and perfil_id = '00000000-0000-0000-0000-000000000f05'), 1::bigint,
          'remover do B não tirou a pessoa do A (vínculos independentes)');

-- ===== Líder de ministério desativado não gerencia =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000f03", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.adicionar_participante('00000000-0000-0000-0000-00000000ff0c', '00000000-0000-0000-0000-000000000f05', 'participante') $$,
                 'P0001', 'sem_permissao', 'líder de ministério desativado não gerencia');
reset role;

-- ===== Conta pendente ou recusada (sem acesso aprovado) não gerencia nada =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000f06", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.adicionar_participante('00000000-0000-0000-0000-00000000ff0a', '00000000-0000-0000-0000-000000000f05', 'participante') $$,
                 'P0001', 'sem_permissao', 'conta pendente não adiciona participantes');
reset role;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000f07", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.remover_participante('00000000-0000-0000-0000-00000000ff0a', '00000000-0000-0000-0000-000000000f05') $$,
                 'P0001', 'sem_permissao', 'conta recusada não remove participantes');
reset role;

-- ===== Visitante =====
set local role anon;
select throws_ok($$ select public.adicionar_participante('00000000-0000-0000-0000-00000000ff0a', '00000000-0000-0000-0000-000000000f05', 'participante') $$,
                 '42501', null, 'visitante não executa adicionar_participante');
reset role;

select * from finish();
rollback;
