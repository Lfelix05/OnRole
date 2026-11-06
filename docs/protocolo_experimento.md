# Protocolo do experimento do OnRolê

Desenho anônimo do experimento do TCC. Ninguém que participa pode ser
identificado, para a pesquisa se enquadrar na dispensa de registro no sistema
CEP/Conep da Resolução CNS nº 510/2016 (art. 1º, parágrafo único, inciso I:
pesquisa de opinião pública com participantes não identificados). A dispensa
vale só se o desenho for realmente anônimo. Por isso o app não registra nem
envia a localização de ninguém, e nada aqui depende de pseudônimos (P01, P02).
Um código ligado à pessoa continua sendo dado pessoal.

O experimento tem duas partes que não se cruzam:

| Parte | Hipóteses | Quem participa | Dados |
| --- | --- | --- | --- |
| Bancada técnica | H2 (precisão das geocercas) e H4 (FPS e bateria) | Só o pesquisador, nos próprios aparelhos | Trajetos e check-ins sintéticos, gerados por código |
| Avaliação de uso | H1 (mapa de calor) e H3 (Conexões), medidas por percepção | Voluntários com 18 anos ou mais (mínimo de 20) | Questionário anônimo, depois de usar a demonstração |

## 1. Bancada técnica (H2 e H4)

Não há participantes nesta parte. Toda localização vem de trajetos
sintéticos, e o gabarito (onde a pessoa fictícia estava e quando) é conhecido
por construção.

**Gerador de trajetos** (`on_role/lib/services/synthetic_trajectories.dart`).
Cada noite sintética sai de um ponto a 400–900 m do primeiro local, visita de
2 a 4 dos 11 locais do catálogo (de 10 a 90 min em cada) e volta. No caminho,
às vezes atravessa a cerca de outro local sem parar ou para menos de 1,5 min
na porta. São as situações que não podem virar check-in. Em 30% das trocas, o
próximo local é o vizinho mais próximo (ex.: Espetinho do Denis e DJ PUB, a
44 m). O erro do GPS segue um modelo explícito:

- precisão log-normal com mediana de 8 m na rua e 20 m dentro dos locais;
- erro correlacionado no tempo, processo AR(1) com τ = 60 s;
- 2% de leituras muito fora, de 40 a 150 m;
- leitura a cada 10 ± 2 s, com o filtro de 10 m do app.

A mesma semente gera sempre os mesmos trajetos.

**Precisão (H2).** As noites passam pelo mesmo `CheckInTracker` que o app usa,
em tempo simulado. As métricas estão definidas em
`on_role/lib/services/geofence_benchmark.dart`. "Transições corretas" é a
meta do projeto (> 95%): entradas e saídas certas sobre as esperadas mais as
erradas.

```powershell
cd on_role
dart run tools/geofence_bench.dart --nights 1000 --seed 1
dart run tools/geofence_bench.dart --nights 1000 --seed 1 --dwell 300   # análise de sensibilidade
```

Rode com 3 a 5 sementes e relate média e desvio entre elas (`--seeds 5`). O
resultado atual, com o ajuste de parâmetros que ele motivou, está em
[resultados_bancada.md](resultados_bancada.md). **Limitação a
declarar no TCC:** o resultado vale para o modelo de GPS e de caminhada
acima, que é uma aproximação. Ele mede a lógica das geocercas, não o GPS de um
aparelho específico.

**Desempenho (H4).** Build `MODE=bancada` em cada aparelho de teste
(intermediário e de entrada, se possível):

```powershell
flutter build apk --release --dart-define=MODE=bancada
```

Em **Perfil → frasco → Desempenho no aparelho**, a bancada repete um trajeto
sintético em tempo real, com os tempos reais das geocercas, enquanto o mapa
acompanha a posição e o mapa de calor atualiza. Ela mede o tempo de construção
e de rasterização de cada quadro do mapa e a bateria a cada 5 min. Para cada
rodada: aparelho fora da tomada, tela sempre ligada, app na aba Mapa, 30 ou
60 min. O relatório traz só o modelo do aparelho, os quadros, a bateria e o
acerto das geocercas naquele trajeto. Copie o texto e cole no TCC.

## 2. Avaliação de uso (H1 e H3)

### Hipóteses

O questionário mede o que a pessoa percebe, não o tempo real nem as
curtidas reais. Por isso H1 e H3 são escritas como hipóteses de percepção:

- **H1.** A percepção de rapidez e de menor frustração ao escolher um local
  pelo mapa de calor do OnRolê é maior do que no método que a pessoa usa
  hoje (itens H1a e H1b).
- **H3.** As sugestões de pessoas com locais em comum são percebidas como
  mais interessantes, e como um ponto de partida mais confortável para puxar
  conversa, do que a aparência nas fotos (itens H3a a H3c).

### Participantes e recrutamento

- **Mínimo de 20 participantes**, com 18 anos ou mais, por adesão voluntária.
- Amostra por conveniência: convite público, o mesmo texto para todos, em
  sala e nos grupos de turma do curso de Sistemas de Informação da UNESC.
- Não há lista de quem participou nem controle de quem respondeu. A contagem
  é só a de respostas recebidas no formulário.
- Com 20 respostas, o alfa de Cronbach e os testes têm pouca precisão, o que
  é declarado nas limitações (seção 4).

### Datas

| Etapa | Período |
| --- | --- |
| Aplicação da demonstração e do questionário | 09/11/2026 a 20/11/2026 |
| Fechamento da análise | até 24/11/2026 |

Se as 20 respostas não forem atingidas até 20/11, isso é relatado no TCC com
o número real, sem estender a coleta sem combinar com o orientador.

### Versão de demonstração

```powershell
flutter build apk --release --dart-define=MODE=demo
```

- Não cria conta e não pede nome, e-mail ou data de nascimento. A pessoa toca
  em "Explorar a demonstração" e entra como "Visitante", que é igual para todo
  mundo.
- Não pede permissão de localização e nunca chama o GPS. A posição vem só de
  toques no mapa.
- Não inicializa o Firebase. Tudo fica na memória do aparelho e some quando o
  app fecha. A única rede usada são as imagens do mapa (OpenStreetMap), que
  recebem a região de Colatina exibida, não a posição da pessoa.
- Mapa de calor e Conexões usam dados sintéticos: 30 pessoas fictícias e uma
  população simulada de check-ins (`lib/services/synthetic_population.dart` e
  `SyntheticCrowd` em `lib/services/crowd_simulator.dart`). Os locais são os
  11 estabelecimentos reais do catálogo, mas a lotação mostrada é inventada,
  e o app avisa disso.
- Conexões segue o desenho da H3: a fila alterna sugestão por afinidade e
  sorteada. A carta mostra o que há em comum, não a nota.
- Sem câmera e sem galeria: não dá para postar foto, vídeo ou story, nem
  trocar a foto do perfil. Uma foto ou vídeo do participante o identificaria
  e ficaria no cache do aparelho mesmo com o app fechado, e a galeria
  mostraria as fotos do dono do aparelho. O post é só texto.
- Nada é registrado sobre o uso: sem telemetria, sem tempo de tela, sem
  curtidas enviadas.

### Como aplicar

1. Convide pessoas maiores de 18 anos. A participação é voluntária.
2. Entregue o aparelho com a demonstração aberta. Não anote nome, contato,
   horário nem qualquer característica de quem usou. Não fotografe nem filme.
3. Sugira um roteiro curto, igual para todos: escolher aonde ir pelo mapa,
   simular a chegada num local, ver o feed e passar algumas cartas em
   Conexões.
4. **Entre um participante e o próximo, feche o app de vez** (tire dos apps
   recentes). Assim os posts e as curtidas da pessoa anterior somem da
   memória.
5. Passe o link (ou o QR code) do questionário, o mesmo para todo mundo. A
   pessoa responde depois, no próprio celular, quando quiser. Não confira quem
   respondeu.

### Questionário (Google Forms)

O script [questionario_forms.gs](questionario_forms.gs) cria o formulário
inteiro, com as perguntas abaixo e as configurações já aplicadas. Abra
script.google.com, crie um projeto novo, cole o arquivo e execute
`criarQuestionario`. O registro de execução mostra o link de edição, para
revisar com o orientador, e o link de resposta, para os participantes.

O formulário definitivo já existe (o link enviado ao orientador em
28/10/2026), e as cópias foram para a lixeira. Para conferir e corrigir as
configurações dele e trocar o espaço reservado do contato pelo e-mail, rode
`ajustarFormulario` do script [ajustar_formulario.gs](ajustar_formulario.gs).
Ele não mexe nas perguntas nem nas respostas.

**Configurações obrigatórias do formulário:**

- Configurações → Respostas → **Coletar endereços de e-mail: Não coletar**.
- **Limitar a 1 resposta: desligado.** Ligado, exige login Google e liga a
  resposta à conta.
- Sem perguntas de upload de arquivo (também exigem login).
- Sem perguntas de idade exata, gênero, curso, bairro ou outros dados que,
  numa amostra pequena, permitem reconhecer alguém.
- Antes de analisar: exporte as respostas, **apague a coluna "Carimbo de
  data/hora"** (o horário permite cruzar com quem testou o app em cada
  momento) e apague qualquer resposta aberta em que alguém tenha se
  identificado.

#### Página 1: apresentação (texto para o participante)

> **Avaliação do aplicativo OnRolê**
>
> Você está sendo convidado(a) a responder este questionário, que faz parte
> do Trabalho de Conclusão de Curso de Lucas Lemes Félix, do curso de Sistemas
> de Informação do Centro Universitário do Espírito Santo (UNESC), orientado
> pelo Prof. Daniel Rossi de Jesus. O objetivo é conhecer sua opinião sobre
> a versão de demonstração do OnRolê que você usou.
>
> - A participação é voluntária e sem nenhum pagamento. Você pode desistir a
>   qualquer momento: basta fechar esta página. Nada é gravado antes de você
>   enviar.
> - Só podem participar pessoas com 18 anos ou mais.
> - O questionário é anônimo. Ele não pede nem registra nome, e-mail,
>   telefone ou qualquer dado que identifique você. Por favor, não escreva
>   dados pessoais nas respostas abertas.
> - A demonstração não usou sua localização e não criou nenhuma conta.
> - Leva cerca de 5 minutos.
> - Os resultados serão divulgados só de forma agregada (porcentagens e
>   médias), no TCC.
> - Dúvidas: lucasyt710@gmail.com.
>
> **Você tem 18 anos ou mais e concorda em participar?**
> ( ) Sim, tenho 18 anos ou mais e concordo em participar
> ( ) Não
>
> *(Em "Não", use "Ir para a seção com base na resposta" e mande para o envio
> do formulário, que termina sem nenhuma outra pergunta.)*

#### Página 2: hábitos (contexto, sem identificar)

1. Com que frequência você sai para bares, festas ou eventos?
   Menos de 1 vez por mês · 1 a 3 vezes por mês · 1 vez por semana · Mais de
   1 vez por semana
2. Hoje, como você costuma escolher aonde ir? (pode marcar mais de uma)
   Instagram · WhatsApp ou amigos · Google Maps · Já sei aonde vou · Outro

#### Página 3: aceitação da tecnologia (TAM)

Escala de 1 a 5 para todos os itens: 1 = Discordo totalmente, 2 = Discordo,
3 = Nem concordo nem discordo, 4 = Concordo, 5 = Concordo totalmente.
Adaptado de Davis (1989).

| Código | Item |
| --- | --- |
| UP1 | Usar o OnRolê me ajudaria a escolher aonde ir mais rápido. |
| UP2 | O OnRolê me ajudaria a evitar lugares vazios ou cheios demais. |
| UP3 | O mapa de calor me ajudaria a decidir aonde ir. |
| UP4 | No geral, o OnRolê seria útil para as minhas saídas. |
| FU1 | Aprender a usar o OnRolê foi fácil. |
| FU2 | Foi fácil encontrar o que eu procurava no app. |
| FU3 | Entendi o mapa de calor sem precisar de explicação. |
| FU4 | No geral, o OnRolê é fácil de usar. |
| IU1 | Se o OnRolê estivesse disponível em Colatina, eu usaria. |
| IU2 | Eu indicaria o OnRolê para amigos. |

UP = utilidade percebida, FU = facilidade de uso percebida, IU = intenção de
uso.

#### Página 4: mapa de calor (H1) e Conexões (H3)

| Código | Item | Escala |
| --- | --- | --- |
| H1a | Comparado ao jeito como escolho hoje, escolher pelo mapa do OnRolê seria… | 1 = muito mais lento … 5 = muito mais rápido |
| H1b | Comparado ao jeito como escolho hoje, escolher pelo mapa do OnRolê seria… | 1 = muito mais frustrante … 5 = muito menos frustrante |
| H3a | As sugestões de pessoas que mostravam locais em comum pareceram mais interessantes do que as outras. | Concordância 1–5 |
| H3b | Eu prefiro conhecer pessoas pelos lugares que elas frequentam do que só pela aparência nas fotos. | Concordância 1–5 |
| H3c | Saber que a pessoa frequenta os mesmos lugares me deixaria mais à vontade para puxar conversa. | Concordância 1–5 |
| H2a | O selo "no rolê agora" me faria confiar mais nos posts. | Concordância 1–5 |
| P1 | Eu me sentiria à vontade com o app detectando sozinho quando estou num local. | Concordância 1–5 |

#### Página 5: comentário (opcional)

- Quer deixar um comentário ou sugestão? *Não escreva seu nome nem dados
  pessoais.*

### Análise

- Para cada construto (UP, FU, IU), use a média dos itens. Relate média,
  mediana e distribuição (porcentagem de 4 e 5). Relate o alfa de Cronbach de
  cada construto, lembrando que com cerca de 20 respostas ele é impreciso.
- H1: mediana e porcentagem acima de 3 em H1a e H1b, e teste de Wilcoxon de
  uma amostra contra o ponto neutro (3). A hipótese é apoiada se as duas
  medianas ficarem acima de 3 com diferença significativa (p < 0,05).
- H3: o mesmo para H3a a H3c. A comparação afinidade x sorteio vira percepção
  (H3a), porque nenhuma curtida é registrada.
- O Wilcoxon é usado porque as respostas são ordinais (escala de 1 a 5) e a
  amostra é pequena, sem supor distribuição normal.
- **Divulgue só resultados agregados.** Nada de respostas individuais, nem
  cruzamentos que isolem grupos pequenos (menos de 5 pessoas). Comentários
  abertos entram resumidos em temas, sem citação literal que possa
  identificar alguém.

## 3. O que foi descartado

- A coleta antiga: telemetria por participante (transições de geocerca, GPS,
  quadros, bateria e tempo até escolher um local), convite de participação e
  diário de campo "Cheguei/Saí", com horários e locais reais. Saiu do app e
  as regras do Firestore negam a coleção `telemetry`.
- A exportação pseudonimizada (`tools/experiment_export`).
- Os dados que a coleta antiga deixou no Firebase foram apagados em
  26/10/2026 com `on_role/tools/purge_experiment` (`node purge.js --apply
  --checkins`): 78 lotes de telemetria com o diário de campo, o
  consentimento, o histórico de check-ins, a presença e a contagem de visitas
  das contas. Antes da aplicação, a contagem sem `--apply`
  (`node purge.js --checkins`) é rodada de novo e precisa dar zero. Qualquer
  cópia local (planilhas, CSVs, anotações) também deve ser apagada.
- O app completo, com Firebase e GPS real, não é entregue a participantes.

## 4. Limitações

- **Sem fotos e stories na demonstração.** Para não identificar ninguém, a
  demonstração não tem câmera nem galeria, e quem avalia publica só texto.
  A avaliação do feed fica limitada a ver as publicações sintéticas.
- **GPS simulado na bancada.** A precisão das geocercas (H2) vem de trajetos
  sintéticos com um modelo de erro do GPS. Ela mede a lógica das geocercas,
  não o GPS de um aparelho real.
- **Amostra por conveniência.** Cerca de 20 voluntários do próprio curso,
  sem sorteio. Os resultados não se generalizam para outros públicos, e o
  alfa de Cronbach e os testes têm pouca precisão.
- **Percepção, não comportamento.** H1 e H3 medem o que a pessoa acha depois
  de usar a demonstração, e não o tempo real de escolha nem curtidas reais.
- **Check-in só com o app aberto** e testado só no Android.

## Referência

DAVIS, F. D. Perceived usefulness, perceived ease of use, and user acceptance
of information technology. **MIS Quarterly**, v. 13, n. 3, p. 319–340, 1989.

BRASIL. Conselho Nacional de Saúde. **Resolução nº 510, de 7 de abril de
2016**. Dispõe sobre as normas aplicáveis a pesquisas em Ciências Humanas e
Sociais. Diário Oficial da União, Brasília, 24 maio 2016.
