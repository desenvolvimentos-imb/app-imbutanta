# Contrato de Rotas (telas) e Acesso: Disponibilidade

Complementa [rotas.md da 003](../../003-escalas-ministerios/contracts/rotas.md). A regra efetiva de
segurança está no banco ([banco-rpc.md](banco-rpc.md)); este contrato define a experiência. Toda a
interface em pt-BR, mobile-first, alvos ≥ 44 px, situação por ícone + texto + cor (nunca só cor).

## Rotas novas e ajustadas

| Rota | Quem acessa | Função |
|------|-------------|--------|
| `/inicio` (ajustada) | `aprovado` | Atalho "Disponibilidade" com destaque "Consulta aguardando sua resposta" quando `contar_consultas_pendentes() > 0` |
| `/disponibilidade` | `aprovado` | Consultas **abertas** dos meus ministérios (ministério, título, prazo, "N datas sem resposta"). Bloco "Fechadas recentemente" em somente leitura. Estado vazio amigável: "Nenhuma consulta aberta no momento." |
| `/disponibilidade/[consultaId]` | participante do ministério | Mensagem e prazo; uma linha por data (data por extenso, rótulo) com duas opções **Disponível** / **Indisponível** (e "Limpar"); campo de observação com contador (300); botão **Salvar** (salva parcial). Consulta fechada: somente leitura com aviso "Esta consulta está fechada". Outro usuário: "não encontrado" |
| `/ministerios/[id]` (ajustada) | participante, líder, administrador | Para gestor: atalho "Disponibilidade" com contagem de consultas abertas |
| `/ministerios/[id]/disponibilidade` | gestor | Lista: **Abertas** e **Histórico** (fechadas), com selo "Aberta", "Fechada" ou "Prazo encerrado", quantidade de datas e de pessoas sem resposta. Botão "Nova consulta" (só ministério ativo) |
| `/ministerios/[id]/disponibilidade/nova` | gestor | Formulário: título, mensagem (opcional), prazo (opcional) e **seletor de datas** (ver abaixo). Cria aberta e leva à grade |
| `/ministerios/[id]/disponibilidade/[consultaId]` | gestor | **Grade** (ver abaixo), editar título/mensagem/prazo (aberta), adicionar/remover datas (com confirmação se houver respostas), **Fechar** e **Reabrir** (pedindo novo prazo ou remoção se vencido), preencher/corrigir a resposta de uma pessoa |
| `/ministerios/[id]/escalas/[escalaId]` (ajustada) | gestor | Ao lado de cada pessoa escalada, selo "Indisponível" ou "Sem resposta" quando a data está numa consulta do ministério; **na escolha da pessoa**, cada candidata mostra a resposta; aviso "Continuar mesmo assim" usa o fluxo de avisos já existente |

Participante comum e quem não participa recebem "não encontrado" nas rotas de gestor (sem revelar
existência); o banco barra mesmo por acesso direto.

## Seletor de datas (criar e adicionar)

- Campo de data nativo + botão "Adicionar data" (bloqueia datas anteriores a hoje).
- **Atalho por mês**: escolher o mês e o dia da semana (ex.: dezembro de 2026, domingo) → "Adicionar
  todos os domingos de dezembro". As datas geradas (sem as anteriores a hoje e sem repetir as já
  escolhidas) entram na lista e podem ser removidas uma a uma antes de salvar.
- Lista das datas escolhidas, em ordem, cada uma com **rótulo opcional** (até 40 caracteres) e
  botão "Remover". Contador "N de 31 datas".
- Data repetida em outra consulta do ministério: mensagem indicando a consulta que já a tem.

## Grade do líder

Uma chamada (`ler_consulta_gestor`) alimenta as duas visões, com botão para alternar:

- **Visão por data** (padrão em telas estreitas): um cartão por data (data por extenso, rótulo,
  "5 disponíveis"), com a contagem por função (função sem disponíveis em destaque, ícone + texto) e as
  pessoas em três grupos ("Disponíveis", "Indisponíveis", "Sem resposta"). Sem rolagem horizontal da
  página.
- **Tabela** (padrão no computador): pessoa por linha, data por coluna, célula com ícone e texto
  ("Disponível", "Indisponível", "Sem resposta"); primeira coluna (nome) fixa e rolagem horizontal
  apenas da tabela; linha de totais "disponíveis" por data; linha por função com os disponíveis.
- **Pessoas que ainda não responderam nada** ficam destacadas ("Ainda não respondeu") e listadas no
  topo; observações aparecem sob o nome da pessoa.
- **Preenchido pelo líder**: a célula traz o marcador "preenchido pelo líder".
- Tocar numa célula (ou no botão "Corrigir" da pessoa) abre o preenchimento daquela pessoa, também em
  consulta fechada.
- Sem funções/aptidões cadastradas: aviso "Cadastre as funções e aptidões para ver a contagem por
  função" com link para a tela de funções da 003.

## Estados e mensagens importantes

- **Consulta fechada**: faixa "Fechada" (com o motivo: pelo líder, prazo encerrado ou ministério
  desativado); no líder, a única ação de situação é "Reabrir"; preencher resposta continua permitido.
- **Remover data com respostas**: diálogo "Esta data tem N respostas. Ao remover, elas serão
  descartadas. Remover mesmo assim?" com botões "Cancelar" e "Remover".
- **Reabrir com prazo vencido**: diálogo pedindo novo prazo ou "Remover o prazo".
- **Salvamento parcial**: mensagem "Respostas salvas. Faltam N datas." (ou "Tudo respondido.").
- Mensagens de erro vêm de `lib/auth/mensagens-erro.ts` em pt-BR; nunca texto técnico cru.

## Acessibilidade e mobile (constitution I)

- Opções de resposta como grupo de botões de rádio com rótulo, operável por teclado e leitor de tela.
- Contraste mínimo AA em todos os selos; situação sempre com ícone + texto.
- Verificação a 360 px: a visão por data não gera rolagem horizontal da página.
