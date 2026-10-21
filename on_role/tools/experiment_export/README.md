# Exportação do experimento de campo

Baixa do Firestore os dados de quem aceitou participar do experimento e gera
as planilhas e o resumo das métricas do TCC (hipóteses H1 a H4). Ninguém sai
identificado: participantes viram P01, P02... (na ordem em que entraram) e
pessoas de fora que aparecem nas Conexões viram N01, N02...

## Antes da primeira vez

1. No [console do Firebase](https://console.firebase.google.com/project/onrole-tcc/settings/serviceaccounts/adminsdk),
   em **Configurações do projeto → Contas de serviço**, clique em
   **Gerar nova chave privada**.
2. Guarde o arquivo **fora do repositório**, por exemplo em
   `C:\Users\<você>\chaves\onrole-tcc.json`. Ele dá acesso total ao banco e o
   repositório é público.
3. Instale as dependências (Node 22 ou mais novo):

   ```powershell
   cd on_role/tools/experiment_export
   npm install
   ```

## Exportar

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\Users\<você>\chaves\onrole-tcc.json"
node export.js --since 2026-10-20 --excel-br
```

| Opção | Para quê |
| --- | --- |
| `--since AAAA-MM-DD` | Ignora o que veio antes da data, como os testes piloto. |
| `--excel-br` | CSV com ponto e vírgula e vírgula decimal, para abrir direto no Excel em português. |
| `--window 15` | Janela, em minutos, para casar o diário de campo com os eventos do app. O padrão é 10. |
| `--dataset out/dataset.json` | Refaz só a análise, sem acessar o Firebase. |

A exportação é incremental. Os lotes já baixados ficam em `out/.cache/` e cada
rodada lê só os novos, o que preserva a cota gratuita de 50 mil leituras por
dia. Quem saiu do experimento é descartado do cache e da análise. Quem apagou
os dados tem o cache refeito.

`out/` está no `.gitignore` porque o cache guarda os ids do Firebase. Não
copie essa pasta para o TCC. Use só os arquivos abaixo.

## O que sai em `out/`

| Arquivo | Conteúdo |
| --- | --- |
| `summary.md` | Tabelas prontas para o capítulo de resultados. |
| `summary.json` | As mesmas métricas, com o detalhe por participante. |
| `events.csv` | Todos os eventos, um por linha, com horário de Colatina. |
| `geofence.csv` | H1: chegadas e saídas do diário x check-in, entrada na cerca e check-out. |
| `battery.csv` | H4: consumo em %/h com o app aberto e em segundo plano, fora da tomada. |
| `frames.csv` | H4: tempo de construção e rasterização dos quadros do mapa, por aparelho. |
| `swipes.csv` | H3: cada curtida ou passe, a fonte da sugestão e se houve reciprocidade. |
| `participants.csv` | Código, período e aparelho de cada participante. |
| `dataset.json` | O conjunto pseudonimizado completo, para refazer a análise. |

## Como as métricas são calculadas

- **Acerto das geocercas (H1).** Cada "Cheguei" ou "Saí" do diário de campo é
  casado com o check-in ou check-out automático no mesmo local mais próximo no
  tempo, dentro da janela. O acerto é a fração de marcações do diário que o app
  detectou. A meta do projeto é acima de 95%. Check-ins sem marcação aparecem
  como "sem marcação no diário": podem ser falsos positivos ou marcações
  esquecidas. Eventos do modo simulação ficam de fora.
- **Latência (H1).** É o tempo entre a marcação e o evento do app. O check-in
  inclui os 2 minutos de permanência exigidos pela geocerca. A entrada na cerca
  mostra a latência do GPS sem essa espera.
- **Do mapa ao local (H2).** Mede o tempo entre abrir o mapa e escolher o
  primeiro local, por pino, busca ou cartão. Aberturas sem escolha em 10
  minutos contam como abandono.
- **Match (H3).** A fila de sugestões alterna uma pessoa por afinidade e uma
  sorteada. Cada decisão guarda a fonte, e a análise compara a taxa de
  curtidas e de reciprocidade entre as duas.
- **Bateria (H4).** O consumo usa só intervalos entre duas amostras
  descarregando, com até 30 minutos de distância. O intervalo é atribuído ao
  estado do app no início: aberto ou em segundo plano.
- **Quadros (H4).** O app resume o mapa em janelas de 30 segundos. A planilha
  combina as janelas pelo número de quadros. "Quadros a 60 FPS" é a fração que
  ficou dentro de 16,7 ms.

## Testes

```powershell
npm test
```

Para testar contra o emulador, sem tocar no banco real, defina
`FIRESTORE_EMULATOR_HOST` e use `--project demo-onrole`.
