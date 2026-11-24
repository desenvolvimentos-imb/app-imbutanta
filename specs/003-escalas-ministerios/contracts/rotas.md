# Contrato de Rotas (telas) e Acesso: Escalas

Complementa [rotas.md da 002](../../002-ministerios-participantes/contracts/rotas.md). A regra
efetiva de segurança está no banco ([banco-rpc.md](banco-rpc.md)); este contrato define a experiência.
Toda a interface em pt-BR, mobile-first, alvos ≥ 44 px, destaques por ícone + texto + cor.

## Quem é quem na interface

Fonte única: `lib/auth/permissoes.ts` (ajustada). "Gestor de um ministério" = administrador ou
líder daquele ministério; a decisão final é sempre do banco.

## Rotas novas e ajustadas

| Rota | Quem acessa | Função |
|------|-------------|--------|
| `/inicio` (ajustada) | `aprovado` | Atalhos "Minhas escalas" (contador de escalas sem resposta) e "Pedidos de troca" (contador de recebidos e, para gestor, de aguardando aprovação) |
| `/minhas-escalas` | `aprovado` | Lista "Próximas" por data e botão "Ver passadas". Cada item: ministério, evento, função(ões), data, horário e situação da resposta ("Pendente", "Confirmado", "Recusado", "Cancelada"). **Confirmar** e **Recusar** (com motivo opcional) direto no item, até o início do evento. Vazia amigável sem escalas |
| `/ministerios/[id]` (ajustada) | participante, líder, administrador | Novos atalhos: "Escalas", e, para gestor, "Funções e aptidões" e o aviso "N escalas com vagas em aberto". Ao desativar (administrador): confirmação com "Isto cancelará N escalas futuras" (FR-020) |
| `/ministerios/[id]/escalas` | participante, líder, administrador | Participante: escalas publicadas (e canceladas em que esteve). Gestor: todas, inclusive rascunhos, com selos "Rascunho", "Publicada", "Cancelada" e contagem de vagas recusadas/sem resposta/em aberto. Botão "Nova escala" (gestor) |
| `/ministerios/[id]/escalas/nova` | gestor | Formulário: evento, data, horário, observação. Cria o rascunho e leva ao detalhe |
| `/ministerios/[id]/escalas/[escalaId]` | quem pode ver a escala | **Participante**: vagas com nome de quem ocupa (ou "Em aberto"), minhas vagas, minha resposta, botões Confirmar/Recusar e "Pedir troca" (por vaga). **Gestor**: tudo isso mais edição de evento/data/horário/observação, adicionar/editar/remover vagas, escolher pessoa (com avisos e "Continuar mesmo assim"), respostas e motivos, vagas em destaque, **Publicar** e **Cancelar escala** (com confirmação). Somente leitura quando já passou do dia da escala |
| `/ministerios/[id]/funcoes` | gestor | Funções do ministério (criar, renomear, desativar/reativar) e, por participante, quais funções ele é apto, com o tipo "principal" ou "secundária" |
| `/pedidos-de-troca` | `aprovado` | Três blocos: **Recebidos** (aceitar/recusar), **Feitos** (cancelar) e, para gestor, **Aguardando minha aprovação** (aprovar/recusar, com avisos e "Continuar mesmo assim"). Cada pedido mostra evento, data, horário, vaga, pessoas e situação; encerrados ficam em "Histórico" |

O pedido de troca é iniciado na tela da escala (botão "Pedir troca" na vaga), com a escolha da
indicada em uma lista de participantes elegíveis (sem digitação de email).

## Regras de acesso das rotas

| Estado | Efeito |
|--------|--------|
| sem login / pendente / recusado | redirecionado como nas funcionalidades anteriores |
| aprovado que não participa do ministério | `/ministerios/[id]/escalas*` e `/funcoes` mostram "não encontrado" (sem revelar existência) |
| participante (sem ser gestor) | não vê rascunhos, respostas dos outros, nem botões de gestão; acesso direto a ações de gestão recebe `sem_permissao` do banco |
| líder de outro ministério | igual a "não participa" para o ministério alheio |
| administrador | acesso a tudo |

## Estados e mensagens importantes

- **Escala cancelada**: faixa "Cancelada"; sem botões de resposta e sem pedido de troca.
- **Somente leitura (dia seguinte em diante)**: faixa "Escala encerrada"; sem botões de gestão.
- **Evento iniciado**: botões de resposta e de troca somem; a resposta final fica visível.
- **Avisos ao líder**: bloco "Atenção" antes de gravar a vaga, com os textos do contrato de avisos e
  os botões "Continuar mesmo assim" e "Escolher outra pessoa".
- **Erros**: sempre pela mensagem em pt-BR do código de erro, nunca texto técnico; ação perdida por
  concorrência ("Este pedido já foi decidido") recarrega o estado atual.
- **Sem notificações**: os escalados veem a versão atual ao abrir o app (FR-016); as telas buscam os
  dados do banco a cada visita.

## Acessibilidade e mobile (checklist para as telas novas)

- Rótulos em todos os campos; erros ligados por `aria-describedby`; foco levado à mensagem de erro.
- Destaques com texto e ícone, não só cor (contraste AA).
- Datas e horários no formato brasileiro (ex.: "dom., 14/12 às 09:00"); fuso America/Sao_Paulo.
- Listas longas legíveis em 360 px de largura; botões de ação empilhados no celular.
- Ações destrutivas (cancelar escala, remover vaga) pedem confirmação.
