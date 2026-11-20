// Estilos dos botões. Fica fora de Botao.tsx (que é um componente de cliente) para poder ser
// usado também em páginas de servidor, por exemplo em links com aparência de botão.

export type Variante = "primario" | "secundario" | "perigo";

const ESTILOS: Record<Variante, string> = {
  primario: "bg-blue-900 text-white hover:bg-blue-800",
  secundario: "border border-slate-500 bg-white text-slate-900 hover:bg-slate-100",
  perigo: "bg-red-800 text-white hover:bg-red-700",
};

export const classesBotao = (variante: Variante = "primario") =>
  `inline-flex min-h-12 w-full items-center justify-center rounded-lg px-4 text-base font-semibold focus:outline-3 focus:outline-offset-2 focus:outline-blue-700 disabled:opacity-60 ${ESTILOS[variante]}`;
