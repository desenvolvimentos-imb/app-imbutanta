// Estado devolvido pelas ações de vaga: além do padrão dos formulários, pode trazer avisos que
// o líder precisa ver antes de continuar (FR-017, FR-018).
import type { EstadoForm } from "@/lib/auth/estado-form";
import type { Aviso } from "./avisos";

export type EstadoVaga = EstadoForm & { avisos?: Aviso[] };
