import 'package:venera_next/foundation/context.dart';
import 'package:venera_next/foundation/application_preferences.dart';
import 'package:venera_next/foundation/global_preference_store.dart';
import 'package:venera_next/routing/local_reading.dart';
import 'package:venera_next/routing/app_navigation.dart';
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/features/comic_source/comic_source.dart';
import 'package:venera_next/features/comic_source/source_repositories.dart';
import 'package:venera_next/foundation/comic_type.dart';
import 'package:venera_next/features/favorites/favorites.dart';
import 'package:venera_next/features/follow_updates/follow_updates.dart';
import 'package:venera_next/features/history/history.dart';
import 'package:venera_next/foundation/log.dart';
import 'package:venera_next/features/agent/agent_reading_statistics.dart';
import 'package:venera_next/network/app_dio.dart';
import 'package:venera_next/features/search/search.dart';
import 'package:venera_next/features/discovery/discovery.dart';
import 'package:venera_next/features/comic_details/comic_details.dart';
import 'package:venera_next/features/local_comics/local_comics.dart';
import 'package:venera_next/features/reader/reader.dart';
import 'package:venera_next/foundation/file_interaction.dart';
import 'agent_session.dart';
import 'agent_source_backups.dart';

/// A download queue entry, detached from the task object for tool results.
class AgentDownloadTask {
  final String sourceKey;
  final String comicId;
  final String title;
  final double progress;
  final bool paused;
  final bool failed;
  final String message;
  const AgentDownloadTask({
    required this.sourceKey,
    required this.comicId,
    required this.title,
    required this.progress,
    required this.paused,
    required this.failed,
    required this.message,
  });
}

/// An installable source from one of the user's enabled source libraries.
class AgentCatalogSource {
  final String key;
  final String name;
  final String version;
  final String description;
  final String url;
  final String libraryId;
  final String libraryName;
  const AgentCatalogSource({
    required this.key,
    required this.name,
    required this.version,
    required this.description,
    required this.url,
    required this.libraryId,
    required this.libraryName,
  });
}

/// A catalog of comic sources configured by the user.
class AgentSourceLibrary {
  final String id;
  final String name;
  final String url;
  final bool enabled;
  const AgentSourceLibrary({
    required this.id,
    required this.name,
    required this.url,
    required this.enabled,
  });
}

/// A comic of the followed favorites folder with a new chapter.
class AgentComicUpdate {
  final FavoriteItem comic;
  final String? updateTime;
  const AgentComicUpdate(this.comic, this.updateTime);
}

/// Pages the agent may open for the user. They only display content; the
/// agent never receives page images.
enum AgentAppPage {
  history('history', '阅读历史'),
  downloads('downloads', '下载队列'),
  local('local', '本地漫画'),
  readLater('later', '稍后再看'),
  updates('updates', '追更'),
  sources('sources', '漫画源管理'),
  statistics('statistics', '阅读统计');

  final String id;
  final String label;
  const AgentAppPage(this.id, this.label);
}

/// Application services used by agent tools beyond local favorites and read
/// later. The default delegates to the app singletons; tests replace it.
class AgentAppBridge {
  const AgentAppBridge();

  bool get historyReady => HistoryManager().isInitialized;
  bool get localReady => LocalManager().isInitialized;
  Future<void> initHistory() => HistoryManager().init();
  List<History> histories() => HistoryManager().getAll();
  History? findHistory(String id, ComicType type) =>
      HistoryManager().find(id, type);
  FutureOr<void> removeHistories(List<ComicID> ids) =>
      HistoryManager().batchDeleteHistories(ids);
  FutureOr<void> addHistory(History value) =>
      HistoryManager().restoreHistory(value);
  Future<void> initLocal() => LocalManager().init();
  List<LocalComic> localComics() =>
      LocalManager().getComics(LocalSortType.timeDesc);
  LocalComic? findLocal(String id, ComicType type) =>
      LocalManager().find(id, type);
  FutureOr<void> deleteLocal(LocalComic comic) =>
      LocalManager().deleteComic(comic);
  FutureOr<void> deleteLocalChapters(LocalComic comic, List<String> chapters) =>
      LocalManager().deleteComicChapters(comic, chapters);

  List<AgentDownloadTask> downloads() => [
    for (final task in LocalManager().downloadingTasks)
      AgentDownloadTask(
        sourceKey: task.comicType.comicSource?.key ?? 'Unknown',
        comicId: task.id,
        title: task.title,
        progress: task.progress,
        paused: task.isPaused,
        failed: task.isError,
        message: task.message,
      ),
  ];
  bool isDownloading(String id, ComicType type) =>
      LocalManager().isDownloading(id, type);
  FutureOr<void> download(
    ComicSource source,
    ComicDetails details,
    List<String>? chapters,
  ) {
    LocalManager().addTask(
      ImagesDownloadTask(
        storage: LocalManager(),
        source: source,
        comicId: details.comicId,
        comic: details,
        chapters: chapters,
        comicTitle: details.title,
      ),
    );
  }

  FutureOr<bool> controlDownload(
    String id,
    ComicType type,
    String action,
  ) async {
    final manager = LocalManager();
    final matches = manager.downloadingTasks.where(
      (task) => task.id == id && task.comicType == type,
    );
    if (matches.isEmpty) return false;
    final task = matches.first;
    switch (action) {
      case 'pause':
        if (task.isPaused) return false;
        await manager.pauseDownload(task);
      case 'resume':
        if (!task.isPaused && !task.isError) return false;
        await manager.moveToFirst(task);
        manager.resumeDownload(task);
      case 'retry':
        if (!task.isError) return false;
        await manager.retryMissingPages(task);
      case 'prioritize':
        await manager.moveToFirst(task);
      case 'cancel':
        await manager.cancelDownload(task);
      default:
        return false;
    }
    return true;
  }

  String? followedFolder() => GlobalPreferenceStore(
    appdata.settings,
  ).read(FavoritePreferences.followUpdatesFolder);
  List<AgentComicUpdate> updates(String folder) => [
    for (final item in LocalFavoritesManager().getComicsWithUpdatesInfo(folder))
      if (item.hasNewUpdate) AgentComicUpdate(item, item.updateTime),
  ];
  Stream<UpdateProgress> checkUpdates(String folder) =>
      updateFolder(folder, true);
  Future<void> setFollowedFolder(String? folder) =>
      LocalFavoritesManager().setFollowUpdatesFolder(
        folder,
        generation: LocalFavoritesManager().connectionGeneration,
      );

  List<AgentSourceLibrary> sourceLibraries() => [
    for (final library in SourceRepositories.instance.all)
      AgentSourceLibrary(
        id: library.id,
        name: library.name,
        url: library.url,
        enabled: true,
      ),
  ];
  FutureOr<void> addSourceLibrary(String name, String url) async {
    final repositories = SourceRepositories.instance;
    await repositories.migrate();
    final existing = repositories.all.where(
      (r) => canonicalLibraryUrl(r.url) == canonicalLibraryUrl(url),
    );
    await repositories.save(
      id: existing.isEmpty ? null : existing.first.id,
      name: name,
      url: url,
    );
  }

  FutureOr<void> removeSourceLibrary(String id) async {
    final repositories = SourceRepositories.instance;
    final repository = repositories.find(id);
    if (repository != null) await repositories.remove(repository);
  }

  Object? setting(String key) => appdata.settings[key];
  FutureOr<void> setSetting(String key, Object? value) =>
      appdata.updateSettings((draft) => draft[key] = value);
  Future<void> saveSettings() async {}

  Future<(List<AgentCatalogSource>, List<String>)> sourceCatalog() async {
    final repositories = SourceRepositories.instance;
    await repositories.migrate();
    final sources = <AgentCatalogSource>[];
    final failures = <String>[];
    for (final library in repositories.all) {
      try {
        final catalog = await repositories.load(library);
        sources.addAll(
          catalog.entries.map(
            (entry) => AgentCatalogSource(
              key: entry.key,
              name: entry.name,
              version: entry.version,
              description: entry.description,
              url: entry.url,
              libraryId: library.id,
              libraryName: library.name,
            ),
          ),
        );
        failures.addAll(
          catalog.skipped.map((entry) => '${library.name}: $entry'),
        );
      } catch (_) {
        failures.add(library.name);
      }
    }
    return (sources, failures);
  }

  Future<ComicSource> installSource(AgentCatalogSource entry) async {
    final client = AppDio();
    try {
      final response = await client.get<String>(
        entry.url,
        options: Options(
          responseType: ResponseType.plain,
          headers: {'cache-time': 'no'},
        ),
      );
      return await ComicSourceManager().installScript(
        js: response.data ?? '',
        fileName: Uri.parse(entry.url).pathSegments.last,
        expectedKey: entry.key,
        origin: SourceOrigin(
          kind: 'repository',
          repositoryId: entry.libraryId,
          repositoryName: entry.libraryName,
          url: entry.url,
        ),
        beforeInstall: () {},
      );
    } finally {
      client.close();
    }
  }

  Future<int> checkSourceUpdates() async {
    final service = SourceUpdateService();
    try {
      return (await service.checkUpdates()).updates.length;
    } finally {
      await service.closeAndWait();
    }
  }

  Map<String, String> availableSourceUpdates() =>
      ComicSourceManager().availableUpdates;
  Future<bool> updateSource(ComicSource source) async {
    final service = SourceUpdateService();
    try {
      await service.update(source);
      return true;
    } finally {
      await service.closeAndWait();
    }
  }

  Future<void> saveSourceData(ComicSource source) => source.saveData();
  List<LogItem> logs() => List.of(Log.logs);
  Future<String> readSourceCode(ComicSource source) =>
      File(source.filePath).readAsString();
  Future<void> writeSourceCode(ComicSource source, String code) async {
    await ComicSourceManager().replaceScript(source, code, validate: () {});
  }

  AgentSourceBackups get sourceBackups =>
      AgentSourceBackups(Directory('${App.dataPath}/agent/source_backups'));
  Future<void> initStatistics() => initHistory();
  List<ReadingStatistic> readingStatistics(int days) =>
      HistoryManager().readingStatistics(days);
  int readingSeconds() => HistoryManager().getTotalReadDurationMs() ~/ 1000;

  void open(Widget Function() builder) {
    final context =
        AgentSession.pageContext ??
        appNavigation.mainNavigatorKey?.currentContext ??
        appNavigation.rootNavigatorKey.currentContext;
    if (context == null) throw StateError('No navigator');
    unawaited(context.to(builder));
  }

  void openFullScreen(Widget Function() builder) {
    final context = appNavigation.rootNavigatorKey.currentContext;
    if (context == null) throw StateError('No navigator');
    unawaited(context.to(builder));
  }

  void openComic(String sourceKey, String id, {String? title, String? cover}) =>
      open(
        () =>
            ComicPage(id: id, sourceKey: sourceKey, title: title, cover: cover),
      );
  void openReader(ComicDetails details, {int? chapter, int? page, int? group}) {
    final history =
        findHistory(details.comicId, details.comicType) ??
        History.fromModel(model: details, ep: 0, page: 0);
    openFullScreen(
      () => Reader(
        onClosed: ReaderSessionScope.onClosedOf(appNavigation.rootContext),
        type: details.comicType,
        cid: details.comicId,
        name: details.title,
        chapters: details.chapters,
        initialChapter: chapter ?? (history.ep > 0 ? history.ep : null),
        initialPage: page ?? (history.page > 0 ? history.page : null),
        initialChapterGroup: group ?? history.group,
        history: history,
        author: details.findAuthor() ?? '',
        tags: details.plainTags,
      ),
    );
  }

  void openLocalReader(LocalComic comic) => openLocalComic(comic);
  void openSearch(String keyword, {String? sourceKey, List<String>? options}) =>
      open(
        () => sourceKey == null
            ? AggregatedSearchPage(keyword: keyword)
            : SearchResultPage(
                text: keyword,
                sourceKey: sourceKey,
                options: options,
              ),
      );
  void openCategory(
    String categoryKey,
    String category, {
    String? param,
    List<String>? options,
  }) => open(
    () => CategoryComicsPage(
      category: category,
      param: param,
      categoryKey: categoryKey,
      options: options,
    ),
  );
  void openRanking(String categoryKey) =>
      open(() => RankingPage(categoryKey: categoryKey));
  void openPage(AgentAppPage page) => open(
    () => switch (page) {
      AgentAppPage.history => const HistoryPage(),
      AgentAppPage.downloads => const DownloadingPage(),
      AgentAppPage.local => const LocalComicsPage(),
      AgentAppPage.readLater => const ReadLaterPage(),
      AgentAppPage.updates => const FollowUpdatesPage(),
      AgentAppPage.sources => const ComicSourcePage(),
      AgentAppPage.statistics => const ReadingStatsPage(),
    },
  );
}

bool isHttpSourceUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      const ['http', 'https'].contains(uri.scheme) &&
      uri.host.isNotEmpty;
}

String canonicalLibraryUrl(String value) =>
    SourceRepositories.normalizeUrl(value).replaceFirst(RegExp(r'/+$'), '');
