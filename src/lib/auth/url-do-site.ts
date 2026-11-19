// Descobre o endereço público do app na requisição atual (local, preview da Vercel ou
// produção), para montar links de retorno do Google e dos emails.
import { headers } from "next/headers";

export async function urlDoSite(): Promise<string> {
  const h = await headers();
  const host = h.get("x-forwarded-host") ?? h.get("host") ?? "localhost:3000";
  const protocolo = h.get("x-forwarded-proto") ?? (host.startsWith("localhost") || host.startsWith("127.") ? "http" : "https");
  return `${protocolo}://${host}`;
}
