import type { Metadata } from "next";
import Link from "next/link";
import { CartaoMinisterio } from "@/components/CartaoMinisterio";
import { classesBotao } from "@/components/estilos-botao";
import { exigirAcesso } from "@/lib/auth/sessao";
import { listarMinisterios } from "@/lib/ministerios/consultas";

export const metadata: Metadata = { title: "Ministérios" };

// Lista de ministérios. O administrador vê ativos e desativados e pode criar; as demais pessoas
// veem só os ativos (nome e descrição). Quem entra em quê é decidido pelo banco (RLS), não aqui.
export default async function PaginaMinisterios() {
  const perfil = await exigirAcesso("/ministerios");
  const ministerios = await listarMinisterios();
  const ativos = ministerios.filter((m) => m.ativo);
  const desativados = ministerios.filter((m) => !m.ativo);
  const ehAdmin = perfil.papel === "administrador";

  return (
    <>
      <h1 className="text-2xl font-bold">Ministérios</h1>

      <div className="flex flex-col gap-3">
        {ehAdmin && (
          <Link href="/ministerios/novo" className={classesBotao("primario")}>
            Novo ministério
          </Link>
        )}
        <Link href="/meus-ministerios" className={classesBotao("secundario")}>
          Meus ministérios
        </Link>
      </div>

      <section aria-labelledby="titulo-ativos" className="flex flex-col gap-3">
        <h2 id="titulo-ativos" className="text-lg font-semibold">
          Ministérios ativos
        </h2>
        {ativos.length === 0 ? (
          <p className="rounded-lg bg-slate-100 p-4 text-lg">
            {ehAdmin
              ? "Ainda não há ministérios. Crie o primeiro em “Novo ministério”."
              : "Ainda não há ministérios cadastrados."}
          </p>
        ) : (
          <ul className="flex flex-col gap-3">
            {ativos.map((m) => (
              <li key={m.id}>
                <CartaoMinisterio ministerio={m} />
              </li>
            ))}
          </ul>
        )}
      </section>

      {ehAdmin && desativados.length > 0 && (
        <section aria-labelledby="titulo-desativados" className="flex flex-col gap-3">
          <h2 id="titulo-desativados" className="text-lg font-semibold">
            Ministérios desativados
          </h2>
          <ul className="flex flex-col gap-3">
            {desativados.map((m) => (
              <li key={m.id}>
                <CartaoMinisterio ministerio={m} />
              </li>
            ))}
          </ul>
        </section>
      )}
    </>
  );
}
