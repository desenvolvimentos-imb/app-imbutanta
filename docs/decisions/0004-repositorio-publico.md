# 0004 — Repositório público no GitHub

- **Data**: 2026-11-20
- **Situação**: Aceita
- **Origem**: publicação do app na Vercel (feature `001-login-papeis-acesso`)

## Contexto

No plano gratuito (Hobby) da Vercel, um repositório **privado** só implanta commits feitos pelo
dono da conta; commits de outra pessoa (inclusive de colaborador) ficam bloqueados e o check da
Vercel falha no PR. O mantenedor trabalha como colaborador do repositório da igreja, então os
PRs ficavam bloqueados. Pagar o plano Pro violaria o princípio VI (custo zero).

## Decisão

Tornar o repositório **público**. O código não contém segredos (princípio V; `.env*` fora do git,
chaves só nos painéis da Vercel e do Supabase), então expô-lo não revela nada sensível.

## Alternativas consideradas

- **Plano Pro da Vercel**: resolve, mas é pago. Rejeitada.
- **Mover o repositório para a conta pessoal do mantenedor**: o dono passa a ser a pessoa, não a
  igreja; piora a continuidade do projeto. Rejeitada.
- **Outra hospedagem gratuita**: trocaria a stack definida no ADR 0001 por um problema de plano.

## Consequências

- (+) Deploys e checks da Vercel funcionam para os commits do mantenedor.
- (−) Qualquer pessoa pode ler o código e os documentos. Nunca versionar segredos, emails reais
  ou dados de membros (já é regra; passa a ser ainda mais importante).
- (−) Sem arquivo de licença, ninguém tem permissão de reutilizar o código; definir a licença
  é uma decisão pendente do dono do projeto.
