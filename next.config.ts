import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  /* config options here */
  // Todas as telas dependem de quem está logado, então são renderizadas a cada requisição.
  // (Os recursos de cache/prerender do Next não ajudam aqui e só adicionam complexidade.)
  turbopack: {
    rules: {
      "*.css": {
        loaders: ["@tailwindcss/turbopack"],
        as: "*.css",
      },
    },
  },
};

export default nextConfig;
