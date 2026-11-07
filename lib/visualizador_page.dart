import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import 'album_page.dart' show kAlbumEmEnvio;

class VisualizadorPage extends StatefulWidget {
  const VisualizadorPage(
      {super.key,
      required this.itens,
      required this.inicial,
      required this.albumId});

  /// Lista do álbum: apagar daqui também a atualiza.
  final List<AssetEntity> itens;
  final int inicial;
  final String albumId;

  @override
  State<VisualizadorPage> createState() => _VisualizadorPageState();
}

class _VisualizadorPageState extends State<VisualizadorPage> {
  late final PageController _pagina = PageController(initialPage: widget.inicial);
  late int _atual = widget.inicial;

  @override
  void dispose() {
    _pagina.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final arquivo = await widget.itens[_atual].originFile;
    if (arquivo == null || !mounted) return;
    // Se o Android fechar o app durante o envio, a tela inicial reabre o álbum.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kAlbumEmEnvio, widget.albumId);
    await SharePlus.instance.share(ShareParams(files: [XFile(arquivo.path)]));
    await prefs.remove(kAlbumEmEnvio);
  }

  Future<void> _apagar() async {
    final item = widget.itens[_atual];
    final tipo = item.type == AssetType.video ? 'vídeo' : 'foto';
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Apagar este $tipo?'),
        content: const Text('Ele será removido do aparelho.'),
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
    final apagados = await PhotoManager.editor.deleteWithIds([item.id]);
    if (!mounted || !apagados.contains(item.id)) return;
    setState(() => widget.itens.removeWhere((e) => e.id == item.id));
    if (widget.itens.isEmpty) {
      Navigator.pop(context);
      return;
    }
    if (_atual >= widget.itens.length) {
      _atual = widget.itens.length - 1;
      _pagina.jumpToPage(_atual);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_atual + 1} de ${widget.itens.length}'),
        actions: [
          IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Enviar',
              onPressed: _enviar),
          IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Apagar',
              onPressed: _apagar),
        ],
      ),
      body: PageView.builder(
        controller: _pagina,
        itemCount: widget.itens.length,
        onPageChanged: (i) => setState(() => _atual = i),
        itemBuilder: (_, i) {
          final item = widget.itens[i];
          return item.type == AssetType.video
              ? _Video(key: ValueKey(item.id), item: item)
              : InteractiveViewer(
                  maxScale: 5,
                  child: Center(
                      child: AssetEntityImage(item,
                          isOriginal: true, fit: BoxFit.contain)),
                );
        },
      ),
    );
  }
}

class _Video extends StatefulWidget {
  const _Video({super.key, required this.item});
  final AssetEntity item;

  @override
  State<_Video> createState() => _VideoState();
}

class _VideoState extends State<_Video> {
  VideoPlayerController? _ctl;

  @override
  void initState() {
    super.initState();
    _abrir();
  }

  Future<void> _abrir() async {
    final arquivo = await widget.item.file;
    if (arquivo == null || !mounted) return;
    final ctl = VideoPlayerController.file(File(arquivo.path));
    await ctl.initialize();
    if (!mounted) {
      ctl.dispose();
      return;
    }
    setState(() => _ctl = ctl);
    ctl.play();
  }

  @override
  void dispose() {
    _ctl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctl = _ctl;
    if (ctl == null) return const Center(child: CircularProgressIndicator());
    return GestureDetector(
      onTap: () => setState(
          () => ctl.value.isPlaying ? ctl.pause() : ctl.play()),
      child: Center(
        child: AspectRatio(
          aspectRatio: ctl.value.aspectRatio,
          child: Stack(alignment: Alignment.bottomCenter, children: [
            VideoPlayer(ctl),
            VideoProgressIndicator(ctl, allowScrubbing: true),
          ]),
        ),
      ),
    );
  }
}
