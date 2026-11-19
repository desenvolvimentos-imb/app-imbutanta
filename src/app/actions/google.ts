"use server";
// Inicia o login/cadastro com Google (fluxo PKCE). Depois do Google, a pessoa volta em
// /auth/callback. A página que ela tentava abrir fica num cookie curto (o endereço de
// retorno do Google não pode carregar parâmetros extras).
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { criarClienteServidor } from "@/lib/supabase/server";
import { caminhoVoltarSeguro } from "@/lib/auth/redirecionamento";
import { urlDoSite } from "@/lib/auth/url-do-site";

export async function entrarComGoogle(formData: FormData) {
  const voltar = caminhoVoltarSeguro(String(formData.get("voltar") ?? ""));
  const guarda = await cookies();
  guarda.set("voltar", voltar, { httpOnly: true, sameSite: "lax", maxAge: 600, path: "/" });

  const supabase = await criarClienteServidor();
  const { data, error } = await supabase.auth.signInWithOAuth({
    provider: "google",
    options: { redirectTo: `${await urlDoSite()}/auth/callback` },
  });

  if (error || !data.url) redirect("/entrar?erro=google");
  redirect(data.url);
}
