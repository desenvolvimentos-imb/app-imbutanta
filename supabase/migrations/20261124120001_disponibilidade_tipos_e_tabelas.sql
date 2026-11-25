-- Disponibilidade dos participantes (specs/004-disponibilidade-participantes): tipo e tabelas.
-- Nenhuma tabela aceita escrita direta: tudo passa por funções (migrações seguintes).
-- Detalhes e o porquê: specs/004-disponibilidade-participantes/data-model.md e research.md.

-- Resposta de uma pessoa numa data. "Sem resposta" NÃO é um valor: é a ausência de linha em
-- `respostas_disponibilidade`. Assim ela nunca pode ser tratada como "indisponível" por engano
-- (RF-017, research.md decisão 1).
create type public.resposta_disponibilidade as enum ('disponivel', 'indisponivel');

-- Consulta: pedido do líder a um ministério (RF-001). Nunca é apagada (RF-012). Ela está "aberta"
-- quando `fechada` é falso e o prazo não venceu; essa situação é CALCULADA, não gravada
-- (research.md decisão 2).
create table public.consultas_disponibilidade (
  id            uuid primary key default gen_random_uuid(),
  ministerio_id uuid not null references public.ministerios (id) on delete restrict,
  titulo        text not null check (char_length(btrim(titulo)) between 2 and 80),
  mensagem      text not null default '' check (char_length(mensagem) <= 500),
  prazo         date,
  fechada       boolean not null default false,
  criada_por    uuid references public.perfis (id) on delete set null,
  criada_em     timestamptz not null default now(),
  atualizada_em timestamptz not null default now(),
  -- Alvo da chave estrangeira composta de `datas_consulta`.
  unique (id, ministerio_id)
);
create index consultas_disponibilidade_ministerio_idx
  on public.consultas_disponibilidade (ministerio_id, criada_em desc);

-- Datas propostas. `ministerio_id` repete o da consulta (a chave composta garante que nunca
-- diverge) só para o índice único abaixo valer no banco, mesmo se dois líderes criarem consultas
-- ao mesmo tempo (RF-005, research.md decisão 3).
create table public.datas_consulta (
  id            uuid primary key default gen_random_uuid(),
  consulta_id   uuid not null,
  ministerio_id uuid not null,
  data          date not null,
  rotulo        text not null default '' check (char_length(rotulo) <= 40),
  criada_em     timestamptz not null default now(),
  foreign key (consulta_id, ministerio_id)
    references public.consultas_disponibilidade (id, ministerio_id) on delete cascade
);
-- A mesma data não entra em duas consultas do mesmo ministério; em ministérios diferentes pode.
create unique index datas_consulta_ministerio_data_unico on public.datas_consulta (ministerio_id, data);
create index datas_consulta_consulta_idx on public.datas_consulta (consulta_id, data);

-- Resposta de uma pessoa numa data. Remover a data descarta as respostas (cascata, RF-010);
-- excluir a conta apaga as respostas da pessoa (LGPD). `preenchida_por` guarda o líder quando foi
-- ele quem preencheu (RF-021); nulo = a própria pessoa respondeu.
create table public.respostas_disponibilidade (
  data_id        uuid not null references public.datas_consulta (id) on delete cascade,
  perfil_id      uuid not null references public.perfis (id) on delete cascade,
  resposta       public.resposta_disponibilidade not null,
  preenchida_por uuid references public.perfis (id) on delete set null,
  atualizada_em  timestamptz not null default now(),
  primary key (data_id, perfil_id)
);
create index respostas_disponibilidade_perfil_idx on public.respostas_disponibilidade (perfil_id);

-- Observação opcional por pessoa e consulta (RF-018). Observação vazia = sem linha.
create table public.observacoes_disponibilidade (
  consulta_id   uuid not null references public.consultas_disponibilidade (id) on delete cascade,
  perfil_id     uuid not null references public.perfis (id) on delete cascade,
  texto         text not null check (char_length(texto) between 1 and 300),
  atualizada_em timestamptz not null default now(),
  primary key (consulta_id, perfil_id)
);
