import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:photo_manager/photo_manager.dart';

const String kServerClientId =
    '510240312901-47kj413v9s2h1nna8q8j0ocmjpuuvvqs.apps.googleusercontent.com';
const String kPastaNuvem = 'CyclePhotos';
const _escopos = [drive.DriveApi.driveFileScope];

/// Cliente HTTP que acrescenta o token do Google a cada pedido.
class _ClienteGoogle extends http.BaseClient {
  _ClienteGoogle(this._cabecalhos);
  final Map<String, String> _cabecalhos;
  final _interno = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_cabecalhos);
    return _interno.send(request);
  }

  @override
  void close() => _interno.close();
}

class ResultadoNuvem {
  ResultadoNuvem(this.enviadosConferidos, this.falhas);

  /// IDs (photo_manager) dos itens que chegaram ao Drive e foram conferidos.
  final List<String> enviadosConferidos;
  final List<String> falhas;
}

class Nuvem {
  static bool _iniciado = false;

  static Future<drive.DriveApi> _entrar() async {
    final login = GoogleSignIn.instance;
    if (!_iniciado) {
      await login.initialize(serverClientId: kServerClientId);
      _iniciado = true;
    }
    final conta = await login.attemptLightweightAuthentication() ??
        await login.authenticate();
    final cabecalhos = await conta.authorizationClient
        .authorizationHeaders(_escopos, promptIfNecessary: true);
    return drive.DriveApi(_ClienteGoogle(cabecalhos!));
  }

  static Future<String> _pasta(drive.DriveApi api) async {
    final achadas = await api.files.list(
      q: "mimeType='application/vnd.google-apps.folder' "
          "and name='$kPastaNuvem' and trashed=false",
      spaces: 'drive',
      $fields: 'files(id)',
    );
    if (achadas.files?.isNotEmpty ?? false) return achadas.files!.first.id!;
    final nova = await api.files.create(
        drive.File(
            name: kPastaNuvem, mimeType: 'application/vnd.google-apps.folder'),
        $fields: 'id');
    return nova.id!;
  }

  static Future<String> _md5(File arquivo) async =>
      (await md5.bind(arquivo.openRead()).first).toString();

  /// Envia cada item ao Drive e só considera "conferido" se o tamanho e o
  /// MD5 do arquivo no Drive forem iguais aos do arquivo no celular.
  static Future<ResultadoNuvem> enviar(
    List<AssetEntity> itens, {
    required void Function(int feitos, int total) progresso,
  }) async {
    final api = await _entrar();
    final pasta = await _pasta(api);
    final ok = <String>[];
    final falhas = <String>[];
    progresso(0, itens.length);
    for (var i = 0; i < itens.length; i++) {
      final item = itens[i];
      try {
        final arquivo = await item.originFile;
        if (arquivo == null) throw Exception('sem arquivo');
        final tamanho = await arquivo.length();
        final nome = await item.titleAsync;
        final enviado = await api.files.create(
          drive.File(name: nome, parents: [pasta]),
          uploadMedia: drive.Media(arquivo.openRead(), tamanho),
          $fields: 'id,size,md5Checksum',
        );
        final igual = enviado.id != null &&
            int.tryParse(enviado.size ?? '') == tamanho &&
            enviado.md5Checksum == await _md5(arquivo);
        if (igual) {
          ok.add(item.id);
        } else {
          if (enviado.id != null) await api.files.delete(enviado.id!);
          falhas.add(item.id);
        }
      } catch (_) {
        falhas.add(item.id);
      }
      progresso(i + 1, itens.length);
    }
    return ResultadoNuvem(ok, falhas);
  }
}
