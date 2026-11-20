# Como contribuir com o IM Butantã

Este guia é o passo a passo prático do fluxo de trabalho. As regras e o porquê estão na
[constituição do projeto](.specify/memory/constitution.md), que prevalece em caso de dúvida.

**Tudo (código, comentários, commits, PRs e documentação) é escrito em português do Brasil.**

## Branches

| Branch | Para que serve | Quem pode alterar |
|---|---|---|
| `main` | **Produção.** O que os usuários da igreja usam. | Apenas por PR vindo de `develop` |
| `develop` | **Integração e testes.** Recebe as funcionalidades prontas. | Apenas por PR vindo de uma branch de feature |
| `feature/...`, `fix/...` ou `NNN-nome` (Spec Kit) | Uma funcionalidade ou correção. | Quem está desenvolvendo |

Nunca faça commit direto em `main` ou `develop`.

```text
feature/escalas ──PR──▶ develop ──PR (release)──▶ main
```

## Passo a passo de uma funcionalidade

1. Atualize a `develop` e crie sua branch a partir dela:
   ```bash
   git checkout develop
   git pull
   git checkout -b feature/nome-curto-da-funcionalidade
   ```
   Se usar o Spec Kit, ele cria uma branch numerada (ex.: `001-escalas`). Garanta que ela saia
   de `develop`.
2. Desenvolva em passos pequenos, com commits frequentes (veja "Commits").
3. Rode os testes e o lint localmente antes de abrir o PR.
4. Envie a branch e abra um Pull Request **para `develop`**:
   ```bash
   git push -u origin feature/nome-curto-da-funcionalidade
   ```
5. Preencha o PR (veja "Pull Requests"), espere os testes passarem e faça o merge.
6. Apague a branch da feature depois do merge (o GitHub faz isso sozinho: *Automatically delete head
   branches* está ligado).

**Uma branch por feature.** Ajustes, correções e registros de validação da mesma feature entram
na **mesma branch** (e no mesmo PR), em vez de uma branch para cada mudança. Branches separadas
ficam para trabalhos independentes. Em PRs pequenos de ajuste, prefira *Squash and merge* (um
commit na `develop`); PRs de release (`develop` → `main`) usam *Create a merge commit*.

## Publicar em produção (release)

1. Valide a `develop` (testes automáticos e uso manual no ambiente de teste).
2. Abra um PR de `develop` para `main`, descrevendo o que está sendo publicado.
3. Após os testes passarem, faça o merge. A `main` é a versão de produção.

## Migrações do banco

Toda mudança de banco é um arquivo novo em `supabase/migrations/`:

1. `npx supabase migration new nome_curto` e escreva o SQL (nunca edite uma migração já aplicada).
2. Teste localmente: `npx supabase db reset && npm run test:db`.
3. O PR roda o CI (inclui os testes de banco). Após o merge, o workflow de migrações aplica o
   arquivo no projeto Supabase do ambiente: `develop` → desenvolvimento, `main` → produção
   (a produção espera a sua aprovação no GitHub). Decisão e detalhes em
   [ADR 0005](docs/decisions/0005-migracoes-automatizadas.md).
4. Colar SQL à mão no painel só como contingência; registre o motivo no PR e conferir o histórico
   de migrações depois.

## Commits

Usamos [Conventional Commits](https://www.conventionalcommits.org/pt-br/), com descrição em
português:

| Prefixo | Uso |
|---|---|
| `feat:` | Nova funcionalidade |
| `fix:` | Correção de bug |
| `docs:` | Só documentação |
| `test:` | Testes |
| `chore:` | Manutenção, configuração, dependências |

Exemplo: `feat: permite líder de ministério criar escala semanal`

A mensagem deve dizer **o que** mudou. Se o **porquê** não for óbvio, explique no corpo do commit.

## Pull Requests

Todo PR deve explicar:
- **Contexto:** que problema ou necessidade motivou a mudança.
- **O que mudou:** resumo da solução.
- **Por que assim:** decisões e alternativas descartadas, se houver.
- **Como testar:** testes automatizados e, para telas visuais, a verificação manual feita.
- **Checklist:**
  - [ ] Testes passando (obrigatórios para escalas, login/permissões e quiz)
  - [ ] Lint sem erros
  - [ ] Telas novas verificadas no celular e com acessibilidade básica
  - [ ] Documentação atualizada (README, comentários, `docs/decisions/`)
  - [ ] Segue a constituição (desvios justificados)

## Documentação

- **Comentários no código** explicam a intenção e o porquê, não repetem o que a linha faz.
- **Decisões importantes** (escolha de serviço, mudança de arquitetura, exceção a um princípio)
  ficam registradas em `docs/decisions/`, uma nota curta por decisão, com contexto, decisão e
  consequências.
- **README** deve permitir que alguém novo rode o projeto sem ajuda.

## Segredos e dados

- Nunca versione senhas, chaves ou tokens. Use variáveis de ambiente e mantenha um arquivo de
  exemplo (`.env.example`) sem valores reais.
- Colete apenas o necessário das pessoas (nome e login), conforme a LGPD.

## Alterando a constituição

Mudanças nas regras do projeto são feitas por PR, atualizando versão e relatório de impacto,
conforme a seção de governança da constituição.
