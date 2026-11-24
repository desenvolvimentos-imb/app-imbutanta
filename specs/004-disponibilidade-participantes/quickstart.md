# Guia de Execução e Validação: Disponibilidade dos Participantes

Como preparar o ambiente e provar que a funcionalidade funciona de ponta a ponta. Dados e contratos:
[data-model.md](data-model.md), [contracts/](contracts/). A preparação (Node, Docker, Supabase local,
`.env.local`) é a mesma da 001–003:
[001](../001-login-papeis-acesso/quickstart.md), [003](../003-escalas-ministerios/quickstart.md).
Os comandos exatos podem ser ajustados na implementação (`/speckit-implement`).

## 1. Rodar localmente

```bash
npm install
npx supabase start     # sobe Postgres, Auth e Mailpit locais
npx supabase db reset  # aplica TODAS as migrações (001 a 004) e o seed.sql
npm run dev             # http://localhost:3000
```

O `seed.sql` mantém as contas da 001–003 (senha `Senha1234`, só ambiente local) e acrescenta, para o
ministério "Louvor": uma consulta **aberta** "Escala de dezembro" com 4 domingos (um com rótulo
"Culto especial") e prazo daqui a alguns dias; respostas variadas (uma pessoa respondeu tudo, outra
só parte, outra nada, e uma resposta preenchida pelo líder); uma observação; e uma consulta
**fechada** de exemplo. Uma das datas coincide com a escala publicada de exemplo da 003, para validar
a integração.

## 2. Testes automatizados

```bash
npm run lint
npm run typecheck
npm test                # Vitest: atalho de datas, validação, avisos, mensagens de erro
npm run test:integracao # Vitest com duas sessões reais: responder × fechar (exige `npx supabase start`)
npx supabase test db    # pgTAP: regras, RLS, prazo, privacidade, integração com escalas
npm run test:e2e        # Playwright em tela de celular, com email/senha
```

Resultado esperado: tudo verde. O CI roda o mesmo conjunto a cada PR.

## 3. Cenários de validação (mapeados aos critérios de sucesso)

| # | Cenário | Resultado esperado | Critério |
|---|---------|--------------------|----------|
| 1 | Líder do Louvor cria "Escala de dezembro" usando o atalho "todos os domingos de dezembro" e salva (< 2 min) | consulta aberta com as datas do mês (as já passadas não entram) | CS-001, RF-002 |
| 2 | Criar com título vazio, sem datas, ou com data de ontem | recusado com mensagem clara | RF-001, RF-004 |
| 3 | Incluir uma data já presente em outra consulta do Louvor; depois a mesma data numa consulta da Recepção | a primeira é recusada indicando a consulta; a segunda é permitida | RF-005 |
| 4 | Participante abre a tela inicial com consulta aberta sem resposta | vê o aviso; ao responder tudo, o aviso some | RF-015 |
| 5 | Participante marca 2 de 4 datas e salva; volta e altera uma | 2 datas continuam "sem resposta"; alteração vale; salvar < 1 min no celular | CS-002, RF-016 |
| 6 | Observação de 301 caracteres | recusada; com 300, salva | RF-018 |
| 7 | Outro participante (e pessoa de outro ministério) tenta ver respostas/observação alheias, inclusive por acesso direto | nada é mostrado | CS-005, RF-020 |
| 8 | Líder abre a grade em celular de 360 px | visão por data legível sem rolagem horizontal da página; quem não respondeu destacado; observações visíveis | CS-003, CS-007, RF-024 |
| 9 | No computador, a tabela com coluna do nome fixa e totais por data | totais corretos; "sem resposta" não conta como disponível nem como indisponível | RF-017, RF-023 |
| 10 | Data com zero disponíveis para a função "Vocal" | contagem por função destaca a falta | RF-025 |
| 11 | Líder remove uma data com respostas | pede confirmação; só depois remove e descarta as respostas; escala existente não muda | RF-010 |
| 12 | Líder fecha a consulta; participante tenta salvar | recusado com mensagem; respostas anteriores intactas; líder ainda corrige a resposta de alguém, com marcador "preenchido pelo líder" | RF-006, RF-021 |
| 13 | Relógio de teste no dia seguinte ao prazo | consulta vale como fechada sem ação do líder; reabrir sem novo prazo é recusado; com novo prazo (ou sem prazo) funciona | RF-007, RF-008 |
| 14 | Participante sai do Louvor | some da grade e das contagens; ao voltar, as respostas reaparecem | RF-019 |
| 15 | Novo participante entra com a consulta aberta | consegue responder | RF-019 |
| 16 | Administrador desativa o Louvor | consultas abertas viram fechadas e ficam no histórico | RF-013 |
| 17 | Escalar uma pessoa "indisponível" ou "sem resposta" numa data da consulta | candidata mostra a resposta; ao salvar, aparece o aviso e é possível continuar; a indicação fica ao lado da pessoa escalada | CS-006, RF-028, RF-029 |
| 18 | Escalar em data sem consulta (ou com consulta só de outro ministério) | nenhuma indicação nem aviso | RF-030 |
| 19 | Responder e fechar quase ao mesmo tempo (duas sessões) | só uma ordem prevalece; nunca estado misto | edge case |
| 20 | Auditoria de acessibilidade (axe) nas telas novas em 360 px | sem violações AA | constitution I |

## 4. Verificação manual (telas puramente visuais)

Conferir em celular real (Chrome Android e Safari iOS): leitura da visão por data em 360 px, contraste
dos selos, alternância entre as visões e o seletor de datas. Registrar o resultado na descrição do PR.
