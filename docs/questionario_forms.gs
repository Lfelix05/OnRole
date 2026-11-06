/**
 * Cria no Google Forms o questionário anônimo do OnRolê (ver
 * protocolo_experimento.md). Como usar:
 *
 * 1. Abra https://script.google.com e clique em "Novo projeto".
 * 2. Apague o conteúdo e cole este arquivo inteiro.
 * 3. Confira o e-mail de contato em CONTATO.
 * 4. Escolha a função criarQuestionario e clique em "Executar". Na primeira
 *    vez o Google pede autorização para criar formulários na sua conta.
 * 5. Em "Registro de execução" aparecem dois links: o de edição (para você e o
 *    orientador revisarem) e o de resposta (para os participantes).
 *
 * O formulário já sai sem coleta de e-mail, sem limite de uma resposta (que
 * exigiria login), sem edição depois do envio e sem mostrar o resumo das
 * respostas a quem responde.
 */

const CONTATO = 'lucasyt710@gmail.com';

const CONCORDANCIA = ['Discordo totalmente', 'Concordo totalmente'];

function criarQuestionario() {
  const form = FormApp.create('Avaliação do aplicativo OnRolê');
  form
    .setDescription(
      'Você está sendo convidado(a) a responder este questionário, que faz parte do Trabalho de ' +
        'Conclusão de Curso de Lucas Lemes Félix, do curso de Sistemas de Informação do Centro ' +
        'Universitário do Espírito Santo (UNESC), orientado pelo Prof. Daniel Rossi de Jesus. O ' +
        'objetivo é conhecer sua opinião sobre a versão de demonstração do OnRolê que você usou.\n\n' +
        '• A participação é voluntária e sem nenhum pagamento. Você pode desistir a qualquer ' +
        'momento: basta fechar esta página. Nada é gravado antes de você enviar.\n' +
        '• Só podem participar pessoas com 18 anos ou mais.\n' +
        '• O questionário é anônimo. Ele não pede nem registra nome, e-mail, telefone ou qualquer ' +
        'dado que identifique você. Por favor, não escreva dados pessoais nas respostas abertas.\n' +
        '• A demonstração não usou sua localização e não criou nenhuma conta.\n' +
        '• Leva cerca de 5 minutos.\n' +
        '• Os resultados serão divulgados só de forma agregada (porcentagens e médias), no TCC.\n' +
        '• Dúvidas: ' + CONTATO + '.',
    )
    .setCollectEmail(false)
    .setLimitOneResponsePerUser(false)
    .setAllowResponseEdits(false)
    .setPublishingSummary(false)
    .setShowLinkToRespondAgain(false)
    .setProgressBar(true)
    .setConfirmationMessage('Obrigado! Sua resposta foi registrada sem nenhum dado que identifique você.');
  try {
    // Só existe em contas Google Workspace; em contas pessoais o login já não é exigido.
    form.setRequireLogin(false);
  } catch (e) {}

  // Página 1: concordância. Quem responde "Não" vai direto para o envio, sem
  // nenhuma outra pergunta.
  const consentimento = form
    .addMultipleChoiceItem()
    .setTitle('Você tem 18 anos ou mais e concorda em participar?')
    .setRequired(true);
  consentimento.setChoices([
    consentimento.createChoice(
      'Sim, tenho 18 anos ou mais e concordo em participar',
      FormApp.PageNavigationType.CONTINUE,
    ),
    consentimento.createChoice('Não', FormApp.PageNavigationType.SUBMIT),
  ]);

  // Página 2: hábitos (contexto, sem identificar).
  form.addPageBreakItem().setTitle('Seus hábitos');
  form
    .addMultipleChoiceItem()
    .setTitle('Com que frequência você sai para bares, festas ou eventos?')
    .setChoiceValues(['Menos de 1 vez por mês', '1 a 3 vezes por mês', '1 vez por semana', 'Mais de 1 vez por semana'])
    .setRequired(true);
  form
    .addCheckboxItem()
    .setTitle('Hoje, como você costuma escolher aonde ir?')
    .setHelpText('Pode marcar mais de uma.')
    .setChoiceValues(['Instagram', 'WhatsApp ou amigos', 'Google Maps', 'Já sei aonde vou'])
    .showOtherOption(true);

  // Página 3: TAM (Davis, 1989). UP = utilidade percebida, FU = facilidade de
  // uso percebida, IU = intenção de uso. Os códigos ficam só aqui: quem
  // responde vê só a frase.
  form
    .addPageBreakItem()
    .setTitle('Sua opinião sobre o OnRolê')
    .setHelpText('1 = Discordo totalmente, 3 = Nem concordo nem discordo, 5 = Concordo totalmente.');
  [
    'Usar o OnRolê me ajudaria a escolher aonde ir mais rápido.', // UP1
    'O OnRolê me ajudaria a evitar lugares vazios ou cheios demais.', // UP2
    'O mapa de calor me ajudaria a decidir aonde ir.', // UP3
    'No geral, o OnRolê seria útil para as minhas saídas.', // UP4
    'Aprender a usar o OnRolê foi fácil.', // FU1
    'Foi fácil encontrar o que eu procurava no app.', // FU2
    'Entendi o mapa de calor sem precisar de explicação.', // FU3
    'No geral, o OnRolê é fácil de usar.', // FU4
    'Se o OnRolê estivesse disponível em Colatina, eu usaria.', // IU1
    'Eu indicaria o OnRolê para amigos.', // IU2
  ].forEach((titulo) => escala(form, titulo, CONCORDANCIA));

  // Página 4: mapa de calor (H1), Conexões (H3) e selo (H2).
  form.addPageBreakItem().setTitle('Mapa de calor e Conexões');
  escala(form, 'Comparado ao jeito como escolho hoje, escolher pelo mapa do OnRolê seria… (rapidez)', [
    'Muito mais lento',
    'Muito mais rápido',
  ]); // H1a
  escala(form, 'Comparado ao jeito como escolho hoje, escolher pelo mapa do OnRolê seria… (frustração)', [
    'Muito mais frustrante',
    'Muito menos frustrante',
  ]); // H1b
  [
    'As sugestões de pessoas que mostravam locais em comum pareceram mais interessantes do que as outras.', // H3a
    'Eu prefiro conhecer pessoas pelos lugares que elas frequentam do que só pela aparência nas fotos.', // H3b
    'Saber que a pessoa frequenta os mesmos lugares me deixaria mais à vontade para puxar conversa.', // H3c
    'O selo "no rolê agora" me faria confiar mais nos posts.', // H2a
    'Eu me sentiria à vontade com o app detectando sozinho quando estou num local.', // P1
  ].forEach((titulo) => escala(form, titulo, CONCORDANCIA));

  // Página 5: comentário opcional.
  form.addPageBreakItem().setTitle('Comentário (opcional)');
  form
    .addParagraphTextItem()
    .setTitle('Quer deixar um comentário ou sugestão?')
    .setHelpText('Não escreva seu nome nem dados pessoais.');

  Logger.log('Editar (você e o orientador): ' + form.getEditUrl());
  Logger.log('Responder (participantes): ' + form.getPublishedUrl());
}

function escala(form, titulo, [esquerda, direita]) {
  form.addScaleItem().setTitle(titulo).setBounds(1, 5).setLabels(esquerda, direita).setRequired(true);
}
