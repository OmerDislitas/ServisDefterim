import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/db/database.dart';
import '../../core/strings.dart';
import 'photo_actions.dart';

/// Tam ekran fotograf goruntuleyici: kaydirarak gecis, iki parmakla yakinlastirma, silme.
/// Tam boyut dosyalar sadece burada yuklenir (PLAN 10).
class PhotoViewerScreen extends ConsumerStatefulWidget {
  const PhotoViewerScreen({super.key, required this.ownerType, required this.ownerId, this.initialIndex = 0});

  final PhotoOwnerType ownerType;
  final String ownerId;
  final int initialIndex;

  @override
  ConsumerState<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends ConsumerState<PhotoViewerScreen> {
  late final PageController _pages = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _delete(Photo photo, int total) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (!await confirmDeletePhoto(context, ref, photo)) return;
    messenger.showSnackBar(const SnackBar(content: Text(S.photoDeleted)));
    if (total <= 1) {
      navigator.pop();
    } else if (_index >= total - 1) {
      setState(() => _index = total - 2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = ref.watch(photosProvider((widget.ownerType, widget.ownerId))).value;
    final dir = ref.watch(photosDirProvider).value;
    final ready = photos != null && photos.isNotEmpty && dir != null;
    final index = ready ? _index.clamp(0, photos.length - 1) : 0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: ready ? Text(S.photoCount(index + 1, photos.length)) : null,
        actions: [
          if (ready)
            IconButton(
              tooltip: S.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(photos[index], photos.length),
            ),
        ],
      ),
      body: !ready
          ? const SizedBox.shrink()
          : PageView.builder(
              controller: _pages,
              itemCount: photos.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => InteractiveViewer(
                key: ValueKey(photos[i].id),
                maxScale: 5,
                child: Center(
                  child: Image.file(
                    File(p.join(dir, photos[i].fileName)),
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64),
                  ),
                ),
              ),
            ),
    );
  }
}
