-- Ministérios e participantes (specs/002-ministerios-participantes): tipos e tabelas base.
-- Detalhes e o porquê de cada campo: specs/002-ministerios-participantes/data-model.md

-- `unaccent` tira acentos; usada só para comparar nomes de ministérios (RF-005).
create extension if not exists unaccent with schema extensions;

-- Normaliza o nome para comparar: sem espaços nas pontas nem repetidos, sem acento, minúsculo.
-- A função `unaccent` não é marcada como imutável (o dicionário poderia mudar), mas fixamos o
-- dicionário aqui e declaramos `immutable` para poder usá-la em um índice (padrão conhecido).
create function public.normalizar_nome_ministerio(p_nome text)
returns text
language sql
immutable
set search_path = ''
as $$
  select lower(extensions.unaccent('extensions.unaccent'::regdictionary,
                                   regexp_replace(btrim(p_nome), '\s+', ' ', 'g')));
$$;

-- Papel da pessoa DENTRO de um ministério (RF-009). Vale só naquele ministério (RF-010).
create type public.papel_ministerio as enum ('participante', 'lider');

-- Estado de um pedido de entrada em ministério.
create type public.situacao_pedido as enum ('pendente', 'aceito', 'recusado', 'cancelado');

-- Um ministério da igreja. Nunca é apagado: só desativado (RF-003), para preservar o histórico.
create table public.ministerios (
  id            uuid primary key default gen_random_uuid(),
  nome          text not null check (char_length(btrim(nome)) between 2 and 60),
  descricao     text not null default '' check (char_length(descricao) <= 200),
  ativo         boolean not null default true,
  criado_em     timestamptz not null default now(),
  desativado_em timestamptz
);

comment on table public.ministerios is
  'Ministérios da igreja. Desativar não apaga participações nem pedidos (histórico).';

-- Dois ministérios ATIVOS não podem ter o mesmo nome (RF-005). Desativados podem repetir nomes.
-- Um índice no banco vale mesmo se duas pessoas criarem ao mesmo tempo.
create unique index ministerios_nome_ativo_unico
  on public.ministerios (public.normalizar_nome_ministerio(nome))
  where ativo;

-- Liga uma pessoa a um ministério. Uma pessoa pode ter várias participações (RF-008).
-- Apagar a conta apaga as participações (cascade), base da exclusão LGPD (RF-037).
create table public.participacoes_ministerio (
  ministerio_id  uuid not null references public.ministerios (id) on delete restrict,
  perfil_id      uuid not null references public.perfis (id) on delete cascade,
  papel          public.papel_ministerio not null default 'participante',
  desde          timestamptz not null default now(),
  adicionado_por uuid references public.perfis (id) on delete set null,
  primary key (ministerio_id, perfil_id)
);

create index participacoes_ministerio_perfil_idx on public.participacoes_ministerio (perfil_id);

-- Pedido de uma pessoa para entrar em um ministério (RF-016). Só vira participação no aceite.
create table public.pedidos_entrada_ministerio (
  id              uuid primary key default gen_random_uuid(),
  ministerio_id   uuid not null references public.ministerios (id) on delete restrict,
  perfil_id       uuid not null references public.perfis (id) on delete cascade,
  situacao        public.situacao_pedido not null default 'pendente',
  origem_cadastro boolean not null default false,
  criado_em       timestamptz not null default now(),
  decidido_por    uuid references public.perfis (id) on delete set null,
  decidido_em     timestamptz
);

-- No máximo um pedido PENDENTE por pessoa e ministério (RF-018). Pedidos já decididos ficam como
-- registro e não impedem um novo pedido (RF-020).
create unique index pedidos_pendente_unico
  on public.pedidos_entrada_ministerio (ministerio_id, perfil_id)
  where situacao = 'pendente';

create index pedidos_ministerio_situacao_idx on public.pedidos_entrada_ministerio (ministerio_id, situacao);
create index pedidos_perfil_idx on public.pedidos_entrada_ministerio (perfil_id);
