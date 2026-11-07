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
  bool _carregando = false;
  bool _fim = false;

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
      appBar: AppBar(title: Text(widget.album.name)),
      body: GridView.builder(
        controller: _rolagem,
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2),
        itemCount: _itens.length,
        itemBuilder: (_, i) {
          final item = _itens[i];
          return GestureDetector(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => VisualizadorPage(itens: _itens, inicial: i))),
            child: Stack(
              fit: StackFit.expand,
              children: [
                AssetEntityImage(item,
                    isOriginal: false,
                    thumbnailSize: const ThumbnailSize.square(300),
                    fit: BoxFit.cover),
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
