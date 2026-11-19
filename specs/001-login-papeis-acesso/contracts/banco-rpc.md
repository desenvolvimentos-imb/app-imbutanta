# Contrato do Banco: Funções (RPC) e Regras

Interface entre o app Next.js e o Supabase. O app chama estas funções com
`supabase.rpc('<nome>', {...})`. Todas são `security definer` com `search_path` fixo e
**validam `auth.uid()` por dentro**: não confiam em nada vindo do cliente além dos parâmetros
abaixo. Cada uma tem teste pgTAP correspondente (constitution IV).

Convenção de erros: as funções levantam exceção com um `code` estável (campo `hint` ou
`message` iniciando com o código). O app traduz em `mensagens-erro.ts`.

| Código | Significado | Mensagem ao usuário |
|--------|-------------|---------------------|
| `sem_permissao` | quem chamou não pode fazer isso | "Você não tem permissão para esta ação." |
| `conflito_situacao` | a situação atual difere da esperada | "A situação desta pessoa mudou. Atualize a lista." |
| `transicao_invalida` | transição fora da tabela de transições | "Esta alteração não é permitida." |
| `ultimo_administrador` | deixaria o app sem administrador | "Não é possível deixar o app sem administrador." |
| `nao_encontrado` | pessoa inexistente | "Pessoa não encontrada." |

## `decidir_cadastro(p_perfil uuid, p_decisao text, p_situacao_esperada situacao_conta)`

- **Quem**: `aprovado` com papel `administrador` ou `lider`.
- **Efeito**: `p_decisao = 'aprovar'` → `situacao = aprovado`, `papel = membro`;
  `'recusar'` → `situacao = recusado`. Grava `decidido_por` e `decidido_em`.
- **Regras**: só atua em `pendente` (esperada obrigatoriamente `pendente`); a pessoa precisa
  ter `email_verificado = true`; quem decide não pode decidir a si mesmo.
- **Atomicidade**: `update ... where id = p_perfil and situacao = p_situacao_esperada`; se
  nenhuma linha for afetada → `conflito_situacao` (ou `nao_encontrado`).
- **Retorno**: o perfil atualizado (id, nome, situacao, papel).

## `alterar_papel(p_perfil uuid, p_papel papel_usuario, p_situacao_esperada situacao_conta)`

- **Quem**: somente `administrador` aprovado.
- **Efeito**: muda o papel de uma pessoa `aprovado`.
- **Regras**: falha com `ultimo_administrador` se o alvo é o único administrador e o novo papel
  não é `administrador` (gatilho garante também).
- **Retorno**: perfil atualizado.

## `alterar_situacao(p_perfil uuid, p_nova situacao_conta, p_situacao_esperada situacao_conta)`

- **Quem**: somente `administrador` aprovado.
- **Efeito**: aplica as transições permitidas (ver [data-model.md](../data-model.md)):
  `aprovado ↔ acesso_removido`, `recusado → aprovado` (reaprovar entra como `membro`).
- **Regras**: `ultimo_administrador` ao remover o acesso do único administrador;
  `transicao_invalida` para o resto.
- **Retorno**: perfil atualizado.

## `excluir_minha_conta()`

- **Quem**: qualquer pessoa autenticada, em **qualquer** situação (inclui recusado e acesso
  removido, que precisam poder exercer o direito de exclusão da LGPD).
- **Efeito**: apaga a linha de `auth.users` de `auth.uid()`; `perfis` é removido por cascata;
  identidades (Google) e credenciais vão junto (RF-031). Sessões deixam de ser válidas.
- **Regras**: `ultimo_administrador` se for o único administrador (RF-022, História 5 cen. 4).
- **Retorno**: nada. O app encerra a sessão local e redireciona para `/entrar`.
- **Observação**: a confirmação explícita (RF-030) acontece na interface antes da chamada; a
  função só atua sobre `auth.uid()`, nunca sobre id recebido.

## Consultas diretas (sem RPC), cobertas por RLS

| Consulta | Quem vê |
|----------|---------|
| `perfis` da própria pessoa | qualquer autenticada |
| `perfis` pendentes com email verificado | líder e administrador |
| todos os `perfis` | administrador |
| atualizar `nome` da própria linha | própria pessoa |

Qualquer outra consulta ou escrita é negada pela RLS (teste: membro tenta ler perfil alheio
→ zero linhas; pendente tenta chamar `decidir_cadastro` → `sem_permissao`).

## Contrato de autenticação (Supabase Auth)

Operações usadas e respectivos comportamentos esperados; configuradas em
`supabase/config.toml` e espelhadas no painel de cada ambiente:

| Operação | Observação |
|----------|-----------|
| `signUp({ email, password, options: { data: { nome } } })` | exige confirmação de email; `nome` vai em metadados e é lido pelo gatilho |
| `signInWithPassword` | falha genérica em credenciais inválidas |
| `signInWithOAuth({ provider: 'google', redirectTo: <origem>/auth/callback })` | fluxo PKCE |
| `resetPasswordForEmail(email)` | resposta neutra; o link do email (modelo em `supabase/templates/`) aponta para `{{ .SiteURL }}/auth/confirmar?token_hash=...&type=recovery` |
| `updateUser({ password })` | só após validar o link de recuperação |
| `signOut()` | encerra a sessão local |
| `exchangeCodeForSession` / `verifyOtp` | `exchangeCodeForSession` em `/auth/callback` (Google); `verifyOtp` com `token_hash` em `/auth/confirmar` (confirmação de email e recuperação), que funciona mesmo abrindo o email em outro aparelho |

Configuração obrigatória (por ambiente): confirmação de email **ligada**; senha mínima 8 com
letras e números; URL do site e URLs de retorno permitidas (local, preview e produção);
provedor Google com Client ID/Secret (segredos só no painel/variáveis de ambiente, nunca no
repositório); SMTP próprio (produção).
