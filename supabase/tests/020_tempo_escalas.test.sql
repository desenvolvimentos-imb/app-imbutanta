-- T005: funções de tempo das escalas (research.md, decisão 2).
-- O relógio é fixado redefinindo `agora_sp()` DENTRO da transação do teste; o rollback final
-- devolve a função original. Nenhuma configuração de sessão altera o relógio.
begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

-- 1) Sem redefinir: `agora_sp()` é o now() de verdade (diferença de menos de 5 segundos).
select ok(abs(extract(epoch from (public.agora_sp() - now()))) < 5, 'agora_sp() devolve o instante atual');

-- 2) Uma configuração de sessão não consegue mudar o relógio.
select set_config('app.agora_teste', '2000-01-01 00:00:00-03', true);
select ok(public.agora_sp() > now() - interval '5 seconds', 'configuração de sessão não altera o relógio');

-- 3) As funções internas não são chamáveis pela API.
select ok(not has_function_privilege('anon', 'public.agora_sp()', 'execute'), 'anon não executa agora_sp');
select ok(not has_function_privilege('authenticated', 'public.agora_sp()', 'execute'), 'authenticated não executa agora_sp');
select ok(not has_function_privilege('authenticated', 'public.hoje_sp()', 'execute'), 'authenticated não executa hoje_sp');

-- 4) `inicio_da_escala` é imutável e correta (São Paulo é UTC-3).
select is((select provolatile::text from pg_proc where proname = 'inicio_da_escala'), 'i', 'inicio_da_escala é imutável');
select is(public.inicio_da_escala('2026-12-14', '09:00'), '2026-12-14 12:00:00+00'::timestamptz,
          'inicio_da_escala converte data e horário de São Paulo para um instante');

-- 5) Perto da meia-noite: 23:30 de 9/12 em São Paulo ainda é dia 9, e 00:30 já é dia 10.
create or replace function public.agora_sp() returns timestamptz language sql stable as
  $$ select '2026-12-10 02:30:00+00'::timestamptz $$;
select is(public.hoje_sp(), '2026-12-09'::date, '23:30 em São Paulo ainda é o dia 9 (mesmo sendo dia 10 em UTC)');

create or replace function public.agora_sp() returns timestamptz language sql stable as
  $$ select '2026-12-10 03:30:00+00'::timestamptz $$;
select is(public.hoje_sp(), '2026-12-10'::date, '00:30 em São Paulo já é o dia 10');

-- 6) A regra de "somente leitura" usa o relógio redefinido: no dia seguinte à escala, só leitura.
select throws_ok($$ select public.exigir_escala_editavel(
                      row(gen_random_uuid(), gen_random_uuid(), 'x', '2026-12-09', '09:00', '', 'publicada',
                          null, now(), now(), null)::public.escalas) $$,
                 'P0001', 'escala_somente_leitura', 'no dia seguinte à data a escala é somente leitura');

select * from finish();
rollback;
