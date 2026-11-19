// Cliente Supabase para componentes que rodam no navegador.
// Usa só a chave pública (anon): quem protege os dados é a RLS do banco.
import { createBrowserClient } from "@supabase/ssr";

export function criarClienteNavegador() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
  );
}
