import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'album_page.dart';
import 'app_version.dart';
import 'tamanho.dart';

void main() => runApp(const GaleriaApp());

class GaleriaApp extends StatelessWidget {
  const GaleriaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CyclePhotos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      darkTheme: ThemeData(
          colorSchemeSeed: Colors.teal,
          brightness: Brightness.dark,
          useMaterial3: true),
      home: const InicioPage(),
    );
  }
}

class InicioPage extends StatefulWidget {
  const InicioPage({super.key});

  @override
  State<InicioPage> createState() => _InicioPageState();
}

class _InicioPageState extends State<InicioPage> {
  List<AssetPathEntity> _albuns = [];
  bool _negado = false;
  bool _carregando = true;
  int _versao = 0;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final perm = await PhotoManager.requestPermissionExtend();
    if (!perm.hasAccess) {
      setState(() {
        _negado = true;
        _carregando = false;
      });
      return;
    }
    final albuns = await PhotoManager.getAssetPathList(type: RequestType.common);
    if (!mounted) return;
    Tamanhos.esquecerAlbuns();
    setState(() {
      _versao++;
      _albuns = albuns;
      _negado = false;
      _carregando = false;
    });
    await _reabrirAlbumDoEnvio();
  }

  /// O app foi fechado enquanto compartilhava: volta ao álbum em que estava.
  Future<void> _reabrirAlbumDoEnvio() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(kAlbumEmEnvio);
    if (id == null) return;
    await prefs.remove(kAlbumEmEnvio);
    final album = _albuns.where((a) => a.id == id).firstOrNull;
    if (album == null || !mounted) return;
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => AlbumPage(album: album)));
    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CyclePhotos')),
      body: _corpo(),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('CyclePhotos v$kAppVersion',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall),
        ),
      ),
    );
  }

  Widget _corpo() {
    if (_carregando) return const Center(child: CircularProgressIndicator());
    if (_negado) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Precisamos de acesso às suas fotos e vídeos.'),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: PhotoManager.openSetting,
                child: const Text('Abrir configurações')),
          ],
        ),
      );
    }
    if (_albuns.isEmpty) {
      return const Center(child: Text('Nenhuma foto ou vídeo encontrado.'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12),
      itemCount: _albuns.length,
      itemBuilder: (_, i) => _CartaoAlbum(
          key: ValueKey('${_albuns[i].id}-$_versao'),
          album: _albuns[i],
          aoVoltar: _carregar),
    );
  }
}

class _CartaoAlbum extends StatelessWidget {
  const _CartaoAlbum({super.key, required this.album, required this.aoVoltar});
  final AssetPathEntity album;
  final VoidCallback aoVoltar;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        await Navigator.push(context,
            MaterialPageRoute(builder: (_) => AlbumPage(album: album)));
        aoVoltar();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: FutureBuilder<List<AssetEntity>>(
                future: album.getAssetListRange(start: 0, end: 1),
                builder: (_, snap) {
                  final item = snap.data?.firstOrNull;
                  if (item == null) return const ColoredBox(color: Colors.black12);
                  return _Miniatura(item: item, tamanho: 400);
                },
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(album.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          FutureBuilder<List<int>>(
            future: Future.wait([album.assetCountAsync, Tamanhos.doAlbum(album)]),
            builder: (_, snap) => Text(
                snap.hasData
                    ? '${snap.data![0]} itens · ${formatarTamanho(snap.data![1])}'
                    : 'calculando…',
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _Miniatura extends StatelessWidget {
  const _Miniatura({required this.item, required this.tamanho});
  final AssetEntity item;
  final int tamanho;

  @override
  Widget build(BuildContext context) {
    return AssetEntityImage(
      item,
      isOriginal: false,
      thumbnailSize: ThumbnailSize.square(tamanho),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const ColoredBox(
          color: Colors.black12,
          child: Center(child: Icon(Icons.image_not_supported_outlined))),
    );
  }
}
