-- Disponibilidade: o líder preenche ou corrige a resposta de um participante (RF-021), inclusive com
-- a consulta fechada, para quem respondeu por outro meio. Grava `preenchida_por` para o app marcar
-- "preenchido pelo líder"; quando a própria pessoa altera depois, a marca some. Não mexe na
-- observação (ela é da própria pessoa).
create function public.preencher_disponibilidade(p_consulta uuid, p_perfil uuid, p_respostas jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_consulta public.consultas_disponibilidade;
begin
  -- Trava a consulta e exige gestor e ministério ativo; NÃO exige consulta aberta.
  v_consulta := public.exigir_gestor_consulta(p_consulta);

  if not exists (
    select 1 from public.participacoes_ministerio pm
      join public.perfis p on p.id = pm.perfil_id and p.situacao = 'aprovado'
     where pm.ministerio_id = v_consulta.ministerio_id and pm.perfil_id = p_perfil
  ) then
    raise exception 'nao_participante';
  end if;

  perform public.gravar_respostas_disponibilidade(p_consulta, p_perfil, p_respostas, auth.uid(), true);
  return jsonb_build_object('salvo', true);
end;
$$;
revoke execute on function public.preencher_disponibilidade(uuid, uuid, jsonb) from public, anon;
grant execute on function public.preencher_disponibilidade(uuid, uuid, jsonb) to authenticated;
