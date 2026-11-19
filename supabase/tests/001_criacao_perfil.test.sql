-- T009: ao criar um usuário no Supabase Auth, o gatilho cria o perfil com situação
-- "pendente" e papel "membro" (RF-008), e mantém email/verificação sincronizados.
begin;
create extension if not exists pgtap with schema extensions;
select plan(11);

-- Cadastro por email/senha: nome vem dos metadados, com espaços nas pontas.
insert into auth.users (id, email, raw_user_meta_data, aud, role)
values ('00000000-0000-0000-0000-0000000000a1', 'Maria@Exemplo.com',
        '{"nome": "  Maria Silva  "}', 'authenticated', 'authenticated');

select is((select nome from public.perfis where id = '00000000-0000-0000-0000-0000000000a1'),
          'Maria Silva', 'nome vem dos metadados, sem espaços nas pontas');
select is((select situacao::text from public.perfis where id = '00000000-0000-0000-0000-0000000000a1'),
          'pendente', 'conta nova começa pendente');
select is((select papel::text from public.perfis where id = '00000000-0000-0000-0000-0000000000a1'),
          'membro', 'papel padrão é membro');
select is((select email from public.perfis where id = '00000000-0000-0000-0000-0000000000a1'),
          'maria@exemplo.com', 'email é guardado em minúsculas');
select is((select email_verificado from public.perfis where id = '00000000-0000-0000-0000-0000000000a1'),
          false, 'email não confirmado fica como não verificado');

-- Confirmar o email atualiza o perfil.
update auth.users set email_confirmed_at = now()
 where id = '00000000-0000-0000-0000-0000000000a1';
select is((select email_verificado from public.perfis where id = '00000000-0000-0000-0000-0000000000a1'),
          true, 'confirmar o email marca o perfil como verificado');

-- Trocar o email no Auth atualiza a cópia no perfil.
update auth.users set email = 'maria.nova@exemplo.com'
 where id = '00000000-0000-0000-0000-0000000000a1';
select is((select email from public.perfis where id = '00000000-0000-0000-0000-0000000000a1'),
          'maria.nova@exemplo.com', 'troca de email é sincronizada');

-- Login com Google: sem "nome", usa "full_name"; já chega verificado.
insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role)
values ('00000000-0000-0000-0000-0000000000a2', 'joao@exemplo.com', now(),
        '{"full_name": "João Pereira"}', 'authenticated', 'authenticated');
select is((select nome from public.perfis where id = '00000000-0000-0000-0000-0000000000a2'),
          'João Pereira', 'nome do Google (full_name) é usado');
select is((select email_verificado from public.perfis where id = '00000000-0000-0000-0000-0000000000a2'),
          true, 'cadastro com Google já chega verificado');

-- Sem nenhum nome nos metadados, o cadastro não pode falhar.
insert into auth.users (id, email, aud, role)
values ('00000000-0000-0000-0000-0000000000a3', 'sem.nome@exemplo.com', 'authenticated', 'authenticated');
select ok(exists (select 1 from public.perfis where id = '00000000-0000-0000-0000-0000000000a3'),
          'perfil é criado mesmo sem nome nos metadados');

-- Apagar o usuário do Auth apaga o perfil (base da exclusão de conta, RF-031).
delete from auth.users where id = '00000000-0000-0000-0000-0000000000a3';
select is((select count(*) from public.perfis where id = '00000000-0000-0000-0000-0000000000a3'),
          0::bigint, 'apagar o usuário apaga o perfil');

select * from finish();
rollback;
