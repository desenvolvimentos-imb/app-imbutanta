import { emailDeContato } from "@/lib/contato";

// Frase de contato usada nas páginas de privacidade e termos.
export function Contato() {
  const email = emailDeContato();
  if (!email) {
    return <>procure a liderança da Igreja Metodista no Butantã</>;
  }
  return (
    <>
      escreva para{" "}
      <a href={`mailto:${email}`} className="font-semibold text-blue-900 underline">
        {email}
      </a>
    </>
  );
}
