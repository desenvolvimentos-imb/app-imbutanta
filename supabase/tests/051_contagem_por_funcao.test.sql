-- T043: contagem de disponíveis por função (aptidões da 003). Relógio: 10/12/2026.
begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

create or replace function public.agora_sp() returns timestamptz language sql stable as
  $$ select '2026-12-10 12:00:00+00'::timestamptz $$;

-- 5101 líder, 5102 Ana (vocal principal + violão secundária), 5103 Bia (vocal), 5104 Caio (sem aptidão)
insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role)
select ('00000000-0000-0000-0000-0000000051' || lpad(n::text, 2, '0'))::uuid, 'u' || n || '.51@exemplo.com', now(),
       jsonb_build_object('nome', 'Pessoa 51 ' || n), 'authenticated', 'authenticated'
  from unnest(array[1, 2, 3, 4]) as n;
update public.perfis set situacao = 'aprovado' where id::text like '00000000-0000-0000-0000-0000000051%';
insert into public.ministerios (id, nome, descricao) values
  ('00000000-0000-0000-0000-00000051000a', 'Teste Func 51 A', ''),
  ('00000000-0000-0000-0000-00000051000b', 'Teste Func 51 B (sem funções)', '');
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel) values
  ('00000000-0000-0000-0000-00000051000a', '00000000-0000-0000-0000-000000005101', 'lider'),
  ('00000000-0000-0000-0000-00000051000a', '00000000-0000-0000-0000-000000005102', 'participante'),
  ('00000000-0000-0000-0000-00000051000a', '00000000-0000-0000-0000-000000005103', 'participante'),
  ('00000000-0000-0000-0000-00000051000a', '00000000-0000-0000-0000-000000005104', 'participante'),
  ('00000000-0000-0000-0000-00000051000b', '00000000-0000-0000-0000-000000005101', 'lider');
insert into public.funcoes_ministerio (id, ministerio_id, nome, ativa) values
  ('00000000-0000-0000-0000-00000051f001', '00000000-0000-0000-0000-00000051000a', 'Vocal', true),
  ('00000000-0000-0000-0000-00000051f002', '00000000-0000-0000-0000-00000051000a', 'Violão', true),
  ('00000000-0000-0000-0000-00000051f003', '00000000-0000-0000-0000-00000051000a', 'Bateria', true),
  ('00000000-0000-0000-0000-00000051f004', '00000000-0000-0000-0000-00000051000a', 'Antiga', false);
insert into public.aptidoes (funcao_id, perfil_id, tipo) values
  ('00000000-0000-0000-0000-00000051f001', '00000000-0000-0000-0000-000000005102', 'principal'),
  ('00000000-0000-0000-0000-00000051f002', '00000000-0000-0000-0000-000000005102', 'secundaria'),
  ('00000000-0000-0000-0000-00000051f001', '00000000-0000-0000-0000-000000005103', 'principal'),
  ('00000000-0000-0000-0000-00000051f004', '00000000-0000-0000-0000-000000005103', 'principal');
insert into public.consultas_disponibilidade (id, ministerio_id, titulo) values
  ('00000000-0000-0000-0000-00000051c001', '00000000-0000-0000-0000-00000051000a', 'Dezembro'),
  ('00000000-0000-0000-0000-00000051c00b', '00000000-0000-0000-0000-00000051000b', 'Sem funções');
insert into public.datas_consulta (id, consulta_id, ministerio_id, data) values
  ('00000000-0000-0000-0000-00000051d001', '00000000-0000-0000-0000-00000051c001', '00000000-0000-0000-0000-00000051000a', '2026-12-13'),
  ('00000000-0000-0000-0000-00000051d002', '00000000-0000-0000-0000-00000051c001', '00000000-0000-0000-0000-00000051000a', '2026-12-20'),
  ('00000000-0000-0000-0000-00000051d00b', '00000000-0000-0000-0000-00000051c00b', '00000000-0000-0000-0000-00000051000b', '2026-12-13');
-- 13/12: Ana, Bia e Caio disponíveis; 20/12: Ana indisponível, Bia sem resposta
insert into public.respostas_disponibilidade (data_id, perfil_id, resposta) values
  ('00000000-0000-0000-0000-00000051d001', '00000000-0000-0000-0000-000000005102', 'disponivel'),
  ('00000000-0000-0000-0000-00000051d001', '00000000-0000-0000-0000-000000005103', 'disponivel'),
  ('00000000-0000-0000-0000-00000051d001', '00000000-0000-0000-0000-000000005104', 'disponivel'),
  ('00000000-0000-0000-0000-00000051d002', '00000000-0000-0000-0000-000000005102', 'indisponivel');

select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000005101", "role": "authenticated"}', true);
set local role authenticated;
-- datas ordenadas: [0] = 13/12, [1] = 20/12. por_funcao ordenado por nome: Bateria, Violão, Vocal.
select is(jsonb_array_length(public.ler_consulta_gestor('00000000-0000-0000-0000-00000051c001') -> 'datas' -> 0 -> 'por_funcao'), 3, 'só funções ATIVAS aparecem (a desativada não)');
select is(public.ler_consulta_gestor('00000000-0000-0000-0000-00000051c001') -> 'datas' -> 0 -> 'por_funcao' -> 2 ->> 'funcao', 'Vocal', 'ordenadas por nome');
select is((public.ler_consulta_gestor('00000000-0000-0000-0000-00000051c001') -> 'datas' -> 0 -> 'por_funcao' -> 2 ->> 'disponiveis')::int, 2, '13/12 Vocal: Ana e Bia (Caio não é apto)');
select is((public.ler_consulta_gestor('00000000-0000-0000-0000-00000051c001') -> 'datas' -> 0 -> 'por_funcao' -> 1 ->> 'disponiveis')::int, 1, '13/12 Violão: Ana (aptidão secundária conta); apto em duas funções conta nas duas');
select is(public.ler_consulta_gestor('00000000-0000-0000-0000-00000051c001') -> 'datas' -> 0 -> 'por_funcao' -> 0 ->> 'faltando', 'true', '13/12 Bateria: ninguém apto disponível => faltando');
select is((public.ler_consulta_gestor('00000000-0000-0000-0000-00000051c001') -> 'datas' -> 1 -> 'por_funcao' -> 2 ->> 'disponiveis')::int, 0, '20/12 Vocal: Ana indisponível e Bia sem resposta => 0 (sem resposta não conta como disponível)');
select is(public.ler_consulta_gestor('00000000-0000-0000-0000-00000051c001') -> 'datas' -> 1 -> 'por_funcao' -> 2 ->> 'faltando', 'true', '20/12 Vocal destacada como falta');
select is(public.ler_consulta_gestor('00000000-0000-0000-0000-00000051c001') ->> 'tem_funcoes', 'true', 'tem_funcoes verdadeiro');
select is(public.ler_consulta_gestor('00000000-0000-0000-0000-00000051c00b') ->> 'tem_funcoes', 'false', 'ministério sem funções: tem_funcoes falso e por_funcao vazio');
reset role;

select * from finish();
rollback;
