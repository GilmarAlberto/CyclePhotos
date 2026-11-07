# CyclePhotos (protótipo)

Protótipo de galeria de fotos e vídeos para **Android**, feito com Flutter.

## O que já funciona
- Pede permissão de acesso a fotos e vídeos (Android 13+ e versões anteriores)
- Lista os **álbuns** do aparelho, com capa e quantidade de itens
- Grade de miniaturas por álbum, com carregamento sob demanda (rolagem infinita)
- Visualizador: passar de uma foto para outra, zoom com pinça, reprodução de vídeo com barra de progresso, **enviar e apagar** o item aberto
- **Selecionar e apagar**: segurar uma foto liga a seleção, tocar marca ou desmarca, **Selecionar tudo** pega o álbum inteiro, a lixeira apaga depois de confirmar; a lista de álbuns se atualiza ao voltar
- **Enviar**: compartilha os itens marcados por WhatsApp, e-mail e outros apps
- Tema claro e escuro automático

## Ainda não incluído (a combinar)
- Anúncios (AdMob) e identidade visual própria
- Favoritos, pastas privadas
- Publicação na Play Store

## Como rodar
```
flutter pub get
flutter run
```
Para gerar o APK de teste: `flutter build apk --debug`

## Estado dos testes
Código analisado (`flutter analyze`, sem avisos), teste unitário da formatação de duração e compilação do APK de teste conferidos.
Ainda **não testado em aparelho físico**.

## Versão
A versão fica em `lib/app_version.dart` (`kAppVersion`) e no `version:` do `pubspec.yaml`. **Toda mudança em `lib/` sobe a versão nos dois lugares**, no mesmo commit. Versão atual: **0.1.2**.
