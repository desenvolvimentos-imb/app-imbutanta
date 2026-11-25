-- T017: listar_consultas_ministerio. Relógio: 10/12/2026.
begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

create or replace function public.agora_sp() returns timestamptz language sql stable as
  $$ select '2026-12-10 12:00:00+00'::timestamptz $$;

-- 4501 adm, 4502 líder A, 4503 part A (respondeu), 4504 part A (nada), 4505 líder B, 4506 estranho, 4507 saiu
insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role)
select ('00000000-0000-0000-0000-0000000045' || lpad(n::text, 2, '0'))::uuid, 'u' || n || '.45@exemplo.com', now(),
       jsonb_build_object('nome', 'Pessoa 45 ' || n), 'authenticated', 'authenticated'
  from unnest(array[1, 2, 3, 4, 5, 6, 7]) as n;
update public.perfis set situacao = 'aprovado' where id::text like '00000000-0000-0000-0000-0000000045%';
update public.perfis set papel = 'administrador' where id = '00000000-0000-0000-0000-000000004501';
insert into public.ministerios (id, nome, descricao) values
  ('00000000-0000-0000-0000-00000045000a', 'Teste Lista 45 A', ''),
  ('00000000-0000-0000-0000-00000045000b', 'Teste Lista 45 B', '');
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel) values
  ('00000000-0000-0000-0000-00000045000a', '00000000-0000-0000-0000-000000004502', 'lider'),
  ('00000000-0000-0000-0000-00000045000a', '00000000-0000-0000-0000-000000004503', 'participante'),
  ('00000000-0000-0000-0000-00000045000a', '00000000-0000-0000-0000-000000004504', 'participante'),
  ('00000000-0000-0000-0000-00000045000b', '00000000-0000-0000-0000-000000004505', 'lider');
insert into public.consultas_disponibilidade (id, ministerio_id, titulo, prazo, fechada, criada_em) values
  ('00000000-0000-0000-0000-00000045c001', '00000000-0000-0000-0000-00000045000a', 'Antiga fechada', null, true, '2026-11-01'),
  ('00000000-0000-0000-0000-00000045c002', '00000000-0000-0000-0000-00000045000a', 'Aberta', null, false, '2026-12-01'),
  ('00000000-0000-0000-0000-00000045c003', '00000000-0000-0000-0000-00000045000a', 'Prazo vencido', '2026-12-09', false, '2026-11-20'),
  ('00000000-0000-0000-0000-00000045c00b', '00000000-0000-0000-0000-00000045000b', 'Do B', null, false, '2026-12-02');
insert into public.datas_consulta (id, consulta_id, ministerio_id, data) values
  ('00000000-0000-0000-0000-00000045d001', '00000000-0000-0000-0000-00000045c002', '00000000-0000-0000-0000-00000045000a', '2026-12-13'),
  ('00000000-0000-0000-0000-00000045d002', '00000000-0000-0000-0000-00000045c002', '00000000-0000-0000-0000-00000045000a', '2026-12-20'),
  ('00000000-0000-0000-0000-00000045d003', '00000000-0000-0000-0000-00000045c001', '00000000-0000-0000-0000-00000045000a', '2026-11-08'),
  ('00000000-0000-0000-0000-00000045d004', '00000000-0000-0000-0000-00000045c003', '00000000-0000-0000-0000-00000045000a', '2026-12-27'),
  ('00000000-0000-0000-0000-00000045d00b', '00000000-0000-0000-0000-00000045c00b', '00000000-0000-0000-0000-00000045000b', '2026-12-13');
-- 4503 respondeu uma data; 4507 saiu do ministério mas deixou resposta (não deve contar)
insert into public.respostas_disponibilidade (data_id, perfil_id, resposta) values
  ('00000000-0000-0000-0000-00000045d001', '00000000-0000-0000-0000-000000004503', 'disponivel'),
  ('00000000-0000-0000-0000-00000045d001', '00000000-0000-0000-0000-000000004507', 'disponivel');

select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000004502", "role": "authenticated"}', true);
set local role authenticated;
select is(jsonb_array_length(public.listar_consultas_ministerio('00000000-0000-0000-0000-00000045000a')), 3, 'líder do A vê as 3 consultas do A (aberta, vencida e fechada)');
select is(public.listar_consultas_ministerio('00000000-0000-0000-0000-00000045000a') -> 0 ->> 'titulo', 'Aberta', 'abertas vêm primeiro');
select is(public.listar_consultas_ministerio('00000000-0000-0000-0000-00000045000a') -> 1 ->> 'titulo', 'Prazo vencido', 'depois o histórico, mais recente primeiro');
select is(public.listar_consultas_ministerio('00000000-0000-0000-0000-00000045000a') -> 1 ->> 'motivo_fechada', 'prazo', 'motivo: prazo encerrado');
select is(public.listar_consultas_ministerio('00000000-0000-0000-0000-00000045000a') -> 2 ->> 'motivo_fechada', 'lider', 'motivo: fechada pelo líder');
select is((public.listar_consultas_ministerio('00000000-0000-0000-0000-00000045000a') -> 0 ->> 'total_datas')::int, 2, 'quantidade de datas');
select is((public.listar_consultas_ministerio('00000000-0000-0000-0000-00000045000a') -> 0 ->> 'sem_resposta_nenhuma')::int, 2,
          'sem resposta nenhuma: líder (também participante) e o participante que não marcaram nada; quem saiu não conta');
select is(jsonb_array_length(public.listar_consultas_ministerio('00000000-0000-0000-0000-00000045000b')), 0, 'líder do A não vê consultas do B');
reset role;

select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000004503", "role": "authenticated"}', true);
set local role authenticated;
select is(jsonb_array_length(public.listar_consultas_ministerio('00000000-0000-0000-0000-00000045000a')), 0, 'participante comum recebe lista vazia');
reset role;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000004506", "role": "authenticated"}', true);
set local role authenticated;
select is(jsonb_array_length(public.listar_consultas_ministerio('00000000-0000-0000-0000-00000045000a')), 0, 'estranho recebe lista vazia');
reset role;

select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000004501", "role": "authenticated"}', true);
set local role authenticated;
select is(jsonb_array_length(public.listar_consultas_ministerio('00000000-0000-0000-0000-00000045000b')), 1, 'administrador vê as consultas de qualquer ministério');
reset role;

-- Ministério desativado continua legível ao administrador, com o motivo
update public.consultas_disponibilidade set fechada = true where id = '00000000-0000-0000-0000-00000045c00b';
update public.ministerios set ativo = false where id = '00000000-0000-0000-0000-00000045000b';
set local role authenticated;
select is(public.listar_consultas_ministerio('00000000-0000-0000-0000-00000045000b') -> 0 ->> 'motivo_fechada', 'ministerio_desativado', 'ministério desativado: histórico legível, com o motivo');
reset role;
select set_config('request.jwt.claims', '{"role": "anon"}', true);
set local role anon;
select throws_ok($$ select public.listar_consultas_ministerio('00000000-0000-0000-0000-00000045000a') $$, '42501', null, 'anônimo não executa');
reset role;

select * from finish();
rollback;
