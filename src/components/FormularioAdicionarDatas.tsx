"use client";
// Acrescenta datas a uma consulta aberta (RF-009). As novas começam "sem resposta" para todos.
import { useActionState } from "react";
import { BotaoEnviar } from "@/components/Botao";
import { MensagemErro, MensagemInfo } from "@/components/MensagemErro";
import { SeletorDatas } from "@/components/SeletorDatas";
import type { EstadoForm } from "@/lib/auth/estado-form";

type Props = {
  acao: (anterior: EstadoForm, formData: FormData) => Promise<EstadoForm>;
  ministerioId: string;
  consultaId: string;
  hoje: string;
  totalDatas: number;
};

export function FormularioAdicionarDatas({ acao, ministerioId, consultaId, hoje, totalDatas }: Props) {
  const [estado, executar] = useActionState<EstadoForm, FormData>(acao, {});
  return (
    <form action={executar} className="flex flex-col gap-3" key={`${totalDatas}-${estado.info ?? ""}`}>
      <MensagemErro texto={estado.erro} />
      <MensagemInfo texto={estado.info} />
      <input type="hidden" name="ministerio" value={ministerioId} />
      <input type="hidden" name="consulta" value={consultaId} />
      <SeletorDatas hoje={hoje} jaExistentes={totalDatas} />
      <BotaoEnviar variante="secundario">Adicionar as datas escolhidas</BotaoEnviar>
    </form>
  );
}
