import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/features/reader/comic_image.dart';

class _Stream extends ImageStreamCompleter {
  void chunk(ImageChunkEvent event) => reportImageChunkEvent(event);
  void frame(ui.Image image) => setImage(ImageInfo(image: image));
}

class _Image extends ImageProvider<_Image> {
  final stream = _Stream();
  @override
  Future<_Image> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);
  @override
  void resolveStreamForKey(
    configuration,
    ImageStream target,
    key,
    handleError,
  ) => target.setCompleter(stream);
  void chunk(int count) => stream.chunk(
    ImageChunkEvent(cumulativeBytesLoaded: count, expectedTotalBytes: 1000),
  );
}

double? _progress(WidgetTester tester) => tester
    .widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator))
    .value;

void main() {
  tearDown(ComicImage.clear);

  testWidgets('changing source cancels queued progress from the old image', (
    tester,
  ) async {
    final old = _Image();
    final current = _Image();
    Widget host(_Image image) => MaterialApp(home: ComicImage(image: image));
    await tester.pumpWidget(host(old));
    old.chunk(200);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pumpWidget(host(current));
    await tester.pump(const Duration(milliseconds: 60));
    expect(_progress(tester), 0);
    current.chunk(700);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_progress(tester), 0.7);
    current.chunk(900);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed stream cannot be revived by queued progress', (
    tester,
  ) async {
    final image = _Image();
    await tester.pumpWidget(MaterialApp(home: ComicImage(image: image)));
    image.chunk(300);
    image.stream.reportError(exception: StateError('download failed'));
    await tester.pump();
    expect(find.text('Retry'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Retry'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'download chunks merge while scrolling and publish the latest progress',
    (tester) async {
      final image = _Image();
      await tester.pumpWidget(MaterialApp(home: ComicImage(image: image)));
      image.chunk(100);
      await tester.pump();
      final before = _progress(tester);
      for (var i = 101; i <= 900; i++) {
        image.chunk(i);
      }
      await tester.pump(const Duration(milliseconds: 40));
      expect(_progress(tester), before);
      await tester.pump(const Duration(milliseconds: 60));
      expect(_progress(tester), 0.9);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a completed frame cancels queued progress and never returns to loading',
    (tester) async {
      final image = _Image();
      await tester.pumpWidget(MaterialApp(home: ComicImage(image: image)));
      image.chunk(200);
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawColor(Colors.white, ui.BlendMode.src);
      final picture = recorder.endRecording();
      image.stream.frame(picture.toImageSync(20, 30));
      picture.dispose();
      await tester.pump();
      expect(find.byType(RawImage), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
      ComicImage.clear();
    },
  );
}
