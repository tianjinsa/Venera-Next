"""Export an exact Git tree and add observers in the disposable copy only.

The reference repositories remain untouched. The manifest and observer patch
make each APK's source, fixture and measurement overhead reviewable.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import shutil
import subprocess
import tarfile

HERE = Path(__file__).resolve().parent


def replace(path, old, new, count=1):
    text = path.read_text(encoding="utf-8")
    actual = text.count(old)
    if actual != count:
        raise ValueError(f"{path}: expected {count} anchors, found {actual}: {old!r}")
    path.write_text(text.replace(old, new), encoding="utf-8")


def instrument(out, variant):
    package = "venera_next" if variant == "next" else "venera"
    native_package = "com.github.cyrilpeng.veneranext" if variant == "next" else "com.github.wgh136.venera"
    native_dir = out / "android/app/src/main/kotlin" / native_package.replace(".", "/")
    native = native_dir / "MainActivity.kt"
    (native_dir / "NativeReaderProbe.kt").write_text(
        (HERE / "NativeReaderProbe.kt").read_text(encoding="utf-8").replace("BENCHMARK_PACKAGE", native_package), encoding="utf-8")
    replace(native, 'class MainActivity : FlutterFragmentActivity() {',
            'class MainActivity : FlutterFragmentActivity() {\n    private var readerProbe: NativeReaderProbe? = null')
    replace(native, 'GeneratedPluginRegistrant.registerWith(flutterEngine)',
            'GeneratedPluginRegistrant.registerWith(flutterEngine)\n        readerProbe = NativeReaderProbe(this, flutterEngine.dartExecutor.binaryMessenger)')
    replace(native, 'override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {',
            'override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {\n        readerProbe?.key(keyCode, event)')
    replace(native, 'override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {',
            'override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {\n        readerProbe?.close()\n        readerProbe = null')
    replace(native, 'override fun onDestroy() {',
            'override fun onDestroy() {\n        readerProbe?.close()\n        readerProbe = null')
    gradle = out / 'android/app/build.gradle'
    # This entire project is a disposable benchmark export, never a release app.
    appid = 'com.github.cyrilpeng.veneranext.readerbenchmark' if variant == 'next' else 'com.github.wgh136.venera.prime.readerbenchmark'
    old = 'applicationId = "com.github.cyrilpeng.veneranext"' if variant == 'next' else 'applicationId = integrationTestBuild ? "com.github.wgh136.venera.prime.integrationtest" : "com.github.wgh136.venera.prime"'
    replace(gradle, old, f'applicationId = "{appid}"')
    if variant == 'next':
        # Flutter adds a default ARM64 NDK filter; AGP accepts this alongside
        # splits only when a universal output is enabled. Packaging only.
        replace(gradle, 'universalApk(buildAbis.size() > 1)', 'universalApk true')
    # Use the existing dedicated benchmark key, never an installed user's key.
    if variant == 'prime':
        replace(gradle, 'rootProject.file("key.properties")', 'file(System.getenv("ANDROID_KEY_PROPERTIES_FILE"))')
    shutil.copyfile(HERE / 'probe.dart', out / 'lib/foundation/reader_perf_probe.dart')
    main = (HERE / 'main_next.dart').read_text(encoding='utf-8')
    main = main.replace("import 'probe.dart';", f"import 'package:{package}/foundation/reader_perf_probe.dart';")
    if variant == 'prime':
        imports = {
            'features/comic_source/models.dart': 'foundation/comic_source/models.dart',
            'features/history/history.dart': 'foundation/history.dart',
            'features/local_comics/local_comics.dart': 'foundation/local.dart',
            'features/reader/reader_page.dart': 'pages/reader/reader.dart',
            'foundation/translations.dart': 'utils/translations.dart',
        }
        for old_import, new_import in imports.items():
            main = main.replace(old_import, new_import)
        for line in [
            "import 'package:venera_next/components/message.dart';\n",
            "import 'package:venera_next/features/favorites/favorites_scope.dart';\n",
            "import 'package:venera_next/features/history/history_scope.dart';\n",
            "import 'package:venera_next/features/reader/platform_effects.dart';\n",
            "import 'package:venera_next/routing/app_navigation.dart';\n",
        ]:
            main = main.replace(line, '')
        main = main.replace('features/favorites/favorites_manager.dart', 'foundation/favorites.dart')
        main = main.replace('LocalManager(initializeSources: () async {})', 'LocalManager()')
        main = main.replace('LocalFavoritesManager.independent()', 'LocalFavoritesManager()')
        main = main.replace('HistoryManager.create()', 'HistoryManager()')
        main = main.replace('  final imageFavorites = ImageFavoriteManager.create(history: historyStore);\n', '')
        main = main.replace('GlobalKey<ReaderState>()', 'GlobalKey()')
        begin = main.index('  runApp(')
        end = main.index('  await Future<void>.delayed', begin)
        main = main[:begin] + '''  runApp(MaterialApp(
    navigatorKey: App.rootNavigatorKey,
    builder: (context, child) => WindowFrame(child!),
    home: Reader(key: key, type: ComicType.local, cid: comic.id, name: comic.title, chapters: chapters, history: history, initialPage: 160, author: comic.subtitle, tags: const []),
  ));
''' + main[end:]
        main = main.replace("key.currentState?.page", "(key.currentState as dynamic)?.page")
        main = main.replace("key.currentState?.controller.state.pendingPage", "(key.currentState as dynamic)?.benchmarkPendingPage")
        main = main.replace("key.currentState?.maxPage", "(key.currentState as dynamic)?.maxPage")
        main = main.replace("key.currentState!.toPage(args['page'] as int, animated: false)", "(key.currentState as dynamic).toPage(args['page'] as int, animate: false)")
        main = main.replace('package:venera_next/', 'package:venera/')
    (out / 'lib/reader_benchmark.dart').write_text(main, encoding='utf-8')

    def add_import(path):
        old = "import 'dart:async';"
        replace(path, old, old + f"\nimport 'package:{package}/foundation/reader_perf_probe.dart';")

    if variant == 'next':
        controller = out / 'lib/features/reader/reader_controller.dart'
        add_import(controller)
        for signature, event in [
            ('void resetAnimation() {', "'reset', [_page, _pendingPage, _generation]"),
            ('bool toPage(int page, {bool animated = true}) {', "'request', [_page, page, _pendingPage, _generation]"),
            ('void reportPage(int page) {', "'report', [_page, page, _pendingPage]"),
            ('void setPage(int page) {', "'setPage', [_page, page, _pendingPage]"),
        ]:
            replace(controller, signature, signature + f'\n    ReaderPerfProbe.event({event});')
        replace(controller, 'onChanged();', "ReaderPerfProbe.event('notify', [_page, _pendingPage]);\n      onChanged();", count=4)
        replace(controller, 'void finish() {', "void finish() {\n        ReaderPerfProbe.event('animationEnd', [generation, _generation, _page, _pendingPage]);")
        page = out / 'lib/features/reader/reader_page.dart'
        add_import(page)
        for signature, label in [('void update() {', 'update'), ('void updateHistory() {', 'history'), ('Widget build(BuildContext context) {', 'readerBuild')]:
            replace(page, signature, signature + f"\n    ReaderPerfProbe.event('{label}', [page]);")
        volume = out / 'lib/features/reader/volume.dart'
        add_import(volume)
        replace(volume, 'final arguments = call.arguments;', "final arguments = call.arguments;\n      ReaderPerfProbe.event('volume', [arguments is Map ? arguments['value'] : null]);")
        gallery = out / 'lib/features/reader/gallery_view.dart'
        add_import(gallery)
        hooks = [
            ('final value = controller.page;', "final value = controller.page;\n    ReaderPerfProbe.event('position', [value]);"),
            ('void cache(int startPage) {', "void cache(int startPage) {\n    ReaderPerfProbe.event('cache', [page, startPage]);"),
            ('if (_lastPrecache == identity) return;', "if (_lastPrecache == identity) return;\n    ReaderPerfProbe.event('cacheReplace', [page, startPage]);"),
            ('Future<void> animateToPage(int page) {', "Future<void> animateToPage(int page) {\n    ReaderPerfProbe.event('animate', [page, controller.hasClients ? controller.page : null]);"),
            ('void toPage(int page) {', "void toPage(int page) {\n    ReaderPerfProbe.event('jump', [page, controller.hasClients ? controller.page : null]);"),
            ('onPageChanged: (i) {', "onPageChanged: (i) {\n              ReaderPerfProbe.event('selected', [i]);"),
            ('Widget build(BuildContext context) {', "Widget build(BuildContext context) {\n    ReaderPerfProbe.event('galleryBuild');"),
        ]
        for old, new in hooks:
            replace(gallery, old, new)
    else:
        reader = out / 'lib/pages/reader/reader.dart'
        add_import(reader)
        hooks = [
            ('int get page => _page;', 'int get page => _page;\n  int? get benchmarkPendingPage => _pendingPage;'),
            ('set page(int value) {', "set page(int value) {\n    ReaderPerfProbe.event('setPage', [_page, value, _pendingPage]);"),
            ('void setPage(int page) {', "void setPage(int page) {\n    ReaderPerfProbe.event('report', [_page, page, _pendingPage]);"),
            ('bool toPage(int page, {bool animate = true}) {', "bool toPage(int page, {bool animate = true}) {\n    ReaderPerfProbe.event('request', [_page, page, _pendingPage, _navigationId]);"),
            ('void finishAnimation() {', "void finishAnimation() {\n          ReaderPerfProbe.event('animationEnd', [navigationId, _navigationId, _page, _pendingPage]);"),
            ('void update() {', "void update() {\n    ReaderPerfProbe.event('update', [page]);"),
            ('void updateHistory() {', "void updateHistory() {\n    ReaderPerfProbe.event('history', [page]);"),
        ]
        for old, new in hooks:
            replace(reader, old, new)
        volume = out / 'lib/utils/volume.dart'
        add_import(volume)
        replace(volume, 'void onEvent(event) {', "void onEvent(event) {\n    ReaderPerfProbe.event('volume', [event]);")
        images = out / 'lib/pages/reader/images.dart'
        hooks = [
            ('void cache(int startPage) {', "void cache(int startPage) {\n    ReaderPerfProbe.event('cache', [reader.page, startPage]);"),
            ('Future<void> animateToPage(int page) {', "Future<void> animateToPage(int page) {\n    ReaderPerfProbe.event('animate', [page]);"),
            ('void toPage(int page) {', "void toPage(int page) {\n    ReaderPerfProbe.event('jump', [page]);"),
            ('onPageChanged: (i) {', "onPageChanged: (i) {\n              ReaderPerfProbe.event('selected', [i]);"),
        ]
        for old, new in hooks:
            replace(images, old, new, count=2 if old in ('Future<void> animateToPage(int page) {', 'void toPage(int page) {') else 1)
    return appid


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', required=True, type=Path)
    parser.add_argument('--ref', required=True)
    parser.add_argument('--variant', required=True, choices=['next', 'prime'])
    parser.add_argument('--out', required=True, type=Path)
    args = parser.parse_args()
    if args.out.exists():
        parser.error('Output must not exist; existing sources/builds are never overwritten')
    sha = subprocess.check_output(['git', '-C', str(args.repo), 'rev-parse', args.ref], text=True).strip()
    archive = subprocess.check_output(['git', '-C', str(args.repo), 'archive', '--format=tar', sha])
    args.out.mkdir(parents=True)
    with tarfile.open(fileobj=io.BytesIO(archive)) as tree:
        tree.extractall(args.out, filter='data')
    appid = instrument(args.out, args.variant)
    manifest = {
        'sourceSha': sha, 'variant': args.variant, 'applicationId': appid,
        'fixturePages': 512, 'fixtureWidth': 2048, 'fixtureHeight': 3072,
        'observers': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in [HERE / 'prepare.py', HERE / 'main_next.dart', HERE / 'probe.dart', HERE / 'NativeReaderProbe.kt']},
    }
    (args.out / 'reader-benchmark-source.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    print(json.dumps(manifest, indent=2))


if __name__ == '__main__':
    main()
