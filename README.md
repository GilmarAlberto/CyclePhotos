# Galeria (protótipo)

Protótipo de galeria de fotos e vídeos para **Android**, feito com Flutter.

## O que já funciona
- Pede permissão de acesso a fotos e vídeos (Android 13+ e versões anteriores)
- Lista os **álbuns** do aparelho, com capa e quantidade de itens
- Grade de miniaturas por álbum, com carregamento sob demanda (rolagem infinita)
- Visualizador: passar de uma foto para outra, zoom com pinça, reprodução de vídeo com barra de progresso
- Tema claro e escuro automático

## Ainda não incluído (a combinar)
- Anúncios (AdMob) e identidade visual própria
- Favoritos, apagar, compartilhar, pastas privadas
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
