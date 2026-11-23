-- T061(a): ações seguidas sobre a mesma escala nunca deixam estado misto (SC-004, FR-035).
-- (A prova com duas sessões ao mesmo tempo está em tests/integration/concorrencia-escalas.test.ts.)
begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

create or replace function public.agora_sp() returns timestamptz language sql stable as
  $$ select '2026-12-10 12:00:00+00'::timestamptz $$;

-- L (3702), P1 (3711), P2 (3712), P3 (3713)
insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role)
select ('00000000-0000-0000-0000-0000000037' || lpad(n::text, 2, '0'))::uuid, 'u' || n || '.37@exemplo.com', now(),
       jsonb_build_object('nome', 'Pessoa 37 ' || n), 'authenticated', 'authenticated'
  from unnest(array[2, 11, 12, 13]) as n;
update public.perfis set situacao = 'aprovado' where id::text like '00000000-0000-0000-0000-0000000037%';
insert into public.ministerios (id, nome, descricao) values ('00000000-0000-0000-0000-00000037000a', 'Teste Sequencial 37', '');
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel)
select '00000000-0000-0000-0000-00000037000a', ('00000000-0000-0000-0000-0000000037' || lpad(n::text, 2, '0'))::uuid,
       case when n = 2 then 'lider'::public.papel_ministerio else 'participante'::public.papel_ministerio end
  from unnest(array[2, 11, 12, 13]) as n;
insert into public.funcoes_ministerio (id, ministerio_id, nome) values ('00000000-0000-0000-0000-00000037f001', '00000000-0000-0000-0000-00000037000a', 'Vocal');
insert into public.aptidoes (funcao_id, perfil_id, tipo)
select '00000000-0000-0000-0000-00000037f001', ('00000000-0000-0000-0000-0000000037' || lpad(n::text, 2, '0'))::uuid, 'principal'
  from unnest(array[11, 12, 13]) as n;
insert into public.escalas (id, ministerio_id, evento, data, horario, situacao) values
  ('00000000-0000-0000-0000-00000037e001', '00000000-0000-0000-0000-00000037000a', 'Culto', '2026-12-15', '09:00', 'publicada');
insert into public.vagas_escala (id, escala_id, funcao_id, perfil_id) values
  ('00000000-0000-0000-0000-00000037a001', '00000000-0000-0000-0000-00000037e001', '00000000-0000-0000-0000-00000037f001', '00000000-0000-0000-0000-000000003711');
insert into public.pedidos_troca (id, vaga_id, escala_id, solicitante_id, indicada_id, situacao) values
  ('00000000-0000-0000-0000-00000037b001', '00000000-0000-0000-0000-00000037a001', '00000000-0000-0000-0000-00000037e001', '00000000-0000-0000-0000-000000003711', '00000000-0000-0000-0000-000000003713', 'aguardando_lider');

-- ===== Cenário A: o líder troca a pessoa da vaga e DEPOIS tenta aprovar o pedido antigo =====
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003702", "role": "authenticated"}', true);
set local role authenticated;
select is((public.salvar_vaga('00000000-0000-0000-0000-00000037e001', '00000000-0000-0000-0000-00000037a001', '00000000-0000-0000-0000-00000037f001', '', '00000000-0000-0000-0000-000000003712')->>'salvo')::boolean, true, 'líder troca a pessoa (P1 → P2)');
select throws_ok($$ select public.decidir_troca_lider('00000000-0000-0000-0000-00000037b001', true, true) $$, 'P0001', 'conflito_troca', 'aprovar o pedido antigo depois da troca de pessoa: conflito_troca');
reset role;
select is((select perfil_id from public.vagas_escala where id = '00000000-0000-0000-0000-00000037a001'), '00000000-0000-0000-0000-000000003712'::uuid, 'a vaga ficou como o líder deixou (P2), sem mistura');
select is((select situacao::text from public.pedidos_troca where id = '00000000-0000-0000-0000-00000037b001'), 'sem_efeito', 'o pedido perdeu efeito quando a pessoa da vaga mudou');

-- ===== Cenário B: novo pedido, aprovado primeiro; DEPOIS o líder troca a pessoa da vaga =====
insert into public.pedidos_troca (id, vaga_id, escala_id, solicitante_id, indicada_id, situacao) values
  ('00000000-0000-0000-0000-00000037b002', '00000000-0000-0000-0000-00000037a001', '00000000-0000-0000-0000-00000037e001', '00000000-0000-0000-0000-000000003712', '00000000-0000-0000-0000-000000003713', 'aguardando_lider');
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003702", "role": "authenticated"}', true);
set local role authenticated;
select is((public.decidir_troca_lider('00000000-0000-0000-0000-00000037b002', true, true)->>'decidido')::boolean, true, 'aprova a troca (P2 → P3)');
select is((public.salvar_vaga('00000000-0000-0000-0000-00000037e001', '00000000-0000-0000-0000-00000037a001', '00000000-0000-0000-0000-00000037f001', 'Novo rótulo', '00000000-0000-0000-0000-000000003713')->>'salvo')::boolean, true, 'o líder ainda edita a vaga (agora de P3) sem erro');
reset role;
select is((select perfil_id from public.vagas_escala where id = '00000000-0000-0000-0000-00000037a001'), '00000000-0000-0000-0000-000000003713'::uuid, 'a vaga é de P3');

-- ===== Cenário C: o horário de início passa entre o aceite e a aprovação =====
insert into public.pedidos_troca (id, vaga_id, escala_id, solicitante_id, indicada_id, situacao) values
  ('00000000-0000-0000-0000-00000037b003', '00000000-0000-0000-0000-00000037a001', '00000000-0000-0000-0000-00000037e001', '00000000-0000-0000-0000-000000003713', '00000000-0000-0000-0000-000000003711', 'aguardando_lider');
create or replace function public.agora_sp() returns timestamptz language sql stable as
  $$ select '2026-12-15 13:00:00+00'::timestamptz $$;   -- 10:00 do dia 15, depois do início (09:00)
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003702", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.decidir_troca_lider('00000000-0000-0000-0000-00000037b003', true, true) $$, 'P0001', 'evento_iniciado', 'depois do horário de início, nada é aprovado');
reset role;
select is((select perfil_id from public.vagas_escala where id = '00000000-0000-0000-0000-00000037a001'), '00000000-0000-0000-0000-000000003713'::uuid, 'e a vaga fica como estava');

select * from finish();
rollback;
