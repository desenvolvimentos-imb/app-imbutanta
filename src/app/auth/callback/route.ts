// Retorno do login com Google: troca o código (PKCE) por uma sessão e leva a pessoa à tela certa.
import { cookies } from "next/headers";
import { NextResponse, type NextRequest } from "next/server";
import { criarClienteServidor } from "@/lib/supabase/server";
import { destinoPosLogin } from "@/lib/auth/destino-pos-login";

export async function GET(request: NextRequest) {
  const { searchParams, origin } = request.nextUrl;
  const codigo = searchParams.get("code");
  if (!codigo) return NextResponse.redirect(`${origin}/entrar?erro=google`);

  const supabase = await criarClienteServidor();
  const { error } = await supabase.auth.exchangeCodeForSession(codigo);
  if (error) return NextResponse.redirect(`${origin}/entrar?erro=google`);

  const guarda = await cookies();
  const voltar = guarda.get("voltar")?.value;
  guarda.delete("voltar");

  return NextResponse.redirect(`${origin}${await destinoPosLogin(supabase, voltar)}`);
}
