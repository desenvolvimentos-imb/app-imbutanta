-- T049: quem vê as respostas e os motivos de recusa (FR-022 a FR-024). Relógio: 10/12/2026.
begin;
create extension if not exists pgtap with schema extensions;
select plan(19);

create or replace function public.agora_sp() returns timestamptz language sql stable as
  $$ select '2026-12-10 12:00:00+00'::timestamptz $$;

insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role)
select ('00000000-0000-0000-0000-0000000032' || lpad(n::text, 2, '0'))::uuid, 'u' || n || '.32@exemplo.com', now(),
       jsonb_build_object('nome', 'Pessoa 32 ' || n), 'authenticated', 'authenticated'
  from unnest(array[1, 2, 3, 11, 12, 13, 14, 20]) as n;
update public.perfis set situacao = 'aprovado' where id::text like '00000000-0000-0000-0000-0000000032%';
update public.perfis set papel = 'administrador' where id = '00000000-0000-0000-0000-000000003201';
insert into public.ministerios (id, nome, descricao) values
  ('00000000-0000-0000-0000-00000032000a', 'Teste Visib 32 A', ''),
  ('00000000-0000-0000-0000-00000032000b', 'Teste Visib 32 B', '');
-- Líder A: 3202. Líder B: 3203. Participantes do A: 3211, 3212, 3213 (3214 saiu do A depois)
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel) values
  ('00000000-0000-0000-0000-00000032000a', '00000000-0000-0000-0000-000000003202', 'lider'),
  ('00000000-0000-0000-0000-00000032000b', '00000000-0000-0000-0000-000000003203', 'lider'),
  ('00000000-0000-0000-0000-00000032000a', '00000000-0000-0000-0000-000000003211', 'participante'),
  ('00000000-0000-0000-0000-00000032000a', '00000000-0000-0000-0000-000000003212', 'participante'),
  ('00000000-0000-0000-0000-00000032000a', '00000000-0000-0000-0000-000000003213', 'participante');
insert into public.funcoes_ministerio (id, ministerio_id, nome) values
  ('00000000-0000-0000-0000-00000032f001', '00000000-0000-0000-0000-00000032000a', 'Vocal');
insert into public.escalas (id, ministerio_id, evento, data, horario, situacao) values
  ('00000000-0000-0000-0000-00000032e001', '00000000-0000-0000-0000-00000032000a', 'Publicada', '2026-12-15', '09:00', 'publicada'),
  ('00000000-0000-0000-0000-00000032e002', '00000000-0000-0000-0000-00000032000a', 'Rascunho', '2026-12-16', '09:00', 'rascunho'),
  ('00000000-0000-0000-0000-00000032e003', '00000000-0000-0000-0000-00000032000a', 'Cancelada', '2026-12-17', '09:00', 'cancelada');
-- Publicada: P1 (confirmou), P2 (recusou com motivo), P3 (sem resposta), uma vaga em aberto
-- 3214 participava do A, foi escalado numa escala (que depois foi cancelada) e saiu do ministério.
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel) values
  ('00000000-0000-0000-0000-00000032000a', '00000000-0000-0000-0000-000000003214', 'participante');
insert into public.vagas_escala (id, escala_id, funcao_id, perfil_id, ordem) values
  ('00000000-0000-0000-0000-00000032a001', '00000000-0000-0000-0000-00000032e001', '00000000-0000-0000-0000-00000032f001', '00000000-0000-0000-0000-000000003211', 1),
  ('00000000-0000-0000-0000-00000032a002', '00000000-0000-0000-0000-00000032e001', '00000000-0000-0000-0000-00000032f001', '00000000-0000-0000-0000-000000003212', 2),
  ('00000000-0000-0000-0000-00000032a003', '00000000-0000-0000-0000-00000032e001', '00000000-0000-0000-0000-00000032f001', '00000000-0000-0000-0000-000000003213', 3),
  ('00000000-0000-0000-0000-00000032a004', '00000000-0000-0000-0000-00000032e001', '00000000-0000-0000-0000-00000032f001', null, 4),
  ('00000000-0000-0000-0000-00000032a005', '00000000-0000-0000-0000-00000032e002', '00000000-0000-0000-0000-00000032f001', '00000000-0000-0000-0000-000000003211', 1),
  ('00000000-0000-0000-0000-00000032a006', '00000000-0000-0000-0000-00000032e003', '00000000-0000-0000-0000-00000032f001', '00000000-0000-0000-0000-000000003214', 1);
delete from public.participacoes_ministerio
 where ministerio_id = '00000000-0000-0000-0000-00000032000a' and perfil_id = '00000000-0000-0000-0000-000000003214';
insert into public.respostas_escala (escala_id, perfil_id, resposta, motivo) values
  ('00000000-0000-0000-0000-00000032e001', '00000000-0000-0000-0000-000000003211', 'confirmado', ''),
  ('00000000-0000-0000-0000-00000032e001', '00000000-0000-0000-0000-000000003212', 'recusado', 'Motivo secreto');

-- ===== Líder do A (gestor) =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003202", "role": "authenticated"}', true);
set local role authenticated;
select is((public.ler_escala('00000000-0000-0000-0000-00000032e001') ->> 'papel'), 'gestor', 'líder lê como gestor');
select is(jsonb_array_length(public.ler_escala('00000000-0000-0000-0000-00000032e001') -> 'respostas'), 3, 'líder recebe a resposta de cada pessoa escalada (3)');
select ok((public.ler_escala('00000000-0000-0000-0000-00000032e001') -> 'respostas') @> '[{"nome":"Pessoa 32 12","resposta":"recusado","motivo":"Motivo secreto"}]'::jsonb, 'inclui a recusa e o motivo');
select is((select string_agg(v ->> 'precisa_atencao', ',' order by (v ->> 'ordem')::int) from jsonb_array_elements(public.ler_escala('00000000-0000-0000-0000-00000032e001') -> 'vagas') v),
          'recusada,sem_resposta,em_aberto', 'destaques: recusada, sem resposta e em aberto (confirmada não tem)');
select isnt(public.ler_escala('00000000-0000-0000-0000-00000032e002'), null, 'líder vê o rascunho');
select is((select recusadas from public.listar_escalas_ministerio('00000000-0000-0000-0000-00000032000a') where evento = 'Publicada'), 1, 'lista: o gestor recebe a contagem de recusadas');
select is((select sem_resposta from public.listar_escalas_ministerio('00000000-0000-0000-0000-00000032000a') where evento = 'Publicada'), 1, 'e a de sem resposta');
select is((select count(*) from public.listar_escalas_ministerio('00000000-0000-0000-0000-00000032000a')), 3::bigint, 'o líder lista rascunho, publicada e cancelada');
reset role;

-- ===== Participante comum (P3, sem resposta) =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003213", "role": "authenticated"}', true);
set local role authenticated;
select is((public.ler_escala('00000000-0000-0000-0000-00000032e001') ->> 'papel'), 'participante', 'participante lê como participante');
select is((public.ler_escala('00000000-0000-0000-0000-00000032e001') -> 'respostas'), 'null'::jsonb, 'participante NÃO recebe as respostas dos outros');
select ok(not (public.ler_escala('00000000-0000-0000-0000-00000032e001')::text like '%Motivo secreto%'), 'nem o motivo de recusa de ninguém');
select ok(not (public.ler_escala('00000000-0000-0000-0000-00000032e001')::text like '%precisa_atencao%'), 'nem os destaques de gestão');
select is((public.ler_escala('00000000-0000-0000-0000-00000032e001') -> 'minha_resposta' ->> 'resposta'), 'pendente', 'vê só a própria resposta (pendente)');
select ok((public.ler_escala('00000000-0000-0000-0000-00000032e001')::text like '%Pessoa 32 11%'), 'vê o nome de quem ocupa cada vaga');
select is(public.ler_escala('00000000-0000-0000-0000-00000032e002'), null, 'não vê o rascunho');
select is((select count(*) from public.listar_escalas_ministerio('00000000-0000-0000-0000-00000032000a')), 1::bigint, 'na lista, só a publicada (cancelada em que não esteve escalado e rascunho ficam de fora)');
select is((select recusadas from public.listar_escalas_ministerio('00000000-0000-0000-0000-00000032000a')), null, 'sem as contagens de gestão');
reset role;

-- ===== Quem estava escalado e saiu do ministério =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003214", "role": "authenticated"}', true);
set local role authenticated;
select isnt(public.ler_escala('00000000-0000-0000-0000-00000032e003'), null, 'escalado que saiu do ministério ainda vê a escala cancelada em que estava');
reset role;

-- ===== Estranho e líder de outro ministério =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003203", "role": "authenticated"}', true);
set local role authenticated;
select is(public.ler_escala('00000000-0000-0000-0000-00000032e001'), null, 'líder de outro ministério não vê a escala');
reset role;

select * from finish();
rollback;
