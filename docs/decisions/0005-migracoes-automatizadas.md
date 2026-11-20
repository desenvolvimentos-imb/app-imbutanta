# 0005 — Migrações aplicadas por workflow do GitHub Actions

- **Data**: 2026-11-20
- **Situação**: Aceita (implementação prevista na funcionalidade `002-ministerios-participantes`)
- **Origem**: ADR 0003 (atualização de 2026-11-20) e emenda 1.3.0 da constituição

## Contexto

A ADR 0003 previa que a integração Supabase + GitHub aplicasse as migrações ao fazer merge em
`develop` (projeto de desenvolvimento) e `main` (projeto de produção). No plano gratuito ela não
aplicou nada sozinha, e as migrações da 001 foram coladas à mão no *SQL Editor*, com o histórico
registrado manualmente. O passo manual depende de memória, pode ser feito fora de ordem e a cada
funcionalidade o risco cresce, sobretudo em produção (dados reais de membros).

## Decisão

- Um workflow do GitHub Actions (`.github/workflows/migracoes.yml`) roda `supabase db push` quando
  há push em `develop` ou `main` que altere `supabase/migrations/`:
  - `develop` → projeto Supabase de desenvolvimento;
  - `main` → projeto Supabase de produção.
- Cada ambiente é um *Environment* do GitHub (`desenvolvimento` e `producao`) com os próprios
  segredos: token de acesso do Supabase, referência do projeto e senha do banco. Nenhum segredo vai
  para o repositório (constituição V).
- O *Environment* `producao` exige **aprovação manual** antes de rodar, para que uma migração só
  chegue à produção com um aceite explícito.
- O `supabase db push` aplica apenas as migrações ainda ausentes no histórico
  (`supabase_migrations.schema_migrations`). O histórico registrado à mão para a 001 faz parte
  desse registro, então ela não será reaplicada.
- O CI já executa os testes de banco (`supabase test db`) a cada PR; o merge só acontece com ele
  verde. O workflow de migrações **não** substitui o CI.
- Colar SQL no painel continua possível apenas como contingência, com o motivo no PR.

## Alternativas consideradas

- **Integração nativa Supabase + GitHub**: não aplicou no plano gratuito (ver ADR 0003).
- **Supabase Branching**: pago; rejeitado pela regra de custo zero.
- **`supabase db push` manual na máquina do mantenedor**: grátis, mas é o passo que se quer evitar.

## Consequências

- (+) Cada merge leva as migrações ao ambiente certo, em ordem, sem colagem manual.
- (+) A produção tem um portão de aprovação.
- (−) É preciso criar e manter segredos nos dois Environments do GitHub.
- (−) Se o histórico de migrações de um projeto divergir do repositório, o `db push` falha em vez de
  reaplicar; a correção é `supabase migration repair` e deve ser feita com cuidado.
- (−) A conexão do runner do GitHub com o banco pode exigir o endereço de pooler do Supabase;
  confirmar na primeira execução em desenvolvimento antes de usar em produção.
- O GitHub Actions é gratuito para repositório público (ADR 0004).

## Atualização (2026-11-20, primeira execução)

A primeira execução mostrou dois ajustes, ambos já corrigidos no workflow:

- Na CLI 3, `supabase db push` mira o **banco local** por padrão; para o projeto vinculado é preciso
  `--remote`. Sem a flag, a simulação falhou com "connection refused" antes de aplicar qualquer coisa.
- `version: latest` no `setup-cli` consulta a API do GitHub para descobrir a versão e falhou por
  limite de requisições ("rate limit exceeded"). A versão passou a ser fixa (3.2.0, a mesma do
  `package.json`); atualizar a CLI passa a ser uma mudança explícita, nos dois workflows e no
  `package.json`.
