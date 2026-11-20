# Modelo de Dados: Ministérios e Participantes

Nomes em português, conforme constitution VII. SQL completo fica nas migrações
(`supabase/migrations/`), não aqui. Parte do modelo da 001:
[../001-login-papeis-acesso/data-model.md](../001-login-papeis-acesso/data-model.md).

## Tipos enumerados (novos)

| Tipo | Valores |
|------|---------|
| `papel_ministerio` | `participante`, `lider` |
| `situacao_pedido` | `pendente`, `aceito`, `recusado`, `cancelado` |

`papel_usuario` (da 001) **não muda de forma**: o valor `lider` continua existindo no tipo, mas
passa a ser proibido em `perfis.papel` por uma constraint (ver "Mudanças em `perfis`").

## Tabela `ministerios`

Um ministério da igreja. Nunca é apagado; só desativado (RF-003).

| Campo | Tipo | Regras |
|-------|------|--------|
| `id` | uuid, chave primária | padrão `gen_random_uuid()` |
| `nome` | texto, obrigatório | sem espaços nas pontas; 2 a 60 caracteres; não pode ser só espaços (RF-006) |
| `descricao` | texto, obrigatório (pode ser vazio) | até 200 caracteres (RF-006) |
| `ativo` | booleano | padrão `true` |
| `criado_em` | timestamptz | padrão `now()` |
| `desativado_em` | timestamptz, anulável | preenchido ao desativar; limpo ao reativar |

**Índice único parcial**: `unique (normalizar_nome_ministerio(nome)) where ativo`. Dois ministérios
ativos não podem ter o mesmo nome, ignorando maiúsculas, acentos e espaços repetidos (RF-005).
Ministérios desativados podem repetir nomes entre si e com um ativo (RF-004).

## Tabela `participacoes_ministerio`

Liga uma pessoa a um ministério e diz qual é o papel dela **naquele** ministério (RF-009, RF-010).

| Campo | Tipo | Regras |
|-------|------|--------|
| `ministerio_id` | uuid | referencia `ministerios(id)` com `on delete restrict` |
| `perfil_id` | uuid | referencia `perfis(id)` com `on delete cascade` (exclusão de conta, RF-037) |
| `papel` | `papel_ministerio` | padrão `participante` |
| `desde` | timestamptz | padrão `now()` |
| `adicionado_por` | uuid, anulável | `perfis(id)` com `on delete set null`; quem adicionou a pessoa (ou quem aceitou o pedido) |

**Chave primária**: (`ministerio_id`, `perfil_id`): uma pessoa tem no máximo uma participação por
ministério, e pode ter várias no total (RF-008).

**Índice**: `perfil_id` (para "Meus ministérios" e para decidir se a pessoa lidera algo).

## Tabela `pedidos_entrada_ministerio`

Pedido de uma pessoa para entrar em um ministério (RF-016 a RF-022).

| Campo | Tipo | Regras |
|-------|------|--------|
| `id` | uuid, chave primária | padrão `gen_random_uuid()` |
| `ministerio_id` | uuid | `ministerios(id)`, `on delete restrict` |
| `perfil_id` | uuid | `perfis(id)`, `on delete cascade` |
| `situacao` | `situacao_pedido` | padrão `pendente` |
| `origem_cadastro` | booleano | `true` se nasceu no cadastro (email) ou na tela de espera da conta nova; informativo |
| `criado_em` | timestamptz | padrão `now()` |
| `decidido_por` | uuid, anulável | `perfis(id)`, `on delete set null` |
| `decidido_em` | timestamptz, anulável | quando foi aceito, recusado ou cancelado |

**Índice único parcial**: `unique (ministerio_id, perfil_id) where situacao = 'pendente'` impede
dois pedidos pendentes iguais (RF-018). Pedidos antigos (aceitos, recusados, cancelados) ficam como
registro e **não** impedem um novo pedido (RF-020).

**Índices**: (`ministerio_id`, `situacao`) para a fila do líder; `perfil_id` para "Meus ministérios".

## Mudanças em `perfis` (da 001)

1. **Migração dos líderes globais** (RF-027): `update perfis set papel = 'membro' where papel =
   'lider'`.
2. **Constraint** `perfis_papel_sem_lider check (papel <> 'lider')`: o valor deixa de poder ser
   gravado. `papel` só tem efeito em contas `aprovado`, como antes.
3. **Dados pessoais**: nenhum campo novo (RF-036).

## Transições de pedido

```text
(cadastro/pedir) ──▶ pendente ──aceitar──▶ aceito          (cria participação)
                        │
                        ├──recusar────────▶ recusado        (líder do ministério ou administrador)
                        └──cancelar───────▶ cancelado       (a própria pessoa)
```

| De | Para | Quem pode |
|----|------|-----------|
| `pendente` | `aceito` | administrador ou líder válido **do ministério do pedido**; nunca a própria pessoa |
| `pendente` | `recusado` | idem |
| `pendente` | `cancelado` | a própria pessoa; também o sistema, quando a conta é recusada ou tem o acesso removido |

`aceito`, `recusado` e `cancelado` são finais. Para tentar de novo, a pessoa cria **outro** pedido.
Toda decisão informa a situação esperada (`situacao_esperada`); se a atual for diferente, a operação
falha com aviso de conflito (RF-021).

**Aceitar** exige: ministério `ativo`; conta da pessoa `aprovado` **ou** `pendente` com email
confirmado. Se `pendente`, a conta passa a `aprovado` + papel `membro`, com `decidido_por`/
`decidido_em` do aprovador. Contas `recusado` ou `acesso_removido` não podem ser aceitas
(`transicao_invalida`).

## Regras de integridade

1. **Pelo menos um líder válido por ministério ativo (RF-012, RF-013, CS-006)**: *líder válido* =
   participação com papel `lider` **e** conta `aprovado`. Gatilho `proteger_ultimo_lider`:
   - em `participacoes_ministerio`, antes de `update` e `delete`: se a linha era de líder válido,
     de ministério ativo, e deixaria de ser (rebaixada ou apagada, inclusive por cascata da exclusão
     de conta), exige que reste outro líder válido; senão levanta `ultimo_lider`;
   - em `perfis`, antes de `update` de `situacao`: se a conta deixa de ser `aprovado`, repete a
     checagem para cada ministério ativo que ela lidera.
   Ambos travam as linhas de líder do ministério (`for update`) contra operações simultâneas.
2. **Líder inicial na criação**: `criar_ministerio` insere o ministério e o líder inicial na mesma
   transação; o líder precisa ter conta `aprovado`. Inserções diretas nas tabelas não existem.
3. **Só contas aprovadas viram participantes por adição direta** (RF-011). Quem não está
   `aprovado` só entra por aceite de pedido (e, nesse caso, a conta é ativada na mesma operação).
4. **Ministério desativado é "congelado"**: funções que adicionam, pedem ou decidem exigem
   `ativo`; participações e pedidos já existentes permanecem como estão.
5. **Cancelamento automático**: gatilho em `perfis`: quando `situacao` vira `recusado` ou
   `acesso_removido`, os pedidos pendentes da pessoa viram `cancelado`.
6. **Pedidos do cadastro (email)**: gatilho `sincronizar_perfil_auth` (da 001) lê
   `raw_user_meta_data->'ministerios'` (lista de UUIDs) e cria pedidos pendentes para ministérios
   ativos válidos; ignora o que for inválido e nunca interrompe a criação da conta. Máx. 30.
7. **Nome do ministério**: normalizado pela função imutável `normalizar_nome_ministerio` (usa
   `unaccent`) só para a comparação de unicidade; o nome exibido é o digitado (sem espaços nas pontas).

## Políticas de acesso (RLS)

RLS ligado nas três tabelas. Funções auxiliares (`security definer`, `stable`, `search_path` fixo,
lidas do banco a cada chamada, então valem na hora, RF-034):

- `eh_lider_de(p_ministerio uuid)`: o usuário atual é líder válido desse ministério ativo?
- `lidera_algum_ministerio()`: lidera ao menos um ministério ativo (usada pela interface, via RPC).

Sem `insert`/`update`/`delete` direto para `anon` nem `authenticated`; só funções.

| Tabela | Operação | Quem | Condição |
|--------|----------|------|----------|
| `ministerios` | `select` | visitante e qualquer pessoa logada | somente `ativo` e só as colunas `id`, `nome`, `descricao`, `ativo` (permissão por coluna) |
| `ministerios` | `select` | administrador aprovado | todos (ativos e desativados) |
| `participacoes_ministerio` | `select` | qualquer pessoa autenticada | só as **próprias** linhas |
| `participacoes_ministerio` | `select` | administrador aprovado | todas |
| `pedidos_entrada_ministerio` | `select` | qualquer pessoa autenticada | só os **próprios** pedidos |
| `pedidos_entrada_ministerio` | `select` | administrador aprovado | todos |

Líderes e participantes veem os **demais** (colegas, pedidos de outras pessoas) apenas pelas funções
de [contracts/banco-rpc.md](contracts/banco-rpc.md) (`listar_participantes`,
`listar_pedidos_pendentes`, `buscar_pessoas`), que devolvem nome e dados do vínculo, nunca email.
A política `perfis_ler_fila_lider` da 001 é **removida**, pois o papel global de líder não existe mais.

## Entidades da especificação → tabelas

| Entidade do spec | Tabela / local |
|------------------|----------------|
| Ministério | `ministerios` |
| Participação | `participacoes_ministerio` |
| Pedido de Entrada | `pedidos_entrada_ministerio` |
| Pessoa/Usuário (ajustada) | `perfis` (sem papel `lider`); liderança derivada das participações |

## Mapeamento requisito → dado

| Requisito | Onde |
|-----------|------|
| RF-001 a RF-007 | `ministerios`, índice único parcial, `criar_ministerio` e funções irmãs |
| RF-008 a RF-010 | PK composta de `participacoes_ministerio`, coluna `papel` |
| RF-011, RF-014 | funções de participantes com checagem de `eh_lider_de` |
| RF-012, RF-013 | gatilhos de último líder (regra 1) |
| RF-015, RF-016 | metadados do cadastro, regra 6, `pedidos_entrada_ministerio` |
| RF-017 a RF-022 | índice único de pedido pendente, `decidir_pedido_entrada`, regra 4 |
| RF-023 a RF-026 | regra de aceite que ativa a conta; `decidir_cadastro` só administrador |
| RF-027, RF-028 | migração dos líderes globais; `listar_pedidos_pendentes` |
| RF-029 a RF-034 | RLS acima e funções `listar_*` |
| RF-035 | RLS + funções `security definer`; sem escrita direta |
| RF-036, RF-037 | nenhuma coluna nova de dado pessoal; `on delete cascade` |
