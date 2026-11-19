# 0001 — Stack: Next.js na Vercel, Supabase para autenticação e banco

- **Data**: 2026-11-19
- **Situação**: Aceita
- **Origem**: plano de `001-login-papeis-acesso` (`specs/001-login-papeis-acesso/`)

## Contexto

O app da igreja precisa de login (Google e email/senha), papéis de acesso e, no futuro, banco
para escalas, informativos e estudos. A constitution exige custo zero (VI), simplicidade (II),
regras de acesso no servidor/banco e senhas tratadas pela plataforma (V). O mantenedor é
uma única pessoa e pediu o uso de Supabase e Vercel.

## Decisão

- **Next.js (App Router) + TypeScript + Tailwind**, hospedado na **Vercel** (plano Hobby).
- **Supabase** (plano gratuito): Auth (Google + email/senha), Postgres e RLS.
- Regras de acesso por RLS e funções SQL; papel lido do banco a cada requisição.
- Dois projetos Supabase gratuitos: desenvolvimento/preview e produção. As migrações são
  implantadas pela integração Supabase + GitHub (ver [ADR 0003](0003-implantacao-de-migracoes.md)).
- Email transacional por SMTP próprio (Resend, plano gratuito), pois o SMTP padrão do Supabase
  não atende uso real.

## Consequências

- (+) Sem servidor próprio a manter; deploy automático por branch; autenticação pronta.
- (+) Segurança aplicada no banco, mesmo para chamadas diretas à API.
- (−) Dependência de dois fornecedores; limites gratuitos precisam ser reconfirmados antes de
  produção (ver `research.md`).
- (−) Projetos gratuitos do Supabase pausam por inatividade; aceitável em produção com uso
  semanal.
- (−) Email em produção depende de domínio verificado; decisão pendente do dono do projeto.
- Trocar a hospedagem (por exemplo, Cloudflare Pages) não exige mudar o banco; trocar o
  Supabase exigiria reescrever autenticação e RLS.
