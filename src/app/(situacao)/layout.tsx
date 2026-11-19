// Telas de situação da conta (aguardando, recusado, acesso removido): exigem login, mas
// não aprovação. Cada página confere se a situação da pessoa é a dela.
export default function LayoutSituacao({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}
