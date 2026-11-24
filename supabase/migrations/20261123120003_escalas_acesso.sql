-- Escalas: regras de acesso (RLS) e auxiliares de permissão, aplicadas NO BANCO (FR-025).
-- Só `funcoes_ministerio` pode ser lida direto (e só o nome). O resto é lido e escrito por funções
-- `security definer`, porque as vagas mostram nomes de pessoas e as respostas só podem ser vistas
-- por quem de direito (research.md, decisão 3; ADR 0006).

alter table public.funcoes_ministerio enable row level security;
alter table public.aptidoes enable row level security;
alter table public.escalas enable row level security;
alter table public.vagas_escala enable row level security;
alter table public.respostas_escala enable row level security;
alter table public.pedidos_troca enable row level security;

revoke all on public.funcoes_ministerio from anon, authenticated;
revoke all on public.aptidoes from anon, authenticated;
revoke all on public.escalas from anon, authenticated;
revoke all on public.vagas_escala from anon, authenticated;
revoke all on public.respostas_escala from anon, authenticated;
revoke all on public.pedidos_troca from anon, authenticated;

-- A pessoa logada participa deste ministério (qualquer papel, conta aprovada)? Não exige que o
-- ministério esteja ativo: quem participou ainda pode LER (somente leitura) as escalas dele.
create function public.eh_participante_de(p_ministerio uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.participacoes_ministerio pm
      join public.perfis p on p.id = pm.perfil_id and p.situacao = 'aprovado'
     where pm.ministerio_id = p_ministerio
       and pm.perfil_id = auth.uid()
  );
$$;

-- Administrador aprovado ou líder válido do ministério (ver `eh_lider_de`, da 002).
create function public.eh_gestor_de(p_ministerio uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.papel_aprovado_atual() = 'administrador', false)
         or public.eh_lider_de(p_ministerio);
$$;

revoke execute on function public.eh_participante_de(uuid) from public, anon;
grant execute on function public.eh_participante_de(uuid) to authenticated;
revoke execute on function public.eh_gestor_de(uuid) from public, anon;
grant execute on function public.eh_gestor_de(uuid) to authenticated;

-- Única leitura direta: funções do ministério, para quem participa dele, o lidera ou administra.
-- Contém só o nome da função (nada pessoal).
grant select on public.funcoes_ministerio to authenticated;
create policy funcoes_ler on public.funcoes_ministerio
  for select to authenticated
  using (public.eh_participante_de(ministerio_id) or public.eh_gestor_de(ministerio_id));

-- Auxiliar interna das funções de escrita: confere que quem chama gere o ministério da escala,
-- TRAVA a linha da escala e a devolve. A trava (`for update`) faz duas alterações simultâneas na
-- mesma escala acontecerem uma depois da outra, nunca misturadas (research.md, decisão 4).
--  * escala inexistente: administrador é avisado (nao_encontrado); os demais recebem
--    sem_permissao, para não revelar quais escalas existem;
--  * ministério desativado: `exigir_gestor_ministerio` levanta ministerio_inativo (toda escrita
--    exige ministério ativo, inclusive para o administrador).
-- A permissão é conferida ANTES da trava, para quem não pode não conseguir bloquear a escala.
create function public.exigir_gestor_escala(p_escala uuid)
returns public.escalas
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ministerio uuid;
  v_escala public.escalas;
begin
  if auth.uid() is null then
    raise exception 'sem_permissao';
  end if;
  select ministerio_id into v_ministerio from public.escalas where id = p_escala;
  if not found then
    raise exception using message =
      case when coalesce(public.papel_aprovado_atual() = 'administrador', false)
           then 'nao_encontrado' else 'sem_permissao' end;
  end if;
  perform public.exigir_gestor_ministerio(v_ministerio);
  select * into v_escala from public.escalas where id = p_escala for update;
  return v_escala;
end;
$$;

-- Confere que a escala ainda pode ser alterada: não cancelada e ainda não "encerrada" (FR-007:
-- a partir do dia seguinte à data ela é só leitura).
create function public.exigir_escala_editavel(p_escala public.escalas)
returns void
language plpgsql
stable
set search_path = public
as $$
begin
  if p_escala.situacao = 'cancelada' then
    raise exception 'escala_cancelada';
  end if;
  if public.hoje_sp() > p_escala.data then
    raise exception 'escala_somente_leitura';
  end if;
end;
$$;

revoke execute on function public.exigir_gestor_escala(uuid) from public, anon, authenticated;
revoke execute on function public.exigir_escala_editavel(public.escalas) from public, anon, authenticated;
