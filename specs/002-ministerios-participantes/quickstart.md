# Guia de Execução e Validação: Ministérios e Participantes

Como preparar o ambiente e provar que a funcionalidade funciona de ponta a ponta. Dados e
contratos: [data-model.md](data-model.md), [contracts/](contracts/). A preparação do ambiente
(Node, Docker, Supabase local, `.env.local`) é a mesma da 001:
[quickstart.md](../001-login-papeis-acesso/quickstart.md). Os comandos exatos podem ser ajustados
na implementação (`/speckit-implement`).

## 1. Rodar localmente

```bash
npm install
npx supabase start     # sobe Postgres, Auth e Mailpit locais
npx supabase db reset  # aplica TODAS as migrações (001 e 002) e o seed.sql
npm run dev             # http://localhost:3000
```

O `seed.sql` passa a criar, além das contas da 001 (senha `Senha1234`, só ambiente local):

| Conta | Papel | Ministérios (seed) |
|-------|-------|--------------------|
| `admin@teste.local` | administrador | líder de "Recepção" |
| `lider@teste.local` | membro | líder de "Louvor" |
| `membro@teste.local` | membro | participante de "Louvor" |
| `pendente@teste.local` | pendente | pedido pendente em "Louvor" |
| `recusado@teste.local` | recusado | — |

Há também o ministério de teste "Teatro" (desativado), com um participante, para validar o histórico.

## 2. Testes automatizados

```bash
npm run lint
npm run typecheck
npm test                # Vitest: validação de ministérios, mensagens de erro, permissões
npx supabase test db   # pgTAP: RLS, funções, último líder, pedidos, migração dos líderes
npm run test:e2e        # Playwright em tela de celular, com email/senha
```

Resultado esperado: tudo verde. O CI roda o mesmo conjunto a cada PR.

## 3. Cenários de validação (mapeados aos critérios de sucesso)

| # | Cenário | Resultado esperado | Critério |
|---|---------|--------------------|----------|
| 1 | Administrador cria o ministério "Teatro" com descrição e líder inicial (< 2 min) | aparece na lista de ativos | CS-001 |
| 2 | Administrador tenta criar outro "teatro " (caixa, espaço) ativo | recusado com "Já existe um ministério ativo com esse nome." | RF-005 |
| 3 | Administrador desativa "Teatro" e cria outro "Teatro" | permitido; o antigo continua com participantes, só fora da lista de ativos | RF-003, RF-004 |
| 4 | Membro e líder tentam criar/editar/desativar ministério (tela e chamada direta) | negado | CS-005 |
| 5 | Líder do Louvor adiciona uma pessoa, a promove a líder e remove o outro líder | tudo passa; a pessoa só é líder do Louvor, não da Recepção | RF-010 |
| 6 | Líder tenta remover/rebaixar o **último** líder | impedido com a mensagem do último líder | CS-006 |
| 7 | Líder do Louvor tenta adicionar participante ou decidir pedido da Recepção | negado | CS-005 |
| 8 | Sem ministério ativo, abrir `/cadastrar` | a escolha de ministérios **não aparece** | RF-015 |
| 9 | Com ministérios ativos, cadastrar marcando Louvor e Recepção, confirmar o email no Mailpit, entrar | cai em `/aguardando-aprovacao` com dois pedidos pendentes; ainda não é participante | CS-003, RF-016 |
| 10 | Líder do Louvor abre `/aprovacoes` e aceita o pedido (≤ 2 toques desde o início) | conta fica ativa como membro e participante do Louvor; o pedido da Recepção segue pendente | CS-002, RF-023 |
| 11 | Mesmo cadastro, mas o líder do Louvor **recusa** | conta continua pendente (não recusada); o pedido da Recepção ainda aguarda | RF-024, CS-007 |
| 12 | Cadastro sem marcar ministério | a pessoa não aparece para líder algum; só o administrador a aprova em `/aprovacoes` | RF-025 |
| 13 | Dois decisores no mesmo pedido, o segundo age depois do primeiro | o segundo recebe "Este pedido já foi decidido" e vê o estado atual | RF-021 |
| 14 | Membro sem ministério abre `/meus-ministerios` | tela vazia amigável, sem erro; pede entrada na Recepção em ≤ 3 toques | CS-004, RF-033 |
| 15 | Membro cancela o próprio pedido pendente e pede de novo | permitido; sem pedido duplicado | RF-017, RF-018 |
| 16 | Participante da Recepção abre `/ministerios/<id do Louvor>` (e chama `listar_participantes`) | só nome e descrição; lista de participantes vazia | RF-031, CS-005 |
| 17 | Administrador abre `/ministerios` | vê ativos e desativados, com participantes e pedidos | RF-029 |
| 18 | Excluir a conta da única líder de um ministério ativo (e remover o acesso dela) | impedido com `ultimo_lider` e o nome do ministério; passa após definir outro líder | RF-013 |
| 19 | Desativar um ministério com pedido pendente | o pedido some da fila dos líderes e, se era o único pedido da conta pendente, só o administrador a aprova | RF-022 |
| 20 | Fluxo Google: continuar com Google, na tela de espera pedir Louvor, líder aceita | conta ativa e participante (roteiro manual) | RF-015, RF-023 |
| 21 | Chamada direta à API (chave pública) por membro: ler `participacoes_ministerio` de outra pessoa, escrever em `ministerios`, chamar `decidir_pedido_entrada` | zero linhas / `sem_permissao` | RF-035 |
| 22 | Excluir a própria conta de um membro com participações e pedidos | vínculos e pedidos somem junto; nenhum dado pessoal restante | RF-037 |
| 23 | Telas em celular (largura 375 px) e verificação de acessibilidade automática | sem rolagem horizontal, sem violações AA | CS-009 |

## 4. Migração dos líderes globais (produção e desenvolvimento)

A migração converte o papel global `lider` em `membro` (RF-027). **Antes de aplicar** em cada
ambiente, registre quem tem esse papel, para que o administrador saiba quem precisa ser
vinculado a ministérios depois:

```sql
-- Rodar no SQL Editor do Supabase do ambiente, ANTES de aplicar a migração (somente leitura).
select id, nome, email from public.perfis where papel = 'lider';
```

Depois de aplicar a migração: o administrador cria os ministérios (cada um com líder inicial) e
re-vincula essas pessoas como líderes. Teste automatizado equivalente: `pgTAP` "migração dos líderes".

## 5. Ordem de implantação nos ambientes online

Regra da constituição 1.3.0 e [ADR 0005](../../docs/decisions/0005-migracoes-automatizadas.md): as
migrações são aplicadas pelo workflow `migracoes.yml`, não por colagem manual.

1. Merge da 002 em `develop`: o workflow aplica as migrações no projeto de **desenvolvimento**.
   Confira em *Supabase → Database → Migrations* e valide os cenários acima (inclusive o roteiro
   Google).
2. Rode a consulta da seção 4 no **produção** antes do release, para saber quem era líder global.
3. PR `develop` → `main`: após o merge, o workflow espera a **sua aprovação** no GitHub
   (*Environment* `producao`) e então aplica no projeto de produção.
4. Se o workflow ainda não estiver ativo, use a contingência da
   [ADR 0003](../../docs/decisions/0003-implantacao-de-migracoes.md) e registre o motivo no PR.

Nenhuma configuração nova de Auth ou de SMTP é necessária.

**Preparação única do workflow** (você faz, pois são segredos): criar os *Environments*
`desenvolvimento` e `producao` no GitHub, com revisor obrigatório em `producao`, e cadastrar em cada
um o token de acesso do Supabase, a referência do projeto e a senha do banco.
