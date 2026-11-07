import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import 'visualizador_page.dart';

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

  bool get _selecionando => _selecionados.isNotEmpty;

  void _alternar(AssetEntity item) {
    setState(() {
      if (!_selecionados.remove(item.id)) _selecionados.add(item.id);
    });
  }

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
    });
  }

  @override
  void initState() {
    super.initState();
    _rolagem.addListener(() {
      if (_rolagem.position.extentAfter < 600) _maisItens();
    });
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
        title: Text(_selecionando
            ? '${_selecionados.length} selecionado(s)'
            : widget.album.name),
        actions: [
          if (_selecionando)
            IconButton(
                icon: const Icon(Icons.select_all),
                tooltip: 'Selecionar tudo',
                onPressed: _selecionarTudo),
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
            onTap: () => _selecionando
                ? _alternar(item)
                : Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            VisualizadorPage(itens: _itens, inicial: i))),
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
