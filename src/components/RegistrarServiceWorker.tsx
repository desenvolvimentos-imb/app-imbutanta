"use client";
// Registra o service worker mínimo (public/sw.js) para habilitar a instalação do PWA.
import { useEffect } from "react";

export function RegistrarServiceWorker() {
  useEffect(() => {
    if ("serviceWorker" in navigator && process.env.NODE_ENV === "production") {
      navigator.serviceWorker.register("/sw.js").catch(() => {
        // Sem service worker o app continua funcionando; só não é instalável.
      });
    }
  }, []);
  return null;
}
