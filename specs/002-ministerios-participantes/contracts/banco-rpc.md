# Contrato do Banco: Funções (RPC) e Regras: Ministérios

Interface entre o app Next.js e o Supabase para esta funcionalidade. Segue as convenções da 001
([banco-rpc.md](../../001-login-papeis-acesso/contracts/banco-rpc.md)): funções `security definer`
com `search_path` fixo, que **validam `auth.uid()` por dentro**; erros com código estável na
mensagem; cada função tem teste pgTAP (constitution IV). O app chama com `supabase.rpc('<nome>', {...})`.

## Novos códigos de erro

Somam-se aos da 001 (`sem_permissao`, `conflito_situacao`, `transicao_invalida`, `nao_encontrado`,
`ultimo_administrador`).

| Código | Significado | Mensagem ao usuário |
|--------|-------------|---------------------|
| `nome_duplicado` | já existe ministério ativo com esse nome | "Já existe um ministério ativo com esse nome." |
| `nome_invalido` | nome ou descrição fora das regras | "Informe um nome de 2 a 60 caracteres e uma descrição de até 200." |
| `ultimo_lider` | deixaria o ministério sem líder (ou a pessoa é a única líder de algum) | "O ministério precisa de pelo menos um líder. Defina outro líder antes." |
| `ministerio_inativo` | ministério desativado | "Este ministério está desativado." |
| `ja_participa` | a pessoa já participa do ministério | "Esta pessoa já participa deste ministério." |
| `pedido_duplicado` | já existe pedido pendente | "Você já tem um pedido pendente para este ministério." |
| `conflito_pedido` | a situação do pedido mudou desde que a tela abriu | "Este pedido já foi decidido. Atualize a lista." |
| `pessoa_invalida` | a pessoa não existe ou não pode ser adicionada (conta não aprovada) | "Esta pessoa não pode ser adicionada." |
| `sem_lider` | reativar sem líder válido | "Escolha um líder para reativar o ministério." |

`ultimo_lider` também é o erro quando se tenta **excluir a conta** ou **remover o acesso** de quem é a
única líder de algum ministério ativo; a mensagem do app inclui o nome do ministério (vem em
`hint`/detalhe da exceção).

## Funções de ministérios (somente administrador)

### `criar_ministerio(p_nome text, p_descricao text, p_lider uuid)` → `ministerios`

- **Quem**: administrador aprovado.
- **Efeito**: cria o ministério ativo e o líder inicial na mesma transação (RF-001).
- **Regras**: nome/descrição validados (`nome_invalido`); líder precisa ter conta `aprovado`
  (`pessoa_invalida`); nome único entre ativos (`nome_duplicado`).

### `editar_ministerio(p_id uuid, p_nome text, p_descricao text)` → `ministerios`

- **Quem**: administrador. **Regras**: mesmas validações; `nome_duplicado` se o novo nome colidir com
  outro ministério **ativo**; `nao_encontrado`.

### `desativar_ministerio(p_id uuid)` → `ministerios`

- **Quem**: administrador. **Efeito**: `ativo = false`, `desativado_em = now()`; **nada** é apagado
  (RF-003). Idempotente: desativar um já desativado devolve o registro.

### `reativar_ministerio(p_id uuid, p_lider uuid default null)` → `ministerios`

- **Quem**: administrador. **Efeito**: `ativo = true`, limpa `desativado_em`.
- **Regras**: `nome_duplicado` se o nome já está em uso por ativo; se não houver líder válido, exige
  `p_lider` (conta `aprovado`) e o torna líder; senão `sem_lider`.

## Funções de participantes (administrador ou líder do ministério)

Em todas: ministério precisa estar `ativo` (`ministerio_inativo`) e quem chama precisa ser
administrador **ou** líder válido daquele ministério (`sem_permissao`; RF-014).

### `adicionar_participante(p_ministerio uuid, p_perfil uuid, p_papel papel_ministerio)` → participação

- **Efeito**: cria a participação (RF-011). Se a pessoa tinha pedido pendente para o ministério, o
  pedido passa a `aceito` (decidido por quem adicionou).
- **Regras**: a pessoa precisa estar `aprovado` (`pessoa_invalida`); `ja_participa` se já existe.

### `alterar_papel_ministerio(p_ministerio uuid, p_perfil uuid, p_papel papel_ministerio)` → participação

- **Efeito**: troca entre `participante` e `lider` apenas **naquele** ministério (RF-010).
- **Regras**: rebaixar o último líder válido → `ultimo_lider` (pelo gatilho); `nao_encontrado` se a
  pessoa não participa.

### `remover_participante(p_ministerio uuid, p_perfil uuid)` → void

- **Efeito**: apaga a participação. **Regras**: remover o último líder válido → `ultimo_lider`.
  Remover-se a si mesmo é permitido, exceto sendo o último líder.

### `buscar_pessoas(p_ministerio uuid, p_termo text)` → tabela (`id`, `nome`)

- **Quem**: administrador ou líder do ministério.
- **Efeito**: nomes de contas `aprovado` que **ainda não participam** do ministério e cujo nome
  contém `p_termo` (sem diferenciar acento/caixa). Mínimo 2 letras; no máximo 20 linhas.
- **Privacidade**: devolve só `id` e `nome` (nunca email). Ver [research.md](../research.md#decisao-3).

## Pedidos de entrada

### `pedir_entrada_ministerio(p_ministerio uuid)` → `pedidos_entrada_ministerio`

- **Quem**: pessoa autenticada com conta `aprovado` **ou** `pendente` (fluxo Google). Contas
  `recusado`/`acesso_removido` → `sem_permissao`.
- **Efeito**: cria pedido `pendente` (RF-017). `origem_cadastro = true` se a conta ainda estava
  `pendente`.
- **Regras**: ministério ativo (`ministerio_inativo`); `ja_participa`; `pedido_duplicado`.

### `cancelar_pedido_entrada(p_pedido uuid)` → void

- **Quem**: a própria pessoa. **Efeito**: `pendente` → `cancelado`. Se já foi decidido,
  `conflito_pedido`. Pedido de outra pessoa ou inexistente responde `nao_encontrado` (não revela que existe).

### `decidir_pedido_entrada(p_pedido uuid, p_decisao text, p_situacao_esperada situacao_pedido)` → resultado

- **Quem**: administrador ou líder válido **do ministério do pedido**; ninguém decide o próprio
  pedido (`sem_permissao`).
- **Efeito**:
  - `'aceitar'`: pedido → `aceito`; cria participação `participante` (se já existir, mantém); se a
    conta estiver `pendente`, ela passa a `aprovado` + `membro`, gravando `decidido_por` e
    `decidido_em` (RF-023). Tudo em uma transação.
  - `'recusar'`: pedido → `recusado`. **Não altera a conta** (RF-020, RF-024).
- **Regras**: `p_situacao_esperada` deve ser `pendente`; conflito se mudou (`conflito_pedido`,
  RF-021); ministério ativo (`ministerio_inativo`); conta `recusado`/`acesso_removido` →
  `transicao_invalida`; conta `pendente` sem email confirmado → `transicao_invalida` (mesma regra da
  fila de aprovação da 001).
- **Retorno**: o pedido atualizado (a situação da conta resultante se consulta à parte).

## Leituras por função (sem expor email)

### `listar_participantes(p_ministerio uuid)` → tabela (`perfil_id`, `nome`, `papel`, `desde`)

- **Quem**: administrador, líder do ministério, ou participante dele. Ministério desativado: só
  administrador. **Só devolve pessoas com conta `aprovado`**: quem foi recusado, teve o acesso
  removido ou excluiu a conta não aparece (o vínculo permanece registrado e volta a aparecer se a
  conta for reaprovada). Quem não se enquadra recebe lista **vazia** (e não erro, para não revelar a
  existência do ministério) (RF-030, RF-031).

### `listar_pedidos_pendentes()` → tabela (`pedido_id`, `ministerio_id`, `ministerio_nome`, `perfil_id`, `nome`, `criado_em`, `conta_pendente`)

- **Quem**: administrador (todos os pedidos pendentes de ministérios ativos) ou líder (somente os
  dos ministérios que lidera). Outros recebem lista vazia.
- **Regra de visibilidade**: só entram pedidos de contas **aprovadas** ou **pendentes com email
  confirmado**; `conta_pendente` indica que aceitar também ativará a conta (RF-028).

### `contar_pedidos_pendentes()` → inteiro

- Mesmas regras de `listar_pedidos_pendentes`; usada pelo contador da tela inicial.

### `ministerios_que_lidero()` → tabela (`id`, `nome`)

- **Quem**: qualquer autenticado. Devolve os ministérios ativos em que o usuário é líder válido; a
  interface usa para mostrar telas de líder (RF-027) e os atalhos.

## Funções alteradas da 001

| Função | Mudança |
|--------|---------|
| `decidir_cadastro` | passa a ser **somente administrador** (antes: administrador ou líder). É o caminho para quem não pediu ministério (RF-025). Líder deixa de poder aprovar conta diretamente; aprova via pedido |
| `alterar_papel` | `p_papel = 'lider'` passa a ser `transicao_invalida` (a constraint em `perfis` também barra) |
| `alterar_situacao` | continua igual, mas o gatilho de `perfis` agora também levanta `ultimo_lider` ao remover o acesso de quem é a única líder de um ministério |
| `excluir_minha_conta` | continua igual; a cascata dispara `proteger_ultimo_lider`, então quem é a única líder de um ministério ativo recebe `ultimo_lider` |
| `sincronizar_perfil_auth` (gatilho) | passa a criar os pedidos a partir dos metadados do cadastro |

## Consultas diretas (sem RPC), cobertas por RLS

| Consulta | Quem vê |
|----------|---------|
| `ministerios` (ativos: `id`, `nome`, `descricao`) | qualquer pessoa, **inclusive visitante** (para o cadastro) |
| `ministerios` (todos) | administrador |
| `participacoes_ministerio` | a própria pessoa (as suas); administrador (todas) |
| `pedidos_entrada_ministerio` | a própria pessoa (os seus); administrador (todos) |

Qualquer outra consulta ou escrita é negada (testes: participante lê participações de outra pessoa →
zero linhas; líder do Louvor chama `decidir_pedido_entrada` de pedido da Recepção → `sem_permissao`;
membro chama `criar_ministerio` → `sem_permissao`; escrita direta nas tabelas → negada).
