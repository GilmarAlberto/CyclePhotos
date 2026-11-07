import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

/// Ex.: 850 KB, 3,4 MB, 1,25 GB.
String formatarTamanho(int bytes) {
  const kb = 1024;
  const mb = kb * 1024;
  const gb = mb * 1024;
  String casas(double v, int n) => v.toStringAsFixed(n).replaceAll('.', ',');
  if (bytes >= gb) return '${casas(bytes / gb, 2)} GB';
  if (bytes >= mb) return '${casas(bytes / mb, 1)} MB';
  if (bytes >= kb) return '${(bytes / kb).round()} KB';
  return '$bytes B';
}

/// Tamanho em disco dos itens e totais por álbum, com cache.
class Tamanhos {
  static final Map<String, int> _itens = {};
  static final Map<String, Future<int>> _albuns = {};
  static const _limite = 6;
  static int _ativos = 0;
  static final List<Completer<void>> _fila = [];

  static Future<void> _vaga() async {
    if (_ativos < _limite) {
      _ativos++;
      return;
    }
    final c = Completer<void>();
    _fila.add(c);
    await c.future;
  }

  static void _libera() {
    if (_fila.isNotEmpty) {
      _fila.removeAt(0).complete();
    } else {
      _ativos--;
    }
  }

  /// Valor já conhecido, sem esperar (null se ainda não foi lido).
  static int? emCache(AssetEntity item) => _itens[item.id];

  static Future<int> doItem(AssetEntity item) async {
    final guardado = _itens[item.id];
    if (guardado != null) return guardado;
    await _vaga();
    try {
      final arquivo = await item.originFile;
      final bytes = arquivo == null ? 0 : await arquivo.length();
      _itens[item.id] = bytes;
      return bytes;
    } catch (_) {
      return 0;
    } finally {
      _libera();
    }
  }

  static Future<int> dosItens(Iterable<AssetEntity> itens) async {
    final partes = await Future.wait(itens.map(doItem));
    return partes.fold<int>(0, (a, b) => a + b);
  }

  static Future<int> doAlbum(AssetPathEntity album) =>
      _albuns.putIfAbsent(album.id, () => _somarAlbum(album));

  static Future<int> _somarAlbum(AssetPathEntity album) async {
    final total = await album.assetCountAsync;
    var soma = 0;
    for (var i = 0; i < total; i += 200) {
      final lote = await album.getAssetListRange(
          start: i, end: (i + 200 > total) ? total : i + 200);
      soma += await dosItens(lote);
    }
    return soma;
  }

  /// Esquece os totais dos álbuns (depois de apagar ou ao recarregar).
  static void esquecerAlbuns() => _albuns.clear();

  @visibleForTesting
  static void limparTudo() {
    _itens.clear();
    _albuns.clear();
  }
}
