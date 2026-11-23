# Plano de Implementação: Escalas dos Ministérios

**Branch**: `003-escalas-ministerios` | **Data**: 2026-11-23 | **Spec**: [spec.md](spec.md)

**Entrada**: Especificação em `specs/003-escalas-ministerios/spec.md`

## Resumo

Terceira funcionalidade do app IM Butantã: funções e aptidões por ministério, escalas de eventos com
vagas, confirmação/recusa, pedidos de troca em dois passos (indicada → líder) e as telas "Minhas
escalas" e "Pedidos de troca".

A stack **não muda** (Next.js 16 + Supabase + Vercel). A abordagem repete a das funcionalidades 001
e 002: **as regras vivem no banco** (RLS + funções SQL atômicas) e a interface só reflete essas regras.

Pontos centrais do desenho (detalhes em [research.md](research.md)):

- **Seis tabelas novas**: `funcoes_ministerio`, `aptidoes`, `escalas`, `vagas_escala`,
  `respostas_escala` e `pedidos_troca`. Nenhuma aceita escrita direta; só funções `security definer`.
- **Leitura de escalas por funções**, nunca pelas tabelas: as vagas mostram nomes de pessoas, e a
  leitura direta de `perfis` continua proibida a líderes e participantes (ADR 0006). As funções
  devolvem só nome, nunca email.
- **Resposta "pendente" é a ausência de linha** em `respostas_escala`. Isso faz "voltar tudo para
  pendente" (mudança de data/horário) ser apenas apagar linhas.
- **"O horário passou" e "somente leitura" são calculados na hora**, no fuso America/Sao_Paulo; não
  há tarefa agendada nem gatilho de tempo. Pedido pendente de escala já iniciada vale como "sem
  efeito" nas leituras e é recusado nas decisões.
- **Concorrência**: toda função que altera uma escala trava a linha da escala (`for update`) antes
  de decidir; assim "líder troca a pessoa" e "líder aprova a troca" nunca se atropelam, e a troca é
  tudo ou nada.
- **Efeitos nas funcionalidades anteriores** (RF-019, RF-020): remover participante, perder acesso,
  excluir conta e desativar ministério passam a liberar vagas futuras ou cancelar escalas futuras,
  por gatilhos e ajuste de funções da 002.
- **Avisos que não bloqueiam** (outro ministério no mesmo dia; falta de aptidão): a função de salvar
  vaga devolve a lista de avisos e só grava quando o líder confirma que está ciente.

## Contexto Técnico

**Linguagem/Versão**: TypeScript 5.x em Node.js 22 LTS; SQL (Postgres 15+ do Supabase), igual à 001/002

**Dependências principais**: as da 001/002 (Next.js 16, React 19, `@supabase/supabase-js`,
`@supabase/ssr`, Tailwind CSS, Zod). **Nenhuma dependência nova**, nem extensão nova no banco.

**Armazenamento**: Supabase Postgres: 6 tabelas e 4 tipos novos; ver [data-model.md](data-model.md)

**Testes**: Vitest (formatação de data/hora, validação, mapeamento de erros; mais um teste de integração de concorrência com duas sessões `supabase-js`), pgTAP via
`supabase test db` (regras, RLS, concorrência lógica, atomicidade), Playwright (fluxos ponta a ponta
em celular emulado, email/senha)

**Plataforma alvo**: navegadores móveis modernos (Chrome Android, Safari iOS) e desktop; PWA

**Tipo de projeto**: aplicação web única (Next.js com o Supabase como backend)

**Metas de desempenho**: telas utilizáveis em < 10 s em conexão móvel comum; cada tela de escala
carrega com **uma** chamada de função (dezenas de vagas); sem paginação (inclusive nas escalas passadas, pois o volume é pequeno; revisitar se crescer)

**Restrições**: custo zero; somente online; pt-BR; WCAG AA; mobile-first; dados mínimos (nenhum
dado pessoal novo); datas no formato brasileiro e fuso America/Sao_Paulo

**Escala/Escopo**: dezenas de ministérios, centenas de pessoas, poucas escalas por semana por
ministério, até 50 vagas por escala; 6 telas novas e 2 ajustadas

### Limites gratuitos e o que acontece ao ultrapassar (constitution VI)

Nenhum serviço novo. Os limites da 001 continuam valendo. Impacto desta funcionalidade:

| Serviço | Limite relevante | Impacto desta funcionalidade |
|---------|------------------|------------------------------|
| Supabase Postgres (500 MB) | espaço do banco | linhas pequenas: 20 ministérios × 4 escalas/mês × 15 vagas ≈ 14 mil vagas/ano, bem abaixo de 10 MB/ano. Ao se aproximar do limite, escalas antigas podem ser arquivadas (fora do escopo agora) |
| Vercel Hobby | banda e execuções | mais telas dinâmicas leves; sem efeito perceptível |

## Verificação da Constitution

*Portão: deve passar antes da Fase 0. Reavaliado após o design da Fase 1.*

| Princípio | Avaliação | Como o plano atende |
|-----------|-----------|---------------------|
| I. Mobile-first, PWA, pt-BR, WCAG AA | ✅ | Ver a própria escala e responder em ≤ 3 toques (início → "Minhas escalas" → confirmar, que fica no próprio item); destaques de vaga **não dependem só de cor** (ícone + texto "Recusou", "Sem resposta", "Em aberto"); alvos ≥ 44 px |
| II. Simplicidade e YAGNI | ✅ | Sem biblioteca nova; sem cron (tempo calculado na leitura); "pendente" sem linha; sem tabela de avisos nem de notificações (o líder vê o que precisa de atenção na própria escala e numa lista simples); sem histórico detalhado |
| III. Robustez onde importa | ✅ | Funções atômicas com trava da escala; datas validadas no banco; erros com código estável traduzidos em pt-BR; troca tudo-ou-nada; nenhuma ação parcial deixa a escala inválida |
| IV. Testes automatizados | ✅ | pgTAP para cada regra de escala (permissões, datas, avisos, respostas, troca, efeitos em cascata); Vitest e Playwright para a interface; conceitos novos explicados em "Como os testes funcionam" |
| V. Privacidade/LGPD | ✅ | Nenhum dado pessoal novo; vagas guardam só o vínculo com a pessoa; exclusão de conta deixa vagas em aberto e apaga respostas e pedidos da pessoa; respostas e motivos só para a própria pessoa e líderes/administradores; sem email nas funções de leitura |
| VI. Custo zero | ✅ | Nenhum serviço novo |
| VII. Documentação pt-BR | ✅ | ADR 0007 (tempo calculado + resposta como ausência + leitura só por funções) a escrever na implementação; comentários com o porquê; README atualizado |
| Migrações automatizadas (constituição 1.3.0) | ✅ | As migrações novas seguem pelo workflow `migracoes.yml` já existente (ADR 0005); nenhuma edição de migração aplicada: os ajustes à 002 entram como migrações novas |
| Fluxo de branches | ✅ | Branch `003-escalas-ministerios` criada a partir de `develop`; ajustes da mesma funcionalidade no mesmo PR |

**Resultado do portão**: aprovado, sem violações.

**Reavaliação pós-design (Fase 1)**: mantida a aprovação. O design acrescentou seis tabelas e
funções SQL; nada além do que a especificação exige. A seção de Complexidade registra a única
decisão não óbvia (travar a escala em toda alteração).

## Estrutura do Projeto

### Documentação (esta funcionalidade)

```text
specs/003-escalas-ministerios/
├── plan.md              # Este arquivo
├── research.md          # Fase 0: decisões e alternativas
├── data-model.md        # Fase 1: tabelas, estados, regras de acesso
├── quickstart.md        # Fase 1: como rodar e validar de ponta a ponta
├── contracts/
│   ├── rotas.md         # Telas novas e ajustadas, e quem pode acessar
│   └── banco-rpc.md     # Funções SQL (RPC) novas/alteradas e suas regras
├── checklists/
│   └── requirements.md  # Qualidade da especificação
└── tasks.md             # Fase 2 (gerado por /speckit-tasks, não por este comando)
```

### Código-fonte (acréscimos e mudanças sobre a 001 e a 002)

```text
src/
├── app/(app)/
│   ├── inicio/                          # AJUSTA: atalhos "Minhas escalas" e "Pedidos de troca" (com contadores)
│   ├── minhas-escalas/                  # NOVO: próximas e passadas; confirmar/recusar no item
│   ├── pedidos-de-troca/                # NOVO: feitos, recebidos e (líder) aguardando aprovação
│   └── ministerios/[id]/
│       ├── page.tsx                     # AJUSTA: atalhos para escalas e funções; aviso de vagas em aberto
│       ├── funcoes/                     # NOVO: funções e aptidões dos participantes (líder/admin)
│       └── escalas/
│           ├── page.tsx                 # NOVO: lista de escalas (participante: publicadas; líder: todas)
│           ├── nova/                    # NOVO: criar escala (líder/admin)
│           └── [escalaId]/              # NOVO: detalhe, editar vagas, publicar, cancelar, responder, pedir troca
├── lib/
│   ├── escalas/
│   │   ├── validacao.ts                 # NOVO: esquemas Zod (evento, data, horário, vaga, função)
│   │   ├── consultas.ts                 # NOVO: leituras por funções (escalas, minhas escalas, trocas)
│   │   ├── datas.ts                     # NOVO: "hoje", "já começou", formatação pt-BR em America/Sao_Paulo
│   │   └── avisos.ts                    # NOVO: tipos e textos dos avisos ao líder
│   └── auth/mensagens-erro.ts           # AJUSTA: novos códigos de erro
├── components/                          # NOVOS: CartaoEscala, ListaVagas, AvisosVaga, BotoesResposta,
│                                        #   FormularioPedidoTroca, CartaoPedidoTroca, EditorFuncoes…

supabase/
├── migrations/                          # NOVAS (ver data-model.md): tipos e tabelas, RLS, funções de
│                                        #   escala, respostas, trocas, gatilhos e ajustes da 002
├── seed.sql                             # AJUSTA: funções, aptidões, escalas de exemplo
└── tests/                               # NOVOS pgTAP 020+ e AJUSTE dos que citam remover/desativar

tests/
├── unit/                                # NOVOS (datas, validação, erros, avisos)
└── e2e/                                 # NOVOS (escala completa, resposta, troca, visibilidade)

docs/decisions/
└── 0007-escalas-tempo-e-leitura.md      # NOVO (a escrever na implementação)
```

**Decisão de estrutura**: a mesma da 001/002 (projeto único Next.js, sem API própria, regras no
banco). As rotas novas ficam no grupo `(app)`; as restrições por papel continuam em `permissoes.ts`
(fonte única para a interface) e a fonte de verdade é o banco.

> **Next.js 16**: parâmetros de rota dinâmica (`params`, `searchParams`) são `Promise` e precisam de
> `await`. A implementação deve consultar `node_modules/next/dist/docs/` antes de escrever código,
> conforme o `AGENTS.md`.

## Como os testes funcionam (didático, constitution IV)

Os conceitos de unitário, banco (pgTAP), ponta a ponta e "escrever antes" são os da 001 (ver
[../001-login-papeis-acesso/plan.md](../001-login-papeis-acesso/plan.md#como-os-testes-funcionam-didático-constitution-iv)).
Nesta funcionalidade, em linguagem simples:

- **Teste de data**: o banco recebe uma escala "de ontem" e **recusa** criá-la; uma escala de hoje
  passa. Como o "agora" muda a cada dia, os testes **fixam o relógio** (o teste diz "hoje é 10/12")
  para o resultado ser sempre o mesmo. Veja [research.md](research.md#decisao-2).
- **Teste de concorrência**: dispara duas ações ao mesmo tempo sobre a mesma escala, de duas sessões reais, e confirma que só uma vence e que o estado nunca fica misturado.
- **Teste de troca atômica**: força uma falha no meio da aprovação (por exemplo, a indicada já foi
  escalada por outro caminho) e confirma que a vaga **não mudou**. Se alguém quebrar a regra, fica vermelho.
- **Teste de visibilidade**: um participante do Louvor lê a escala e **não** vê as respostas dos
  outros; uma pessoa de outro ministério não vê **nada**. Prova que vale mesmo sem a interface.
- **Teste de efeito em cascata**: remove uma pessoa do ministério e confere que as vagas futuras
  dela ficaram em aberto e as passadas continuam com ela.

## Rastreabilidade dos requisitos

| Requisitos | Onde é atendido |
|------------|-----------------|
| FR-001–004 | tabelas `funcoes_ministerio` e `aptidoes`; funções `criar_funcao`, `editar_funcao`, `desativar_funcao`, `reativar_funcao`, `definir_aptidoes`; índice único parcial por nome normalizado |
| FR-005–011 | tabelas `escalas` e `vagas_escala`; funções `criar_escala`, `editar_escala`, `salvar_vaga`, `remover_vaga`, `publicar_escala`; checagens de data no banco |
| FR-012, FR-013 | situação da escala; `cancelar_escala`; funções de leitura `listar_escalas_ministerio` e `ler_escala` |
| FR-014–016 | `salvar_vaga` (troca de pessoa) e `editar_escala` (data/horário) tratam respostas e trocas na mesma transação; leitura sempre da versão atual |
| FR-017, FR-018 | função `avisos_para_vaga` (usada por `salvar_vaga` e por `decidir_troca_lider`) |
| FR-019, FR-020 | gatilhos de remoção de participação e perda de acesso; ajuste de `desativar_ministerio` + `contar_escalas_futuras` |
| FR-021–025 | `minhas_escalas`, `listar_escalas_ministerio`, `ler_escala`; RLS e funções `security definer`; telas |
| FR-026–028 | `responder_escala` |
| FR-029–036 | `pedir_troca`, `responder_pedido_troca`, `decidir_troca_lider`, `cancelar_pedido_troca`, `listar_pedidos_troca`; índice único de pedido pendente por vaga |
| FR-037, FR-038 | constitution (acessibilidade, erros amigáveis); nenhuma coluna de dado pessoal nova |

## Acompanhamento de Complexidade

| Decisão | Por que é necessária | Alternativa mais simples rejeitada porque |
|---------|----------------------|-------------------------------------------|
| Travar a linha da escala em toda alteração (`for update`) | Garantir que troca de pessoa, mudança de horário, cancelamento e aprovação de troca nunca se misturem (FR-035, SC-004) | Sem trava, duas ações simultâneas poderiam ambas passar nas checagens e deixar a vaga num estado impossível |
| Funções de leitura em vez de leitura direta das tabelas | Mostrar nomes sem abrir `perfis` e esconder respostas dos colegas (FR-022, ADR 0006) | Liberar `select` nas tabelas exigiria uma RLS por coluna/linha complexa e arriscada |
