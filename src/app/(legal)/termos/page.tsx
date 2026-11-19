import type { Metadata } from "next";
import { Contato } from "@/components/Contato";

export const metadata: Metadata = { title: "Termos de Uso" };

export default function PaginaTermos() {
  return (
    <article className="flex flex-col gap-4 text-base [&_h2]:mt-4 [&_h2]:text-xl [&_h2]:font-semibold [&_ul]:list-disc [&_ul]:pl-6 [&_li]:mb-1">
      <h1 className="text-3xl font-bold">Termos de Uso</h1>
      <p className="text-sm text-slate-700">Última atualização: 19 de novembro de 2026.</p>

      <p>
        Ao criar uma conta e usar o app <strong>IM Butantã</strong>, você concorda com estes termos.
        Eles são curtos de propósito.
      </p>

      <h2>O que é o app</h2>
      <p>
        É um aplicativo da Igreja Metodista no Butantã para consultar escalas dos ministérios,
        informativos da igreja e conteúdos de estudo. Algumas dessas áreas ainda estão sendo
        construídas.
      </p>

      <h2>Quem pode usar</h2>
      <ul>
        <li>Qualquer pessoa pode pedir uma conta, mas o acesso só é liberado depois da aprovação pela liderança.</li>
        <li>A liderança pode recusar um cadastro ou remover um acesso quando achar necessário.</li>
      </ul>

      <h2>A sua conta</h2>
      <ul>
        <li>Informe dados verdadeiros e mantenha a sua senha só com você.</li>
        <li>Se achar que alguém usou a sua conta, troque a senha e avise a liderança.</li>
      </ul>

      <h2>Uso adequado</h2>
      <p>Não é permitido:</p>
      <ul>
        <li>tentar burlar a segurança do app ou acessar dados de outras pessoas;</li>
        <li>usar o app para fins ilegais, ofensivos ou que prejudiquem a comunidade;</li>
        <li>copiar ou divulgar o conteúdo restrito a quem tem login.</li>
      </ul>

      <h2>Conteúdo</h2>
      <p>
        Os conteúdos do app pertencem à igreja ou aos seus autores. Você pode usá-los para a sua
        participação na comunidade, sem fins comerciais.
      </p>

      <h2>Disponibilidade</h2>
      <p>
        O app é oferecido gratuitamente, como apoio à vida da igreja. Fazemos o possível para que
        funcione bem, mas não garantimos que ficará sempre disponível, nem sem erros. Ele pode mudar
        ou ser encerrado.
      </p>

      <h2>Encerrar a conta</h2>
      <p>
        Você pode excluir a sua conta quando quiser, em <em>Conta → Excluir minha conta</em>. A
        igreja também pode remover o acesso de quem descumprir estes termos.
      </p>

      <h2>Privacidade</h2>
      <p>
        O tratamento dos seus dados está descrito na{" "}
        <a href="/privacidade" className="font-semibold text-blue-900 underline">
          Política de Privacidade
        </a>
        .
      </p>

      <h2>Mudanças e contato</h2>
      <p>
        Podemos atualizar estes termos; a data no topo mostra a versão em vigor. Estes termos seguem a
        legislação brasileira. Em caso de dúvida, <Contato />.
      </p>
    </article>
  );
}
