# Perfis de demonstração

Seis pessoas fictícias para o OnRolê não parecer vazio: Marina, Rodrigo,
Camila, Beatriz, Gabriel e Larissa. Cada perfil tem avatar ilustrado, bio,
gostos de rolê, visitas a locais do catálogo e alguns posts com texto e
fotos. Os perfis também curtem e respondem os posts uns dos outros. Os dados
estão em `profiles.js` e as imagens em `images/`.

Os posts são convites e assuntos do dia a dia. Nenhum elogia nem afirma nada
sobre os estabelecimentos reais do catálogo.

## Antes do teste de campo: remova os perfis

Os perfis falsos aparecem nas Conexões dos participantes. Curtidas em perfis
falsos nunca são correspondidas, o que distorce a comparação da H3. Remova os
perfis antes de o teste começar:

```powershell
cd on_role/tools/demo_profiles
npm install
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\Users\<você>\chaves\onrole-tcc.json"
node remove.js
```

A chave é a mesma da exportação do experimento. Veja como gerá-la em
`../experiment_export/README.md`. A remoção encontra as contas
`demo.*@example.com` e apaga:

- os posts delas, com as respostas, inclusive as de pessoas reais;
- as fotos e os stories;
- as curtidas que elas deram;
- as decisões e os matches nas Conexões, nos dois sentidos;
- a presença, o perfil e a conta.

## Criar de novo

```powershell
node seed.js
```

O script cria cada perfil como o app faria: uma conta com e-mail e senha, e
tudo passando pelas regras do Firestore. Os e-mails, senhas e ids ficam em
`out/state.json`, fora do git. Com eles dá para entrar no app como um perfil
de demonstração, por exemplo para curtir de volta e testar um match. Rodar de
novo continua de onde parou e não duplica nada.

## Testar no emulador

Os dois scripts usam o emulador quando ele está ligado. O Auth e o Firestore
precisam estar ligados juntos, e os scripts param se só um estiver.

```powershell
cd on_role
firebase emulators:exec --only firestore,auth --project demo-onrole "node tools/demo_profiles/seed.js --state tools/demo_profiles/out/emulador.json && node tools/demo_profiles/remove.js --state tools/demo_profiles/out/emulador.json"
```

## Créditos das imagens

Todas as imagens são de domínio público (CC0), sem exigência de atribuição.
Os créditos ficam registrados mesmo assim.

| Arquivo | Origem |
| --- | --- |
| `avatar_*.jpg` | [DiceBear](https://www.dicebear.com/styles/lorelei/), estilo Lorelei, de Lisa Wischofsky, com fundo colorido |
| `marina_brinde.jpg` | [Wil Stewart, StockSnap](https://stocksnap.io/photo/cheers-beer-ZXWXE8FAJN) |
| `marina_violao.jpg` | [Negative Space, StockSnap](https://stocksnap.io/photo/acoustic-guitar-HP2GGWWPIN) |
| `rodrigo_bateria.jpg` | [Freestocks.org, StockSnap](https://stocksnap.io/photo/drums-set-O61HO0R6HH) |
| `rodrigo_show.jpg` | [Olu Eletu, StockSnap](https://stocksnap.io/photo/concert-show-FZE048NY32) |
| `camila_dj.jpg` | [Thomas Habr, StockSnap](https://stocksnap.io/photo/people-man-NWRLUAXJX5) |
| `camila_vinil.jpg` | [Matt Bango, StockSnap](https://stocksnap.io/photo/dj-record-ZSOYMYCJAZ) |
| `beatriz_rio.jpg` | [Humphrey Muleba, StockSnap](https://stocksnap.io/photo/sunset-river-FJK8M75ELF) |
| `gabriel_espetinho.jpg` | [Creative Vix, StockSnap](https://stocksnap.io/photo/barbecue-bbq-07Z2HAJFID) |
| `larissa_chope.jpg` | [Little Visuals, StockSnap](https://stocksnap.io/photo/beer-brew-F15A241D0A) |
| `larissa_hamburguer.jpg` | [Eaters Collective, StockSnap](https://stocksnap.io/photo/food-burger-WYL5KWIPUD) |
