// Links enviados por email (confirmação de cadastro e recuperação de senha).
// Valida o token com verifyOtp, que funciona mesmo abrindo o email em outro aparelho.
import { NextResponse, type NextRequest } from "next/server";
import type { EmailOtpType } from "@supabase/supabase-js";
import { criarClienteServidor } from "@/lib/supabase/server";
import { destinoPosLogin } from "@/lib/auth/destino-pos-login";

// Só aceitamos os dois tipos que usamos.
const TIPOS: EmailOtpType[] = ["email", "recovery"];

export async function GET(request: NextRequest) {
  const { searchParams, origin } = request.nextUrl;
  const tokenHash = searchParams.get("token_hash");
  const tipo = searchParams.get("type") as EmailOtpType | null;

  const linkInvalido = tipo === "recovery" ? "/recuperar-senha?erro=link" : "/entrar?erro=link";
  if (!tokenHash || !tipo || !TIPOS.includes(tipo)) {
    return NextResponse.redirect(`${origin}${linkInvalido}`);
  }

  const supabase = await criarClienteServidor();
  const { error } = await supabase.auth.verifyOtp({ type: tipo, token_hash: tokenHash });
  if (error) return NextResponse.redirect(`${origin}${linkInvalido}`);

  if (tipo === "recovery") return NextResponse.redirect(`${origin}/redefinir-senha`);
  return NextResponse.redirect(`${origin}${await destinoPosLogin(supabase)}`);
}
