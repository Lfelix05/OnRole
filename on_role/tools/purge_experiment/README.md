# Descarte dos dados da antiga coleta de campo

O experimento não coleta mais dados de participantes (veja
`docs/protocolo_experimento.md` na raiz do repositório). Este script apaga do
Firestore o que a coleta antiga deixou:

- `telemetry/{uid}/batches`: os lotes de eventos, com o diário de campo
  ("Cheguei" / "Saí"), que tem horários e locais reais;
- `users/{uid}/private/experiment`: o consentimento de cada conta.

Com `--checkins`, apaga também a localização real de quem testou o app
completo: o histórico `users/{uid}/checkins`, a `presence` e a contagem de
`visits` de cada perfil.

## Como rodar

1. Gere a chave da conta de serviço como no README de `tools/demo_profiles`
   e guarde **fora do repositório**.
2. Instale as dependências (Node 22 ou mais novo):

   ```powershell
   cd on_role/tools/purge_experiment
   npm install
   ```

3. Primeiro só conte o que seria apagado. Nada muda:

   ```powershell
   $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\Users\<você>\chaves\onrole-tcc.json"
   node purge.js --checkins
   ```

4. Depois apague:

   ```powershell
   node purge.js --apply --checkins
   ```

   No fim, o script confere se sobrou algo.

Não dá para desfazer. Apague também qualquer cópia que tenha saído do Firebase,
como planilhas ou CSVs exportados, prints e anotações do diário de campo.

Para testar no emulador, sem tocar no banco real, defina
`FIRESTORE_EMULATOR_HOST` e use `--project demo-onrole`.
