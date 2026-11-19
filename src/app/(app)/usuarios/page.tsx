import type { Metadata } from "next";
import { exigirAcesso } from "@/lib/auth/sessao";
import { criarClienteServidor } from "@/lib/supabase/server";
import { ListaDeUsuarios, type Usuario } from "./lista";

export const metadata: Metadata = { title: "Usuários" };

export default async function PaginaUsuarios() {
  // Somente administrador. O banco (RLS) também só entrega esta lista a ele.
  await exigirAcesso("/usuarios");

  const supabase = await criarClienteServidor();
  const { data } = await supabase
    .from("perfis")
    .select("id, nome, email, situacao, papel")
    .neq("situacao", "pendente") // pendentes são tratados na tela de aprovação
    .order("nome", { ascending: true });

  return (
    <>
      <h1 className="text-2xl font-bold">Usuários</h1>
      <ListaDeUsuarios usuarios={(data ?? []) as Usuario[]} />
    </>
  );
}
