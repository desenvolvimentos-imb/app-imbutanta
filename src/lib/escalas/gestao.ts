// Quem GERE as escalas de um ministério na interface: administrador, ou líder daquele ministério
// ativo. É só conveniência de tela (mostrar ou esconder botões): o banco confere de novo em cada ação.
import type { Perfil } from "@/lib/auth/perfil";
import { idsDosMinisteriosQueLidero } from "@/lib/ministerios/consultas";

export async function ehGestorDoMinisterio(perfil: Perfil, ministerioId: string): Promise<boolean> {
  if (perfil.papel === "administrador") return true;
  if (!perfil.lidera) return false;
  return (await idsDosMinisteriosQueLidero()).includes(ministerioId);
}
