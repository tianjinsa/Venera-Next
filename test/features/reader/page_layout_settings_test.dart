import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/features/reader/reader_page.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/comic_type.dart';

class _Layout with ReaderImagePerPageHandler {
  @override
  bool isPortrait = true;
  @override
  int page = 1;
  @override
  ReaderMode mode = ReaderMode.galleryLeftToRight;
  @override
  String cid = 'layout';
  @override
  ComicType type = ComicType.local;
  @override
  List<String>? images = List.generate(12, (i) => '$i');
  @override
  void resetPageAnimation() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('hot layout fields retain normalization and live scope precedence', () {
    final before = Map<String, dynamic>.from(
      jsonDecode(jsonEncode(appdata.toJson()['settings'])) as Map,
    );
    addTearDown(
      () => before.forEach((key, value) => appdata.settings[key] = value),
    );
    final settings = appdata.settings;
    final layout = _Layout();
    settings['deviceId'] = 'layout-device';
    final device = <String, dynamic>{'enabled': true};
    final comic = <String, dynamic>{'enabled': true};
    settings['deviceSpecificSettings'] = {'layout-device': device};
    settings['comicSpecificSettings'] = {'layout@local': comic};
    for (final scope in <dynamic>[settings, device, comic]) {
      for (final value in [null, 'broken', -1, 0, 1, 2, 3, 99]) {
        scope['readerScreenPicNumberForPortrait'] = value;
        scope['readerScreenPicNumberForLandscape'] = value;
        scope['showSingleImageOnFirstPage'] = value == 2;
        // Mutate the same scope map in place, without a settings notification.
        final snapshot = settings.readerSettings('layout', 'local');
        layout.isPortrait = true;
        expect(layout.imagesPerPage, snapshot.readerScreenPicNumberForPortrait);
        layout.isPortrait = false;
        expect(
          layout.imagesPerPage,
          snapshot.readerScreenPicNumberForLandscape,
        );
        expect(
          layout.showSingleImageOnFirstPage(),
          snapshot.showSingleImageOnFirstPage,
        );
      }
    }
    comic['enabled'] = false;
    device['enabled'] = false;
    settings['readerScreenPicNumberForLandscape'] = 3;
    expect(layout.imagesPerPage, 3);
    layout.mode = ReaderMode.continuousTopToBottom;
    expect(layout.imagesPerPage, 1);
  });
}
