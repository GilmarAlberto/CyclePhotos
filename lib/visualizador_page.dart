import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:video_player/video_player.dart';

class VisualizadorPage extends StatefulWidget {
  const VisualizadorPage({super.key, required this.itens, required this.inicial});
  final List<AssetEntity> itens;
  final int inicial;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_atual + 1} de ${widget.itens.length}'),
      ),
      body: PageView.builder(
        controller: _pagina,
        itemCount: widget.itens.length,
        onPageChanged: (i) => setState(() => _atual = i),
        itemBuilder: (_, i) {
          final item = widget.itens[i];
          return item.type == AssetType.video
              ? _Video(item: item)
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
  const _Video({required this.item});
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
