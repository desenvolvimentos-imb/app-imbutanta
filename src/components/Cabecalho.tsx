// Cabeçalho e rodapé de navegação do grupo (app). Em celular, a navegação fica embaixo,
// ao alcance do polegar (mobile-first).
import Link from "next/link";
import { atalhosPorPapel, type Papel } from "@/lib/auth/permissoes";

export function Cabecalho({ titulo }: { titulo?: string }) {
  return (
    <header className="border-b border-slate-300 bg-blue-900 px-4 py-3 text-white">
      <p className="mx-auto max-w-xl text-lg font-semibold">{titulo ?? "IM Butantã"}</p>
    </header>
  );
}

export function NavegacaoInferior({ papel }: { papel: Papel }) {
  const itens = [{ href: "/inicio", rotulo: "Início" }, ...atalhosPorPapel(papel), { href: "/conta", rotulo: "Conta" }];
  return (
    <nav
      aria-label="Principal"
      className="sticky bottom-0 border-t border-slate-300 bg-white"
    >
      <ul className="mx-auto flex max-w-xl">
        {itens.map((i) => (
          <li key={i.href} className="flex-1">
            <Link
              href={i.href}
              className="flex min-h-14 items-center justify-center px-1 text-center text-sm font-medium text-blue-950 hover:bg-blue-50 focus:outline-3 focus:outline-offset-[-3px] focus:outline-blue-700"
            >
              {i.rotulo}
            </Link>
          </li>
        ))}
      </ul>
    </nav>
  );
}
