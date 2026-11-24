// Datas e horários das escalas. Tudo é calculado no fuso da igreja (America/Sao_Paulo) e nunca no
// fuso de quem abre o app: "hoje" e "já começou" precisam dar o mesmo resultado para todos.
// A regra oficial vive no banco (`hoje_sp`, `inicio_da_escala`); isto só decide o que MOSTRAR.

export const FUSO = "America/Sao_Paulo";

/** Data e hora de São Paulo no formato "AAAA-MM-DD" e "HH:MM" (comparáveis como texto). */
function partesEmSaoPaulo(agora: Date): { data: string; hora: string } {
  const f = new Intl.DateTimeFormat("en-CA", {
    timeZone: FUSO,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  });
  const p = Object.fromEntries(f.formatToParts(agora).map((x) => [x.type, x.value]));
  return { data: `${p.year}-${p.month}-${p.day}`, hora: `${p.hour}:${p.minute}` };
}

/** Data de hoje em São Paulo, "AAAA-MM-DD". */
export function hoje(agora: Date = new Date()): string {
  return partesEmSaoPaulo(agora).data;
}

/** O horário de início da escala já passou? (`horario` aceita "HH:MM" ou "HH:MM:SS".) */
export function jaComecou(data: string, horario: string, agora: Date = new Date()): boolean {
  const { data: hojeSp, hora } = partesEmSaoPaulo(agora);
  if (data !== hojeSp) return data < hojeSp;
  return horario.slice(0, 5) <= hora;
}

/** A partir do dia seguinte à data da escala, ela é somente leitura (FR-007). */
export function somenteLeitura(data: string, agora: Date = new Date()): boolean {
  return hoje(agora) > data;
}

const REGEX_DATA = /^(\d{4})-(\d{2})-(\d{2})$/;

/** "AAAA-MM-DD" é uma data de calendário real? (rejeita 2026-02-31). */
export function dataValida(data: string): boolean {
  const m = REGEX_DATA.exec(data);
  if (!m) return false;
  const [ano, mes, dia] = [Number(m[1]), Number(m[2]), Number(m[3])];
  const d = new Date(Date.UTC(ano, mes - 1, dia));
  return d.getUTCFullYear() === ano && d.getUTCMonth() === mes - 1 && d.getUTCDate() === dia;
}

/** "dom., 14/12": dia da semana abreviado, dia e mês. */
export function formatarData(data: string): string {
  const m = REGEX_DATA.exec(data);
  if (!m) return data;
  const d = new Date(Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3])));
  return d.toLocaleDateString("pt-BR", { weekday: "short", day: "2-digit", month: "2-digit", timeZone: "UTC" });
}

/** "09:00" a partir de "09:00:00". */
export function formatarHorario(horario: string): string {
  return horario.slice(0, 5);
}

/** "dom., 14/12 às 09:00". */
export function formatarDataHora(data: string, horario: string): string {
  return `${formatarData(data)} às ${formatarHorario(horario)}`;
}
