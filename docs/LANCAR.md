# Lançar o Tilt Turret na Play Store

O APK de pré-release usa os anúncios de teste do Google. Ele serve para instalar no celular e jogar. A ficha da loja recebe o AAB, com os IDs reais do AdMob, no passo 6.

Guarde o arquivo `C:\Users\styhx\TiltTurret-upload.keystore` e a senha que está em `C:\Users\styhx\TiltTurret-keystore.txt`. Sem esses dois você não consegue publicar atualização do mesmo app.

## 1. Conta

1. Abra [play.google.com/console](https://play.google.com/console) e pague a taxa única de desenvolvedor.
2. Em [admob.google.com](https://admob.google.com), crie um app Android com o pacote `com.tiltturret.stackdefense`.
3. Crie quatro blocos: banner, intersticial, premiado e o ID do app. Anote os números `ca-app-pub-...`.
4. No Play Console, crie o produto gerenciado `remove_forced_ads`, compra única, R$ 9,90.

## 2. Trocar os IDs de teste

No arquivo `scripts/autoload/ads.gd`, substitua as quatro constantes do topo pelos IDs reais. O ID do app também entra na predefinição de exportação do Android, no meta-data do AdMob, quando o plugin nativo estiver ligado.

Gere de novo o AAB. Suba o `version/code` em 1 a cada envio.

## 3. Política de privacidade

1. Abra `docs/privacy.html` e troque `CONTACT_EMAIL` pelo seu e-mail.
2. No GitHub, em Settings, Pages, publique a pasta `/docs`.
3. A URL fica `https://styhxd.github.io/Tilt-Turret/privacy.html`. Cole essa URL na ficha da Play.

## 4. Criar o app

Nome: **Tilt Turret: Stack & Defense**. Pacote: `com.tiltturret.stackdefense`. Grátis. Categoria: jogo casual.

Ficha em português e em inglês:

- Título: Tilt Turret: Stack & Defense
- Descrição curta: Empilhe a torre, segure o pêndulo e derrube os kaiju.
- Descrição longa: Gire a torre, solte o bloco pesado no lado que está subindo e deixe os canhões atirarem. Quanto mais perto do prumo, mais forte é o tiro. Besouros, caranguejos e lesmas empurram a base. Arraias, vespas e carrapatos batem no alto.

Ícone: `assets/store/icon.png` (512). Banner: `assets_src/store/feature_1024x500.jpeg`. Capturas: jogue uma partida e salve pelo menos duas telas em retrato, 1080x1920.

## 5. Questionários

- Contém anúncios: sim.
- Público: 13 anos ou mais. Não marque Feito para Família.
- Classificação etária: violência de desenho, sem sangue.
- Segurança dos dados: dados coletados pelo AdMob (ID de publicidade e diagnóstico de anúncio), não vendidos, sem conta. Compra processada pelo Google Play. Progresso salvo só no aparelho.
- Notícias, governo, saúde: não.
- Alvo da API: 36. Mínimo: 29 (Android 10). O renderer Mobile do Godot 4.7 usa Vulkan e recusa alvo menor que isso.

## 6. Enviar

1. Em Teste interno, suba `build/TiltTurret-0.1.0.aab`.
2. Adicione o seu e-mail de testador e instale pelo link.
3. Confira: girar, soltar, tiro, queda, anúncio de congelar, super cola, baú, banner só no menu.
4. Quando estiver redondo, promova o mesmo AAB para produção. Preencha países, a política de privacidade e o preço grátis.
5. A revisão do Google costuma levar de algumas horas a alguns dias.

## Abrir o projeto de novo

O Godot portátil está em `C:\Users\styhx\OneDrive\Área de Trabalho\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe`. Abra a pasta deste repositório. A cena principal é `scenes/main.tscn`.

Antes de exportar, pause a sincronização do OneDrive nesta pasta. O acento no caminho às vezes trava o Gradle. Se travar, copie o projeto para `C:\dev\TiltTurret` e exporte de lá.

No editor, em Editor, Configurações do editor, Exportar, Android: o SDK é `%LOCALAPPDATA%\Android\Sdk` e o Java é o JDK 21 da Adoptium.
