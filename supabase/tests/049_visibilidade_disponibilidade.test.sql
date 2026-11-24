-- T032: privacidade das respostas e observações (RF-018, RF-019, RF-020).
begin;
create extension if not exists pgtap with schema extensions;
select plan(11);

create or replace function public.agora_sp() returns timestamptz language sql stable as
  $$ select '2026-12-10 12:00:00+00'::timestamptz $$;

-- 4901 líder A, 4902 P1, 4903 P2, 4904 estranho (nenhum ministério), 4905 líder B, 4906 saiu
insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role)
select ('00000000-0000-0000-0000-0000000049' || lpad(n::text, 2, '0'))::uuid, 'u' || n || '.49@exemplo.com', now(),
       jsonb_build_object('nome', 'Pessoa 49 ' || n), 'authenticated', 'authenticated'
  from unnest(array[1, 2, 3, 4, 5, 6]) as n;
update public.perfis set situacao = 'aprovado' where id::text like '00000000-0000-0000-0000-0000000049%';
insert into public.ministerios (id, nome, descricao) values
  ('00000000-0000-0000-0000-00000049000a', 'Teste Vis 49 A', ''),
  ('00000000-0000-0000-0000-00000049000b', 'Teste Vis 49 B', '');
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel) values
  ('00000000-0000-0000-0000-00000049000a', '00000000-0000-0000-0000-000000004901', 'lider'),
  ('00000000-0000-0000-0000-00000049000a', '00000000-0000-0000-0000-000000004902', 'participante'),
  ('00000000-0000-0000-0000-00000049000a', '00000000-0000-0000-0000-000000004903', 'participante'),
  ('00000000-0000-0000-0000-00000049000b', '00000000-0000-0000-0000-000000004905', 'lider');
insert into public.consultas_disponibilidade (id, ministerio_id, titulo) values
  ('00000000-0000-0000-0000-00000049c001', '00000000-0000-0000-0000-00000049000a', 'Consulta A');
insert into public.datas_consulta (id, consulta_id, ministerio_id, data) values
  ('00000000-0000-0000-0000-00000049d001', '00000000-0000-0000-0000-00000049c001', '00000000-0000-0000-0000-00000049000a', '2026-12-13');
insert into public.respostas_disponibilidade (data_id, perfil_id, resposta) values
  ('00000000-0000-0000-0000-00000049d001', '00000000-0000-0000-0000-000000004902', 'indisponivel'),
  ('00000000-0000-0000-0000-00000049d001', '00000000-0000-0000-0000-000000004903', 'disponivel'),
  ('00000000-0000-0000-0000-00000049d001', '00000000-0000-0000-0000-000000004906', 'disponivel');
insert into public.observacoes_disponibilidade (consulta_id, perfil_id, texto) values
  ('00000000-0000-0000-0000-00000049c001', '00000000-0000-0000-0000-000000004902', 'OBS-SECRETA-P1'),
  ('00000000-0000-0000-0000-00000049c001', '00000000-0000-0000-0000-000000004906', 'OBS-DE-QUEM-SAIU');

-- Participante: só o que é dele
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000004903", "role": "authenticated"}', true);
set local role authenticated;
select ok(public.ler_consulta_participante('00000000-0000-0000-0000-00000049c001')::text not like '%OBS-SECRETA-P1%', 'P2 não vê a observação do P1');
select is(public.ler_consulta_participante('00000000-0000-0000-0000-00000049c001') -> 'datas' -> 0 ->> 'resposta', 'disponivel', 'P2 só vê a própria resposta');
select ok(public.minhas_consultas()::text not like '%OBS-SECRETA-P1%', 'minhas_consultas não vaza observação alheia');
select is(public.ler_consulta_gestor('00000000-0000-0000-0000-00000049c001'), null::jsonb, 'participante comum não lê a grade');
reset role;

-- Estranho e líder de outro ministério
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000004904", "role": "authenticated"}', true);
set local role authenticated;
select is(public.ler_consulta_participante('00000000-0000-0000-0000-00000049c001'), null::jsonb, 'estranho não lê a consulta');
select is(public.ler_consulta_gestor('00000000-0000-0000-0000-00000049c001'), null::jsonb, 'estranho não lê a grade');
reset role;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000004905", "role": "authenticated"}', true);
set local role authenticated;
select is(public.ler_consulta_gestor('00000000-0000-0000-0000-00000049c001'), null::jsonb, 'líder de outro ministério não lê a grade');
reset role;

-- Líder do A vê tudo do A, e quem saiu não aparece
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000004901", "role": "authenticated"}', true);
set local role authenticated;
select ok(public.ler_consulta_gestor('00000000-0000-0000-0000-00000049c001')::text like '%OBS-SECRETA-P1%', 'líder vê a observação do P1');
select ok(public.ler_consulta_gestor('00000000-0000-0000-0000-00000049c001')::text not like '%OBS-DE-QUEM-SAIU%', 'quem saiu do ministério não aparece (nem a observação)');
select ok(public.ler_consulta_gestor('00000000-0000-0000-0000-00000049c001')::text not like '%@exemplo.com%', 'a grade não traz email');
reset role;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000004906", "role": "authenticated"}', true);
set local role authenticated;
select is(public.ler_consulta_participante('00000000-0000-0000-0000-00000049c001'), null::jsonb, 'quem saiu do ministério não lê mais a consulta');
reset role;

select * from finish();
rollback;
