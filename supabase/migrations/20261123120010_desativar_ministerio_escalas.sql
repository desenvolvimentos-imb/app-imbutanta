-- Desativar um ministério passa a cancelar as escalas futuras dele (FR-020).
-- Ajuste da funcionalidade 002: `desativar_ministerio` e um contador para o aviso que o app mostra
-- ao administrador ANTES de ele confirmar. Escalas passadas e as que já estavam canceladas não
-- mudam; vagas e respostas continuam gravadas (a escala é só marcada como cancelada), e os pedidos
-- de troca pendentes dessas escalas perdem efeito.

-- Quantas escalas serão canceladas se este ministério for desativado agora: não canceladas, de
-- hoje em diante (rascunhos e publicadas). Só o administrador.
create function public.contar_escalas_futuras(p_ministerio uuid)
returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public.exigir_administrador();
  return (
    select count(*)::integer
      from public.escalas e
     where e.ministerio_id = p_ministerio
       and e.situacao <> 'cancelada'
       and e.data >= public.hoje_sp()
  );
end;
$$;
revoke execute on function public.contar_escalas_futuras(uuid) from public, anon;
grant execute on function public.contar_escalas_futuras(uuid) to authenticated;

-- Mesma assinatura e mesmo comportamento da 002 (só administrador; nada é apagado; idempotente),
-- mais o cancelamento das escalas futuras na MESMA transação.
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

  return v_ministerio;
end;
$$;
