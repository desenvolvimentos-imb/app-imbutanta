# 0002 — Primeiro administrador definido por configuração do ambiente

- **Data**: 2026-11-19
- **Situação**: Aceita
- **Origem**: `specs/001-login-papeis-acesso` (RF-014)

## Contexto

Todo cadastro novo nasce pendente e precisa ser aprovado por um administrador ou líder.
Alguém precisa ser o primeiro administrador sem depender de ninguém. O dono do projeto
(Arthur) é essa pessoa. O email dele não deve ir para o repositório (dado pessoal e
específico de cada ambiente), e a regra não pode permitir que um terceiro vire
administrador criando conta com o email do dono.

## Decisão

- Tabela `administradores_iniciais` (apenas email), criada **vazia** pelas migrações, sem
  acesso para usuários da API.
- O dono insere o próprio email nela, pelo painel do Supabase de cada ambiente.
- Um gatilho em `auth.users` aplica `aprovado` + `administrador` **somente quando o email é
  confirmado** (cadastro por senha com link confirmado, ou Google, que já chega verificado).

## Como configurar em cada ambiente

No *SQL Editor* do painel do Supabase (desenvolvimento e produção), substituindo pelo email
real, em minúsculas:

```sql
insert into public.administradores_iniciais (email) values ('email-do-dono@exemplo.com');
```

Depois, criar a conta com esse email e confirmá-lo. Se a conta já existia e estava pendente
com email confirmado, promover uma única vez pelo painel:

```sql
update public.perfis set situacao = 'aprovado', papel = 'administrador'
 where email = 'email-do-dono@exemplo.com';
```

No ambiente local, o `supabase/seed.sql` já faz isso para `admin@teste.local`.

## Consequências

- (+) Reproduzível e testado (pgTAP `002_administrador_inicial`).
- (+) Nenhum dado pessoal no repositório.
- (−) É um passo manual por ambiente; fica registrado aqui e no checklist de implantação.
- Outros administradores são criados pelo próprio administrador, na tela de usuários.
