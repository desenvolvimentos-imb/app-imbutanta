-- Disponibilidade: acesso (RLS) e auxiliares de permissão, aplicados NO BANCO (RF-027).
-- Nenhuma das quatro tabelas é lida ou escrita direto: a grade mostra nomes de pessoas e só
-- líderes/administradores podem ver respostas alheias e observações (research.md decisão 4; ADR 0006).

alter table public.consultas_disponibilidade enable row level security;
alter table public.datas_consulta enable row level security;
alter table public.respostas_disponibilidade enable row level security;
alter table public.observacoes_disponibilidade enable row level security;

revoke all on public.consultas_disponibilidade from anon, authenticated;
revoke all on public.datas_consulta from anon, authenticated;
revoke all on public.respostas_disponibilidade from anon, authenticated;
revoke all on public.observacoes_disponibilidade from anon, authenticated;

-- A consulta está aberta? Não fechada e, havendo prazo, hoje (em São Paulo) ainda não passou dele:
-- o prazo vale até o FIM do dia (RF-007). Nenhuma tarefa agendada: é só esta comparação.
create function public.consulta_esta_aberta(p_consulta public.consultas_disponibilidade)
returns boolean
language sql
stable
set search_path = public
as $$
  select not p_consulta.fechada
         and (p_consulta.prazo is null or public.hoje_sp() <= p_consulta.prazo);
$$;

-- Confere que quem chama gere o ministério da consulta, TRAVA a linha da consulta e a devolve.
-- A trava (`for update`) faz "pessoa responde" e "líder fecha" acontecerem uma depois da outra
-- (research.md decisão 5). Consulta inexistente: o administrador é avisado (nao_encontrado); os
-- demais recebem sem_permissao, para não revelar quais consultas existem. Ministério desativado:
-- `exigir_gestor_ministerio` levanta ministerio_inativo (toda escrita exige ministério ativo).
-- A permissão é conferida ANTES da trava, para quem não pode não conseguir bloquear a consulta.
create function public.exigir_gestor_consulta(p_consulta uuid)
returns public.consultas_disponibilidade
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ministerio uuid;
  v_consulta public.consultas_disponibilidade;
begin
  if auth.uid() is null then
    raise exception 'sem_permissao';
  end if;
  select ministerio_id into v_ministerio from public.consultas_disponibilidade where id = p_consulta;
  if not found then
    raise exception using message =
      case when coalesce(public.papel_aprovado_atual() = 'administrador', false)
           then 'nao_encontrado' else 'sem_permissao' end;
  end if;
  perform public.exigir_gestor_ministerio(v_ministerio);
  select * into v_consulta from public.consultas_disponibilidade where id = p_consulta for update;
  return v_consulta;
end;
$$;

-- Confere que quem chama é participante aprovado do ministério da consulta (e que ela existe),
-- TRAVA a consulta e a devolve. Quem não participa recebe sem_permissao, sem revelar a existência.
create function public.exigir_participante_consulta(p_consulta uuid)
returns public.consultas_disponibilidade
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ministerio uuid;
  v_consulta public.consultas_disponibilidade;
begin
  if auth.uid() is null then
    raise exception 'sem_permissao';
  end if;
  select ministerio_id into v_ministerio from public.consultas_disponibilidade where id = p_consulta;
  if not found or not public.eh_participante_de(v_ministerio) then
    raise exception 'sem_permissao';
  end if;
  select * into v_consulta from public.consultas_disponibilidade where id = p_consulta for update;
  return v_consulta;
end;
$$;

revoke execute on function public.consulta_esta_aberta(public.consultas_disponibilidade) from public, anon, authenticated;
revoke execute on function public.exigir_gestor_consulta(uuid) from public, anon, authenticated;
revoke execute on function public.exigir_participante_consulta(uuid) from public, anon, authenticated;
