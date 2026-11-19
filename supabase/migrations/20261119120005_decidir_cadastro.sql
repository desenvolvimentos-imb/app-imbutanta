-- Aprovar ou recusar um cadastro pendente (RF-011, RF-012, RF-013).
-- Contrato: specs/001-login-papeis-acesso/contracts/banco-rpc.md
--
-- Erros levantados (a mensagem é o código; o app traduz para português):
--   sem_permissao, conflito_situacao, transicao_invalida, nao_encontrado

create function public.decidir_cadastro(
  p_perfil uuid,
  p_decisao text,
  p_situacao_esperada public.situacao_conta
)
returns public.perfis
language plpgsql
security definer
set search_path = public
as $$
declare
  v_papel public.papel_usuario := public.papel_aprovado_atual();
  v_nova public.situacao_conta;
  v_atual public.situacao_conta;
  v_resultado public.perfis;
begin
  -- Só administrador ou líder APROVADO decide, e ninguém decide sobre si mesmo.
  if auth.uid() is null or v_papel is null or v_papel not in ('lider', 'administrador')
     or p_perfil = auth.uid() then
    raise exception 'sem_permissao';
  end if;

  if p_decisao = 'aprovar' then
    v_nova := 'aprovado';
  elsif p_decisao = 'recusar' then
    v_nova := 'recusado';
  else
    raise exception 'transicao_invalida';
  end if;

  -- Esta função só trata da fila de pendentes. Reabrir recusados e remover acesso é
  -- exclusivo do administrador (alterar_situacao).
  if p_situacao_esperada <> 'pendente' then
    raise exception 'transicao_invalida';
  end if;

  -- Atômico: só muda se a situação ainda for a que o aprovador viu na tela (RF-013).
  update public.perfis
     set situacao = v_nova,
         papel = case when v_nova = 'aprovado' then 'membro' else papel end,
         decidido_por = auth.uid(),
         decidido_em = now()
   where id = p_perfil
     and situacao = p_situacao_esperada
     and email_verificado
  returning * into v_resultado;

  if found then
    return v_resultado;
  end if;

  select situacao into v_atual from public.perfis where id = p_perfil;
  if not found then
    raise exception 'nao_encontrado';
  elsif v_atual <> p_situacao_esperada then
    raise exception 'conflito_situacao';
  else
    -- Ainda pendente, mas com email não confirmado: não entra na fila.
    raise exception 'transicao_invalida';
  end if;
end;
$$;

revoke execute on function public.decidir_cadastro(uuid, text, public.situacao_conta) from public, anon;
grant execute on function public.decidir_cadastro(uuid, text, public.situacao_conta) to authenticated;
