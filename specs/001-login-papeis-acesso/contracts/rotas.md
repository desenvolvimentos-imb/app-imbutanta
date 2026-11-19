# Contrato de Rotas (telas) e Acesso

A interface do app é a "API" para as pessoas. Este contrato define cada rota, quem acessa e
para onde cada caso é redirecionado. A regra efetiva de segurança está no banco
([banco-rpc.md](banco-rpc.md)); este contrato define a experiência.

## Redirecionamento por situação

Fonte única: `lib/auth/sessao.ts`.

| Estado da pessoa | Destino ao abrir qualquer rota protegida |
|------------------|-------------------------------------------|
| Sem login | `/entrar?voltar=<caminho interno>` |
| Logada, `pendente` | `/aguardando-aprovacao` |
| Logada, `recusado` | `/cadastro-recusado` |
| Logada, `acesso_removido` | `/acesso-removido` |
| Logada, `aprovado` | a rota pedida (se o papel permitir), senão `/inicio` |
| Logada, tentando abrir `/entrar` ou `/cadastrar` | `/inicio` (ou a tela da situação) |

## Rotas

| Rota | Quem acessa | Função |
|------|-------------|--------|
| `/entrar` | sem login | Entrar com Google ou email/senha; links para cadastrar e recuperar senha |
| `/cadastrar` | sem login | Criar conta (nome, email, senha) ou continuar com Google |
| `/recuperar-senha` | sem login | Pedir link de recuperação; resposta sempre neutra (RF-007) |
| `/redefinir-senha` | via link de email válido | Definir nova senha; link expirado mostra aviso e oferece novo pedido |
| `/auth/callback` | navegador, após Google | Troca o código PKCE por sessão e redireciona conforme a situação |
| `/auth/confirmar` | navegador, via link de email | Confirma email ou valida recuperação e redireciona |
| `/privacidade` | qualquer pessoa, com ou sem login | Política de Privacidade (dados guardados, uso, direitos, contato) |
| `/termos` | qualquer pessoa, com ou sem login | Termos de Uso |
| `/aguardando-aprovacao` | logada `pendente` | Explica que o cadastro aguarda aprovação; permite sair |
| `/cadastro-recusado` | logada `recusado` | Informa que o cadastro não foi aprovado; permite sair e excluir conta |
| `/acesso-removido` | logada `acesso_removido` | Informa que o acesso foi removido; permite sair e excluir conta |
| `/inicio` | `aprovado` (qualquer papel) | Tela inicial que muda conforme o papel (abaixo) |
| `/aprovacoes` | `aprovado` + `administrador` ou `lider` | Lista de pendentes com email verificado; aprovar/recusar |
| `/usuarios` | `aprovado` + `administrador` | Lista de usuários, alterar papel/situação |
| `/conta` | `aprovado` | Dados da conta, sair e excluir a própria conta com confirmação |

`/entrar`, `/cadastrar`, `/recuperar-senha`, `/redefinir-senha`, `/privacidade`, `/termos`, `/auth/*` e as três telas de
situação são as **únicas** acessíveis sem conta aprovada (RF-024). Qualquer outra rota,
inclusive inexistente, exige login.

## Conteúdo da tela `/inicio` por papel

| Papel | Mostra |
|-------|--------|
| `membro` | Saudação, espaços reservados para escalas/informativos/estudos (futuros), acesso à conta |
| `lider` | Tudo do membro + atalho "Aprovar cadastros" (com contagem de pendentes) |
| `administrador` | Tudo do líder + atalho "Gerenciar usuários" |

Regra de interface: o que aparece vem de `lib/auth/permissoes.ts`. Esconder uma opção **não**
é segurança; o banco barra de qualquer forma.

## Ações de formulário (Server Actions) — entradas e erros

| Ação | Entrada | Validação | Erros exibidos (pt-BR) |
|------|---------|-----------|------------------------|
| Cadastrar com senha | nome, email, senha | nome 2–100 caracteres sem ser só espaços; email válido; senha ≥ 8 com letras e números | campo a campo; "Não foi possível criar a conta com esses dados. Tente entrar ou recuperar a senha." (sem revelar existência) |
| Entrar com senha | email, senha | campos obrigatórios | "Email ou senha incorretos." (genérica); limite de tentativas: "Muitas tentativas. Aguarde alguns minutos e tente de novo." |
| Entrar com Google | — | — | falha do Google: "Não foi possível entrar com o Google. Tente novamente." |
| Recuperar senha | email | email válido | sempre "Se o email estiver cadastrado, enviaremos um link." |
| Redefinir senha | nova senha (+ confirmação) | mesma regra de senha | link inválido/expirado: "Este link expirou ou já foi usado. Peça um novo." |
| Aprovar/recusar | id da pessoa, decisão, situação esperada | admin/líder | conflito: "A situação desta pessoa mudou. Atualize a lista." |
| Alterar papel/situação | id, novo valor, situação esperada | só admin | "Não é possível deixar o app sem administrador." / conflito |
| Excluir minha conta | confirmação explícita (digitar "EXCLUIR" ou botão de duas etapas) | confirmação presente | "Você é o único administrador. Passe o papel a outra pessoa antes de excluir a conta." |

Toda falha de rede mostra "Sem conexão. Verifique a internet e tente de novo." e não deixa a
ação pela metade (operações atômicas no banco).

## Requisitos de interface (constitution I)

- Mobile-first; alvo de toque ≥ 44 px; contraste WCAG AA; rótulos visíveis nos campos; foco
  visível; mensagens de erro associadas ao campo (`aria-describedby`) e anunciadas a leitores
  de tela.
- Aprovar/recusar a partir de `/inicio` em ≤ 3 toques (CS-003); entrar em ≤ 3 toques (CS-002).
- Botão "Continuar com Google" no padrão visual exigido pelo Google, em pt-BR.
