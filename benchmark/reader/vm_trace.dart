// Standalone Dart VM Service protocol client. No additional dependencies.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.length != 3) {
    stderr.writeln(
      'dart vm_trace.dart <ws-service-url> <output-directory> <seconds>',
    );
    exitCode = 2;
    return;
  }
  final socket = await WebSocket.connect(args[0]);
  final pending = <String, Completer<Map<String, dynamic>>>{};
  var id = 0;
  final subscription = socket.listen((message) {
    final data = jsonDecode(message as String) as Map<String, dynamic>;
    final request = pending.remove(data['id']);
    if (request == null) return;
    if (data.containsKey('error')) {
      request.completeError(StateError('${data['error']}'));
    } else {
      request.complete(data['result'] as Map<String, dynamic>);
    }
  });
  Future<Map<String, dynamic>> rpc(
    String method, [
    Map<String, Object?> params = const {},
  ]) {
    final key = '${++id}';
    final result = pending[key] = Completer<Map<String, dynamic>>();
    socket.add(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': key,
        'method': method,
        'params': params,
      }),
    );
    return result.future.timeout(const Duration(seconds: 30));
  }

  final directory = await Directory(args[1]).create(recursive: true);
  Future<void> save(String name, Object value) =>
      File('${directory.path}/$name.json').writeAsString(jsonEncode(value));
  try {
    final vm = await rpc('getVM');
    await save('vm', vm);
    await save('flags', await rpc('getFlagList'));
    final isolate = (vm['isolates'] as List).firstWhere(
      (entry) => entry['name'] == 'main',
    );
    final isolateId = isolate['id'] as String;
    await rpc('setVMTimelineFlags', {
      'recordedStreams': ['Dart', 'Embedder', 'GC'],
    });
    await rpc('clearVMTimeline');
    await rpc('clearCpuSamples', {'isolateId': isolateId});
    final start = await rpc('getVMTimelineMicros');
    await save(
      'allocation-before',
      await rpc('getAllocationProfile', {'isolateId': isolateId}),
    );
    stdout.writeln('VM CAPTURE READY');
    await Future<void>.delayed(Duration(seconds: int.parse(args[2])));
    final finish = await rpc('getVMTimelineMicros');
    final origin = start['timestamp'] as int;
    final extent = (finish['timestamp'] as int) - origin;
    await save(
      'timeline',
      await rpc('getVMTimeline', {
        'timeOriginMicros': origin,
        'timeExtentMicros': extent,
      }),
    );
    await save(
      'cpu',
      await rpc('getCpuSamples', {
        'isolateId': isolateId,
        'timeOriginMicros': origin,
        'timeExtentMicros': extent,
      }),
    );
    await save(
      'allocation-after',
      await rpc('getAllocationProfile', {'isolateId': isolateId}),
    );
    stdout.writeln('VM CAPTURE SAVED');
  } finally {
    await socket.close();
    await subscription.cancel();
  }
}
