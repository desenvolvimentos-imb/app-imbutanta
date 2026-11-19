// Cliente Supabase para Server Components, Server Actions e Route Handlers.
// A sessão fica em cookies; é preciso criar um cliente novo a cada requisição.
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

export async function criarClienteServidor() {
  const guardaCookies = await cookies();

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll: () => guardaCookies.getAll(),
        setAll: (cookiesParaGravar) => {
          try {
            cookiesParaGravar.forEach(({ name, value, options }) =>
              guardaCookies.set(name, value, options),
            );
          } catch {
            // Server Components não podem gravar cookies. Sem problema: o proxy.ts já
            // renova a sessão a cada requisição.
          }
        },
      },
    },
  );
}
