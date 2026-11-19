import type { Metadata } from "next";
import { exigirAcesso } from "@/lib/auth/sessao";
import { criarClienteServidor } from "@/lib/supabase/server";
import { FilaDeAprovacao, type Pendente } from "./fila";

export const metadata: Metadata = { title: "Aprovar cadastros" };

export default async function PaginaAprovacoes() {
  // Administrador e líder. O banco (RLS) também só entrega a fila a eles.
  await exigirAcesso("/aprovacoes");

  const supabase = await criarClienteServidor();
  const { data } = await supabase
    .from("perfis")
    .select("id, nome, criado_em")
    .eq("situacao", "pendente")
    .eq("email_verificado", true) // quem não confirmou o email ainda não entra na fila
    .order("criado_em", { ascending: true });

  return (
    <>
      <h1 className="text-2xl font-bold">Aprovar cadastros</h1>
      <FilaDeAprovacao pendentes={(data ?? []) as Pendente[]} />
    </>
  );
}
