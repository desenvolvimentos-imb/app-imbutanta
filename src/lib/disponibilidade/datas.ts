// Datas das consultas de disponibilidade. Tudo no fuso da igreja (America/Sao_Paulo), como nas
// escalas: "hoje" e "prazo vencido" precisam dar o mesmo resultado para todos. A regra oficial vive
// no banco (`hoje_sp`, `consulta_esta_aberta`); isto só gera e formata o que a tela mostra.
import { dataValida, hoje } from "@/lib/escalas/datas";

export { hoje, dataValida };

/** Dias da semana como no JavaScript: 0 = domingo ... 6 = sábado. */
export const DIAS_DA_SEMANA = [
  "domingo", "segunda-feira", "terça-feira", "quarta-feira", "quinta-feira", "sexta-feira", "sábado",
] as const;

const doisDigitos = (n: number) => String(n).padStart(2, "0");

/**
 * Todas as datas de um dia da semana num mês ("todos os domingos de dezembro"), em ordem, sem as
 * anteriores a `hojeSp` (RF-002, RF-004). `mes` vai de 1 a 12. Trabalha só com datas de calendário
 * (UTC), sem fuso, para não escorregar um dia.
 */
export function datasDoDiaDaSemana(ano: number, mes: number, diaDaSemana: number, hojeSp: string): string[] {
  const datas: string[] = [];
  const ultimoDia = new Date(Date.UTC(ano, mes, 0)).getUTCDate();
  for (let dia = 1; dia <= ultimoDia; dia++) {
    if (new Date(Date.UTC(ano, mes - 1, dia)).getUTCDay() !== diaDaSemana) continue;
    const data = `${ano}-${doisDigitos(mes)}-${doisDigitos(dia)}`;
    if (data >= hojeSp) datas.push(data);
  }
  return datas;
}

const REGEX_DATA = /^(\d{4})-(\d{2})-(\d{2})$/;

/** "domingo, 06/12" (dia da semana por extenso, dia e mês). */
export function formatarDataConsulta(data: string): string {
  const m = REGEX_DATA.exec(data);
  if (!m) return data;
  const d = new Date(Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3])));
  const semana = DIAS_DA_SEMANA[d.getUTCDay()];
  return `${semana}, ${m[3]}/${m[2]}`;
}

/** "06/12/2026". */
export function formatarDataCompleta(data: string): string {
  const m = REGEX_DATA.exec(data);
  return m ? `${m[3]}/${m[2]}/${m[1]}` : data;
}

/** O prazo já venceu? Vale até o fim do dia do prazo: vencido só a partir do dia seguinte (RF-007). */
export function prazoVencido(prazo: string | null, hojeSp: string = hoje()): boolean {
  return prazo !== null && hojeSp > prazo;
}
