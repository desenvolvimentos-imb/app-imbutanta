-- Decidir pedidos de entrada e listá-los para quem decide (RF-019 a RF-028).
-- Contrato: specs/002-ministerios-participantes/contracts/banco-rpc.md
--
-- Erros levantados (a mensagem é o código; o app traduz para português):
--   sem_permissao, nao_encontrado, ministerio_inativo, conflito_pedido, transicao_invalida

-- Aceita ou recusa um pedido. Quem decide: administrador ou líder VÁLIDO do ministério do
-- pedido; ninguém decide o próprio pedido.
--  * 'aceitar': cria a participação e, se a conta ainda está pendente (com email confirmado),
--    ativa a conta como membro — tudo em uma transação (RF-023);
--  * 'recusar': só marca o pedido; NÃO mexe na conta (RF-020, RF-024).
-- `p_situacao_esperada` (sempre 'pendente') protege contra decisões conflitantes (RF-021).
create function public.decidir_pedido_entrada(
  p_pedido uuid,
  p_decisao text,
  p_situacao_esperada public.situacao_pedido
)
returns public.pedidos_entrada_ministerio
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin boolean;
  v_pedido public.pedidos_entrada_ministerio;
  v_ativo boolean;
  v_conta public.perfis;
begin
  if auth.uid() is null then
    raise exception 'sem_permissao';
  end if;
  -- coalesce: para conta pendente, recusada ou sem acesso `papel_aprovado_atual()` é NULL, e um NULL
  -- aqui faria o `if`/`not` abaixo pular a checagem de permissão. Sempre verdadeiro ou falso.
  v_admin := coalesce(public.papel_aprovado_atual() = 'administrador', false);

  -- Trava o pedido: duas decisões simultâneas não passam juntas.
  select * into v_pedido from public.pedidos_entrada_ministerio where id = p_pedido for update;
  if not found then
    raise exception using message = case when v_admin then 'nao_encontrado' else 'sem_permissao' end;
  end if;

  if not (v_admin or public.eh_lider_de(v_pedido.ministerio_id)) or v_pedido.perfil_id = auth.uid() then
    raise exception 'sem_permissao';
  end if;

  if p_decisao not in ('aceitar', 'recusar') or p_situacao_esperada is distinct from 'pendente' then
    raise exception 'transicao_invalida';
  end if;
  if v_pedido.situacao <> p_situacao_esperada then
    raise exception 'conflito_pedido';
  end if;

  select ativo into v_ativo from public.ministerios where id = v_pedido.ministerio_id;
  if not v_ativo then
    raise exception 'ministerio_inativo';
  end if;

  if p_decisao = 'recusar' then
    update public.pedidos_entrada_ministerio
       set situacao = 'recusado', decidido_por = auth.uid(), decidido_em = now()
     where id = p_pedido
    returning * into v_pedido;
    return v_pedido;
  end if;

  -- Aceitar: confere a conta da pessoa.
  select * into v_conta from public.perfis where id = v_pedido.perfil_id for update;
  if not found or v_conta.situacao not in ('aprovado', 'pendente')
     or (v_conta.situacao = 'pendente' and not v_conta.email_verificado) then
    raise exception 'transicao_invalida';
  end if;

  if v_conta.situacao = 'pendente' then
    update public.perfis
       set situacao = 'aprovado', papel = 'membro', decidido_por = auth.uid(), decidido_em = now()
     where id = v_conta.id;
  end if;

  insert into public.participacoes_ministerio (ministerio_id, perfil_id, papel, adicionado_por)
  values (v_pedido.ministerio_id, v_pedido.perfil_id, 'participante', auth.uid())
  on conflict (ministerio_id, perfil_id) do nothing;

  update public.pedidos_entrada_ministerio
     set situacao = 'aceito', decidido_por = auth.uid(), decidido_em = now()
   where id = p_pedido
  returning * into v_pedido;
  return v_pedido;
end;
$$;

-- Pedidos pendentes que a pessoa logada pode decidir (RF-028): o administrador vê os de todos os
-- ministérios ativos; o líder, só os dos ministérios que lidera. Só entram contas aprovadas ou
-- pendentes com email confirmado, e nunca o próprio pedido. Devolve só nome (nunca email).
create function public.listar_pedidos_pendentes()
returns table (
  pedido_id uuid,
  ministerio_id uuid,
  ministerio_nome text,
  perfil_id uuid,
  nome text,
  criado_em timestamptz,
  conta_pendente boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
#variable_conflict use_column
declare
  v_admin boolean := coalesce(auth.uid() is not null and public.papel_aprovado_atual() = 'administrador', false);
begin
  if auth.uid() is null then
    return;
  end if;

  return query
    select pe.id, m.id, m.nome, p.id, p.nome, pe.criado_em, (p.situacao = 'pendente')
      from public.pedidos_entrada_ministerio pe
      join public.ministerios m on m.id = pe.ministerio_id and m.ativo
      join public.perfis p on p.id = pe.perfil_id
     where pe.situacao = 'pendente'
       and pe.perfil_id <> auth.uid()
       and (p.situacao = 'aprovado' or (p.situacao = 'pendente' and p.email_verificado))
       and (
         v_admin
         or exists (
           select 1
             from public.participacoes_ministerio pm
             join public.perfis lider on lider.id = pm.perfil_id and lider.situacao = 'aprovado'
            where pm.ministerio_id = pe.ministerio_id
              and pm.perfil_id = auth.uid()
              and pm.papel = 'lider'
         )
       )
     order by pe.criado_em;
end;
$$;

create function public.contar_pedidos_pendentes()
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::integer from public.listar_pedidos_pendentes();
$$;

revoke execute on function public.decidir_pedido_entrada(uuid, text, public.situacao_pedido) from public, anon;
grant execute on function public.decidir_pedido_entrada(uuid, text, public.situacao_pedido) to authenticated;
revoke execute on function public.listar_pedidos_pendentes() from public, anon;
grant execute on function public.listar_pedidos_pendentes() to authenticated;
revoke execute on function public.contar_pedidos_pendentes() from public, anon;
grant execute on function public.contar_pedidos_pendentes() to authenticated;
