// ==============================
// CyclePhotos — Anúncios (AdMob)
//
// Copiado do CycleCursos (lib/dados/anuncios.dart), que veio do CycleCal: o mesmo formato combinado com
// o Gil — um banner 320x50 ancorado no rodapé, sempre visível, sem tela cheia.
// Só Android, falha em silêncio, nunca bloqueia o boot. Antes de pedir anúncio
// roda o consentimento UMP do Google (LGPD/GDPR).
//
// IDs (conta cycledev26): App ID ca-app-pub-1636142638953362~3246842296 (no
// AndroidManifest.xml) e o bloco "CycleCursos rodape" abaixo. Em debug usa o ID
// de teste oficial do Google, para não gerar impressão real durante o
// desenvolvimento.
// ==============================

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// ── IDs ──────────────────────────────────────────────────────────────────

// TODO: trocar pelo bloco "CyclePhotos rodape" criado no AdMob (conta cycledev26).
const String _bannerReal = 'ca-app-pub-3940256099942544/6300978111';
const String _bannerTeste =
    'ca-app-pub-3940256099942544/6300978111'; // teste oficial do Google
// APK de teste para o Gil instalar: --dart-define=ANUNCIO_TESTE=true força o banner de teste
// mesmo em release (clicar no próprio anúncio real pode suspender a conta do AdMob).
const bool _forcarTeste = bool.fromEnvironment('ANUNCIO_TESTE');
const String _bannerUnitId = (kReleaseMode && !_forcarTeste)
    ? _bannerReal
    : _bannerTeste;

// ── Config ───────────────────────────────────────────────────────────────

// Teto pro fluxo de consentimento não segurar nada além do razoável numa
// rede ruim (o form em si, quando aparece, não conta esse tempo).
const Duration _consentTimeout = Duration(seconds: 12);

// ── Estado ───────────────────────────────────────────────────────────────

/// Desliga todos os anúncios (init e banner viram no-op).
/// Gancho pra futura opção paga; hoje sempre true.
bool adsEnabled = true;

/// Vira true quando o SDK terminou de inicializar (com consentimento OK).
/// O `_BannerSlot` escuta isso pra pedir o banner — o widget monta antes
/// do SDK ficar pronto, então não dá pra checar só uma vez no init dele.
final ValueNotifier<bool> adsReady = ValueNotifier<bool>(false);

bool _initStarted = false;

bool get _supported {
  try {
    return Platform.isAndroid;
  } catch (_) {
    return false;
  }
}

// ==============================
// initAds()
// Chamado no main(). Roda o consentimento e inicializa o SDK. Fire-and-forget:
// não precisa (nem deve) segurar o runApp.
// ==============================

Future<void> initAds() async {
  if (!adsEnabled || !_supported || _initStarted) return;
  _initStarted = true;
  try {
    final podePedir = await _rodarConsentimento();
    if (!podePedir) return; // recusou / sem info — fica tudo inerte

    await MobileAds.instance.initialize();
    adsReady.value = true;
  } catch (_) {
    // sem anúncios nessa sessão
  }
}

// ==============================
// bannerSlot()
// Widget pro rodapé do Scaffold. Some sozinho (SizedBox de altura 0) até
// um anúncio de fato carregar — não reserva espaço antes. No-op fora do
// Android ou com anúncios desligados.
// ==============================

Widget bannerSlot() {
  if (!adsEnabled || !_supported) return const SizedBox.shrink();
  return const _BannerSlot();
}

// ── internos ─────────────────────────────────────────────────────────────

// Fluxo UMP. Retorna true se dá pra pedir anúncio (consentimento obtido
// ou não exigido). Em erro de rede a gente ainda tenta `canRequestAds`
// (o SDK pode ter estado em cache de sessões anteriores).
Future<bool> _rodarConsentimento() async {
  try {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        try {
          await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
        } catch (_) {}
        if (!done.isCompleted) done.complete();
      },
      (_) {
        if (!done.isCompleted) done.complete();
      },
    );
    await done.future.timeout(_consentTimeout, onTimeout: () {});
  } catch (_) {
    // segue pro canRequestAds mesmo assim
  }
  try {
    return await ConsentInformation.instance.canRequestAds();
  } catch (_) {
    return false;
  }
}

// ── Banner ───────────────────────────────────────────────────────────────

class _BannerSlot extends StatefulWidget {
  const _BannerSlot();

  @override
  State<_BannerSlot> createState() => _BannerSlotState();
}

class _BannerSlotState extends State<_BannerSlot> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _pedido = false;

  @override
  void initState() {
    super.initState();
    // O SDK quase sempre ainda não está pronto quando este widget monta
    // (initAds() leva 1-3s). Escuta o adsReady e pede o banner quando
    // virar — ou já pede, se por acaso o init tiver terminado antes.
    if (adsReady.value) {
      _pedirBanner();
    } else {
      adsReady.addListener(_aoFicarPronto);
    }
  }

  void _aoFicarPronto() {
    if (adsReady.value && mounted) {
      adsReady.removeListener(_aoFicarPronto);
      _pedirBanner();
    }
  }

  void _pedirBanner() {
    if (_pedido) return;
    _pedido = true;
    try {
      final ad = BannerAd(
        adUnitId: _bannerUnitId,
        // Tamanho fixo 320x50 — altura previsível (~50px), sem chamada
        // assíncrona de tamanho adaptativo que podia voltar null.
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) {
            if (!mounted) return;
            setState(() => _loaded = true);
          },
          onAdFailedToLoad: (ad, _) {
            ad.dispose();
            if (!mounted) return;
            setState(() {
              _ad = null;
              _loaded = false;
            });
          },
        ),
      );
      _ad = ad;
      ad.load();
    } catch (_) {
      // sem banner nessa sessão
    }
  }

  @override
  void dispose() {
    adsReady.removeListener(_aoFicarPronto);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
