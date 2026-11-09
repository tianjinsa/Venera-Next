import 'package:flutter/foundation.dart';
import 'package:venera_next/features/comic_source/comic_source_api.dart';
import 'package:venera_next/features/favorites/favorites_manager.dart';
import 'package:venera_next/features/favorites/favorites_api.dart';
import 'package:venera_next/foundation/batched_notifications.dart';
import 'package:venera_next/foundation/comic_type.dart';

/// Compatibility for saved Agent tool calls, backed by Next's read-later folder.
/// There is no separate Prime database or second copy of the user's library.
class ReadLaterManager extends ChangeNotifier with BatchedNotifications {
  ReadLaterManager({LocalFavoritesManager? manager})
    : _manager = manager ?? LocalFavoritesManager();

  final LocalFavoritesManager _manager;
  bool _ready = false;
  bool get isInitialized => _ready && _manager.isInitialized;

  Future<void> init() async {
    await _manager.init();
    if (!_ready) {
      _ready = true;
      _manager.addListener(notifyListeners);
    }
  }

  void close() {
    if (_ready) _manager.removeListener(notifyListeners);
    _ready = false;
  }

  bool contains(String id, ComicType type) => _manager.isInReadLater(id, type);
  List<FavoriteItem> getAll({String? keyword}) {
    final comics = _manager.getReadLaterComics();
    if (keyword == null || keyword.trim().isEmpty) return comics;
    final query = keyword.toLowerCase();
    return comics
        .where(
          (comic) => '${comic.title}\n${comic.subtitle}\n${comic.id}'
              .toLowerCase()
              .contains(query),
        )
        .toList();
  }

  FavoriteItem? getComic(String id, ComicType type) {
    final folder = _manager.readLaterFolder;
    return folder != null && _manager.comicExists(folder, id, type)
        ? _manager.getComic(folder, id, type)
        : null;
  }

  Future<bool> add(Comic comic) async {
    await init();
    final item = FavoriteItem(
      id: comic.id,
      name: comic.title,
      coverPath: comic.cover,
      author: comic.subtitle ?? '',
      type: comic.sourceKey.startsWith('Unknown:')
          ? ComicType(int.parse(comic.sourceKey.substring(8)))
          : ComicType.fromKey(comic.sourceKey),
      tags: comic.tags ?? [],
    );
    if (contains(item.id, item.type)) return false;
    await _manager.setReadLater(item, included: true, folderName: '稍后再看');
    return true;
  }

  Future<bool> remove(String id, ComicType type) async {
    final item = getComic(id, type);
    if (item == null) return false;
    await _manager.setReadLater(item, included: false, folderName: '稍后再看');
    return true;
  }
}
