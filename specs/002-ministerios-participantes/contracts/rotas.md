# Contrato de Rotas (telas) e Acesso: Ministérios

Complementa [rotas.md da 001](../../001-login-papeis-acesso/contracts/rotas.md). A regra efetiva de
segurança está no banco ([banco-rpc.md](banco-rpc.md)); este contrato define a experiência.

## Quem é "líder" na interface

Fonte única: `lib/auth/permissoes.ts` (ajustada). Não existe mais o papel global `lider`. Uma pessoa
é tratada como **líder** quando `ministerios_que_lidero()` devolve ao menos um ministério. A
sessão (`lib/auth/sessao.ts`) carrega esse dado junto do perfil, **do banco a cada requisição**
(RF-034).

| Estado | Efeito |
|--------|--------|
| `administrador` | acesso a tudo desta funcionalidade |
| aprovado com `lidera > 0` | vê "Pedidos e aprovações" e gerencia só os ministérios que lidera |
| aprovado sem liderança | vê "Meus ministérios" e a lista de ministérios para pedir entrada |

## Rotas novas e ajustadas

| Rota | Quem acessa | Função |
|------|-------------|--------|
| `/cadastrar` (ajustada) | sem login | Formulário ganha, antes do botão, a lista opcional "Ministérios de que você participa" (caixas de marcar). A lista **não aparece** se não houver ministério ativo |
| `/aguardando-aprovacao` (ajustada) | logada `pendente` | Além do aviso, mostra os pedidos já feitos e, se houver ministérios ativos, "Pedir ministérios" (fluxo do Google e quem esqueceu de marcar) |
| `/inicio` (ajustada) | `aprovado` | Atalhos "Meus ministérios" e "Ministérios" para todos; "Pedidos e aprovações" com contador para administrador e líder; "Gerenciar usuários" só administrador |
| `/aprovacoes` (ajustada) | `aprovado` + administrador **ou** líder de algum ministério | Seção **Pedidos de entrada** (administrador: todos; líder: só dos seus ministérios) com Aceitar/Recusar por pedido, indicando o ministério e, se for o caso, "Aceitar também ativa a conta". Seção **Cadastros pendentes** só para administrador (aprovar/recusar a conta sem ministério) |
| `/usuarios` (ajustada) | `aprovado` + administrador | A opção de papel "Líder" some; só "Membro" e "Administrador". Remover acesso de quem lidera sozinho mostra o erro `ultimo_lider` |
| `/meus-ministerios` | `aprovado` | Ministérios de que participo (papel em cada um), meus pedidos e estado (pendente, recusado), botão "Pedir para entrar em outro ministério" e "Cancelar pedido". **Tela vazia amigável** quando não participo de nenhum (RF-033) |
| `/ministerios` | `aprovado` | Administrador: lista de ativos e desativados com "Novo ministério". Demais: lista de ativos com nome e descrição, e "Pedir para entrar" quando aplicável (RF-032) |
| `/ministerios/novo` | `aprovado` + administrador | Criar ministério: nome, descrição curta e líder inicial (busca por nome entre contas aprovadas) |
| `/ministerios/[id]` | `aprovado`; conteúdo por papel (abaixo) | Detalhe do ministério |

`/ministerios/[id]` exige `await params` (Next.js 16).

### Conteúdo de `/ministerios/[id]` por papel

| Quem | Mostra |
|------|--------|
| Administrador | tudo: nome, descrição, participantes (nome e papel), pedidos pendentes, editar, desativar/reativar, adicionar/remover participante, promover/rebaixar líder |
| Líder **deste** ministério (ativo) | participantes e pedidos pendentes; adicionar/remover participante; promover/rebaixar; **não** edita nem desativa (só administrador) |
| Participante **deste** ministério | nome, descrição e lista de participantes (nome e papel); sem ações de gestão |
| Qualquer outra pessoa | só nome e descrição, e "Pedir para entrar"; **sem** lista de participantes (RF-031). Para ministério desativado: não encontrado |

Regra de interface: o que aparece vem de `permissoes.ts` e das funções de leitura; esconder uma
opção **não** é segurança, o banco barra de qualquer forma (RF-035).

## Redirecionamento por situação (inalterado)

O comportamento da 001 continua: sem login → `/entrar`; `pendente` → `/aguardando-aprovacao`;
etc. As rotas novas ficam no grupo `(app)`, exigem conta `aprovado`, e as restrições de papel são
estas: `/aprovacoes` (administrador ou líder), `/ministerios/novo` e `/usuarios` (administrador).
Páginas sem login continuam sendo só as da 001; **a lista de ministérios ativos usada no cadastro é
lida no servidor e não cria rota pública nova**.

## Ações de formulário (Server Actions): entradas e erros

| Ação | Entrada | Validação | Erros exibidos (pt-BR) |
|------|---------|-----------|------------------------|
| Cadastrar com senha (ajustada) | nome, email, senha, `ministerios[]` (opcional) | como na 001; ids precisam ser UUID (ignorados se inválidos) | como na 001; o cadastro **não falha** por causa dos ministérios |
| Pedir ministérios (tela de espera) | `ministerios[]` | ids UUID | "Este ministério está desativado." / "Você já tem um pedido pendente…" |
| Criar ministério | nome, descrição, líder inicial | nome 2–60, descrição ≤ 200, líder escolhido | `nome_duplicado`, `nome_invalido`, `pessoa_invalida` |
| Editar ministério | nome, descrição | idem | idem |
| Desativar / reativar | id (reativar: líder opcional) | — | `sem_lider` ao reativar sem líder; `nome_duplicado` |
| Adicionar participante | ministério, pessoa (da busca), papel | pessoa escolhida da lista de resultados | `ja_participa`, `pessoa_invalida`, `ministerio_inativo` |
| Alterar papel / remover participante | ministério, pessoa | — | `ultimo_lider` ("O ministério precisa de pelo menos um líder. Defina outro líder antes.") |
| Pedir entrada | ministério | — | `ja_participa`, `pedido_duplicado`, `ministerio_inativo` |
| Cancelar pedido | pedido | — | `conflito_pedido` |
| Aceitar / recusar pedido | pedido, decisão, situação esperada = `pendente` | — | `conflito_pedido` ("Este pedido já foi decidido. Atualize a lista."), `sem_permissao` |

Toda falha de rede mostra "Sem conexão. Verifique a internet e tente de novo." e não deixa a ação
pela metade (operações atômicas no banco). `mensagens-erro.ts` traduz os novos códigos.

## Requisitos de interface (constitution I)

- Mobile-first; alvo de toque ≥ 44 px; contraste WCAG AA; rótulos visíveis; foco visível; erros
  associados ao campo (`aria-describedby`) e anunciados; caixas de marcar do cadastro com rótulo
  claro e agrupadas em `fieldset`/`legend`.
- Toques a partir da tela inicial: aceitar pedido = 2 (Início → Pedidos e aprovações → Aceitar);
  pedir entrada = 3 (Início → Meus ministérios → Pedir → confirmar); ver "Meus ministérios" = 1.
- A tela "Meus ministérios" e a de pedidos têm **estado vazio** com texto orientador, não tela em branco.
- Confirmação antes de ações que removem pessoa ou desativam ministério (botão de duas etapas).
