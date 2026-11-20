-- T006: regras básicas dos pedidos de entrada e da limpeza de vínculos (RF-018, RF-020, RF-037).
begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role) values
  ('00000000-0000-0000-0000-000000000d01', 'm1.p@exemplo.com', now(), '{"nome":"Membro Um P"}',   'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000d02', 'm2.p@exemplo.com', now(), '{"nome":"Pendente P"}',    'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000d03', 'm3.p@exemplo.com', now(), '{"nome":"Membro Tres P"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000d04', 'm4.p@exemplo.com', now(), '{"nome":"Membro Quatro P"}', 'authenticated', 'authenticated');
update public.perfis set situacao = 'aprovado' where id in
  ('00000000-0000-0000-0000-000000000d01', '00000000-0000-0000-0000-000000000d03', '00000000-0000-0000-0000-000000000d04');

insert into public.ministerios (id, nome, descricao) values
  ('00000000-0000-0000-0000-00000000dd0a', 'Teste Pedidos A', ''),
  ('00000000-0000-0000-0000-00000000dd0c', 'Teste Pedidos C', '');

-- ===== Pedido pendente único por pessoa e ministério =====
insert into public.pedidos_entrada_ministerio (ministerio_id, perfil_id) values
  ('00000000-0000-0000-0000-00000000dd0a', '00000000-0000-0000-0000-000000000d01');
select throws_ok($$ insert into public.pedidos_entrada_ministerio (ministerio_id, perfil_id)
                    values ('00000000-0000-0000-0000-00000000dd0a', '00000000-0000-0000-0000-000000000d01') $$,
                 '23505', null, 'dois pedidos pendentes iguais são barrados');
select lives_ok($$ insert into public.pedidos_entrada_ministerio (ministerio_id, perfil_id)
                    values ('00000000-0000-0000-0000-00000000dd0c', '00000000-0000-0000-0000-000000000d01') $$,
                'a mesma pessoa pode pedir outro ministério');

-- Pedidos já decididos não impedem um novo pedido (RF-020).
update public.pedidos_entrada_ministerio set situacao = 'recusado', decidido_em = now()
 where ministerio_id = '00000000-0000-0000-0000-00000000dd0a' and perfil_id = '00000000-0000-0000-0000-000000000d01';
select lives_ok($$ insert into public.pedidos_entrada_ministerio (ministerio_id, perfil_id)
                    values ('00000000-0000-0000-0000-00000000dd0a', '00000000-0000-0000-0000-000000000d01') $$,
                'depois de recusado, a pessoa pode pedir de novo');
update public.pedidos_entrada_ministerio set situacao = 'cancelado', decidido_em = now()
 where ministerio_id = '00000000-0000-0000-0000-00000000dd0a' and perfil_id = '00000000-0000-0000-0000-000000000d01'
   and situacao = 'pendente';
select lives_ok($$ insert into public.pedidos_entrada_ministerio (ministerio_id, perfil_id)
                    values ('00000000-0000-0000-0000-00000000dd0a', '00000000-0000-0000-0000-000000000d01') $$,
                'depois de cancelado, a pessoa pode pedir de novo');

-- ===== Conta recusada: os pedidos pendentes são cancelados =====
insert into public.pedidos_entrada_ministerio (ministerio_id, perfil_id) values
  ('00000000-0000-0000-0000-00000000dd0a', '00000000-0000-0000-0000-000000000d02'),
  ('00000000-0000-0000-0000-00000000dd0c', '00000000-0000-0000-0000-000000000d02');
update public.perfis set situacao = 'recusado' where id = '00000000-0000-0000-0000-000000000d02';
select is((select count(*) from public.pedidos_entrada_ministerio
            where perfil_id = '00000000-0000-0000-0000-000000000d02' and situacao = 'pendente'),
          0::bigint, 'conta recusada: nenhum pedido continua pendente');
select is((select count(*) from public.pedidos_entrada_ministerio
            where perfil_id = '00000000-0000-0000-0000-000000000d02' and situacao = 'cancelado'),
          2::bigint, 'conta recusada: os pedidos viraram cancelados');
select isnt((select min(decidido_em) from public.pedidos_entrada_ministerio
              where perfil_id = '00000000-0000-0000-0000-000000000d02'),
            null, 'o cancelamento automático registra quando aconteceu');

-- ===== Acesso removido: idem =====
insert into public.pedidos_entrada_ministerio (ministerio_id, perfil_id) values
  ('00000000-0000-0000-0000-00000000dd0a', '00000000-0000-0000-0000-000000000d03');
update public.perfis set situacao = 'acesso_removido' where id = '00000000-0000-0000-0000-000000000d03';
select is((select situacao::text from public.pedidos_entrada_ministerio
            where perfil_id = '00000000-0000-0000-0000-000000000d03'),
          'cancelado', 'acesso removido: o pedido pendente foi cancelado');

-- Reaprovar a conta NÃO ressuscita pedidos antigos.
update public.perfis set situacao = 'aprovado' where id = '00000000-0000-0000-0000-000000000d03';
select is((select situacao::text from public.pedidos_entrada_ministerio
            where perfil_id = '00000000-0000-0000-0000-000000000d03'),
          'cancelado', 'reaprovar a conta não reativa o pedido cancelado');

-- ===== Excluir a conta apaga vínculos e pedidos (LGPD, RF-037) =====
insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel) values
  ('00000000-0000-0000-0000-00000000dd0a', '00000000-0000-0000-0000-000000000d04', 'participante');
insert into public.pedidos_entrada_ministerio (ministerio_id, perfil_id) values
  ('00000000-0000-0000-0000-00000000dd0c', '00000000-0000-0000-0000-000000000d04');
select lives_ok($$ delete from auth.users where id = '00000000-0000-0000-0000-000000000d04' $$,
                'quem não é a única liderança consegue excluir a conta');
select is((select count(*) from public.participacoes_ministerio where perfil_id = '00000000-0000-0000-0000-000000000d04'),
          0::bigint, 'as participações saíram junto com a conta');
select is((select count(*) from public.pedidos_entrada_ministerio where perfil_id = '00000000-0000-0000-0000-000000000d04'),
          0::bigint, 'os pedidos saíram junto com a conta');
select is((select count(*) from public.ministerios where id in
            ('00000000-0000-0000-0000-00000000dd0a', '00000000-0000-0000-0000-00000000dd0c')),
          2::bigint, 'os ministérios continuam existindo');

select * from finish();
rollback;
