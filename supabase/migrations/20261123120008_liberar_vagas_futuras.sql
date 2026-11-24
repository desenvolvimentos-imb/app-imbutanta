-- Efeito nas escalas quando alguém sai do ministério ou perde o acesso (FR-019).
-- As vagas FUTURAS da pessoa (escalas não canceladas com data de hoje em diante) ficam em aberto, a
-- resposta dela some e os pedidos de troca pendentes em que ela aparece perdem efeito. Escalas
-- passadas e canceladas ficam como estão (histórico). Quem avisa o líder é a própria escala, que
-- mostra a vaga "em aberto" em destaque e o aviso na página do ministério (sem notificações).
-- Vale por gatilho no banco, venha a mudança da tela, de outra função ou da exclusão de conta.

create function public.liberar_vagas_futuras(p_perfil uuid, p_ministerio uuid default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_futuras uuid[];
begin
  -- Escalas que ainda podem mudar (não canceladas, de hoje em diante), do ministério ou de todos.
  select coalesce(array_agg(e.id), '{}') into v_futuras
    from public.escalas e
   where e.situacao <> 'cancelada'
     and e.data >= public.hoje_sp()
     and (p_ministerio is null or e.ministerio_id = p_ministerio);

  if cardinality(v_futuras) = 0 then
    return;
  end if;

  -- Pedidos de troca pendentes em que a pessoa aparece (pedindo OU indicada) perdem efeito, mesmo
  -- que ela não ocupe vaga nessa escala: quem foi indicada e saiu do ministério não pode assumir.
  update public.pedidos_troca
     set situacao = 'sem_efeito', decidido_em = now()
   where escala_id = any (v_futuras)
     and situacao in ('aguardando_indicada', 'aguardando_lider')
     and (solicitante_id = p_perfil or indicada_id = p_perfil);

  update public.escalas set atualizada_em = now()
   where id in (select v.escala_id from public.vagas_escala v
                 where v.escala_id = any (v_futuras) and v.perfil_id = p_perfil);

  update public.vagas_escala set perfil_id = null
   where escala_id = any (v_futuras) and perfil_id = p_perfil;

  delete from public.respostas_escala
   where escala_id = any (v_futuras) and perfil_id = p_perfil;
end;
$$;
revoke execute on function public.liberar_vagas_futuras(uuid, uuid) from public, anon, authenticated;

-- Saiu do ministério (removido por um líder, por si mesmo ou por cascata): libera as vagas dele.
create function public.liberar_vagas_ao_sair_do_ministerio()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.liberar_vagas_futuras(old.perfil_id, old.ministerio_id);
  return old;
end;
$$;

create trigger trg_liberar_vagas_ao_sair_do_ministerio
  after delete on public.participacoes_ministerio
  for each row execute function public.liberar_vagas_ao_sair_do_ministerio();

-- A conta deixou de ser "aprovado" (acesso removido ou recusada): libera as vagas futuras em TODOS
-- os ministérios. Reaprovar depois não devolve as vagas: o líder reorganiza.
create function public.liberar_vagas_ao_perder_acesso()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.situacao = 'aprovado' and new.situacao <> 'aprovado' then
    perform public.liberar_vagas_futuras(new.id, null);
  end if;
  return new;
end;
$$;

create trigger trg_liberar_vagas_ao_perder_acesso
  after update of situacao on public.perfis
  for each row execute function public.liberar_vagas_ao_perder_acesso();
