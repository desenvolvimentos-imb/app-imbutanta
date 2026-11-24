-- T050: preencher_disponibilidade (líder). Relógio: 10/12/2026.
begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

create or replace function public.agora_sp() returns timestamptz language sql stable as
  $$ select '2026-12-10 12:00:00+00'::timestamptz $$;

-- 5201 líder A, 5202 P1, 5203 estranho, 5204 líder B, 5205 adm
insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role)
select ('00000000-0000-0000-0000-0000000052' || lpad(n::text, 2, '0'))::uuid, 'u' || n || '.52@exemplo.com', now(),
       jsonb_build_object('nome', 'Pessoa 52 ' || n), 'authenticated', 'authenticated'
  from unnest(array[1, 2, 3, 4, 5]) as n;
update public.perfis set situacao = 'aprovado' where id::text like '00000000-0000-0000-0000-0000000052%';
update public.perfis set papel = 'administrador' where id = '00000000-0000-0000-0000-000000005205';
insert into public.ministerios (id, nome, descricao) values
  ('00000000-0000-0000-0000-00000052000a', 'Teste Preencher 52 A', ''),
  ('00000000-0000-0000-0000-00000052000b', 'Teste Preencher 52 B', '');
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel) values
  ('00000000-0000-0000-0000-00000052000a', '00000000-0000-0000-0000-000000005201', 'lider'),
  ('00000000-0000-0000-0000-00000052000a', '00000000-0000-0000-0000-000000005202', 'participante'),
  ('00000000-0000-0000-0000-00000052000b', '00000000-0000-0000-0000-000000005204', 'lider');
insert into public.consultas_disponibilidade (id, ministerio_id, titulo, prazo, fechada) values
  ('00000000-0000-0000-0000-00000052c001', '00000000-0000-0000-0000-00000052000a', 'Aberta', null, false),
  ('00000000-0000-0000-0000-00000052c002', '00000000-0000-0000-0000-00000052000a', 'Fechada', null, true),
  ('00000000-0000-0000-0000-00000052c003', '00000000-0000-0000-0000-00000052000a', 'Prazo vencido', '2026-12-01', false),
  ('00000000-0000-0000-0000-00000052c00b', '00000000-0000-0000-0000-00000052000b', 'Do B', null, false);
insert into public.datas_consulta (id, consulta_id, ministerio_id, data) values
  ('00000000-0000-0000-0000-00000052d001', '00000000-0000-0000-0000-00000052c001', '00000000-0000-0000-0000-00000052000a', '2026-12-13'),
  ('00000000-0000-0000-0000-00000052d002', '00000000-0000-0000-0000-00000052c001', '00000000-0000-0000-0000-00000052000a', '2026-12-06'),
  ('00000000-0000-0000-0000-00000052d003', '00000000-0000-0000-0000-00000052c002', '00000000-0000-0000-0000-00000052000a', '2026-12-20'),
  ('00000000-0000-0000-0000-00000052d004', '00000000-0000-0000-0000-00000052c003', '00000000-0000-0000-0000-00000052000a', '2026-12-27'),
  ('00000000-0000-0000-0000-00000052d00b', '00000000-0000-0000-0000-00000052c00b', '00000000-0000-0000-0000-00000052000b', '2026-12-13');
insert into public.observacoes_disponibilidade (consulta_id, perfil_id, texto) values
  ('00000000-0000-0000-0000-00000052c001', '00000000-0000-0000-0000-000000005202', 'Minha observação');

select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000005201", "role": "authenticated"}', true);
set local role authenticated;
select lives_ok($$ select public.preencher_disponibilidade('00000000-0000-0000-0000-00000052c001', '00000000-0000-0000-0000-000000005202',
  '[{"data_id":"00000000-0000-0000-0000-00000052d001","resposta":"disponivel"},{"data_id":"00000000-0000-0000-0000-00000052d002","resposta":"indisponivel"}]') $$,
  'líder preenche (inclui data que já passou, 06/12)');
reset role;
select is((select preenchida_por from public.respostas_disponibilidade where data_id = '00000000-0000-0000-0000-00000052d001' and perfil_id = '00000000-0000-0000-0000-000000005202'),
          '00000000-0000-0000-0000-000000005201'::uuid, 'grava quem preencheu');
select is((select texto from public.observacoes_disponibilidade where perfil_id = '00000000-0000-0000-0000-000000005202'), 'Minha observação', 'não mexe na observação da pessoa');
set local role authenticated;
select lives_ok($$ select public.preencher_disponibilidade('00000000-0000-0000-0000-00000052c002', '00000000-0000-0000-0000-000000005202', '[{"data_id":"00000000-0000-0000-0000-00000052d003","resposta":"disponivel"}]') $$, 'em consulta fechada pelo líder');
select lives_ok($$ select public.preencher_disponibilidade('00000000-0000-0000-0000-00000052c003', '00000000-0000-0000-0000-000000005202', '[{"data_id":"00000000-0000-0000-0000-00000052d004","resposta":"indisponivel"}]') $$, 'em consulta com prazo vencido');
select lives_ok($$ select public.preencher_disponibilidade('00000000-0000-0000-0000-00000052c001', '00000000-0000-0000-0000-000000005202', '[{"data_id":"00000000-0000-0000-0000-00000052d002","resposta":null}]') $$, 'o líder também pode limpar uma data');
select throws_ok($$ select public.preencher_disponibilidade('00000000-0000-0000-0000-00000052c001', '00000000-0000-0000-0000-000000005203', '[]') $$, 'P0001', 'nao_participante', 'pessoa que não participa do ministério');
select throws_ok($$ select public.preencher_disponibilidade('00000000-0000-0000-0000-00000052c001', '00000000-0000-0000-0000-000000005202', '[{"data_id":"00000000-0000-0000-0000-00000052d00b","resposta":"disponivel"}]') $$, 'P0001', 'resposta_invalida', 'data de outra consulta');
reset role;
select is((select count(*) from public.respostas_disponibilidade where data_id = '00000000-0000-0000-0000-00000052d00b'), 0::bigint, 'nada gravado na data inválida');

-- A própria pessoa altera depois: o marcador some
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000005202", "role": "authenticated"}', true);
set local role authenticated;
select lives_ok($$ select public.responder_disponibilidade('00000000-0000-0000-0000-00000052c001', '[{"data_id":"00000000-0000-0000-0000-00000052d001","resposta":"indisponivel"}]') $$, 'a pessoa altera depois');
reset role;
select is((select preenchida_por from public.respostas_disponibilidade where data_id = '00000000-0000-0000-0000-00000052d001' and perfil_id = '00000000-0000-0000-0000-000000005202'), null::uuid, 'marcador "preenchido pelo líder" some');

-- Permissões
set local role authenticated;
select throws_ok($$ select public.preencher_disponibilidade('00000000-0000-0000-0000-00000052c001', '00000000-0000-0000-0000-000000005202', '[]') $$, 'P0001', 'sem_permissao', 'participante comum não preenche');
reset role;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000005204", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.preencher_disponibilidade('00000000-0000-0000-0000-00000052c001', '00000000-0000-0000-0000-000000005202', '[]') $$, 'P0001', 'sem_permissao', 'líder de outro ministério não preenche');
reset role;
update public.ministerios set ativo = false where id = '00000000-0000-0000-0000-00000052000a';
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000005205", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.preencher_disponibilidade('00000000-0000-0000-0000-00000052c001', '00000000-0000-0000-0000-000000005202', '[]') $$, 'P0001', 'ministerio_inativo', 'ministério desativado');
reset role;

-- Salvar a tela inteira sem mudar uma data NÃO apaga a marca dela (quem alterou por último fica marcado)
update public.respostas_disponibilidade set preenchida_por = '00000000-0000-0000-0000-000000005201'
 where data_id = '00000000-0000-0000-0000-00000052d001' and perfil_id = '00000000-0000-0000-0000-000000005202';
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000005202", "role": "authenticated"}', true);
set local role authenticated;
select lives_ok($$ select public.responder_disponibilidade('00000000-0000-0000-0000-00000052c001', '[{"data_id":"00000000-0000-0000-0000-00000052d001","resposta":"indisponivel"}]') $$, 'a pessoa salva a mesma resposta de novo');
reset role;
select is((select preenchida_por from public.respostas_disponibilidade where data_id = '00000000-0000-0000-0000-00000052d001' and perfil_id = '00000000-0000-0000-0000-000000005202'),
          '00000000-0000-0000-0000-000000005201'::uuid, 'resposta repetida mantém a marca do líder; só muda quando a resposta muda');

select * from finish();
rollback;
