-- Login e papéis de acesso (specs/001-login-papeis-acesso): tipos e tabelas base.
-- Detalhes e o porquê de cada campo: specs/001-login-papeis-acesso/data-model.md

-- Situação da conta: define o que a pessoa enxerga ao abrir o app.
create type public.situacao_conta as enum ('pendente', 'aprovado', 'recusado', 'acesso_removido');

-- Papel: define o que uma pessoa APROVADA pode ver e fazer.
create type public.papel_usuario as enum ('membro', 'lider', 'administrador');

-- Uma linha por pessoa, ligada 1:1 a auth.users (tabela do Supabase com email, senha
-- criptografada e identidades Google). Apagar a conta no Auth apaga o perfil (cascade),
-- que é a base da exclusão de conta pedida pela LGPD.
create table public.perfis (
  id               uuid primary key references auth.users (id) on delete cascade,
  nome             text not null check (char_length(btrim(nome)) between 2 and 100),
  email            text not null,
  email_verificado boolean not null default false,
  situacao         public.situacao_conta not null default 'pendente',
  papel            public.papel_usuario not null default 'membro',
  criado_em        timestamptz not null default now(),
  decidido_por     uuid references public.perfis (id) on delete set null,
  decidido_em      timestamptz
);

comment on table public.perfis is
  'Pessoas que usam o app. Só guarda nome e email (LGPD, constituição V).';
comment on column public.perfis.papel is
  'Só tem efeito quando situacao = aprovado.';

-- A fila de aprovação filtra por situação.
create index perfis_situacao_idx on public.perfis (situacao);

-- Emails que viram administrador ao serem CONFIRMADOS (RF-014). A migração cria a tabela
-- vazia; o email do dono é inserido à mão em cada ambiente (ver docs/decisions/0002).
create table public.administradores_iniciais (
  email text primary key check (email = lower(email))
);

-- Sem políticas e sem permissões para usuários da API: só o painel do Supabase mexe aqui.
alter table public.administradores_iniciais enable row level security;
revoke all on public.administradores_iniciais from anon, authenticated;
