import type { Metadata } from "next";
import { Contato } from "@/components/Contato";

export const metadata: Metadata = { title: "Política de Privacidade" };

// Texto em linguagem simples, descrevendo o que o app realmente faz hoje.
// Se o app passar a coletar algo novo, atualize esta página junto (constituição, princípio V).
export default function PaginaPrivacidade() {
  return (
    <article className="flex flex-col gap-4 text-base [&_h2]:mt-4 [&_h2]:text-xl [&_h2]:font-semibold [&_ul]:list-disc [&_ul]:pl-6 [&_li]:mb-1">
      <h1 className="text-3xl font-bold">Política de Privacidade</h1>
      <p className="text-sm text-slate-700">Última atualização: 19 de novembro de 2026.</p>

      <p>
        Este app é da <strong>Igreja Metodista no Butantã</strong>, responsável pelos dados tratados
        aqui. Explicamos abaixo, de forma simples, quais dados guardamos, para quê e quais são os seus
        direitos, conforme a Lei Geral de Proteção de Dados (LGPD).
      </p>

      <h2>Quais dados guardamos</h2>
      <ul>
        <li>
          <strong>Seu nome e o email.</strong> São os únicos dados pessoais que pedimos.
        </li>
        <li>
          <strong>Sua senha</strong>, se você criar a conta com email e senha. Ela fica guardada de
          forma criptografada pelo serviço de autenticação, e nós nunca a vemos.
        </li>
        <li>
          <strong>Entrando com o Google:</strong> recebemos apenas o seu nome e o email da conta
          Google. Não acessamos contatos, arquivos, emails nem outras informações da sua conta.
        </li>
        <li>
          <strong>Dados da sua conta no app:</strong> a situação (aguardando aprovação, aprovado,
          recusado, acesso removido), o papel (membro ou administrador), a data do cadastro e
          quem decidiu a aprovação.
        </li>
        <li>
          <strong>Ministérios:</strong> de quais ministérios você participa, se é participante ou
          líder em cada um, e os pedidos que você fez para entrar (com a decisão e quando ela foi
          tomada).
        </li>
        <li>
          <strong>Cookies necessários</strong> para manter você conectado. Não usamos cookies de
          propaganda nem ferramentas que acompanham o seu comportamento.
        </li>
      </ul>

      <h2>Para que usamos</h2>
      <ul>
        <li>Identificar você e permitir o seu acesso ao app da igreja.</li>
        <li>Controlar quem tem acesso e mostrar o conteúdo adequado ao papel de cada pessoa.</li>
        <li>Organizar quem participa de cada ministério e decidir os pedidos de entrada.</li>
        <li>Enviar emails de confirmação do cadastro e de recuperação de senha.</li>
      </ul>
      <p>Não vendemos os seus dados nem os usamos para propaganda.</p>

      <h2>Quem pode ver os seus dados</h2>
      <ul>
        <li>
          Os líderes de um ministério veem o seu <strong>nome</strong> e o pedido que você fez para
          entrar nele, enquanto o pedido aguarda decisão.
        </li>
        <li>
          Quem faz parte do mesmo ministério que você vê o seu <strong>nome e o seu papel</strong>{" "}
          (participante ou líder) naquele ministério. Seu email não aparece para colegas.
        </li>
        <li>
          Administradores veem também o seu <strong>email, o seu papel e os seus ministérios</strong>,
          para gerenciar os acessos.
        </li>
      </ul>

      <h2>Serviços que ajudam a manter o app</h2>
      <p>
        Para funcionar, o app usa prestadores de serviço que guardam ou processam dados em nosso nome:
        o <strong>Supabase</strong> (banco de dados e autenticação), a <strong>Vercel</strong>{" "}
        (hospedagem do app) e o <strong>Google</strong> (login com Google e envio dos emails de
        confirmação). Alguns desses serviços podem processar dados fora do Brasil.
      </p>

      <h2>Por quanto tempo guardamos</h2>
      <p>
        Guardamos os seus dados enquanto a sua conta existir. Quando você exclui a conta, o seu nome,
        o email e as credenciais são apagados. Registros técnicos mantidos pelos prestadores (como
        registros de acesso) seguem as regras deles.
      </p>

      <h2>Os seus direitos</h2>
      <p>Você pode, a qualquer momento:</p>
      <ul>
        <li>saber quais dados temos sobre você e pedir uma cópia;</li>
        <li>pedir a correção de dados incorretos;</li>
        <li>
          <strong>excluir a sua conta e os seus dados</strong> sozinho, no próprio app, em{" "}
          <em>Conta → Excluir minha conta</em> (também disponível nas telas de aguardando aprovação,
          cadastro recusado e acesso removido);
        </li>
        <li>pedir informações sobre com quem os dados são compartilhados.</li>
      </ul>
      <p>
        Para qualquer pedido ou dúvida sobre os seus dados, <Contato />.
      </p>

      <h2>Mudanças nesta política</h2>
      <p>
        Se mudarmos algo importante, atualizaremos esta página e a data no topo. Veja também os{" "}
        <a href="/termos" className="font-semibold text-blue-900 underline">
          Termos de Uso
        </a>
        .
      </p>
    </article>
  );
}
