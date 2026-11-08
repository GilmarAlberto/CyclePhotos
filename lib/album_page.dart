import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import 'nuvem.dart';
import 'tamanho.dart';
import 'visualizador_page.dart';

const String kAlbumEmEnvio = 'album_em_envio';

String duracaoTexto(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(1, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

class AlbumPage extends StatefulWidget {
  const AlbumPage({super.key, required this.album});
  final AssetPathEntity album;

  @override
  State<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends State<AlbumPage> {
  static const _lote = 80;
  final List<AssetEntity> _itens = [];
  final _rolagem = ScrollController();
  final Set<String> _selecionados = {};
  bool _carregando = false;
  bool _fim = false;

  late Future<int> _totalAlbum;

  bool get _selecionando => _selecionados.isNotEmpty;

  void _recalcularTotal() {
    Tamanhos.esquecerAlbuns();
    _totalAlbum = Tamanhos.doAlbum(widget.album);
  }

  Widget _subtitulo() {
    if (_selecionando) {
      final marcados = _itens.where((e) => _selecionados.contains(e.id));
      return FutureBuilder<int>(
        future: Tamanhos.dosItens(marcados),
        builder: (_, snap) => Text(
            snap.hasData ? formatarTamanho(snap.data!) : 'calculando…',
            style: Theme.of(context).textTheme.bodySmall),
      );
    }
    return FutureBuilder<int>(
      future: _totalAlbum,
      builder: (_, snap) => Text(
          snap.hasData
              ? 'Total: ${formatarTamanho(snap.data!)}'
              : 'Calculando tamanho…',
          style: Theme.of(context).textTheme.bodySmall),
    );
  }

  void _alternar(AssetEntity item) {
    setState(() {
      if (!_selecionados.remove(item.id)) _selecionados.add(item.id);
    });
  }

  Future<void> _enviar() async {
    final escolhidos = _itens.where((e) => _selecionados.contains(e.id));
    final arquivos = <XFile>[];
    for (final item in escolhidos) {
      final arquivo = await item.originFile;
      if (arquivo != null) arquivos.add(XFile(arquivo.path));
    }
    if (arquivos.isEmpty || !mounted) return;
    // Se o Android fechar o app durante o envio, a tela inicial reabre este álbum.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kAlbumEmEnvio, widget.album.id);
    await SharePlus.instance.share(ShareParams(files: arquivos));
    await prefs.remove(kAlbumEmEnvio);
  }

  Future<void> _nuvem() async {
    final modo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar para o Google Drive'),
        content: const Text(
            'Mover: envia, o app confere que chegou e só então apaga do celular.\n\n'
            'Copiar: envia e deixa no celular.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          OutlinedButton(
              onPressed: () => Navigator.pop(ctx, 'copiar'),
              child: const Text('COPIAR')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, 'mover'),
              child: const Text('MOVER')),
        ],
      ),
    );
    if (modo == null || !mounted) return;
    final escolhidos =
        _itens.where((e) => _selecionados.contains(e.id)).toList();
    final andamento = ValueNotifier<String>('Entrando na conta Google…');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: ValueListenableBuilder<String>(
            valueListenable: andamento,
            builder: (_, t, _) => Row(children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(child: Text(t)),
            ]),
          ),
        ),
      ),
    );
    ResultadoNuvem? r;
    Object? erro;
    try {
      r = await Nuvem.enviar(escolhidos,
          progresso: (f, t) => andamento.value = 'Enviando $f de $t…');
    } catch (e) {
      erro = e;
    }
    if (!mounted) return;
    Navigator.pop(context); // fecha o andamento
    if (r == null) {
      await _aviso('Não foi possível entrar no Google Drive. '
          'Nada foi apagado.\n\n($erro)');
      return;
    }
    var apagados = 0;
    if (modo == 'mover' && r.enviadosConferidos.isNotEmpty) {
      final feitos =
          await PhotoManager.editor.deleteWithIds(r.enviadosConferidos);
      apagados = feitos.length;
      if (!mounted) return;
      setState(() {
        _itens.removeWhere((e) => feitos.contains(e.id));
        _recalcularTotal();
      });
    }
    setState(_selecionados.clear);
    final n = r.enviadosConferidos.length;
    var msg = '$n enviado(s) ao Drive (pasta "$kPastaNuvem") e conferido(s).';
    if (modo == 'mover') msg += '\n$apagados apagado(s) do celular.';
    if (r.falhas.isNotEmpty) {
      msg += '\n\n${r.falhas.length} não puderam ser enviados e '
          'continuam no celular.';
    }
    await _aviso(msg);
  }

  Future<void> _aviso(String texto) => showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(texto),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
          ],
        ),
      );

  Future<void> _selecionarTudo() async {
    final total = await widget.album.assetCountAsync;
    if (_itens.length < total) {
      final resto = await widget.album
          .getAssetListRange(start: _itens.length, end: total);
      if (!mounted) return;
      _itens.addAll(resto);
    }
    setState(() {
      _fim = true;
      _selecionados.addAll(_itens.map((e) => e.id));
    });
  }

  Future<void> _apagar() async {
    final qtd = _selecionados.length;
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(qtd == 1 ? 'Apagar 1 item?' : 'Apagar $qtd itens?'),
        content: const Text('Eles serão removidos do aparelho.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Apagar')),
        ],
      ),
    );
    if (confirmou != true) return;
    final apagados =
        await PhotoManager.editor.deleteWithIds(_selecionados.toList());
    if (!mounted) return;
    setState(() {
      _itens.removeWhere((e) => apagados.contains(e.id));
      _selecionados.clear();
      _recalcularTotal();
    });
  }

  @override
  void initState() {
    super.initState();
    _rolagem.addListener(() {
      if (_rolagem.position.extentAfter < 600) _maisItens();
    });
    _totalAlbum = Tamanhos.doAlbum(widget.album);
    _maisItens();
  }

  @override
  void dispose() {
    _rolagem.dispose();
    super.dispose();
  }

  Future<void> _maisItens() async {
    if (_carregando || _fim) return;
    _carregando = true;
    final novos = await widget.album
        .getAssetListRange(start: _itens.length, end: _itens.length + _lote);
    if (!mounted) return;
    setState(() {
      _itens.addAll(novos);
      _fim = novos.length < _lote;
      _carregando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _selecionando
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(_selecionados.clear))
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_selecionando
                ? '${_selecionados.length} selecionado(s)'
                : widget.album.name),
            _subtitulo(),
          ],
        ),
        actions: [
          if (_selecionando)
            IconButton(
                icon: const Icon(Icons.select_all),
                tooltip: 'Selecionar tudo',
                onPressed: _selecionarTudo),
          if (_selecionando)
            IconButton(
                icon: const Icon(Icons.cloud_upload_outlined),
                tooltip: 'Enviar para o Drive',
                onPressed: _nuvem),
          if (_selecionando)
            IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'Enviar',
                onPressed: _enviar),
          if (_selecionando)
            IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Apagar',
                onPressed: _apagar),
        ],
      ),
      body: GridView.builder(
        controller: _rolagem,
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2),
        itemCount: _itens.length,
        itemBuilder: (_, i) {
          final item = _itens[i];
          final marcado = _selecionados.contains(item.id);
          return GestureDetector(
            onLongPress: () => _alternar(item),
            onTap: () async {
              if (_selecionando) {
                _alternar(item);
                return;
              }
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => VisualizadorPage(
                          itens: _itens,
                          inicial: i,
                          albumId: widget.album.id)));
              if (mounted) setState(_recalcularTotal);
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                AssetEntityImage(item,
                    isOriginal: false,
                    thumbnailSize: const ThumbnailSize.square(300),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: Colors.black12)),
                if (marcado)
                  ColoredBox(color: Colors.teal.withValues(alpha: 0.45)),
                if (_selecionando)
                  Positioned(
                    left: 6,
                    top: 6,
                    child: Icon(
                        marcado ? Icons.check_circle : Icons.circle_outlined,
                        color: Colors.white),
                  ),
                Positioned(
                  left: 4,
                  bottom: 4,
                  child: _SeloTamanho(item: item),
                ),
                if (item.type == AssetType.video)
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.play_arrow,
                              size: 14, color: Colors.white),
                          Text(duracaoTexto(item.videoDuration),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12)),
                        ]),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SeloTamanho extends StatelessWidget {
  const _SeloTamanho({required this.item});
  final AssetEntity item;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: Tamanhos.doItem(item),
      initialData: Tamanhos.emCache(item),
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        return DecoratedBox(
          decoration: BoxDecoration(
              color: Colors.black54, borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Text(formatarTamanho(snap.data!),
                style: const TextStyle(color: Colors.white, fontSize: 11)),
          ),
        );
      },
    );
  }
}
