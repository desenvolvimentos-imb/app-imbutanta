# 0006 — Liderança por ministério e leitura restrita de dados

- **Data**: 2026-11-20
- **Situação**: Aceita e implementada
- **Origem**: plano de `002-ministerios-participantes` ([research](../../specs/002-ministerios-participantes/research.md))

## Contexto

A funcionalidade 001 tinha três papéis globais (administrador, líder de ministério e membro) e
previa, sem criar, a participação em ministérios. A 002 cria os ministérios e exige que a liderança
valha **por ministério** (quem lidera o Louvor não lidera a Recepção). Dois papéis de liderança ao
mesmo tempo (um global e um por ministério) gerariam contradições, por exemplo um "líder global"
aprovando qualquer pessoa. Além disso, a tela de cadastro (sem login) precisa listar os ministérios
para a pessoa marcar, e líderes e participantes precisam ver colegas sem receber o email deles.

## Decisão

1. **A liderança é derivada, não um papel da pessoa.** É líder quem tem participação com papel
   `lider` em um ministério **ativo** e conta `aprovado`. `perfis.papel` fica só com `membro` e
   `administrador`. O valor `lider` permanece no tipo `papel_usuario` (o Postgres não remove valores
   de enumeração sem recriar o tipo), mas uma constraint impede gravá-lo; a migração converte os
   líderes globais antigos em membros, que voltam a liderar quando um administrador os vincular.
2. **Todo ministério ativo tem pelo menos um líder válido**, garantido por gatilhos no banco (inclui
   a exclusão de conta por cascata e a perda de acesso), no mesmo modelo do "último administrador".
3. **Toda escrita passa por funções SQL** `security definer`; as tabelas não aceitam `insert`,
   `update` nem `delete` diretos. As funções **nunca confiam num valor possivelmente nulo** para
   decidir permissão (ver "Lição aprendida").
4. **Colegas se veem por funções que devolvem só nome e papel.** Líderes e participantes não ganham
   leitura da tabela `perfis`, porque a RLS libera linhas inteiras e `perfis` tem email
   (constituição V). O administrador continua lendo `perfis`.
5. **Lista pública de ministérios ativos**: o visitante lê só `id`, `nome`, `descricao` e `ativo` dos
   ministérios ativos (permissão por coluna), para o cadastro mostrar as opções. É uma exceção
   estreita ao RF-024 da 001 (todas as páginas pedem login); nome e descrição de ministério não são
   dado pessoal e nenhuma rota pública nova foi criada.
6. **Pedidos de entrada** são registros próprios (`pendente`, `aceito`, `recusado`, `cancelado`).
   Aceitar o pedido de uma conta pendente cria a participação e ativa a conta em uma só transação;
   recusar nunca altera a conta.

## Alternativas consideradas

- Manter o papel global e acrescentar o por ministério: dois conceitos de líder, regras em conflito.
- Recriar o tipo `papel_usuario` sem `lider`: migração arriscada em tabela em uso, sem ganho real.
- Abrir leitura de `perfis` a líderes e participantes: mais simples, mas expõe o email dos colegas.
- Exigir login antes de mostrar os ministérios no cadastro: contraria o fluxo pedido (marcar no cadastro).

## Consequências

- (+) Uma única fonte da verdade para liderança; regras no banco valem contra chamadas diretas.
- (+) Nenhum email de colega é exposto por esta funcionalidade.
- (−) Quem era líder global na 001 volta a ser membro até ser vinculado a um ministério: antes de
  aplicar em produção, listar essas pessoas (consulta no quickstart da 002).
- (−) Leituras de colegas dependem de funções (`listar_participantes`, `listar_pedidos_pendentes`,
  `buscar_pessoas`) em vez de consultas diretas.
- (−) A lista de ministérios ativos fica legível sem login.

## Lição aprendida (testes de segurança)

Em SQL, `papel_aprovado_atual() = 'administrador'` é **NULL** (nem verdadeiro nem falso) para contas
pendentes, recusadas ou sem acesso. Usado direto em `if not (...)`, o NULL fazia a checagem de
permissão ser **pulada**: os testes de "conta pendente tenta gerir ministério" falharam e revelaram o
problema antes da publicação. As funções passaram a usar `coalesce(..., false)`. Regra: toda decisão de
permissão em SQL deve tratar NULL explicitamente e ter um teste com conta sem acesso aprovado.
Da mesma forma, no app, consultas "minhas" (participações e pedidos da própria pessoa) filtram pela
pessoa logada, porque a RLS do administrador libera todas as linhas.
