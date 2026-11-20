-- T005: todo ministério ATIVO tem pelo menos um líder válido (RF-012, RF-013, CS-006).
-- "Líder válido" = participação com papel líder E conta aprovada. Os gatilhos valem até para
-- alteração direta no banco, inclusive na exclusão de conta (cascata) e na remoção de acesso.
begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role) values
  ('00000000-0000-0000-0000-000000000c01', 'l1.l@exemplo.com', now(), '{"nome":"Lider Um"}',   'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000c02', 'l2.l@exemplo.com', now(), '{"nome":"Lider Dois"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000c03', 'p1.l@exemplo.com', now(), '{"nome":"Particip Um"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000c04', 'l4.l@exemplo.com', now(), '{"nome":"Lider Quatro"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000c05', 'l5.l@exemplo.com', now(), '{"nome":"Lider Cinco"}',  'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000c06', 'lb.l@exemplo.com', now(), '{"nome":"Lider B"}',      'authenticated', 'authenticated');
update public.perfis set situacao = 'aprovado' where id::text like '00000000-0000-0000-0000-000000000c0%';

insert into public.ministerios (id, nome, descricao, ativo) values
  ('00000000-0000-0000-0000-00000000cc0a', 'Teste Último Líder A', '', true),
  ('00000000-0000-0000-0000-00000000cc0b', 'Teste Último Líder B', '', false),
  ('00000000-0000-0000-0000-00000000cc0c', 'Teste Último Líder C', '', true);
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel) values
  ('00000000-0000-0000-0000-00000000cc0a', '00000000-0000-0000-0000-000000000c01', 'lider'),
  ('00000000-0000-0000-0000-00000000cc0a', '00000000-0000-0000-0000-000000000c03', 'participante'),
  ('00000000-0000-0000-0000-00000000cc0b', '00000000-0000-0000-0000-000000000c06', 'lider'),
  ('00000000-0000-0000-0000-00000000cc0c', '00000000-0000-0000-0000-000000000c04', 'lider'),
  ('00000000-0000-0000-0000-00000000cc0c', '00000000-0000-0000-0000-000000000c05', 'lider');

-- ===== Ministério A: um único líder (c01) =====
select throws_ok($$ update public.participacoes_ministerio set papel = 'participante'
                     where ministerio_id = '00000000-0000-0000-0000-00000000cc0a'
                       and perfil_id = '00000000-0000-0000-0000-000000000c01' $$,
                 'P0001', 'ultimo_lider', 'não rebaixa o único líder');
select throws_ok($$ delete from public.participacoes_ministerio
                     where ministerio_id = '00000000-0000-0000-0000-00000000cc0a'
                       and perfil_id = '00000000-0000-0000-0000-000000000c01' $$,
                 'P0001', 'ultimo_lider', 'não remove a participação do único líder');
select throws_ok($$ delete from auth.users where id = '00000000-0000-0000-0000-000000000c01' $$,
                 'P0001', 'ultimo_lider', 'excluir a conta do único líder é barrado (cascata)');
select throws_ok($$ update public.perfis set situacao = 'acesso_removido'
                     where id = '00000000-0000-0000-0000-000000000c01' $$,
                 'P0001', 'ultimo_lider', 'remover o acesso do único líder é barrado');
select throws_ok($$ update public.perfis set situacao = 'recusado'
                     where id = '00000000-0000-0000-0000-000000000c01' $$,
                 'P0001', 'ultimo_lider', 'recusar a conta do único líder também é barrado');

-- Remover quem não é líder continua livre.
select lives_ok($$ delete from public.participacoes_ministerio
                    where ministerio_id = '00000000-0000-0000-0000-00000000cc0a'
                      and perfil_id = '00000000-0000-0000-0000-000000000c03' $$,
                'remover um participante comum é permitido');

-- Com um segundo líder, o primeiro pode sair; o que sobra fica protegido.
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel) values
  ('00000000-0000-0000-0000-00000000cc0a', '00000000-0000-0000-0000-000000000c02', 'lider');
select lives_ok($$ update public.participacoes_ministerio set papel = 'participante'
                    where ministerio_id = '00000000-0000-0000-0000-00000000cc0a'
                      and perfil_id = '00000000-0000-0000-0000-000000000c01' $$,
                'com dois líderes, um pode ser rebaixado');
select throws_ok($$ update public.participacoes_ministerio set papel = 'participante'
                     where ministerio_id = '00000000-0000-0000-0000-00000000cc0a'
                       and perfil_id = '00000000-0000-0000-0000-000000000c02' $$,
                 'P0001', 'ultimo_lider', 'o que sobrou virou o último e fica protegido');

-- ===== Ministério B (desativado): não exige líder =====
select lives_ok($$ delete from public.participacoes_ministerio
                    where ministerio_id = '00000000-0000-0000-0000-00000000cc0b'
                      and perfil_id = '00000000-0000-0000-0000-000000000c06' $$,
                'ministério desativado pode ficar sem líder (é só histórico)');

-- ===== Ministério C: líder com conta não aprovada não conta =====
select lives_ok($$ update public.perfis set situacao = 'acesso_removido'
                    where id = '00000000-0000-0000-0000-000000000c05' $$,
                'um dos dois líderes perde o acesso (o outro continua válido)');
select throws_ok($$ update public.participacoes_ministerio set papel = 'participante'
                     where ministerio_id = '00000000-0000-0000-0000-00000000cc0c'
                       and perfil_id = '00000000-0000-0000-0000-000000000c04' $$,
                 'P0001', 'ultimo_lider', 'líder sem conta aprovada não conta como líder válido');

-- ===== Mudanças que não afetam a liderança seguem livres =====
select lives_ok($$ update public.perfis set nome = 'Lider Quatro Editado'
                    where id = '00000000-0000-0000-0000-000000000c04' $$,
                'editar o nome de um líder é permitido');
select lives_ok($$ update public.perfis set situacao = 'aprovado'
                    where id = '00000000-0000-0000-0000-000000000c05' $$,
                'reaprovar a conta é permitido');

select * from finish();
rollback;
