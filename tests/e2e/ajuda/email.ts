// Ajuda para testes: lê os emails que o Supabase local "envia" para o Mailpit
// (caixa de emails de teste, http://127.0.0.1:54324) e extrai links.
const MAILPIT = "http://127.0.0.1:54324/api/v1";

type ResumoMensagem = { ID: string; To: { Address: string }[]; Created: string };

/**
 * Espera chegar pelo menos `minimo` emails para o destinatário e devolve o HTML do MAIS RECENTE
 * (links antigos deixam de valer quando um novo email é enviado).
 */
export async function esperarEmail(destinatario: string, minimo = 1): Promise<string> {
  for (let tentativa = 0; tentativa < 30; tentativa++) {
    const lista = await fetch(`${MAILPIT}/messages`).then((r) => r.json());
    const dele = (lista.messages as ResumoMensagem[])
      .filter((m) => m.To.some((t) => t.Address.toLowerCase() === destinatario.toLowerCase()))
      .sort((a, b) => a.Created.localeCompare(b.Created));
    if (dele.length >= minimo) {
      const msg = await fetch(`${MAILPIT}/message/${dele[dele.length - 1].ID}`).then((r) => r.json());
      return msg.HTML as string;
    }
    await new Promise((r) => setTimeout(r, 500));
  }
  throw new Error(`Nenhum email chegou para ${destinatario}`);
}

/** Primeiro link do HTML que contém o trecho informado (ex.: "/auth/confirmar"). */
export function extrairLink(html: string, trecho: string): string {
  const achados = [...html.matchAll(/href="([^"]+)"/g)].map((m) => m[1].replaceAll("&amp;", "&"));
  const link = achados.find((l) => l.includes(trecho));
  if (!link) throw new Error(`Link com "${trecho}" não encontrado no email`);
  return link;
}

/** Email único por execução, para os testes não colidirem. */
export const emailNovo = (prefixo: string) =>
  `${prefixo}.${Date.now()}.${Math.floor(Math.random() * 1e4)}@teste.local`;

/** Senha das contas do seed (supabase/seed.sql) e das criadas pelos testes. */
export const SENHA = "Senha1234";
