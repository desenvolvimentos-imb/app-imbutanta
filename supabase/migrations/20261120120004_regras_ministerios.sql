-- Regras de integridade dos ministérios, aplicadas por gatilhos para valer até contra alteração
-- direta no banco (RF-012, RF-013, CS-006). Mesmo padrão do "último administrador" da 001.

-- Todo ministério ATIVO tem pelo menos um líder VÁLIDO (participação de líder + conta aprovada).
-- Este gatilho cobre rebaixar e apagar a participação, inclusive pela cascata da exclusão de
-- conta. O nome do ministério vai no detalhe do erro para a interface avisar qual é.
create function public.proteger_ultimo_lider()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ativo boolean;
  v_nome  text;
begin
  -- Só interessa se a linha ANTES era de um líder e, depois, deixa de ser (rebaixado ou apagado).
  if old.papel = 'lider'
     and (tg_op = 'DELETE' or new.papel <> 'lider'
          or new.ministerio_id <> old.ministerio_id or new.perfil_id <> old.perfil_id) then
    select ativo, nome into v_ativo, v_nome from public.ministerios where id = old.ministerio_id;

    -- Ministério desativado é só histórico: não exige líder.
    if v_ativo then
      -- Trava os líderes do ministério para que duas operações simultâneas não removam os dois.
      perform 1 from public.participacoes_ministerio pm
        where pm.ministerio_id = old.ministerio_id and pm.papel = 'lider'
        for update;

      if not exists (
        select 1
          from public.participacoes_ministerio pm
          join public.perfis p on p.id = pm.perfil_id and p.situacao = 'aprovado'
         where pm.ministerio_id = old.ministerio_id
           and pm.papel = 'lider'
           and pm.perfil_id <> old.perfil_id
      ) then
        raise exception 'ultimo_lider' using errcode = 'P0001', detail = v_nome;
      end if;
    end if;
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create trigger trg_proteger_ultimo_lider
before update or delete on public.participacoes_ministerio
for each row execute function public.proteger_ultimo_lider();

-- Quando a conta deixa de ser "aprovado" (recusada ou com acesso removido), ela deixa de contar
-- como líder válida: não pode ser a única líder de nenhum ministério ativo.
create function public.proteger_lideres_ao_perder_acesso()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
begin
  if old.situacao = 'aprovado' and new.situacao <> 'aprovado' then
    for r in
      select m.id, m.nome
        from public.participacoes_ministerio pm
        join public.ministerios m on m.id = pm.ministerio_id and m.ativo
       where pm.perfil_id = old.id and pm.papel = 'lider'
    loop
      perform 1 from public.participacoes_ministerio pm
        where pm.ministerio_id = r.id and pm.papel = 'lider'
        for update;

      if not exists (
        select 1
          from public.participacoes_ministerio pm
          join public.perfis p on p.id = pm.perfil_id and p.situacao = 'aprovado'
         where pm.ministerio_id = r.id
           and pm.papel = 'lider'
           and pm.perfil_id <> old.id
      ) then
        raise exception 'ultimo_lider' using errcode = 'P0001', detail = r.nome;
      end if;
    end loop;
  end if;
  return new;
end;
$$;

create trigger trg_proteger_lideres_ao_perder_acesso
before update of situacao on public.perfis
for each row execute function public.proteger_lideres_ao_perder_acesso();

-- Conta recusada ou sem acesso: os pedidos pendentes dela são cancelados, para não ficarem
-- "órfãos" na fila dos líderes. Reaprovar a conta NÃO reativa pedidos antigos.
create function public.cancelar_pedidos_da_conta()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.situacao in ('recusado', 'acesso_removido') and old.situacao is distinct from new.situacao then
    update public.pedidos_entrada_ministerio
       set situacao = 'cancelado', decidido_em = now()
     where perfil_id = new.id and situacao = 'pendente';
  end if;
  return new;
end;
$$;

create trigger trg_cancelar_pedidos_da_conta
after update of situacao on public.perfis
for each row execute function public.cancelar_pedidos_da_conta();
