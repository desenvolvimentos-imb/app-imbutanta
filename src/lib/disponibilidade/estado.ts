// Estado devolvido pela ação de remover data: além do padrão dos formulários, pode pedir a
// confirmação do líder quando a data já tem respostas (RF-010). O banco NÃO remove nada até a
// confirmação chegar.
import type { EstadoForm } from "@/lib/auth/estado-form";

export type EstadoRemocao = EstadoForm & { confirmacao?: { dataId: string; respostas: number } };
