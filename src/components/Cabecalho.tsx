// Cabeçalho e rodapé de navegação do grupo (app). Em celular, a navegação fica embaixo,
// ao alcance do polegar (mobile-first).
import Link from "next/link";
import { atalhosPorPapel, type Papel } from "@/lib/auth/permissoes";

export function Cabecalho({ titulo }: { titulo?: string }) {
  return (
    <header className="border-b border-slate-300 bg-blue-900 px-4 py-3 text-white md:order-1">
      <p className="mx-auto max-w-xl text-lg font-semibold">{titulo ?? "IM Butantã"}</p>
    </header>
  );
}

export function NavegacaoInferior({ papel, lidera }: { papel: Papel; lidera: boolean }) {
  // Rótulos curtos: o celular tem pouca largura. "Escalas" leva a Minhas escalas e "Trocas" aos
  // Pedidos de troca; "Aprovações" (pedidos de entrada e contas novas) só aparece a quem decide.
  // "Usuários" fica na tela inicial (Gestão) para a barra não passar de 6 itens. Em telas de 360 px ou
  // menos, a letra da barra diminui um pouco para os 6 itens caberem sem rolagem horizontal da página.
  const aprovacoes = atalhosPorPapel(papel, lidera).find((a) => a.href === "/aprovacoes");
  const itens = [
    { href: "/inicio", rotulo: "Início" },
    { href: "/minhas-escalas", rotulo: "Escalas" },
    { href: "/pedidos-de-troca", rotulo: "Trocas" },
    { href: "/ministerios", rotulo: "Ministérios" },
    ...(aprovacoes ? [{ href: aprovacoes.href, rotulo: "Aprovações" }] : []),
    { href: "/conta", rotulo: "Conta" },
  ];
  return (
    <nav
      aria-label="Principal"
      // Celular: barra embaixo, ao alcance do polegar. Computador (tela larga): logo abaixo do título,
      // como nos sites comuns, e fixa no topo ao rolar.
      className="sticky bottom-0 border-t border-slate-300 bg-white md:visible md:order-2 md:top-0 md:bottom-auto md:border-b md:border-t-0"
    >
      <ul className="mx-auto flex max-w-xl">
        {itens.map((i) => (
          <li key={i.href} className="min-w-0 flex-1">
            <Link
              href={i.href}
              className="flex min-h-14 items-center justify-center px-0.5 text-center text-xs font-medium min-[400px]:px-1 min-[400px]:text-sm text-blue-950 hover:bg-blue-50 focus:outline-3 focus:outline-offset-[-3px] focus:outline-blue-700"
            >
              {i.rotulo}
            </Link>
          </li>
        ))}
      </ul>
    </nav>
  );
}
