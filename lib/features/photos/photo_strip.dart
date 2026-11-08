import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/db/database.dart';
import '../../core/strings.dart';
import '../../shared/widgets/section_header.dart';
import 'photo_actions.dart';
import 'photo_viewer_screen.dart';

/// Detay ekranlarindaki "Fotograflar" bolumu: yatay kucuk resim seridi ve ekleme butonu.
/// Listede sadece kucuk resimler yuklenir; tam boyut dokununca acilan goruntuleyicide (PLAN 10).
class PhotoStrip extends ConsumerWidget {
  const PhotoStrip({super.key, required this.ownerType, required this.ownerId});

  final PhotoOwnerType ownerType;
  final String ownerId;

  static const _size = 96.0;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final camera = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text(S.takePhoto),
              onTap: () => Navigator.pop(context, true),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text(S.pickFromGallery),
              onTap: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
    if (camera == null || !context.mounted) return;
    await addPhotos(context, ref, ownerType: ownerType, ownerId: ownerId, camera: camera);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = ref.watch(photosProvider((ownerType, ownerId))).value ?? const <Photo>[];
    final dir = ref.watch(photosDirProvider).value;
    final theme = Theme.of(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: S.photos,
          action: TextButton.icon(
            onPressed: () => _add(context, ref),
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text(S.addPhoto),
          ),
        ),
        if (photos.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(S.noPhotos, style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)),
          )
        else if (dir != null)
          SizedBox(
            height: _size,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => InkWell(
                key: ValueKey(photos[i].id),
                borderRadius: BorderRadius.circular(8),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => PhotoViewerScreen(ownerType: ownerType, ownerId: ownerId, initialIndex: i),
                )),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(p.join(dir, photos[i].thumbFileName)),
                    width: _size,
                    height: _size,
                    fit: BoxFit.cover,
                    cacheWidth: (_size * dpr).round(),
                    errorBuilder: (_, _, _) => Container(
                      width: _size,
                      height: _size,
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
