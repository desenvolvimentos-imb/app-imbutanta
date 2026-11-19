"use server";
// Excluir a própria conta e os dados (RF-030, RF-031). A confirmação explícita é exigida
// aqui no servidor também, não só na tela. A exclusão em si é a função SQL
// `excluir_minha_conta`, que sempre age sobre a pessoa logada.
import { redirect } from "next/navigation";
import { criarClienteServidor } from "@/lib/supabase/server";
import { traduzirErro } from "@/lib/auth/mensagens-erro";
import type { EstadoForm } from "@/lib/auth/estado-form";

export async function excluirMinhaConta(_anterior: EstadoForm, formData: FormData): Promise<EstadoForm> {
  if (String(formData.get("confirmacao") ?? "").trim() !== "EXCLUIR") {
    return { erro: 'Para excluir a conta, digite EXCLUIR (em maiúsculas) no campo abaixo.' };
  }

  const supabase = await criarClienteServidor();
  const { error } = await supabase.rpc("excluir_minha_conta");
  if (error) {
    // Ex.: o único administrador precisa passar o papel a outra pessoa antes.
    return { erro: traduzirErro(error) };
  }

  // A sessão local pode já ser inválida (o usuário não existe mais); ignorar erros aqui.
  await supabase.auth.signOut().catch(() => undefined);
  redirect("/entrar?ok=excluida");
}
