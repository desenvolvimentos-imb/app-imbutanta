"use server";
// Encerra a sessão (RF-029) e leva ao login.
import { redirect } from "next/navigation";
import { criarClienteServidor } from "@/lib/supabase/server";

export async function sair() {
  const supabase = await criarClienteServidor();
  await supabase.auth.signOut();
  redirect("/entrar");
}
