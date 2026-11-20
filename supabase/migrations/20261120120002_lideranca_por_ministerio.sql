-- A liderança passa a ser POR MINISTÉRIO: o papel global "líder" deixa de existir (RF-027).
-- Decisão e alternativas: specs/002-ministerios-participantes/research.md (decisão 1).

-- 1. Quem era "líder" global volta a ser membro. Só passa a liderar de novo quando um
--    administrador o vincular a um ministério. Nenhum outro dado é alterado.
update public.perfis set papel = 'membro' where papel = 'lider';

-- 2. O valor 'lider' continua no tipo (o Postgres não remove valores de enumeração sem recriar
--    o tipo, o que é arriscado em tabela em uso), mas ninguém mais pode gravá-lo.
alter table public.perfis
  add constraint perfis_papel_sem_lider check (papel <> 'lider');

-- 3. Sem líder global, a política que dava a ele leitura da fila deixa de fazer sentido.
--    Líderes passam a ver pedidos por funções que devolvem só nome (sem email).
drop policy perfis_ler_fila_lider on public.perfis;

-- 4. Decidir cadastro (aprovar/recusar a CONTA) passa a ser só do administrador. O líder decide
--    PEDIDOS de entrada no ministério dele (decidir_pedido_entrada). Assinatura inalterada.
create or replace function public.decidir_cadastro(
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
  -- Só o administrador APROVADO decide, e ninguém decide sobre si mesmo.
  if auth.uid() is null or v_papel is distinct from 'administrador' or p_perfil = auth.uid() then
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

  -- Atômico: só muda se a situação ainda for a que o aprovador viu na tela (RF-013 da 001).
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

-- 5. alterar_papel passa a recusar o papel 'lider' com um erro claro.
create or replace function public.alterar_papel(
  p_perfil uuid,
  p_papel public.papel_usuario,
  p_situacao_esperada public.situacao_conta
)
returns public.perfis
language plpgsql
security definer
set search_path = public
as $$
declare
  v_resultado public.perfis;
begin
  if auth.uid() is null or public.papel_aprovado_atual() is distinct from 'administrador' then
    raise exception 'sem_permissao';
  end if;

  -- Liderança não é mais um papel da pessoa: é uma participação em um ministério.
  if p_papel = 'lider' then
    raise exception 'transicao_invalida';
  end if;

  -- Papel só tem efeito para quem está aprovado.
  if p_situacao_esperada <> 'aprovado' then
    raise exception 'transicao_invalida';
  end if;

  -- Se for o único administrador sendo rebaixado, o gatilho levanta 'ultimo_administrador'.
  update public.perfis
     set papel = p_papel, decidido_por = auth.uid(), decidido_em = now()
   where id = p_perfil and situacao = p_situacao_esperada
  returning * into v_resultado;

  if not found then
    perform public.explicar_falha_gestao(p_perfil, p_situacao_esperada);
  end if;
  return v_resultado;
end;
$$;
