-- T057: pedir troca de vaga (FR-029, FR-031, FR-033). Relógio: 10/12/2026 09:00 (São Paulo).
begin;
create extension if not exists pgtap with schema extensions;
select plan(15);

create or replace function public.agora_sp() returns timestamptz language sql stable as
  $$ select '2026-12-10 12:00:00+00'::timestamptz $$;

-- L (3302, líder), P1..P5 (3311..3315), X (3320, não participa)
insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role)
select ('00000000-0000-0000-0000-0000000033' || lpad(n::text, 2, '0'))::uuid, 'u' || n || '.33@exemplo.com', now(),
       jsonb_build_object('nome', 'Pessoa 33 ' || n), 'authenticated', 'authenticated'
  from unnest(array[2, 11, 12, 13, 14, 15, 20]) as n;
update public.perfis set situacao = 'aprovado' where id::text like '00000000-0000-0000-0000-0000000033%';
insert into public.ministerios (id, nome, descricao) values ('00000000-0000-0000-0000-00000033000a', 'Teste Pedir Troca 33', '');
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel)
select '00000000-0000-0000-0000-00000033000a', ('00000000-0000-0000-0000-0000000033' || lpad(n::text, 2, '0'))::uuid,
       case when n = 2 then 'lider'::public.papel_ministerio else 'participante'::public.papel_ministerio end
  from unnest(array[2, 11, 12, 13, 14, 15]) as n;
insert into public.funcoes_ministerio (id, ministerio_id, nome) values ('00000000-0000-0000-0000-00000033f001', '00000000-0000-0000-0000-00000033000a', 'Vocal');
insert into public.escalas (id, ministerio_id, evento, data, horario, situacao) values
  ('00000000-0000-0000-0000-00000033e001', '00000000-0000-0000-0000-00000033000a', 'Publicada', '2026-12-15', '09:00', 'publicada'),
  ('00000000-0000-0000-0000-00000033e002', '00000000-0000-0000-0000-00000033000a', 'Rascunho', '2026-12-16', '09:00', 'rascunho'),
  ('00000000-0000-0000-0000-00000033e003', '00000000-0000-0000-0000-00000033000a', 'Cancelada', '2026-12-17', '09:00', 'cancelada'),
  ('00000000-0000-0000-0000-00000033e004', '00000000-0000-0000-0000-00000033000a', 'Hoje cedo', '2026-12-10', '08:00', 'publicada');
insert into public.vagas_escala (id, escala_id, funcao_id, perfil_id) values
  ('00000000-0000-0000-0000-00000033a001', '00000000-0000-0000-0000-00000033e001', '00000000-0000-0000-0000-00000033f001', '00000000-0000-0000-0000-000000003311'),
  ('00000000-0000-0000-0000-00000033a002', '00000000-0000-0000-0000-00000033e001', '00000000-0000-0000-0000-00000033f001', '00000000-0000-0000-0000-000000003312'),
  ('00000000-0000-0000-0000-00000033a003', '00000000-0000-0000-0000-00000033e002', '00000000-0000-0000-0000-00000033f001', '00000000-0000-0000-0000-000000003315'),
  ('00000000-0000-0000-0000-00000033a004', '00000000-0000-0000-0000-00000033e003', '00000000-0000-0000-0000-00000033f001', '00000000-0000-0000-0000-000000003311'),
  ('00000000-0000-0000-0000-00000033a005', '00000000-0000-0000-0000-00000033e004', '00000000-0000-0000-0000-00000033f001', '00000000-0000-0000-0000-000000003311'),
  ('00000000-0000-0000-0000-00000033a006', '00000000-0000-0000-0000-00000033e001', '00000000-0000-0000-0000-00000033f001', '00000000-0000-0000-0000-000000003311');

set local role anon;
select throws_ok($$ select public.pedir_troca('00000000-0000-0000-0000-00000033a001', '00000000-0000-0000-0000-000000003313') $$, '42501', null, 'anônimo não executa pedir_troca');
reset role;

select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003311", "role": "authenticated"}', true);
set local role authenticated;

-- ===== Caminho feliz =====
select is((select (public.pedir_troca('00000000-0000-0000-0000-00000033a001', '00000000-0000-0000-0000-000000003313')).situacao::text), 'aguardando_indicada', 'cria o pedido aguardando a indicada');
reset role;
select is((select perfil_id from public.vagas_escala where id = '00000000-0000-0000-0000-00000033a001'), '00000000-0000-0000-0000-000000003311'::uuid, 'enquanto pendente, nada muda na escala');
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003311", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.pedir_troca('00000000-0000-0000-0000-00000033a001', '00000000-0000-0000-0000-000000003314') $$, 'P0001', 'troca_duplicada', 'a vaga já tem um pedido pendente');

-- ===== Validações da indicada (usa a vaga a006, do mesmo P1, sem pedido) =====
select throws_ok($$ select public.pedir_troca('00000000-0000-0000-0000-00000033a006', '00000000-0000-0000-0000-000000003311') $$, 'P0001', 'troca_invalida', 'não indica a si mesma');
select throws_ok($$ select public.pedir_troca('00000000-0000-0000-0000-00000033a006', null) $$, 'P0001', 'troca_invalida', 'indicada obrigatória');
select throws_ok($$ select public.pedir_troca('00000000-0000-0000-0000-00000033a006', '00000000-0000-0000-0000-000000003320') $$, 'P0001', 'troca_invalida', 'quem não participa do ministério não pode ser indicada');
select throws_ok($$ select public.pedir_troca('00000000-0000-0000-0000-00000033a006', '00000000-0000-0000-0000-000000003312') $$, 'P0001', 'ja_escalada', 'quem já está escalada nesta escala não pode ser indicada');

-- ===== Situações da escala e de quem pede =====
select throws_ok($$ select public.pedir_troca('00000000-0000-0000-0000-00000033a004', '00000000-0000-0000-0000-000000003313') $$, 'P0001', 'escala_cancelada', 'escala cancelada');
select throws_ok($$ select public.pedir_troca('00000000-0000-0000-0000-00000033a005', '00000000-0000-0000-0000-000000003313') $$, 'P0001', 'evento_iniciado', 'o horário de início já passou');
reset role;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003315", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.pedir_troca('00000000-0000-0000-0000-00000033a003', '00000000-0000-0000-0000-000000003313') $$, 'P0001', 'escala_nao_publicada', 'rascunho');
reset role;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003313", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select public.pedir_troca('00000000-0000-0000-0000-00000033a001', '00000000-0000-0000-0000-000000003314') $$, 'P0001', 'nao_escalado', 'quem não ocupa a vaga não pede troca dela');

-- ===== Candidatas =====
reset role;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000003311", "role": "authenticated"}', true);
set local role authenticated;
select is((select array_agg(nome order by nome) from public.listar_candidatas_troca('00000000-0000-0000-0000-00000033a006')),
          array['Pessoa 33 13', 'Pessoa 33 14', 'Pessoa 33 15', 'Pessoa 33 2'], 'candidatas: participantes ainda não escaladas nesta escala, inclusive o líder (sem a própria e sem quem já está nela)');
select is((select count(*) from public.listar_candidatas_troca('00000000-0000-0000-0000-00000033a005')), 0::bigint, 'vaga de escala que já começou: nenhuma candidata');
select ok(position('email' in pg_get_function_result('public.listar_candidatas_troca(uuid)'::regprocedure)) = 0, 'a função não devolve email');
reset role;

select * from finish();
rollback;
