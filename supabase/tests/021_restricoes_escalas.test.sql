-- T007: restrições de integridade das tabelas de escalas (data-model.md).
begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role) values
  ('00000000-0000-0000-0000-000000002101', 'lider.21@exemplo.com', now(), '{"nome":"Lider 21"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000002102', 'part.21@exemplo.com',  now(), '{"nome":"Part 21"}',  'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000002103', 'fora.21@exemplo.com',  now(), '{"nome":"Fora 21"}',  'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000002104', 'ind.21@exemplo.com',   now(), '{"nome":"Ind 21"}',   'authenticated', 'authenticated');
update public.perfis set situacao = 'aprovado' where id::text like '00000000-0000-0000-0000-0000000021%';

insert into public.ministerios (id, nome, descricao) values
  ('00000000-0000-0000-0000-00000021000a', 'Teste Escalas 21 A', ''),
  ('00000000-0000-0000-0000-00000021000b', 'Teste Escalas 21 B', '');
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel) values
  ('00000000-0000-0000-0000-00000021000a', '00000000-0000-0000-0000-000000002101', 'lider'),
  ('00000000-0000-0000-0000-00000021000a', '00000000-0000-0000-0000-000000002102', 'participante'),
  ('00000000-0000-0000-0000-00000021000a', '00000000-0000-0000-0000-000000002104', 'participante');

-- ===== Nome de função ativa único por ministério =====
insert into public.funcoes_ministerio (id, ministerio_id, nome) values
  ('00000000-0000-0000-0000-00000021f001', '00000000-0000-0000-0000-00000021000a', 'Vocal'),
  ('00000000-0000-0000-0000-00000021f002', '00000000-0000-0000-0000-00000021000a', 'Violão');
select throws_ok($$ insert into public.funcoes_ministerio (ministerio_id, nome) values ('00000000-0000-0000-0000-00000021000a', '  vocal ') $$,
                 '23505', null, 'nome repetido (caixa e espaços) entre funções ativas é recusado');
select throws_ok($$ insert into public.funcoes_ministerio (ministerio_id, nome) values ('00000000-0000-0000-0000-00000021000a', 'VIOLAO') $$,
                 '23505', null, 'nome repetido sem acento também é recusado');
select lives_ok($$ insert into public.funcoes_ministerio (ministerio_id, nome) values ('00000000-0000-0000-0000-00000021000b', 'Vocal') $$,
                'o mesmo nome em outro ministério é permitido');
update public.funcoes_ministerio set ativa = false, desativada_em = now() where id = '00000000-0000-0000-0000-00000021f001';
select lives_ok($$ insert into public.funcoes_ministerio (ministerio_id, nome) values ('00000000-0000-0000-0000-00000021000a', 'Vocal') $$,
                'o nome de uma função desativada pode ser reutilizado');
select throws_ok($$ insert into public.funcoes_ministerio (ministerio_id, nome) values ('00000000-0000-0000-0000-00000021000a', 'A') $$,
                 '23514', null, 'nome de função muito curto é recusado');

-- ===== Escala, vagas e pedidos =====
insert into public.escalas (id, ministerio_id, evento, data, horario) values
  ('00000000-0000-0000-0000-00000021e001', '00000000-0000-0000-0000-00000021000a', 'Culto', current_date + 5, '09:00'),
  ('00000000-0000-0000-0000-00000021e002', '00000000-0000-0000-0000-00000021000a', 'Outro culto', current_date + 6, '09:00');
select throws_ok($$ insert into public.vagas_escala (escala_id, funcao_id, perfil_id) values
                      ('00000000-0000-0000-0000-00000021e001', '00000000-0000-0000-0000-00000021f002', '00000000-0000-0000-0000-000000002103') $$,
                 'P0001', 'nao_participante', 'escalar quem não participa do ministério é recusado, mesmo por escrita direta');
insert into public.vagas_escala (id, escala_id, funcao_id, perfil_id) values
  ('00000000-0000-0000-0000-00000021a001', '00000000-0000-0000-0000-00000021e001', '00000000-0000-0000-0000-00000021f002', '00000000-0000-0000-0000-000000002102'),
  ('00000000-0000-0000-0000-00000021a002', '00000000-0000-0000-0000-00000021e001', '00000000-0000-0000-0000-00000021f002', null);

insert into public.pedidos_troca (id, vaga_id, escala_id, solicitante_id, indicada_id) values
  ('00000000-0000-0000-0000-00000021b001', '00000000-0000-0000-0000-00000021a001', '00000000-0000-0000-0000-00000021e001',
   '00000000-0000-0000-0000-000000002102', '00000000-0000-0000-0000-000000002104');
select throws_ok($$ insert into public.pedidos_troca (vaga_id, escala_id, solicitante_id, indicada_id) values
                      ('00000000-0000-0000-0000-00000021a001', '00000000-0000-0000-0000-00000021e001',
                       '00000000-0000-0000-0000-000000002102', '00000000-0000-0000-0000-000000002101') $$,
                 '23505', null, 'uma vaga não pode ter dois pedidos de troca pendentes');
update public.pedidos_troca set situacao = 'cancelado' where id = '00000000-0000-0000-0000-00000021b001';
select lives_ok($$ insert into public.pedidos_troca (vaga_id, escala_id, solicitante_id, indicada_id) values
                      ('00000000-0000-0000-0000-00000021a001', '00000000-0000-0000-0000-00000021e001',
                       '00000000-0000-0000-0000-000000002102', '00000000-0000-0000-0000-000000002101') $$,
                'depois de encerrado o primeiro, um novo pedido pode ser criado');
select throws_ok($$ insert into public.pedidos_troca (vaga_id, escala_id, solicitante_id, indicada_id) values
                      ('00000000-0000-0000-0000-00000021a002', '00000000-0000-0000-0000-00000021e002',
                       '00000000-0000-0000-0000-000000002102', '00000000-0000-0000-0000-000000002104') $$,
                 '23503', null, 'o pedido não pode apontar para uma escala diferente da escala da vaga');
select throws_ok($$ insert into public.pedidos_troca (vaga_id, escala_id, solicitante_id, indicada_id) values
                      ('00000000-0000-0000-0000-00000021a002', '00000000-0000-0000-0000-00000021e001',
                       '00000000-0000-0000-0000-000000002102', '00000000-0000-0000-0000-000000002102') $$,
                 '23514', null, 'não se indica a si mesma');

-- ===== Limites de tamanho =====
select throws_ok($$ insert into public.respostas_escala (escala_id, perfil_id, resposta, motivo) values
                      ('00000000-0000-0000-0000-00000021e001', '00000000-0000-0000-0000-000000002102', 'recusado', repeat('x', 201)) $$,
                 '23514', null, 'motivo de recusa tem no máximo 200 caracteres');

-- ===== Saída do ministério não atrapalha escala antiga =====
delete from public.participacoes_ministerio
 where ministerio_id = '00000000-0000-0000-0000-00000021000a' and perfil_id = '00000000-0000-0000-0000-000000002102';
select lives_ok($$ update public.vagas_escala set rotulo = 'Vocal 1' where id = '00000000-0000-0000-0000-00000021a001' $$,
                'editar o rótulo de vaga de quem já saiu do ministério não é barrado');

-- ===== Exclusão de conta (LGPD): aptidões, respostas e pedidos somem; a vaga fica em aberto =====
insert into public.aptidoes (funcao_id, perfil_id, tipo) values
  ('00000000-0000-0000-0000-00000021f002', '00000000-0000-0000-0000-000000002104', 'principal');
insert into public.respostas_escala (escala_id, perfil_id, resposta) values
  ('00000000-0000-0000-0000-00000021e001', '00000000-0000-0000-0000-000000002104', 'confirmado');
update public.vagas_escala set perfil_id = '00000000-0000-0000-0000-000000002104' where id = '00000000-0000-0000-0000-00000021a002';
delete from auth.users where id = '00000000-0000-0000-0000-000000002104';
select is((select perfil_id from public.vagas_escala where id = '00000000-0000-0000-0000-00000021a002'), null::uuid,
          'ao excluir a conta, a vaga dela fica em aberto');
select is((select count(*) from public.aptidoes where perfil_id = '00000000-0000-0000-0000-000000002104')
        + (select count(*) from public.respostas_escala where perfil_id = '00000000-0000-0000-0000-000000002104')
        + (select count(*) from public.pedidos_troca where indicada_id = '00000000-0000-0000-0000-000000002104'), 0::bigint,
          'ao excluir a conta, aptidões, respostas e pedidos dela somem');

select * from finish();
rollback;
