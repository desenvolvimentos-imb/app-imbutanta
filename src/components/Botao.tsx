"use client";
// Botões com alvo de toque grande (≥ 44 px, WCAG). BotaoEnviar desativa enquanto envia,
// evitando cliques duplos (ex.: cadastro criado duas vezes).
import { useFormStatus } from "react-dom";
import type { ButtonHTMLAttributes } from "react";
import { classesBotao, type Variante } from "./estilos-botao";

type Props = ButtonHTMLAttributes<HTMLButtonElement> & { variante?: Variante };

export function BotaoEnviar({ variante = "primario", children, disabled, ...resto }: Props) {
  const { pending } = useFormStatus();
  return (
    <button type="submit" className={classesBotao(variante)} {...resto} disabled={pending || disabled}>
      {pending ? "Aguarde..." : children}
    </button>
  );
}
