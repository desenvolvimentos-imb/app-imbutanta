// Proxy do Next.js (antigo "middleware"): roda antes de cada página.
// Aqui só fazemos a checagem rápida "tem login?". Quem decide o que cada situação/papel pode
// ver são os layouts de cada grupo de rotas e, de verdade, o banco (RLS).
import { NextResponse, type NextRequest } from "next/server";
import { renovarSessao } from "@/lib/supabase/proxy";

// Rotas acessíveis sem login (RF-024). As telas de situação exigem login, mas não aprovação.
// "/privacidade" e "/termos" são páginas legais abertas a todos (exigidas pelo Google e pela LGPD).
const ROTAS_PUBLICAS = [
  "/entrar",
  "/cadastrar",
  "/recuperar-senha",
  "/redefinir-senha",
  "/privacidade",
  "/termos",
  "/auth",
];

const ehPublica = (caminho: string) =>
  ROTAS_PUBLICAS.some((r) => caminho === r || caminho.startsWith(`${r}/`));

export async function proxy(request: NextRequest) {
  const { resposta, usuario } = await renovarSessao(request);
  const { pathname, search } = request.nextUrl;

  if (!usuario && !ehPublica(pathname)) {
    const destino = request.nextUrl.clone();
    destino.pathname = "/entrar";
    destino.search = "";
    // Guarda a página que a pessoa tentava abrir para voltar a ela depois do login.
    if (pathname !== "/") destino.searchParams.set("voltar", pathname + search);

    const redirecionamento = NextResponse.redirect(destino);
    // Mantém cookies renovados (ex.: sessão expirada limpa) na resposta de redirecionamento.
    resposta.cookies.getAll().forEach((c) => redirecionamento.cookies.set(c));
    return redirecionamento;
  }

  return resposta;
}

export const config = {
  // Ignora arquivos estáticos, ícones, manifesto e service worker.
  matcher: ["/((?!_next/static|_next/image|favicon.ico|icons/|sw.js|manifest.webmanifest).*)"],
};
