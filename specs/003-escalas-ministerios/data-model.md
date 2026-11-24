# Modelo de Dados: Escalas dos Ministérios

Nomes em português, conforme constitution VII. SQL completo fica nas migrações
(`supabase/migrations/`), não aqui. Parte dos modelos anteriores:
[001](../001-login-papeis-acesso/data-model.md) e [002](../002-ministerios-participantes/data-model.md).

## Tipos enumerados (novos)

| Tipo | Valores |
|------|---------|
| `tipo_aptidao` | `principal`, `secundaria` |
| `situacao_escala` | `rascunho`, `publicada`, `cancelada` |
| `resposta_escala` | `confirmado`, `recusado` ("pendente" = sem linha; ver [Decisão 1](research.md#decisao-1)) |
| `situacao_troca` | `aguardando_indicada`, `aguardando_lider`, `aprovado`, `recusado_indicada`, `recusado_lider`, `cancelado`, `sem_efeito` |

## Funções auxiliares de tempo e normalização

| Função | O que faz |
|--------|-----------|
| `agora_sp()` | instante atual (`now()`); os testes a redefinem na própria transação ([Decisão 2](research.md#decisao-2)) |
| `hoje_sp()` | data de hoje em America/Sao_Paulo |
| `inicio_da_escala(data, horario)` | instante de início em America/Sao_Paulo (imutável) |
| `normalizar_nome_funcao(texto)` | mesma ideia de `normalizar_nome_ministerio` da 002 (sem acento, caixa e espaços repetidos) |

## Tabela `funcoes_ministerio`

Papel dentro de um ministério (FR-001 a FR-003).

| Campo | Tipo | Regras |
|-------|------|--------|
| `id` | uuid, chave primária | `gen_random_uuid()` |
| `ministerio_id` | uuid | referencia `ministerios(id)`, `on delete restrict` |
| `nome` | texto, obrigatório | 2 a 40 caracteres, sem espaços nas pontas |
| `ativa` | booleano | padrão `true` |
| `criada_em` | timestamptz | padrão `now()` |
| `desativada_em` | timestamptz, anulável | preenchida ao desativar |

**Índice único parcial**: `(ministerio_id, normalizar_nome_funcao(nome)) where ativa` (FR-002).

## Tabela `aptidoes`

Em quais funções um participante é apto (FR-004).

| Campo | Tipo | Regras |
|-------|------|--------|
| `funcao_id` | uuid | referencia `funcoes_ministerio(id)`, `on delete restrict` |
| `perfil_id` | uuid | referencia `perfis(id)`, `on delete cascade` (exclusão de conta apaga) |
| `tipo` | `tipo_aptidao` | `principal` ou `secundaria`; ambas contam como "apto" |

Chave primária `(funcao_id, perfil_id)`. Só participantes do ministério da função podem ter aptidão
(validado pelas funções de escrita). Remover a pessoa do ministério **mantém** as aptidões (voltam a
valer se ela retornar); elas só deixam de ser consultadas.

## Tabela `escalas`

O conjunto de vagas de um ministério para um evento (FR-005).

| Campo | Tipo | Regras |
|-------|------|--------|
| `id` | uuid, chave primária | `gen_random_uuid()` |
| `ministerio_id` | uuid | referencia `ministerios(id)`, `on delete restrict` |
| `evento` | texto, obrigatório | 2 a 80 caracteres, sem espaços nas pontas |
| `data` | date, obrigatório | na criação `>= hoje_sp()` (FR-007) |
| `horario` | time, obrigatório | horário de início |
| `observacao` | texto | até 300 caracteres; padrão vazio |
| `situacao` | `situacao_escala` | padrão `rascunho` |
| `criada_por` | uuid, anulável | referencia `perfis(id)`, `on delete set null` |
| `criada_em`, `atualizada_em` | timestamptz | padrão `now()`; `atualizada_em` muda a cada alteração |
| `cancelada_em` | timestamptz, anulável | preenchida ao cancelar |

Índice `(ministerio_id, data)`.

**Estados**: `rascunho → publicada → cancelada`, e `rascunho → cancelada`. Não há volta de `publicada`
para `rascunho` nem reativação de cancelada (para refazer, o líder cria outra). Escala **sem vagas**
não publica. Escala com `hoje_sp() > data` é **somente leitura** em qualquer situação (FR-007), e
cancelar também é uma alteração, portanto não é permitido nesse caso.

## Tabela `vagas_escala`

Posição em uma escala (FR-008 a FR-010).

| Campo | Tipo | Regras |
|-------|------|--------|
| `id` | uuid, chave primária | `gen_random_uuid()` |
| `escala_id` | uuid | referencia `escalas(id)`, `on delete cascade` |
| `funcao_id` | uuid | referencia `funcoes_ministerio(id)`, `on delete restrict`; função ativa só ao **criar** a vaga |
| `rotulo` | texto | até 40 caracteres; padrão vazio |
| `perfil_id` | uuid, anulável | referencia `perfis(id)`, `on delete set null`; nulo = "em aberto" |
| `ordem` | inteiro | posição na lista; padrão = última + 1 |

Chave única `(id, escala_id)` (alvo da chave composta de `pedidos_troca`). Regras (nas funções de escrita e conferidas por gatilho no banco, que só age quando `perfil_id` muda, para não atrapalhar escalas antigas): `perfil_id`, quando preenchido, é
participante do ministério da escala; no máximo 50 vagas por escala; a mesma pessoa pode aparecer em
mais de uma vaga da mesma escala. Índices `(escala_id, ordem)` e `(perfil_id)`.

## Tabela `respostas_escala`

Resposta de uma pessoa a uma escala (FR-026, FR-027). Uma por pessoa por escala.

| Campo | Tipo | Regras |
|-------|------|--------|
| `escala_id` | uuid | referencia `escalas(id)`, `on delete cascade` |
| `perfil_id` | uuid | referencia `perfis(id)`, `on delete cascade` |
| `resposta` | `resposta_escala` | `confirmado` ou `recusado` |
| `motivo` | texto | até 200 caracteres; só faz sentido para `recusado`; padrão vazio |
| `respondida_em` | timestamptz | padrão `now()` |

Chave primária `(escala_id, perfil_id)`. **Invariante**: só existe linha para quem ocupa pelo menos
uma vaga da escala; as funções de escrita e o gatilho de liberação de vagas apagam a linha quando a
pessoa deixa de estar escalada.

## Tabela `pedidos_troca`

Pedido de troca de uma vaga (FR-029 a FR-036).

| Campo | Tipo | Regras |
|-------|------|--------|
| `id` | uuid, chave primária | `gen_random_uuid()` |
| `vaga_id` | uuid | referencia `vagas_escala(id)`, `on delete cascade` |
| `escala_id` | uuid | referencia `escalas(id)`, `on delete cascade` (facilita travas e consultas); chave estrangeira composta `(vaga_id, escala_id)` → `vagas_escala(id, escala_id)` garante que bate com a escala da vaga |
| `solicitante_id` | uuid | quem pediu; referencia `perfis(id)`, `on delete cascade` |
| `indicada_id` | uuid | quem foi indicada; referencia `perfis(id)`, `on delete cascade`; diferente do solicitante |
| `situacao` | `situacao_troca` | padrão `aguardando_indicada` |
| `criado_em` | timestamptz | padrão `now()` |
| `respondido_em` | timestamptz, anulável | quando a indicada respondeu |
| `decidido_por` | uuid, anulável | quem aprovou/recusou/cancelou; `on delete set null` |
| `decidido_em` | timestamptz, anulável | quando encerrou |

**Índice único parcial**: `(vaga_id) where situacao in ('aguardando_indicada','aguardando_lider')`
(FR-033). Índices por `indicada_id` e `solicitante_id` com a situação, para as telas.

### Transições do pedido

| De | Para | Quem/como |
|----|------|-----------|
| (novo) | `aguardando_indicada` | o solicitante, que ocupa a vaga, em escala publicada que ainda não começou |
| `aguardando_indicada` | `aguardando_lider` | a indicada aceita |
| `aguardando_indicada` | `recusado_indicada` | a indicada recusa |
| `aguardando_lider` | `aprovado` | o líder (ou administrador) aprova; **move a vaga** na mesma transação |
| `aguardando_lider` | `recusado_lider` | o líder (ou administrador) recusa |
| `aguardando_indicada` / `aguardando_lider` | `cancelado` | o solicitante ou o líder/administrador |
| `aguardando_*` | `sem_efeito` | efeitos automáticos (ver [Decisão 7](research.md#decisao-7)) |

Estados finais não mudam. Decidir um pedido que já não está no estado esperado devolve
`conflito_pedido`.

## Mudanças em estruturas da 002

- `participacoes_ministerio`: novo gatilho `after delete` que libera vagas futuras (FR-019).
- `perfis`: novo gatilho `after update of situacao` (quando deixa de ser `aprovado`) que libera vagas
  futuras em todos os ministérios.
- `desativar_ministerio`: passa a cancelar escalas futuras (FR-020).
- `remover_participante`: sem mudança de assinatura; o efeito vem do gatilho.

## Regras de acesso (RLS e funções)

| Tabela | Acesso direto | Como se lê/escreve |
|--------|----------------|--------------------|
| `funcoes_ministerio` | `select` para participantes do ministério, líderes e administrador (política) | escrita só por funções |
| `aptidoes` | nenhum | `listar_aptidoes` (líder/admin) e `minhas_aptidoes` |
| `escalas`, `vagas_escala`, `respostas_escala`, `pedidos_troca` | nenhum | funções de leitura e escrita ([banco-rpc.md](contracts/banco-rpc.md)) |

Quem vê o quê, resumido: administrador vê tudo; líder vê tudo do ministério que lidera (inclusive
rascunhos, respostas e motivos); participante vê escalas **publicadas** do ministério (e canceladas em
que esteve escalado), com nomes, e **só a própria** resposta; quem não participa não vê nada.

## Volume e retenção

Cresce de forma lenta e linear (ver limites em [plan.md](plan.md)). Nada expira. Exclusão de conta
apaga aptidões, respostas e pedidos da pessoa; as vagas dela ficam "em aberto" (LGPD, constitution V).
