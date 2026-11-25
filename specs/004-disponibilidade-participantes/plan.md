# Plano de Implementação: Disponibilidade dos Participantes dos Ministérios

**Branch**: `004-disponibilidade-participantes` | **Data**: 2026-11-24 | **Spec**: [spec.md](spec.md)

**Entrada**: Especificação em `specs/004-disponibilidade-participantes/spec.md`

## Resumo

Quarta funcionalidade do app IM Butantã: o líder cria **consultas de disponibilidade** (datas
propostas de um ministério), os participantes marcam "disponível" ou "indisponível" por data, e o
líder acompanha tudo numa **grade** com totais por data e por função. A disponibilidade também
aparece na hora de escalar alguém (integração com a 003).

A stack **não muda** (Next.js 16 + Supabase + Vercel). A abordagem repete a da 001, 002 e 003:
**as regras vivem no banco** (RLS + funções SQL atômicas) e a interface só reflete essas regras.

Pontos centrais do desenho (detalhes em [research.md](research.md)):

- **Quatro tabelas novas**: `consultas_disponibilidade`, `datas_consulta`, `respostas_disponibilidade`
  e `observacoes_disponibilidade`. Nenhuma aceita escrita direta; só funções `security definer`.
- **"Sem resposta" é a ausência de linha** em `respostas_disponibilidade`, como o "pendente" da 003.
  Por construção, "sem resposta" nunca vira "indisponível": são coisas diferentes no banco.
- **"Mesma data, mesmo ministério" garantida por índice único** (`ministerio_id`, `data`) em
  `datas_consulta`, e não só por checagem na função; vale até em corrida entre dois líderes.
- **"Consulta aberta" é calculada**: não está fechada e o prazo não terminou (`hoje_sp() <= prazo`).
  Nenhuma tarefa agendada; mesma ideia do tempo calculado da 003 (ADR 0007).
- **Leitura só por funções**, nunca pelas tabelas: a grade mostra nomes e só líderes/administradores
  veem respostas alheias e observações (ADR 0006: `perfis` continua fechada).
- **Quem sai do ministério** some das leituras por junção com `participacoes_ministerio`, sem apagar
  nada; se voltar, as respostas reaparecem.
- **Confirmação de remoção de data** devolvida como dado (`confirmacao_necessaria`), no mesmo padrão
  dos avisos de `salvar_vaga`: nada é gravado até o líder confirmar.
- **Integração com escalas sem mexer em funções já aplicadas**: `avisos_para_vaga` ganha um novo tipo
  de aviso (`sem_disponibilidade`) por migração nova, e uma função de leitura nova
  (`disponibilidade_da_escala`) alimenta a indicação ao lado de cada pessoa e na escolha da pessoa.
- **Tela inicial**: uma função leve (`contar_consultas_pendentes`) alimenta o aviso.

## Contexto Técnico

**Linguagem/Versão**: TypeScript 5.x em Node.js 22 LTS; SQL (Postgres 15+ do Supabase), igual à 001–003

**Dependências principais**: as da 001–003 (Next.js 16, React 19, `@supabase/supabase-js`,
`@supabase/ssr`, Tailwind CSS, Zod). **Nenhuma dependência nova**, nem extensão no banco. O
calendário usa o seletor de data nativo do navegador (`<input type="date">`) e a lista de datas
escolhidas; sem biblioteca de calendário (constitution II).

**Armazenamento**: Supabase Postgres: 4 tabelas e 1 tipo novos; ver [data-model.md](data-model.md)

**Testes**: Vitest (atalho "todos os <dia da semana> do mês", validação, mensagens de erro, avisos),
pgTAP via `supabase test db` (regras, RLS, privacidade, prazo, atomicidade, integração com escalas),
Playwright (fluxos ponta a ponta em celular emulado), mais um teste de concorrência com duas sessões
`supabase-js` (responder × fechar)

**Plataforma alvo**: navegadores móveis modernos (Chrome Android, Safari iOS) e desktop; PWA

**Tipo de projeto**: aplicação web única (Next.js com o Supabase como backend)

**Metas de desempenho**: telas utilizáveis em < 10 s em conexão móvel comum; a grade de uma consulta
carrega com **uma** chamada de função (até ~60 participantes × ~10 datas); sem paginação

**Restrições**: custo zero; somente online; pt-BR; WCAG AA; mobile-first (grade utilizável a 360 px);
dados mínimos (única informação nova: a resposta e uma observação de até 300 caracteres); datas no
formato brasileiro e fuso America/Sao_Paulo

**Escala/Escopo**: dezenas de ministérios, centenas de pessoas, poucas consultas por mês por
ministério, até 31 datas por consulta; 4 telas novas e 3 ajustadas

### Limites gratuitos e o que acontece ao ultrapassar (constitution VI)

Nenhum serviço novo. Os limites da 001 continuam valendo. Impacto desta funcionalidade:

| Serviço | Limite relevante | Impacto desta funcionalidade |
|---------|------------------|------------------------------|
| Supabase Postgres (500 MB) | espaço do banco | linhas minúsculas: 20 ministérios × 2 consultas/mês × 8 datas × 15 pessoas ≈ 57 mil respostas/ano, bem abaixo de 10 MB/ano. Ao se aproximar do limite, consultas antigas podem ser arquivadas (fora do escopo agora) |
| Vercel Hobby | banda e execuções | algumas telas dinâmicas leves; sem efeito perceptível |

## Verificação da Constitution

*Portão: deve passar antes da Fase 0. Reavaliado após o design da Fase 1.*

| Princípio | Avaliação | Como o plano atende |
|-----------|-----------|---------------------|
| I. Mobile-first, PWA, pt-BR, WCAG AA | ✅ | Responder: início → "Disponibilidade" → marcar e salvar (≤ 3 toques até a consulta); grade com **visão por data no celular** e tabela com coluna do nome fixa no computador; situação **nunca só por cor** (ícone + texto "Disponível", "Indisponível", "Sem resposta"); alvos ≥ 44 px |
| II. Simplicidade e YAGNI | ✅ | Sem biblioteca nova (data nativa); sem cron (prazo calculado); "sem resposta" = sem linha; sem notificações; sem tabela de histórico (consulta fechada já é histórico); lista de consultas do administrador reaproveita a tela do ministério |
| III. Robustez onde importa | ✅ | Funções atômicas com trava da consulta (`for update`); unicidade de data por índice; erros com código estável em pt-BR; remoção de data com respostas só após confirmação; nenhuma ação parcial deixa consulta inválida |
| IV. Testes automatizados | ✅ | pgTAP para cada regra (permissões, prazo, datas, unicidade, respostas, privacidade, integração com escalas); Vitest e Playwright para a interface; conceitos novos explicados em "Como os testes funcionam". Disponibilidade influencia escalas, área crítica da constitution |
| V. Privacidade/LGPD | ✅ | Dado novo mínimo e justificado na spec (resposta e observação); respostas e observação só para a própria pessoa e líderes/administradores; exclusão de conta apaga respostas e observações (cascata); sem email nas funções de leitura; acesso aplicado no banco |
| VI. Custo zero | ✅ | Nenhum serviço novo |
| VII. Documentação pt-BR | ✅ | ADR 0008 (prazo calculado + "sem resposta" como ausência + integração por avisos) a escrever na implementação; comentários com o porquê; README atualizado |
| Migrações automatizadas (constituição 1.3.0) | ✅ | Migrações novas seguem pelo workflow `migracoes.yml` (ADR 0005); nenhuma migração aplicada é editada: `avisos_para_vaga` e `desativar_ministerio` são redefinidos por migração nova |
| Fluxo de branches | ✅ | Branch `004-disponibilidade-participantes` criada a partir de `develop` (já com o fechamento da 003 mergeado); ajustes da mesma funcionalidade no mesmo PR |

**Resultado do portão**: aprovado, sem violações.

**Reavaliação pós-design (Fase 1)**: mantida a aprovação. O design acrescentou quatro tabelas e
funções SQL; nada além do que a especificação exige. A seção de Complexidade registra as duas
decisões não óbvias.

## Estrutura do Projeto

### Documentação (esta funcionalidade)

```text
specs/004-disponibilidade-participantes/
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

### Código-fonte (acréscimos e mudanças sobre a 001–003)

```text
src/
├── app/(app)/
│   ├── inicio/                              # AJUSTA: atalho "Disponibilidade" com aviso de consulta aguardando resposta
│   ├── disponibilidade/                     # NOVO: consultas abertas dos meus ministérios
│   │   └── [consultaId]/                    # NOVO: responder (datas, observação); fechada = somente leitura
│   └── ministerios/[id]/
│       ├── page.tsx                         # AJUSTA: atalho "Disponibilidade" (gestor)
│       ├── disponibilidade/                 # NOVO: lista de consultas (abertas e histórico), gestor
│       │   ├── nova/                        # NOVO: criar consulta (datas, atalho de mês, rótulos)
│       │   └── [consultaId]/                # NOVO: grade, editar, fechar/reabrir, preencher pela pessoa
│       └── escalas/[escalaId]/              # AJUSTA: indicação de disponibilidade ao lado de cada pessoa
├── lib/
│   ├── disponibilidade/
│   │   ├── validacao.ts                     # NOVO: esquemas Zod (título, mensagem, prazo, datas, observação)
│   │   ├── consultas.ts                     # NOVO: leituras por funções (minhas, lista, grade)
│   │   ├── datas.ts                         # NOVO: atalho "todos os <dia> de <mês>", formatação pt-BR
│   │   └── gestao.ts                        # NOVO: ações do servidor (criar, editar, fechar, responder…)
│   ├── escalas/avisos.ts                    # AJUSTA: novo tipo de aviso `sem_disponibilidade`
│   └── auth/mensagens-erro.ts               # AJUSTA: novos códigos de erro
├── components/                              # NOVOS: SeletorDatas, FormularioConsulta, FormularioResposta,
│                                            #   GradeDisponibilidade, VisaoPorData, SeloDisponibilidade,
│                                            #   ContagemPorFuncao, AcoesConsulta; AJUSTA: AvisosVaga, ListaVagas

supabase/
├── migrations/                              # NOVAS (ver data-model.md): tipo e tabelas, acesso, escrita,
│                                            #   respostas, leitura, integração com escalas, desativar ministério
├── seed.sql                                 # AJUSTA: consultas, datas e respostas de exemplo
└── tests/                                   # NOVOS pgTAP 040+ e AJUSTE dos que citam avisos de vaga

tests/
├── unit/                                    # NOVOS (atalho de datas, validação, erros, avisos)
└── e2e/                                     # NOVOS (criar e responder, grade no celular, integração com escala)

docs/decisions/
└── 0008-disponibilidade-prazo-e-ausencia.md # NOVO (a escrever na implementação)
```

**Decisão de estrutura**: a mesma da 001–003 (projeto único Next.js, sem API própria, regras no
banco). As rotas novas ficam no grupo `(app)`; as restrições por papel continuam em `permissoes.ts`
(fonte única para a interface) e a fonte de verdade é o banco.

> **Next.js 16**: parâmetros de rota dinâmica (`params`, `searchParams`) são `Promise` e precisam de
> `await`. A implementação deve consultar `node_modules/next/dist/docs/` antes de escrever código,
> conforme o `AGENTS.md`.

## Como os testes funcionam (didático, constitution IV)

Os conceitos de unitário, banco (pgTAP), ponta a ponta e "escrever antes" são os da 001 (ver
[../001-login-papeis-acesso/plan.md](../001-login-papeis-acesso/plan.md#como-os-testes-funcionam-didático-constitution-iv)).
O relógio fixo vem da 003 ([research.md da 003](../003-escalas-ministerios/research.md#decisao-2)).
Nesta funcionalidade, em linguagem simples:

- **Teste de prazo**: o teste diz "hoje é 10/12" e cria uma consulta com prazo em 10/12: ela ainda
  está aberta; diz "hoje é 11/12": passou a fechada, sem ninguém ter feito nada. É o relógio fixo que
  torna o resultado sempre o mesmo.
- **Teste de "sem resposta ≠ indisponível"**: a pessoa marca só uma data; o teste confirma que as
  outras aparecem como "sem resposta" e que a contagem de "disponíveis" não as inclui nem as trata
  como "indisponível". Se alguém quebrar essa distinção, fica vermelho.
- **Teste de data repetida**: duas consultas do mesmo ministério com a mesma data: a segunda é
  recusada; ministérios diferentes: permitido. Um teste extra tenta "furar" a regra gravando as duas
  ao mesmo tempo.
- **Teste de privacidade**: um participante não vê respostas nem observação de outro; uma pessoa de
  outro ministério não vê nada; quem saiu do ministério some da grade. Prova que vale sem a interface.
- **Teste de remoção com respostas**: remover uma data com respostas sem confirmar não muda nada;
  confirmando, a data e as respostas somem juntas (tudo ou nada).
- **Teste de integração com escalas**: escalar alguém "indisponível" ou "sem resposta" devolve o
  aviso e só grava quando o líder confirma; data sem consulta não gera aviso nenhum.
- **Teste de concorrência**: a pessoa salva a resposta no mesmo instante em que o líder fecha a
  consulta: só uma ordem é possível, e o resultado nunca fica misturado.

## Rastreabilidade dos requisitos

| Requisitos | Onde é atendido |
|------------|-----------------|
| RF-001–005 | tabelas `consultas_disponibilidade` e `datas_consulta`; funções `criar_consulta`, `adicionar_datas_consulta`; índice único `(ministerio_id, data)`; atalho de mês em `lib/disponibilidade/datas.ts` |
| RF-006–008 | coluna `fechada` + prazo calculado em `consulta_esta_aberta`; funções `fechar_consulta`, `reabrir_consulta` |
| RF-009–011 | `editar_consulta`, `adicionar_datas_consulta`, `remover_data_consulta` (com `confirmacao_necessaria`) |
| RF-012, RF-013 | nenhuma função de exclusão; ajuste de `desativar_ministerio` (fecha as consultas abertas) |
| RF-014–017 | `responder_disponibilidade`, `minhas_consultas`, `contar_consultas_pendentes`; ausência de linha = "sem resposta" |
| RF-018, RF-020 | tabela `observacoes_disponibilidade`; leituras por funções; sem leitura direta das tabelas |
| RF-019 | junção com `participacoes_ministerio` em todas as leituras; nada é apagado |
| RF-021 | `preencher_disponibilidade` (coluna `preenchida_por`) |
| RF-022–027 | `ler_consulta_gestor`, `listar_consultas_ministerio`; `eh_gestor_de` em toda função de gestão; telas |
| RF-028–030 | `avisos_para_vaga` (novo aviso), `disponibilidade_da_escala`; telas de escala ajustadas |

## Acompanhamento de Complexidade

| Decisão | Por que é necessária | Alternativa mais simples rejeitada porque |
|---------|----------------------|-------------------------------------------|
| `ministerio_id` repetido em `datas_consulta` (com chave estrangeira composta) | Permitir o índice único `(ministerio_id, data)` e garantir a regra RF-005 no banco, também em corrida entre dois líderes | Checar só dentro da função deixaria duas gravações simultâneas passarem; o índice é a única garantia total |
| Visão por data **e** tabela na grade | A tabela com muitas colunas não é legível a 360 px; a visão por data resolve o celular sem perder a tabela no computador | Só tabela com rolagem horizontal falha no teste de uso do celular (constitution I); só visão por data perde a visão geral no computador |
