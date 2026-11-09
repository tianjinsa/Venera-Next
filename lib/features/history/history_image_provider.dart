import 'package:venera_next/network/request_scope.dart';
import 'dart:collection';
import 'package:venera_next/features/favorites/favorites_manager.dart';
import 'package:venera_next/foundation/operation_failure.dart';
import 'package:venera_next/features/history/history_api.dart';
import 'dart:async' show Future, Stream, StreamController, Completer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:venera_next/features/comic_source/comic_source_api.dart';
import 'package:venera_next/features/local_comics/local.dart';
import 'package:venera_next/network/images.dart';
import 'package:venera_next/network/image_stream.dart';
import 'package:venera_next/features/history/history_manager.dart';
import 'package:venera_next/foundation/image_provider/base_image_provider.dart';

class HistoryImageProvider extends BaseImageProvider<HistoryImageProvider> {
  /// Image provider for normal image.
  ///
  /// [url] is the url of the image. Local file path is also supported.
  HistoryImageProvider(this.history)
    : _key = "history${history.id}${history.type.value}${history.cover}";
  final String _key;

  @override
  int get maxLoadAttempts => 1;

  final History history;
  static final _refreshWaiters = Queue<Completer<void>>();
  static int _activeRefreshes = 0;
  static final _consumers = <(int, int, String), List<void Function()>>{};
  static final _coverLookups = <(int, int, String), Future<String>>{};
  static final _failedLookups =
      <(int, int, String), (DateTime, Object, StackTrace)>{};

  Future<String> _recoverCover(void Function() checkStop) async {
    final manager = HistoryManager();
    final key = (manager.connectionGeneration, history.type.value, history.id);
    final failure = _failedLookups[key];
    if (failure != null &&
        DateTime.now().difference(failure.$1) < const Duration(seconds: 30)) {
      Error.throwWithStackTrace(failure.$2, failure.$3);
    }
    _failedLookups.remove(key);
    final pending = _coverLookups[key];
    if (pending != null) {
      _consumers[key]?.add(checkStop);
      final cover = await pending;
      checkStop();
      return cover;
    }
    _consumers[key] = [checkStop];
    final id = history.id;
    final type = history.type;
    final updateMetadata = manager.metadataUpdaterFor(history);
    final future = () async {
      if (_activeRefreshes >= 2) {
        final waiter = Completer<void>();
        _refreshWaiters.add(waiter);
        await waiter.future;
      } else {
        _activeRefreshes++;
      }
      try {
        var anyActive = false;
        for (final check in _consumers[key] ?? const <void Function()>[]) {
          try {
            check();
            anyActive = true;
            break;
          } catch (_) {}
        }
        if (!anyActive) throw const RequestCancelled();
        final source =
            type.comicSource ??
            (throw OperationFailure.message('Comic source not found.'));
        final result = await source.loadComicInfo!(id);
        final cover = result.data.cover;
        if (!(_consumers[key] ?? const <void Function()>[]).any((check) {
          try {
            check();
            return true;
          } catch (_) {
            return false;
          }
        })) {
          throw const RequestCancelled();
        }
        await updateMetadata(
          cover: cover,
          title: result.data.title,
          subtitle: result.data.subTitle,
        );
        return cover;
      } finally {
        _consumers.remove(key);
        if (_refreshWaiters.isNotEmpty) {
          _refreshWaiters.removeFirst().complete();
        } else {
          _activeRefreshes--;
        }
      }
    }();
    _coverLookups[key] = future;
    try {
      final cover = await future;
      checkStop();
      return cover;
    } catch (error, stack) {
      // Cancellation of one provider does not poison a shared metadata result.
      if (!BaseImageProvider.isCancellation(error)) {
        _failedLookups[key] = (DateTime.now(), error, stack);
        while (_failedLookups.length > 256) {
          _failedLookups.remove(_failedLookups.keys.first);
        }
      }
      rethrow;
    } finally {
      if (identical(_coverLookups[key], future)) _coverLookups.remove(key);
    }
  }

  @protected
  Stream<ImageDownloadProgress> loadThumbnail(
    String url,
    String? sourceKey,
    String id,
  ) => ImageDownloader.loadThumbnail(url, sourceKey, id);

  Future<Uint8List> _readCover(
    String url,
    StreamController<ImageChunkEvent> events,
    void Function() checkStop,
  ) async {
    final bytes = await readImageStream(
      loadThumbnail(url, history.sourceKey, history.id),
      cancelSignal: BaseImageProvider.cancelSignalOf(checkStop),
      checkStop: checkStop,
      onProgress: (progress) => events.add(
        ImageChunkEvent(
          cumulativeBytesLoaded: progress.currentBytes,
          expectedTotalBytes: progress.totalBytes,
        ),
      ),
    );
    checkStop();
    return bytes ??
        (throw OperationFailure.message('Error: Empty response body.'));
  }

  @override
  Future<Uint8List> load(
    StreamController<ImageChunkEvent> chunkEvents,
    void Function() checkStop,
  ) async {
    checkStop();
    final id = history.id;
    final type = history.type;
    final original = history.cover;
    if (!original.contains('/') && LocalManager().isInitialized) {
      final comic = LocalManager().find(id, type);
      if (comic != null) {
        final bytes = await comic.coverFile.readAsBytes();
        checkStop();
        return bytes;
      }
    }
    Object? lastError;
    final tried = <String>{};
    Future<Uint8List?> tryCover(String? url, {bool save = false}) async {
      if (url == null || url.trim().isEmpty || !tried.add(url)) return null;
      checkStop();
      try {
        final bytes = await _readCover(url, chunkEvents, checkStop);
        if (save) {
          await HistoryManager().metadataUpdaterFor(history)(cover: url);
          checkStop();
          if (history.id == id && history.type == type) history.cover = url;
        }
        return bytes;
      } catch (error) {
        if (BaseImageProvider.isCleanupFailure(error) ||
            BaseImageProvider.isCancellation(error)) {
          rethrow;
        }
        checkStop();
        lastError = error;
        return null;
      }
    }

    if (original.contains('/')) {
      final bytes = await tryCover(original);
      if (bytes != null) return bytes;
    }
    final favorites = LocalFavoritesManager.cache;
    if (favorites?.isInitialized == true) {
      final folders = favorites!.find(id, type);
      if (folders.isNotEmpty) {
        final bytes = await tryCover(
          favorites.getComic(folders.first, id, type).cover,
          save: true,
        );
        if (bytes != null) return bytes;
      }
    }
    try {
      final cover = await _recoverCover(checkStop);
      final bytes = await tryCover(cover);
      if (bytes != null) return bytes;
    } catch (error) {
      if (BaseImageProvider.isCleanupFailure(error) ||
          BaseImageProvider.isCancellation(error)) {
        rethrow;
      }
      checkStop();
      lastError = error;
    }
    final bytes = await tryCover(original);
    if (bytes != null) return bytes;
    throw lastError ?? OperationFailure.message('Error: Empty response body.');
  }

  @override
  Future<HistoryImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  String get key => _key;
}
