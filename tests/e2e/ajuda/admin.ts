// Cliente administrativo SÓ PARA TESTES (usa a chave service_role do Supabase LOCAL).
// Serve para preparar e conferir dados que os usuários comuns não enxergam.
import { execSync } from "node:child_process";
import { createClient } from "@supabase/supabase-js";

let cache: { url: string; chave: string; anon: string } | null = null;

function configLocal() {
  if (cache) return cache;
  const saida = execSync("npx supabase status -o env", { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] });
  const pega = (nome: string) => saida.match(new RegExp(`^${nome}="?([^"\\n]+)"?$`, "m"))?.[1] ?? "";
  cache = { url: pega("API_URL"), chave: pega("SERVICE_ROLE_KEY"), anon: pega("ANON_KEY") };
  return cache;
}

export function clienteAdmin() {
  const { url, chave } = configLocal();
  return createClient(url, chave, { auth: { persistSession: false, autoRefreshToken: false } });
}

/** Cliente com a chave PÚBLICA, como qualquer pessoa na internet teria (para testar a RLS). */
export function clientePublico() {
  const { url, anon } = configLocal();
  return createClient(url, anon, { auth: { persistSession: false, autoRefreshToken: false } });
}
