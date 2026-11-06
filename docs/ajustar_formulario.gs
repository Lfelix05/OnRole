/**
 * Confere e corrige as configurações do questionário definitivo do OnRolê,
 * que já existe (ver protocolo_experimento.md). Não mexe nas perguntas nem
 * nas respostas. Como usar:
 *
 * 1. Abra https://script.google.com e clique em "Novo projeto".
 * 2. Apague o conteúdo e cole este arquivo inteiro.
 * 3. Escolha a função ajustarFormulario e clique em "Executar". Na primeira
 *    vez o Google pede autorização para editar seus formulários.
 * 4. Leia o "Registro de execução": cada linha diz o que estava certo, o que
 *    foi corrigido e o que precisa ser feito à mão.
 */

// O formulário enviado ao orientador em 28/10/2026.
const FORMULARIO_ID = '1NNhL1I7pnkOI-dUPEWuSy5awaoFip8aS1tDwvMt7cRk';

const CONTATO = 'lucasyt710@gmail.com';

function ajustarFormulario() {
  const form = FormApp.openById(FORMULARIO_ID);
  Logger.log('Formulário: ' + form.getTitle());

  // Coleta de e-mail desligada.
  if (form.collectsEmail()) {
    try {
      form.setEmailCollectionType(FormApp.EmailCollectionType.DO_NOT_COLLECT);
    } catch (e) {
      form.setCollectEmail(false);
    }
    Logger.log('CORRIGIDO: a coleta de e-mail estava ligada e foi desligada.');
  } else {
    Logger.log('OK: não coleta e-mail.');
  }

  // "Limitar a 1 resposta" desligado (ligado, exige login e liga a resposta à conta).
  if (form.hasLimitOneResponsePerUser()) {
    form.setLimitOneResponsePerUser(false);
    Logger.log('CORRIGIDO: "limitar a 1 resposta" estava ligado e foi desligado.');
  } else {
    Logger.log('OK: "limitar a 1 resposta" desligado.');
  }

  // Nenhuma pergunta de upload. Não apaga sozinho: avisa para apagar à mão.
  const uploads = form.getItems(FormApp.ItemType.FILE_UPLOAD);
  if (uploads.length > 0) {
    uploads.forEach((item) => Logger.log('ATENÇÃO: apague à mão a pergunta de upload "' + item.getTitle() + '".'));
  } else {
    Logger.log('OK: nenhuma pergunta de upload.');
  }

  // Contato no texto de apresentação, no lugar do espaço reservado.
  const descricao = form.getDescription();
  const reservado = /\[[^\]]*e-mail[^\]]*\]/g;
  if (reservado.test(descricao)) {
    form.setDescription(descricao.replace(reservado, CONTATO));
    Logger.log('CORRIGIDO: o espaço reservado do contato virou ' + CONTATO + '.');
  } else if (descricao.indexOf(CONTATO) >= 0) {
    Logger.log('OK: o texto de apresentação já traz ' + CONTATO + '.');
  } else {
    Logger.log('ATENÇÃO: o texto de apresentação não tem o e-mail de contato. Inclua à mão.');
  }

  // Só a contagem. Respostas de teste devem ser apagadas antes da aplicação.
  const respostas = form.getResponses().length;
  if (respostas > 0) {
    Logger.log('ATENÇÃO: já há ' + respostas + ' resposta(s). Se forem de teste, apague em Respostas > ⋮ > Excluir todas as respostas antes de 09/11.');
  } else {
    Logger.log('OK: nenhuma resposta ainda.');
  }

  Logger.log('Responder (participantes): ' + form.getPublishedUrl());
}
