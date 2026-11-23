-- Escalas dos ministérios: tabelas (specs/003-escalas-ministerios/data-model.md).
-- Nenhuma delas aceita escrita direta: tudo passa por funções (migração 003 em diante).

-- Função: papel dentro de um ministério (vocal, violão...). Nunca é apagada: só desativada (FR-003).
create table public.funcoes_ministerio (
  id            uuid primary key default gen_random_uuid(),
  ministerio_id uuid not null references public.ministerios (id) on delete restrict,
  nome          text not null check (char_length(btrim(nome)) between 2 and 40),
  ativa         boolean not null default true,
  criada_em     timestamptz not null default now(),
  desativada_em timestamptz
);

-- Duas funções ATIVAS do mesmo ministério não podem ter o mesmo nome (FR-002). Um índice no banco
-- vale mesmo se duas pessoas criarem ao mesmo tempo.
create unique index funcoes_nome_ativo_unico
  on public.funcoes_ministerio (ministerio_id, public.normalizar_nome_funcao(nome))
  where ativa;

-- Em quais funções cada participante é apto (FR-004). Apagar a conta apaga as aptidões.
create table public.aptidoes (
  funcao_id uuid not null references public.funcoes_ministerio (id) on delete restrict,
  perfil_id uuid not null references public.perfis (id) on delete cascade,
  tipo      public.tipo_aptidao not null,
  primary key (funcao_id, perfil_id)
);
create index aptidoes_perfil_idx on public.aptidoes (perfil_id);

-- Escala: o conjunto de vagas de um ministério para um evento (FR-005).
create table public.escalas (
  id            uuid primary key default gen_random_uuid(),
  ministerio_id uuid not null references public.ministerios (id) on delete restrict,
  evento        text not null check (char_length(btrim(evento)) between 2 and 80),
  data          date not null,
  horario       time not null,
  observacao    text not null default '' check (char_length(observacao) <= 300),
  situacao      public.situacao_escala not null default 'rascunho',
  criada_por    uuid references public.perfis (id) on delete set null,
  criada_em     timestamptz not null default now(),
  atualizada_em timestamptz not null default now(),
  cancelada_em  timestamptz
);
create index escalas_ministerio_data_idx on public.escalas (ministerio_id, data);
create index escalas_data_idx on public.escalas (data);

-- Vaga: posição de uma escala. `perfil_id` nulo = "vaga em aberto". Se a conta for excluída, a vaga
-- fica em aberto (on delete set null) e o histórico das demais permanece (LGPD, constitution V).
create table public.vagas_escala (
  id        uuid primary key default gen_random_uuid(),
  escala_id uuid not null references public.escalas (id) on delete cascade,
  funcao_id uuid not null references public.funcoes_ministerio (id) on delete restrict,
  rotulo    text not null default '' check (char_length(rotulo) <= 40),
  perfil_id uuid references public.perfis (id) on delete set null,
  ordem     integer not null default 0,
  -- Alvo da chave estrangeira composta de `pedidos_troca`: garante que o pedido sempre aponta para
  -- a escala da própria vaga.
  unique (id, escala_id)
);
create index vagas_escala_ordem_idx on public.vagas_escala (escala_id, ordem);
create index vagas_escala_perfil_idx on public.vagas_escala (perfil_id);

-- Só participantes do ministério da escala podem ocupar uma vaga (FR-009). A regra mora no banco
-- para valer mesmo contra escrita direta. Só confere quando a pessoa MUDA, para não atrapalhar
-- escalas antigas em que a pessoa já saiu do ministério.
create function public.validar_pessoa_da_vaga()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.perfil_id is null then
    return new;
  end if;
  if tg_op = 'UPDATE' and new.perfil_id is not distinct from old.perfil_id then
    return new;
  end if;
  if not exists (
    select 1
      from public.escalas e
      join public.participacoes_ministerio pm
        on pm.ministerio_id = e.ministerio_id and pm.perfil_id = new.perfil_id
     where e.id = new.escala_id
  ) then
    raise exception 'nao_participante';
  end if;
  return new;
end;
$$;

create trigger trg_validar_pessoa_da_vaga
  before insert or update on public.vagas_escala
  for each row execute function public.validar_pessoa_da_vaga();

-- Resposta de uma pessoa a uma escala: uma por pessoa por escala (FR-026). Pendente = sem linha.
create table public.respostas_escala (
  escala_id     uuid not null references public.escalas (id) on delete cascade,
  perfil_id     uuid not null references public.perfis (id) on delete cascade,
  resposta      public.resposta_escala not null,
  motivo        text not null default '' check (char_length(motivo) <= 200),
  respondida_em timestamptz not null default now(),
  primary key (escala_id, perfil_id)
);

-- Pedido de troca de uma vaga (FR-029 a FR-036).
create table public.pedidos_troca (
  id             uuid primary key default gen_random_uuid(),
  vaga_id        uuid not null,
  escala_id      uuid not null references public.escalas (id) on delete cascade,
  solicitante_id uuid not null references public.perfis (id) on delete cascade,
  indicada_id    uuid not null references public.perfis (id) on delete cascade,
  situacao       public.situacao_troca not null default 'aguardando_indicada',
  criado_em      timestamptz not null default now(),
  respondido_em  timestamptz,
  decidido_por   uuid references public.perfis (id) on delete set null,
  decidido_em    timestamptz,
  check (solicitante_id <> indicada_id),
  foreign key (vaga_id, escala_id) references public.vagas_escala (id, escala_id) on delete cascade
);

-- No máximo um pedido PENDENTE por vaga (FR-033). Pedidos encerrados ficam como registro.
create unique index pedidos_troca_pendente_unico
  on public.pedidos_troca (vaga_id)
  where situacao in ('aguardando_indicada', 'aguardando_lider');

create index pedidos_troca_indicada_idx on public.pedidos_troca (indicada_id, situacao);
create index pedidos_troca_solicitante_idx on public.pedidos_troca (solicitante_id, situacao);
create index pedidos_troca_escala_idx on public.pedidos_troca (escala_id, situacao);
