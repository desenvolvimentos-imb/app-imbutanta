import Link from "next/link";

// Links para as páginas públicas de privacidade e termos, mostrados nas telas sem login.
export function RodapeLegal() {
  return (
    <nav aria-label="Informações legais" className="flex justify-center gap-4 text-sm">
      <Link href="/privacidade" className="min-h-11 py-2 font-medium text-blue-900 underline">
        Política de Privacidade
      </Link>
      <Link href="/termos" className="min-h-11 py-2 font-medium text-blue-900 underline">
        Termos de Uso
      </Link>
    </nav>
  );
}
