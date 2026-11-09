import 'dart:async';
import 'package:venera_next/foundation/image_provider/base_image_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/components/image.dart';

class _UnavailableCover extends BaseImageProvider<_UnavailableCover> {
  int requests = 0;

  @override
  Future<_UnavailableCover> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  String get key => 'unavailable-cover';

  @override
  Future<Uint8List> load(
    StreamController<ImageChunkEvent> events,
    void Function() checkStop,
  ) async {
    requests++;
    throw StateError('Invalid Status Code: 404');
  }
}

void main() {
  testWidgets(
    'failed covers survive tab and keyboard changes until a real image configuration changes',
    (tester) async {
      final cover = _UnavailableCover();
      Widget view({
        bool enabled = true,
        double ratio = 1,
        double keyboard = 0,
      }) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            devicePixelRatio: ratio,
            viewInsets: EdgeInsets.only(bottom: keyboard),
          ),
          child: TickerMode(
            enabled: enabled,
            child: Center(
              child: AnimatedImage(image: cover, width: 100, height: 100),
            ),
          ),
        ),
      );
      await tester.pumpWidget(view());
      await tester.pumpAndSettle();
      expect(cover.requests, 1);
      await tester.pumpWidget(view(enabled: false));
      await tester.pumpAndSettle();
      await tester.pumpWidget(view(keyboard: 300));
      await tester.pumpAndSettle();
      expect(cover.requests, 1);
      await tester.pumpWidget(view(ratio: 2));
      await tester.pumpAndSettle();
      expect(cover.requests, 2);
      tester.binding.buildOwner!.reassemble(tester.binding.rootElement!);
      await tester.pumpAndSettle();
      expect(cover.requests, 3);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
