-- T010: o dono do projeto vira administrador sem passar pela fila (RF-014), mas somente
-- depois de confirmar o email (evita que um terceiro crie conta com o email do dono).
begin;
create extension if not exists pgtap with schema extensions;
select plan(7);

insert into public.administradores_iniciais (email) values ('dono@exemplo.com');

-- Cadastro por senha, ainda sem confirmar: continua pendente.
insert into auth.users (id, email, raw_user_meta_data, aud, role)
values ('00000000-0000-0000-0000-0000000000b1', 'Dono@Exemplo.com',
        '{"nome": "Dono"}', 'authenticated', 'authenticated');
select is((select situacao::text from public.perfis where id = '00000000-0000-0000-0000-0000000000b1'),
          'pendente', 'email do dono NÃO confirmado continua pendente');
select is((select papel::text from public.perfis where id = '00000000-0000-0000-0000-0000000000b1'),
          'membro', 'e continua membro');

-- Ao confirmar o email, vira administrador aprovado.
update auth.users set email_confirmed_at = now()
 where id = '00000000-0000-0000-0000-0000000000b1';
select is((select situacao::text from public.perfis where id = '00000000-0000-0000-0000-0000000000b1'),
          'aprovado', 'ao confirmar o email do dono, a conta é aprovada');
select is((select papel::text from public.perfis where id = '00000000-0000-0000-0000-0000000000b1'),
          'administrador', 'e vira administrador');

-- Entrada pelo Google (já verificada na criação) também vale.
delete from public.administradores_iniciais;
insert into public.administradores_iniciais (email) values ('google.dono@exemplo.com');
insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role)
values ('00000000-0000-0000-0000-0000000000b2', 'google.dono@exemplo.com', now(),
        '{"full_name": "Dono Google"}', 'authenticated', 'authenticated');
select is((select papel::text from public.perfis where id = '00000000-0000-0000-0000-0000000000b2'),
          'administrador', 'dono entrando verificado pelo Google já é administrador');

-- Outro email verificado, fora da lista, segue pendente.
insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role)
values ('00000000-0000-0000-0000-0000000000b3', 'outra@exemplo.com', now(),
        '{"nome": "Outra"}', 'authenticated', 'authenticated');
select is((select situacao::text from public.perfis where id = '00000000-0000-0000-0000-0000000000b3'),
          'pendente', 'email fora da lista continua pendente');

-- Usuário comum não lê a lista de administradores iniciais.
select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000000b3", "role": "authenticated"}', true);
set local role authenticated;
select throws_ok($$ select * from public.administradores_iniciais $$,
                 '42501', null, 'usuário comum não acessa administradores_iniciais');
reset role;

select * from finish();
rollback;
