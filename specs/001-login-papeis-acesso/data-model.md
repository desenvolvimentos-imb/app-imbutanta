# Modelo de Dados: Login e Papéis de Acesso

Nomes em português, conforme constitution VII. SQL completo fica nas migrações
(`supabase/migrations/`), não aqui.

## Tipos enumerados

| Tipo | Valores |
|------|---------|
| `situacao_conta` | `pendente`, `aprovado`, `recusado`, `acesso_removido` |
| `papel_usuario` | `membro`, `lider`, `administrador` |

## Tabela `perfis`

Uma linha por pessoa. Ligada 1:1 a `auth.users` (tabela do Supabase que guarda email, senha
criptografada e identidades Google; **não** a manipulamos).

| Campo | Tipo | Regras |
|-------|------|--------|
| `id` | uuid, chave primária | referencia `auth.users(id)` com `on delete cascade` (apagar a conta apaga o perfil) |
| `nome` | texto, obrigatório | removidos espaços nas pontas; 2 a 100 caracteres; não pode ser só espaços (RF-003) |
| `email` | texto, obrigatório | cópia do email de `auth.users` para listar para aprovadores sem expor `auth.users`; sincronizada por gatilho |
| `email_verificado` | booleano | `false` até a confirmação; Google já chega `true` |
| `situacao` | `situacao_conta` | padrão `pendente` (RF-008) |
| `papel` | `papel_usuario` | padrão `membro`; só tem efeito quando `situacao = aprovado` |
| `criado_em` | timestamptz | padrão `now()` (exibido em America/Sao_Paulo) |
| `decidido_por` | uuid, anulável | quem aprovou/recusou/alterou a situação; `on delete set null` |
| `decidido_em` | timestamptz, anulável | quando |

**Dados pessoais guardados**: nome e email apenas (constitution V). A exclusão remove ambos.

**Índices**: `situacao` (fila de aprovação) e `lower(email)` apenas se a busca for necessária;
na escala atual, não criar nada além da chave primária e de `situacao`.

## Tabela `administradores_iniciais`

Lista de emails que, ao serem **confirmados**, viram administradores aprovados (RF-014).

| Campo | Tipo | Regras |
|-------|------|--------|
| `email` | texto, chave primária | em minúsculas |

Criada **vazia** pela migração; o email do dono é inserido manualmente em cada ambiente.
Nenhuma política de leitura/escrita para usuários comuns (acesso só pelo painel do Supabase).

## Transições de situação

```text
(cadastro) ──▶ pendente ──aprovar──▶ aprovado ──remover acesso──▶ acesso_removido
                  │                     ▲  ▲                          │
                  └────recusar────▶ recusado  └──── reaprovar ────────┘
                                        │                  (administrador)
                                        └──── reaprovar ──▶ aprovado
```

| De | Para | Quem pode |
|----|------|-----------|
| `pendente` | `aprovado` (papel `membro`) | administrador, líder |
| `pendente` | `recusado` | administrador, líder |
| `recusado` | `aprovado` | somente administrador (reabrir cadastro) |
| `aprovado` | `acesso_removido` | somente administrador |
| `acesso_removido` | `aprovado` | somente administrador |

Qualquer outra transição é rejeitada. Toda transição exige informar a situação esperada
(`situacao_esperada`); se a atual for diferente, a operação falha com aviso de conflito (RF-013).

## Regras de integridade

1. **Último administrador (RF-022, CS-008)**: gatilho em `perfis` (antes de `update` e
   `delete`) impede que a quantidade de linhas com `situacao = aprovado` e
   `papel = administrador` chegue a zero. Vale para rebaixar, remover acesso e excluir conta,
   inclusive por alteração direta.
2. **Criação do perfil**: gatilho em `auth.users` (`insert`) cria o perfil `pendente`/`membro`
   com `nome` vindo dos metadados do cadastro (ou do nome da conta Google).
3. **Sincronia de email**: gatilho em `auth.users` (`update` de `email` ou
   `email_confirmed_at`) atualiza `email` e `email_verificado` em `perfis`.
4. **Administrador inicial**: no mesmo gatilho, quando `email_verificado` passa a `true` e o
   email está em `administradores_iniciais`, o perfil recebe `aprovado` + `administrador`.
5. **Campos protegidos**: usuário comum **não** pode alterar diretamente `situacao`, `papel`,
   `decidido_*`, `email`, `email_verificado` (só pelas funções RPC ou gatilhos).

## Políticas de acesso (RLS) em `perfis`

RLS ligado. Função auxiliar `perfil_atual()` (`security definer`, `stable`) devolve situação e
papel de `auth.uid()` lendo `perfis`, evitando recursão nas políticas.

| Operação | Quem | Condição |
|----------|------|----------|
| `select` | qualquer pessoa autenticada | somente a **própria linha** (`id = auth.uid()`), em qualquer situação (precisa ler a própria situação para saber qual tela ver) |
| `select` | administrador aprovado | todas as linhas |
| `select` | líder aprovado | apenas linhas com `situacao = pendente` **e** `email_verificado = true` |
| `update` direto | ninguém (exceto campo `nome` da própria linha) | demais mudanças só via RPC |
| `insert` / `delete` direto | ninguém | criação por gatilho; exclusão só por `excluir_minha_conta` |
| qualquer coisa | anônimo (sem login) | nenhum acesso |

A fila de aprovação mostra só quem confirmou o email (premissa do spec).

## Entidades previstas (NÃO criadas nesta funcionalidade)

- **Participação em Ministério** (RF-019): futura tabela `participacoes_ministerio`
  (`perfil_id`, `ministerio_id`, chave composta) permitirá várias participações por pessoa.
  O modelo atual já suporta isso porque a identidade da pessoa é `perfis.id`, uma chave estável
  que a tabela futura apenas referencia. Nada é criado agora (YAGNI).
- **Marcação de visibilidade de informativo** (RF-025): campo futuro `publico boolean`
  (padrão `false`) na tabela de informativos, definido na criação. Nada é criado agora e
  nenhuma rota pública existe.

## Mapeamento requisito → dado

| Requisito | Onde |
|-----------|------|
| RF-005 (mesmo email, uma conta) | unicidade de email em `auth.users` + vinculação de identidades do Supabase |
| RF-008/009/010 | `situacao` |
| RF-014 | `administradores_iniciais` + gatilho |
| RF-015/016/017/018 | `papel` + RLS |
| RF-022 | gatilho do último administrador |
| RF-030/031 | `on delete cascade` + `excluir_minha_conta` |
