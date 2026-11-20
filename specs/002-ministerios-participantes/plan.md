# Plano de Implementação: Ministérios e Participantes

**Branch**: `002-ministerios-participantes` | **Data**: 2026-11-19 | **Spec**: [spec.md](spec.md)

**Entrada**: Especificação em `specs/002-ministerios-participantes/spec.md`

## Resumo

Segunda funcionalidade do app IM Butantã: cadastro de ministérios pelo administrador, vínculo de
pessoas a ministérios como "participante" ou "líder" (por ministério), pedidos de entrada
decididos pelo líder, ajuste na aprovação de novos usuários e a tela "Meus ministérios".

A stack **não muda** (Next.js 16 + Supabase + Vercel, definida na funcionalidade 001). A
abordagem repete a da 001: **as regras vivem no banco** (RLS + funções SQL atômicas) e a
interface só reflete essas regras.

Pontos centrais do desenho (detalhes em [research.md](research.md)):

- **Três tabelas novas**: `ministerios`, `participacoes_ministerio` e `pedidos_entrada_ministerio`.
- **Liderança deixa de ser um papel global**: o valor `lider` de `papel_usuario` deixa de ser
  usado. Quem lidera é quem tem participação com papel `lider` em um ministério **ativo** e conta
  `aprovado`. Uma migração converte os "líderes globais" da 001 em membros (RF-027).
- **Toda escrita passa por funções SQL** (`security definer`): criar/editar/desativar ministério,
  gerenciar participantes, pedir/cancelar/decidir pedidos. Nenhuma escrita direta nas tabelas.
- **"Pelo menos um líder"** é garantido por gatilho no banco (como o "último administrador" da 001),
  inclusive na exclusão de conta e na remoção de acesso.
- **Quem vê o quê** sem expor email: líderes e participantes leem nome e papel por funções
  (`listar_participantes`, `listar_pedidos_pendentes`, `buscar_pessoas`), nunca a tabela `perfis`.
- **Pedido no cadastro**: por email e senha, os ministérios marcados vão nos metadados do cadastro e
  o gatilho existente cria os pedidos; por Google, a escolha é feita na tela "aguardando aprovação".
- **Aprovação de conta**: aceitar um pedido de uma conta `pendente` a ativa (como membro) e a torna
  participante, tudo na mesma operação atômica (`decidir_pedido_entrada`).

## Contexto Técnico

**Linguagem/Versão**: TypeScript 5.x em Node.js 22 LTS; SQL (Postgres 15+ do Supabase) — igual à 001

**Dependências principais**: as da 001 (Next.js 16, React 19, `@supabase/supabase-js`,
`@supabase/ssr`, Tailwind CSS, Zod). **Nenhuma dependência nova.** No banco, usa-se a extensão
`unaccent` (já disponível no Supabase, sem custo) para comparar nomes sem acento (RF-005).

**Armazenamento**: Supabase Postgres: 3 tabelas e 2 tipos novos; ver [data-model.md](data-model.md)

**Testes**: Vitest (unitários), pgTAP via `supabase test db` (regras e RLS), Playwright (ponta a
ponta em celular emulado, email/senha). O fluxo Google segue com roteiro manual.

**Plataforma alvo**: navegadores móveis modernos (Chrome Android, Safari iOS) e desktop; PWA

**Tipo de projeto**: aplicação web única (Next.js com o Supabase como backend) — igual à 001

**Metas de desempenho**: telas utilizáveis em < 10 s em conexão móvel comum; consultas simples
por chave (a escala é de dezenas de ministérios e centenas de pessoas); sem paginação nesta fase

**Restrições**: custo zero; somente online; pt-BR; WCAG AA; mobile-first; dados mínimos (só nome
já existente + vínculos e pedidos)

**Escala/Escopo**: dezenas de ministérios, algumas centenas de pessoas; ~6 telas novas e 4 ajustadas

### Limites gratuitos e o que acontece ao ultrapassar (constitution VI)

Nenhum serviço novo. Os limites da 001 continuam valendo (ver
[../001-login-papeis-acesso/research.md](../001-login-papeis-acesso/research.md#limites-gratuitos)).
O impacto desta funcionalidade é desprezível:

| Serviço | Limite relevante | Impacto desta funcionalidade |
|---------|------------------|------------------------------|
| Supabase Postgres (500 MB) | espaço do banco | linhas pequenas: mesmo com 100 ministérios, 1.000 pessoas e 10.000 pedidos ocupam bem menos de 5 MB |
| Supabase (extensão `unaccent`) | disponível em todos os planos | gratuita; sem custo adicional |
| Vercel Hobby | banda e execuções | mais algumas telas dinâmicas; sem efeito perceptível |

## Verificação da Constitution

*Portão: deve passar antes da Fase 0. Reavaliado após o design da Fase 1.*

| Princípio | Avaliação | Como o plano atende |
|-----------|-----------|---------------------|
| I. Mobile-first, PWA, pt-BR, WCAG AA | ✅ | Telas novas seguem os componentes e o padrão da 001 (alvos ≥ 44 px, rótulos, `aria-describedby`); "Meus ministérios" a 1 toque da tela inicial; pedir entrada em ≤ 3 toques (CS-004); aceitar pedido em ≤ 3 (CS-002) |
| II. Simplicidade e YAGNI | ✅ | Sem biblioteca nova; 3 tabelas, cada uma com razão de existir (ver complexidade); sem funções internas ao ministério (vocal, bateria), sem notificações, sem histórico detalhado; sem paginação |
| III. Robustez onde importa | ✅ | Operações críticas em funções SQL atômicas com checagem de conflito; gatilho do "pelo menos um líder" (inclui cascata da exclusão de conta); erros traduzidos para pt-BR; o cadastro nunca falha por causa dos ministérios marcados |
| IV. Testes automatizados | ✅ | pgTAP para cada regra (permissões, último líder, pedidos, aprovação por líder, visibilidade, migração dos líderes); Vitest para validação e mapeamento de erros; Playwright para os fluxos; conceitos explicados em "Como os testes funcionam" |
| V. Privacidade/LGPD | ✅ | Nenhum dado pessoal novo; vínculos e pedidos saem junto na exclusão de conta (cascata); regras no banco; colegas de ministério veem **só nome e papel** (nunca email), via funções; justificativa em [research.md](research.md#decisao-3) |
| VI. Custo zero | ✅ | Nenhum serviço novo |
| VII. Documentação pt-BR | ✅ | ADR 0006 (liderança por ministério) a escrever na implementação; comentários com o porquê; README atualizado |
| Migrações automatizadas (constituição 1.3.0) | ✅ | A 002 traz migrações e inclui o workflow `migracoes.yml` (ADR 0005); até ele existir, a aplicação em dev/prod segue a contingência da ADR 0003, com o motivo no PR |
| Fluxo de branches | ✅ | Branch `002-ministerios-participantes` criada a partir de `develop` (já com a 001 mergeada); trabalho e ajustes da mesma funcionalidade no mesmo PR para `develop` |

**Resultado do portão**: aprovado, sem violações.

**Reavaliação pós-design (Fase 1)**: mantida a aprovação. O design acrescentou três tabelas, duas
enumerações e funções SQL; nada além do que a especificação exige. A seção de Complexidade
registra apenas a decisão de ler dados de colegas por funções em vez de abrir `perfis`.

## Estrutura do Projeto

### Documentação (esta funcionalidade)

```text
specs/002-ministerios-participantes/
├── plan.md              # Este arquivo
├── research.md          # Fase 0: decisões e alternativas
├── data-model.md        # Fase 1: tabelas, estados, regras de RLS
├── quickstart.md        # Fase 1: como rodar e validar de ponta a ponta
├── contracts/
│   ├── rotas.md         # Rotas/telas novas e ajustadas, e quem pode acessar
│   └── banco-rpc.md     # Funções SQL (RPC) novas/alteradas e suas regras
├── checklists/
│   └── requirements.md  # Qualidade da especificação
└── tasks.md             # Fase 2 (gerado por /speckit-tasks, não por este comando)
```

### Código-fonte (acréscimos e mudanças sobre a 001)

```text
src/
├── app/
│   ├── (publico)/cadastrar/            # AJUSTA: marcar ministérios (email e senha)
│   ├── (situacao)/aguardando-aprovacao/ # AJUSTA: mostra e permite pedir ministérios (fluxo Google)
│   └── (app)/
│       ├── inicio/                      # AJUSTA: atalhos "Meus ministérios", "Ministérios" e contagem de pedidos
│       ├── aprovacoes/                  # AJUSTA: cadastros pendentes (admin) + pedidos de entrada (admin e líder)
│       ├── usuarios/                    # AJUSTA: some a opção de papel "líder"
│       ├── meus-ministerios/            # NOVO: meus ministérios, meus pedidos e pedir entrada
│       └── ministerios/                 # NOVO
│           ├── page.tsx                 #   lista (admin: gestão; demais: ativos para pedir entrada)
│           ├── novo/                    #   criar ministério (admin)
│           └── [id]/                    #   detalhe: participantes, pedidos, editar/desativar
├── lib/
│   ├── auth/
│   │   ├── permissoes.ts                # AJUSTA: "líder" passa a derivar de `lidera` (ministérios)
│   │   ├── sessao.ts                    # AJUSTA: perfil ganha `lidera` (nº de ministérios ativos que lidera)
│   │   ├── perfil.ts                    # AJUSTA: tipo Perfil
│   │   └── mensagens-erro.ts            # AJUSTA: novos códigos de erro
│   └── ministerios/
│       ├── validacao.ts                 # NOVO: esquemas Zod (nome, descrição, papel)
│       └── consultas.ts                 # NOVO: leituras (ministérios, participantes, pedidos)
└── components/                          # NOVOS: CartaoMinisterio, ListaParticipantes, SeletorMinisterios…

supabase/
├── migrations/                          # NOVAS (ver data-model.md): tipos e tabelas, RLS, funções,
│                                        #   gatilhos, migração dos líderes globais, ajuste do cadastro
├── seed.sql                             # AJUSTA: líder de teste passa a liderar um ministério de teste
└── tests/                               # NOVOS pgTAP 009+ e AJUSTE dos que citam o papel "lider"

tests/
├── unit/                                # NOVOS e ajustados (permissões, validação, erros)
└── e2e/                                 # NOVOS (ministérios, pedidos, líder aprova) e ajustados

docs/decisions/
└── 0006-lideranca-por-ministerio.md     # NOVO (a escrever na implementação)

.github/workflows/
└── migracoes.yml                        # NOVO: aplica migrações em dev/prod (ADR 0005, constituição 1.3.0)
```

**Decisão de estrutura**: mesma da 001 (projeto único Next.js, sem API própria, regras no banco).
As rotas novas ficam no grupo `(app)`, que já exige conta aprovada; as restrições por papel
continuam em `permissoes.ts` (fonte única para a interface).

> **Next.js 16**: parâmetros de rota dinâmica (`params`, `searchParams`) são `Promise` e precisam
> de `await` (confirmado em `node_modules/next/dist/docs/01-app/01-getting-started/03-layouts-and-pages.md`).
> A implementação deve consultar o guia em `node_modules/next/dist/docs/` antes de escrever código,
> conforme o `AGENTS.md`.

## Como os testes funcionam (didático, constitution IV)

Os conceitos de unitário, banco (pgTAP), ponta a ponta e "escrever antes" são os da 001 (ver
[../001-login-papeis-acesso/plan.md](../001-login-papeis-acesso/plan.md#como-os-testes-funcionam-didático-constitution-iv)).
Nesta funcionalidade, em linguagem simples:

- **Teste de banco para "pelo menos um líder"**: cria um ministério com um líder, tenta remover
  esse líder e confirma que o banco **recusa**. Depois adiciona um segundo líder e confirma que a
  remoção do primeiro passa. Se alguém mexer na regra por engano, o teste fica vermelho.
- **Teste de visibilidade**: entra como participante da Recepção e tenta ler os participantes do
  Louvor; o esperado é **nada** (ou erro de permissão). Isso prova que a regra vale mesmo sem a
  interface.
- **Teste da aprovação por líder**: uma conta pendente que pediu o Louvor é aceita pelo líder do
  Louvor e passa a ativa; outra, que pediu só a Recepção, **não** é afetada pelo líder do Louvor.
- **Teste de migração**: prepara um "líder global" antigo, roda a migração e confere que ele
  virou membro e que nenhum dado foi perdido.

## Rastreabilidade dos requisitos

| Requisitos | Onde é atendido |
|------------|-----------------|
| RF-001–007 | tabela `ministerios`; funções `criar_ministerio`, `editar_ministerio`, `desativar_ministerio`, `reativar_ministerio`; índice único parcial por nome normalizado; `validacao.ts` |
| RF-008–010 | `participacoes_ministerio` (papel por ministério); `permissoes.ts` (líder derivado) |
| RF-011, RF-014 | funções `adicionar_participante`, `alterar_papel_ministerio`, `remover_participante`, `buscar_pessoas` |
| RF-012, RF-013 | gatilhos `proteger_ultimo_lider` (em participações e em perfis) |
| RF-015, RF-016 | metadados do cadastro + gatilho; seletor no `/cadastrar`; tela `/aguardando-aprovacao` (Google) |
| RF-017, RF-018 | funções `pedir_entrada_ministerio`, `cancelar_pedido_entrada`; índice único de pedido pendente |
| RF-019–022 | função `decidir_pedido_entrada`; `aprovacoes/` |
| RF-023–026 | `decidir_pedido_entrada` (ativa a conta), ajuste de `decidir_cadastro` (só administrador), `aprovacoes/`, tela de espera existente |
| RF-027, RF-028 | migração dos líderes globais; `permissoes.ts`; `listar_pedidos_pendentes` |
| RF-029–034 | RLS + funções `listar_*`; telas `ministerios/` e `meus-ministerios/` |
| RF-035 | RLS e funções `security definer`; testes pgTAP e `seguranca-api.spec.ts` ampliado |
| RF-036, RF-037 | nenhuma coluna de dado pessoal nova; `on delete cascade` em vínculos e pedidos |
| RF-038, RF-039 | constitution (acessibilidade, erros amigáveis); testes citados acima |

## Acompanhamento de Complexidade

| Decisão | Por que é necessária | Alternativa mais simples rejeitada |
|---------|----------------------|------------------------------------|
| Funções `listar_*` em vez de abrir leitura de `perfis` a líderes e participantes | A RLS libera linhas inteiras e `perfis` tem **email**; abrir a tabela exporia o email dos colegas (constitution V) | Políticas de leitura em `perfis`: menos código, mas vaza email |
| Tabela própria de pedidos (`pedidos_entrada_ministerio`) | Pedido tem estado, decisor e data; não cabe em `participacoes_ministerio` sem criar "participantes que não são" | Guardar pedido como participação "pendente": mistura conceitos e enfraquece a regra do líder |
| Valor `lider` mantido no tipo `papel_usuario` | O Postgres não remove valor de enumeração; uma constraint garante que ninguém o use | Recriar o tipo: migração arriscada em tabela em produção, sem ganho |
