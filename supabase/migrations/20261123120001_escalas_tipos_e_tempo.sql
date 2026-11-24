-- Escalas dos ministérios (specs/003-escalas-ministerios): tipos e funções de tempo.
-- Detalhes e o porquê: specs/003-escalas-ministerios/data-model.md e research.md.

-- Em quais funções uma pessoa é apta. Nesta funcionalidade ambas contam como "apto" (FR-004).
create type public.tipo_aptidao as enum ('principal', 'secundaria');

-- Situação de uma escala (FR-011).
create type public.situacao_escala as enum ('rascunho', 'publicada', 'cancelada');

-- Resposta de quem está escalado. "Pendente" NÃO é um valor: é a ausência de linha em
-- `respostas_escala` (research.md, decisão 1).
create type public.resposta_escala as enum ('confirmado', 'recusado');

-- Situação de um pedido de troca (data-model.md, transições).
create type public.situacao_troca as enum (
  'aguardando_indicada', 'aguardando_lider', 'aprovado',
  'recusado_indicada', 'recusado_lider', 'cancelado', 'sem_efeito'
);

-- O "agora" de TODAS as regras de data das escalas passa por esta função. Em produção é só now().
-- Não há nenhum gancho de teste aqui de propósito: os testes a redefinem dentro da própria
-- transação (que termina em rollback), e assim nada no app permite "mudar o relógio"
-- (research.md, decisão 2).
create function public.agora_sp()
returns timestamptz
language sql
stable
set search_path = ''
as $$
  select now();
$$;

-- Data de hoje no fuso da igreja (America/Sao_Paulo), não no fuso do servidor.
create function public.hoje_sp()
returns date
language sql
stable
set search_path = ''
as $$
  select (public.agora_sp() at time zone 'America/Sao_Paulo')::date;
$$;

-- Instante de início de uma escala. Imutável: com o fuso fixo, a mesma data e hora sempre dão o
-- mesmo instante, e isso permite usá-la em índices e comparações sem surpresa.
create function public.inicio_da_escala(p_data date, p_horario time)
returns timestamptz
language sql
immutable
set search_path = ''
as $$
  select (p_data + p_horario) at time zone 'America/Sao_Paulo';
$$;

-- Mesma normalização do nome de ministério (sem acento, caixa nem espaços repetidos), para
-- impedir duas funções ativas com o mesmo nome no mesmo ministério (FR-002).
create function public.normalizar_nome_funcao(p_nome text)
returns text
language sql
immutable
set search_path = ''
as $$
  select public.normalizar_nome_ministerio(p_nome);
$$;

-- Funções internas: ninguém chama pela API; as funções `security definer` as usam por dentro.
revoke execute on function public.agora_sp() from public, anon, authenticated;
revoke execute on function public.hoje_sp() from public, anon, authenticated;
revoke execute on function public.inicio_da_escala(date, time) from public, anon, authenticated;
revoke execute on function public.normalizar_nome_funcao(text) from public, anon, authenticated;
