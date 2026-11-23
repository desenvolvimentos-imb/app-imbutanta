import type { Metadata } from "next";
import Link from "next/link";
import { ATALHOS_MINISTERIOS, atalhosPorPapel } from "@/lib/auth/permissoes";
import { exigirAcesso } from "@/lib/auth/sessao";
import { contarPendencias } from "@/lib/escalas/consultas";
import { contarPedidosPendentes } from "@/lib/ministerios/consultas";
import { criarClienteServidor } from "@/lib/supabase/server";

export const metadata: Metadata = { title: "Início" };

const RESERVADOS = ["Informativos", "Estudos"];

// Tela inicial: muda conforme o papel (RF-023). Informativos e estudos chegam em funcionalidades
// futuras; por enquanto ficam como espaços reservados.
export default async function PaginaInicio() {
  const perfil = await exigirAcesso("/inicio");
  const atalhos = atalhosPorPapel(perfil.papel, perfil.lidera);

  // Contagem de pendentes para quem decide: pedidos de entrada (líder e administrador) e, só para o
  // administrador, também as contas novas sem decisão. As regras de quem vê o quê estão no banco.
  let pendentes = 0;
  if (atalhos.some((a) => a.href === "/aprovacoes")) {
    pendentes = await contarPedidosPendentes();
    if (perfil.papel === "administrador") {
      const supabase = await criarClienteServidor();
      const { count } = await supabase
        .from("perfis")
        .select("id", { count: "exact", head: true })
        .eq("situacao", "pendente")
        .eq("email_verificado", true);
      pendentes += count ?? 0;
    }
  }

  const pendenciasEscala = await contarPendencias();

  return (
    <>
      <h1 className="text-2xl font-bold">Olá, {perfil.nome}!</h1>

      <section aria-labelledby="titulo-escalas" className="flex flex-col gap-3">
        <h2 id="titulo-escalas" className="text-lg font-semibold">
          Escalas
        </h2>
        <ul className="flex flex-col gap-3">
          <li>
            <Link
              href="/minhas-escalas"
              className="flex min-h-14 items-center rounded-lg border-2 border-blue-900 px-4 text-lg font-semibold text-blue-900 hover:bg-blue-50"
            >
              Minhas escalas
              {pendenciasEscala.sem_resposta > 0 && (
                <span className="ml-2 rounded-full bg-blue-900 px-2 py-0.5 text-sm text-white">
                  {pendenciasEscala.sem_resposta} sem resposta
                </span>
              )}
            </Link>
          </li>
          <li>
            <Link
              href="/pedidos-de-troca"
              className="flex min-h-14 items-center rounded-lg border-2 border-blue-900 px-4 text-lg font-semibold text-blue-900 hover:bg-blue-50"
            >
              Pedidos de troca
              {pendenciasEscala.trocas_recebidas + pendenciasEscala.trocas_para_aprovar > 0 && (
                <span className="ml-2 rounded-full bg-blue-900 px-2 py-0.5 text-sm text-white">
                  {pendenciasEscala.trocas_recebidas + pendenciasEscala.trocas_para_aprovar} aguardando
                </span>
              )}
            </Link>
          </li>
        </ul>
      </section>

      <section aria-labelledby="titulo-ministerios" className="flex flex-col gap-3">
        <h2 id="titulo-ministerios" className="text-lg font-semibold">
          Ministérios
        </h2>
        <ul className="flex flex-col gap-3">
          {ATALHOS_MINISTERIOS.map((a) => (
            <li key={a.href}>
              <Link
                href={a.href}
                className="flex min-h-14 items-center rounded-lg border-2 border-blue-900 px-4 text-lg font-semibold text-blue-900 hover:bg-blue-50"
              >
                {a.rotulo}
              </Link>
            </li>
          ))}
        </ul>
      </section>

      {atalhos.length > 0 && (
        <section aria-labelledby="titulo-gestao" className="flex flex-col gap-3">
          <h2 id="titulo-gestao" className="text-lg font-semibold">
            Gestão
          </h2>
          <ul className="flex flex-col gap-3">
            {atalhos.map((a) => (
              <li key={a.href}>
                <Link
                  href={a.href}
                  className="flex min-h-14 items-center rounded-lg border-2 border-blue-900 px-4 text-lg font-semibold text-blue-900 hover:bg-blue-50"
                >
                  {a.rotulo}
                  {a.href === "/aprovacoes" && pendentes > 0 && (
                    <span className="ml-2 rounded-full bg-blue-900 px-2 py-0.5 text-sm text-white">
                      {pendentes} {pendentes === 1 ? "pendente" : "pendentes"}
                    </span>
                  )}
                </Link>
              </li>
            ))}
          </ul>
        </section>
      )}

      <section aria-labelledby="titulo-em-breve" className="flex flex-col gap-3">
        <h2 id="titulo-em-breve" className="text-lg font-semibold">
          Em breve
        </h2>
        <ul className="flex flex-col gap-2">
          {RESERVADOS.map((r) => (
            <li key={r} className="rounded-lg bg-slate-100 p-4 text-slate-700">
              {r}
            </li>
          ))}
        </ul>
      </section>
    </>
  );
}
