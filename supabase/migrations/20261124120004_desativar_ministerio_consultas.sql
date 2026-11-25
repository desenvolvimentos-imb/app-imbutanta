-- Desativar um ministério passa a fechar as consultas de disponibilidade abertas dele (RF-013).
-- Ajuste de `desativar_ministerio` (002/003): mesma assinatura e mesmo comportamento da versão da 003
-- (só administrador; cancela escalas futuras; nada é apagado; idempotente), mais o fechamento das
-- consultas abertas na MESMA transação. As respostas continuam gravadas (histórico).
create or replace function public.desativar_ministerio(p_id uuid)
returns public.ministerios
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ministerio public.ministerios;
begin
  perform public.exigir_administrador();

  update public.ministerios
     set ativo = false, desativado_em = coalesce(desativado_em, now())
   where id = p_id
  returning * into v_ministerio;

  if not found then
    raise exception 'nao_encontrado';
  end if;

  update public.pedidos_troca
     set situacao = 'sem_efeito', decidido_em = now()
   where situacao in ('aguardando_indicada', 'aguardando_lider')
     and escala_id in (
       select e.id from public.escalas e
        where e.ministerio_id = p_id and e.situacao <> 'cancelada' and e.data >= public.hoje_sp()
     );

  update public.escalas
     set situacao = 'cancelada', cancelada_em = now(), atualizada_em = now()
   where ministerio_id = p_id
     and situacao <> 'cancelada'
     and data >= public.hoje_sp();

  -- Consultas abertas (não fechadas) passam a fechadas; as já fechadas não mudam.
  update public.consultas_disponibilidade
     set fechada = true, atualizada_em = now()
   where ministerio_id = p_id
     and not fechada;

  return v_ministerio;
end;
$$;
