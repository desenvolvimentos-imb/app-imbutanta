# Guia de Execução e Validação: Escalas dos Ministérios

Como preparar o ambiente e provar que a funcionalidade funciona de ponta a ponta. Dados e contratos:
[data-model.md](data-model.md), [contracts/](contracts/). A preparação (Node, Docker, Supabase local,
`.env.local`) é a mesma da 001 e da 002:
[001](../001-login-papeis-acesso/quickstart.md), [002](../002-ministerios-participantes/quickstart.md).
Os comandos exatos podem ser ajustados na implementação (`/speckit-implement`).

## 1. Rodar localmente

```bash
npm install
npx supabase start     # sobe Postgres, Auth e Mailpit locais
npx supabase db reset  # aplica TODAS as migrações (001, 002 e 003) e o seed.sql
npm run dev             # http://localhost:3000
```

O `seed.sql` mantém as contas da 001/002 (senha `Senha1234`, só ambiente local) e acrescenta, para o
ministério "Louvor": as funções "Vocal", "Violão" e "Bateria"; aptidões (o membro é apto em Vocal e
Violão; o líder em Bateria); uma escala **publicada** de exemplo com vagas ocupadas e uma em aberto;
e uma escala em **rascunho** (ids fixos `44444444-…401` e `…402`). A Ana (líder da Recepção)
**confirmou** uma escala da Recepção no mesmo dia da escala publicada do Louvor: para validar o aviso de outro
ministério, adicione-a como participante do Louvor e escale-a numa vaga desse dia.

## 2. Testes automatizados

```bash
npm run lint
npm run typecheck
npm test                # Vitest: datas, validação, avisos, mensagens de erro, permissões
npm run test:integracao # Vitest com duas sessões reais: concorrência (exige `npx supabase start`)
npx supabase test db   # pgTAP: regras, RLS, troca atômica, cascatas, privacidade das respostas
npm run test:e2e        # Playwright em tela de celular, com email/senha
```

Resultado esperado: tudo verde. O CI roda o mesmo conjunto a cada PR.

## 3. Cenários de validação (mapeados aos critérios de sucesso)

| # | Cenário | Resultado esperado | Critério |
|---|---------|--------------------|----------|
| 1 | Líder do Louvor cria a função "Vocal" e tenta criar "vocal" | segunda é recusada com mensagem clara; desativar a primeira e criar de novo é permitido | FR-002 |
| 2 | Líder cadastra aptidões (principal/secundária) de um participante | ficam registradas; ambas contam como "apto" | FR-004 |
| 3 | Líder cria escala (evento, data de hoje ou futura, horário) com 6 vagas e publica (em celular, < 5 min) | participantes passam a ver; vaga sem pessoa aparece "Em aberto" | SC-001, FR-011 |
| 4 | Tentar criar escala com data de ontem | recusado ("A data não pode ser anterior a hoje.") | FR-007 |
| 5 | Mesma pessoa em "Vocal" e "Violão" na mesma escala | aparece uma vez como escalada, com as duas vagas | FR-010 |
| 6 | Escalar alguém que já **confirmou** a escala da Recepção no mesmo dia (e, em contraste, alguém só pendente ou recusado lá) | aviso "participante já escalado em outro ministério neste mesmo dia" com ministério, evento e horário; é possível continuar; para pendente/recusado não há aviso | FR-017 |
| 7 | Escalar alguém sem aptidão para a função | aviso de falta de aptidão; é possível continuar | FR-018 |
| 8 | Escalado abre "Minhas escalas" e confirma no próprio item (≤ 3 toques desde o início) | resposta "confirmado" vale para todas as vagas dele | SC-002, FR-026 |
| 9 | Escalado recusa com motivo | continua com a vaga; líder vê a vaga em destaque e o motivo; outro participante **não** vê resposta nem motivo | FR-022, FR-023, FR-028 |
| 10 | Líder troca a pessoa de uma vaga numa escala publicada | nova pessoa "pendente"; a anterior deixa de estar escalada | FR-014 |
| 11 | Líder muda o horário de uma escala publicada | todas as respostas voltam a "pendente"; pedidos de troca pendentes são cancelados | FR-015 |
| 12 | Participante pede troca indicando colega sem vaga na escala; colega aceita; líder aprova (com avisos, se houver) | vaga passa à colega com "confirmado"; quem pediu deixa a vaga e mantém as outras | FR-029, FR-030 |
| 13 | Pedido pendente: nada muda na escala; quem pediu cancela | pedido "cancelado"; escala igual | FR-031 |
| 14 | Dois pedidos para a mesma vaga | o segundo é recusado ("em andamento") | FR-033 |
| 15 | Líder cancela a escala com pedido pendente | escala "cancelada" visível a quem estava escalada; pedido sem efeito | FR-013, FR-032 |
| 16 | Líder troca a pessoa da vaga enquanto outro líder aprova a troca (concorrência) | só uma ação prevalece; a outra recebe aviso; nunca estado misto | SC-004, FR-035 |
| 17 | Remover um participante do Louvor | as vagas futuras dele no Louvor ficam "em aberto"; as passadas continuam; líder vê o aviso | FR-019 |
| 18 | Administrador desativa um ministério com escalas futuras | o app mostra "N escalas serão canceladas"; só depois de confirmar, elas ficam canceladas | FR-020, SC-003 |
| 19 | Participante de outro ministério abre a escala por acesso direto | nada é mostrado | FR-024, SC-003 |
| 20 | No dia seguinte à data da escala (relógio de teste), tentar editar, responder ou pedir troca | tudo recusado; leitura continua | FR-007, FR-027 |
| 21 | Auditoria de acessibilidade (axe) nas telas novas em 360 px | sem violações AA | constitution I |

## 4. Verificação manual (telas puramente visuais)

Conferir em celular real (Chrome Android e Safari iOS): leitura das telas de escala em 360 px,
contraste dos destaques, instalação do PWA e abertura de "Minhas escalas" a um toque da tela inicial.
Registrar o resultado na descrição do PR.
