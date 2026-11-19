// Service worker MÍNIMO: existe só para o navegador oferecer a instalação do app (PWA).
// De propósito NÃO guarda páginas em cache: o app exige internet e páginas autenticadas
// em cache poderiam mostrar conteúdo a quem já saiu da conta.
self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", (evento) => evento.waitUntil(self.clients.claim()));
self.addEventListener("fetch", () => {
  // Sem interceptação: toda requisição vai direto à rede.
});
