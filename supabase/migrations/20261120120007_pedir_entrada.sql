-- Pedidos de entrada em ministérios (RF-015 a RF-018).
-- Contrato: specs/002-ministerios-participantes/contracts/banco-rpc.md
--
-- Erros levantados (a mensagem é o código; o app traduz para português):
--   sem_permissao, nao_encontrado, ministerio_inativo, ja_participa, pedido_duplicado

-- Cria os pedidos que a pessoa marcou no cadastro por email e senha. A lista de ministérios vai
-- nos metadados do cadastro (`raw_user_meta_data.ministerios`). Metadados são controlados por
-- quem se cadastra, então cada item é conferido: tem de ser um UUID de ministério ATIVO. O que
-- for inválido é ignorado, no máximo 30 pedidos nascem, e NADA aqui pode impedir a criação da
-- conta (RF-015): qualquer falha vira só um aviso no log do banco.
create function public.criar_pedidos_do_cadastro(p_perfil uuid, p_meta jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if jsonb_typeof(p_meta -> 'ministerios') is distinct from 'array' then
    return;
  end if;

  insert into public.pedidos_entrada_ministerio (ministerio_id, perfil_id, origem_cadastro)
  select m.id, p_perfil, true
    from public.ministerios m
   where m.ativo
     and m.id::text in (
       select lower(btrim(item))
         from (select jsonb_array_elements_text(p_meta -> 'ministerios') as item limit 200) itens
        where btrim(item) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
     )
   order by m.nome
   limit 30;
exception when others then
  raise warning 'criar_pedidos_do_cadastro falhou para %: %', p_perfil, sqlerrm;
end;
$$;

revoke execute on function public.criar_pedidos_do_cadastro(uuid, jsonb) from public, anon, authenticated;

-- Mesma função da 001, com uma chamada nova no `insert` da conta: criar os pedidos marcados no
-- cadastro. Alterar metadados depois NÃO cria pedidos (só o insert conta).
create or replace function public.sincronizar_perfil_auth()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email      text := lower(new.email);
  v_verificado boolean := new.email_confirmed_at is not null;
  v_acabou_de_verificar boolean;
begin
  if tg_op = 'INSERT' then
    insert into public.perfis (id, nome, email, email_verificado)
    values (new.id, public.nome_dos_metadados(new.raw_user_meta_data, v_email), v_email, v_verificado);
    v_acabou_de_verificar := v_verificado;
    perform public.criar_pedidos_do_cadastro(new.id, new.raw_user_meta_data);
  else
    update public.perfis
       set email = v_email, email_verificado = v_verificado
     where id = new.id;
    v_acabou_de_verificar := v_verificado and old.email_confirmed_at is null;
  end if;

  -- Administrador inicial: só vale com email VERIFICADO, para que um terceiro não vire
  -- administrador criando uma conta com o email do dono do projeto.
  if v_acabou_de_verificar
     and exists (select 1 from public.administradores_iniciais where email = v_email) then
    update public.perfis
       set situacao = 'aprovado', papel = 'administrador'
     where id = new.id;
  end if;

  return new;
end;
$$;

-- Pede para entrar em um ministério. Vale para conta aprovada e também para conta pendente
-- (quem entrou por Google escolhe os ministérios na tela de espera). Contas recusadas ou sem
-- acesso não pedem. O pedido só vira participação quando um líder (ou o administrador) aceita.
create function public.pedir_entrada_ministerio(p_ministerio uuid)
returns public.pedidos_entrada_ministerio
language plpgsql
security definer
set search_path = public
as $$
declare
  v_situacao public.situacao_conta;
  v_ministerio public.ministerios;
  v_pedido public.pedidos_entrada_ministerio;
begin
  if auth.uid() is null then
    raise exception 'sem_permissao';
  end if;

  select situacao into v_situacao from public.perfis where id = auth.uid();
  if v_situacao is null or v_situacao not in ('aprovado', 'pendente') then
    raise exception 'sem_permissao';
  end if;

  select * into v_ministerio from public.ministerios where id = p_ministerio;
  if not found then
    raise exception 'nao_encontrado';
  end if;
  if not v_ministerio.ativo then
    raise exception 'ministerio_inativo';
  end if;

  if exists (
    select 1 from public.participacoes_ministerio
     where ministerio_id = p_ministerio and perfil_id = auth.uid()
  ) then
    raise exception 'ja_participa';
  end if;

  begin
    insert into public.pedidos_entrada_ministerio (ministerio_id, perfil_id, origem_cadastro)
    values (p_ministerio, auth.uid(), v_situacao = 'pendente')
    returning * into v_pedido;
  exception when unique_violation then
    raise exception 'pedido_duplicado';
  end;

  return v_pedido;
end;
$$;

revoke execute on function public.pedir_entrada_ministerio(uuid) from public, anon;
grant execute on function public.pedir_entrada_ministerio(uuid) to authenticated;
