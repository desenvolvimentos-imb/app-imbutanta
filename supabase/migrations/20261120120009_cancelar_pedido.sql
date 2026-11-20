-- Cancelar o próprio pedido de entrada (RF-017).
-- Contrato: specs/002-ministerios-participantes/contracts/banco-rpc.md
--
-- Erros levantados (a mensagem é o código): nao_encontrado, conflito_pedido

-- Só a própria pessoa cancela, e só enquanto o pedido está pendente. Pedido de outra pessoa
-- responde "não encontrado" para não revelar que ele existe. Depois de cancelado, a pessoa pode
-- pedir de novo (o índice único só vale para pedidos pendentes).
create function public.cancelar_pedido_entrada(p_pedido uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pedido public.pedidos_entrada_ministerio;
begin
  if auth.uid() is null then
    raise exception 'sem_permissao';
  end if;

  select * into v_pedido
    from public.pedidos_entrada_ministerio
   where id = p_pedido and perfil_id = auth.uid()
   for update;
  if not found then
    raise exception 'nao_encontrado';
  end if;

  if v_pedido.situacao <> 'pendente' then
    raise exception 'conflito_pedido';
  end if;

  update public.pedidos_entrada_ministerio
     set situacao = 'cancelado', decidido_por = auth.uid(), decidido_em = now()
   where id = p_pedido;
end;
$$;

revoke execute on function public.cancelar_pedido_entrada(uuid) from public, anon;
grant execute on function public.cancelar_pedido_entrada(uuid) to authenticated;
