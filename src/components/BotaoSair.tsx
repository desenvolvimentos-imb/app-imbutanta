import { sair } from "@/app/actions/sair";
import { BotaoEnviar } from "./Botao";

export function BotaoSair() {
  return (
    <form action={sair}>
      <BotaoEnviar variante="secundario">Sair</BotaoEnviar>
    </form>
  );
}
