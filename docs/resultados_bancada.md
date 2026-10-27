# Resultados da bancada: precisão das geocercas (H2)

Trajetos sintéticos (ver [protocolo_experimento.md](protocolo_experimento.md),
seção 1). Nenhum participante, nenhuma localização real. Para refazer:

```powershell
cd on_role
dart run tools/geofence_bench.dart --seeds 5 --nights 1000                        # parâmetros atuais do app
dart run tools/geofence_bench.dart --seeds 5 --nights 1000 --dwell 120 --still 0  # antes do ajuste
```

## Antes e depois do ajuste

5 sementes (1 a 5), com 1.000 noites cada e cerca de 3.000 visitas por
semente. Os valores são a média ± o desvio-padrão entre as sementes.

| Métrica | Antes: 2 min, sem detecção de parada | Depois: 3 min, parada de 30 m |
| --- | --- | --- |
| Transições corretas (meta > 95%) | 57,3% ± 0,3 | **93,9% ± 0,7** |
| Visitas detectadas (sensibilidade) | 99,7% ± 0,1 | 98,0% ± 0,4 |
| Check-ins certos (precisão) | 58,0% ± 0,3 | **97,1% ± 0,3** |
| Check-outs no tempo | 98,1% ± 0,2 | 97,3% ± 0,4 |
| Check-ins falsos por noite | 2,1 | 0,1 |
| Atraso mediano do check-in | 80 s | 183 s |
| Atraso mediano do check-out | 138 s | 138 s |

Nas duas configurações: saída confirmada após 60 s, histerese de 25 m e
precisão máxima aceita de 60 m.

## O que mudou e por quê

A primeira rodada mostrou que quase todas as visitas eram detectadas, mas que
42% dos check-ins eram falsos. A análise por local mostrou duas causas.

1. **Atravessar uma cerca andando.** Cruzar a cerca da Área Verde (120 m de
   raio) leva mais de 2 minutos, e cercas de 75 m também, para quem anda
   devagar. Isso bastava para confirmar a permanência. Aumentar só o tempo de
   permanência não resolveu: com 5 minutos, as transições corretas chegaram a
   73,5%, porque continuava valendo estar dentro da cerca, parado ou não.
   **Solução:** a permanência só conta enquanto a pessoa está parada, isto é,
   com as leituras a até 30 m da média das anteriores. Duas leituras seguidas
   fora desse raio indicam que ela andou, e a contagem recomeça. Uma leitura
   solta longe da média (reflexo do GPS) é ignorada.
2. **Sair de um local que fica dentro da cerca de outro.** Quem estava no
   Bharem também estava dentro da cerca da Área Verde, e quem estava no
   Espetinho do Denis, dentro da cerca do DJ PUB. Ao sair, o app fazia
   check-in na hora no vizinho, ainda "em permanência", com a pessoa já
   andando. **Solução:** um check-in novo só acontece num local em que a
   pessoa está parada há pelo menos o tempo de permanência. A troca entre
   vizinhos também passou a exigir que o novo local esteja mais perto por mais
   de 25 m (a histerese).

A permanência de 3 minutos veio de uma varredura com 2, 3, 4 e 5 minutos,
raios de parada de 25 a 60 m, histerese de 25 e 40 m e saída de 60 a 120 s.
Ela teve o melhor equilíbrio entre acerto e atraso.

## Leitura do resultado

- A meta de 95% não foi atingida por pouco: 93,9% ± 0,7. O preço do ajuste é
  um check-in mais lento (mediana de 3 min depois da chegada, antes 80 s) e
  2% de visitas não detectadas, quase todas por GPS ruim dentro do local, que
  impede a parada de ser reconhecida.
- **Limitação:** o resultado vale para o modelo de GPS e de caminhada da
  bancada:
  - precisão mediana de 8 m na rua e 20 m dentro dos locais;
  - erro correlacionado no tempo;
  - 2% de leituras muito fora;
  - caminhada em linha reta a 1,0–1,5 m/s.

  A bancada mede a lógica das geocercas, não o GPS de um aparelho específico.
  O ajuste foi escolhido e avaliado com o mesmo modelo de trajetos. A
  varredura usou as sementes 1 e 11 a 15, e a tabela usa as sementes 1 a 5:
  só a semente 1 se repete.
