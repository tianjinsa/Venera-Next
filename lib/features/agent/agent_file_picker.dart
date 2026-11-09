import 'package:file_selector/file_selector.dart';
import 'package:venera_next/foundation/file_interaction.dart' show IO;
import 'agent_models.dart';
import 'agent_files.dart';

Future<List<AgentTextDraft>> pickAgentTextFiles() => IO.withFileSelection(
  () async {
    final files = await openFiles(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: '文本文件',
          extensions: [
            'txt',
            'md',
            'csv',
            'tsv',
            'json',
            'jsonl',
            'ndjson',
            'xml',
            'yaml',
            'yml',
            'log',
            'ini',
            'conf',
            'toml',
            'sql',
          ],
          mimeTypes: [
            'text/*',
            'application/json',
            'application/x-ndjson',
            'application/xml',
            'application/yaml',
          ],
          uniformTypeIdentifiers: ['public.text', 'public.json', 'public.xml'],
        ),
        // Also allow extensionless and uncommon text files. The selected bytes
        // are decoded and checked below, independently of the picker filter.
        XTypeGroup(label: '所有文件'),
      ],
    );
    return [for (final file in files) await readAgentTextFile(file)];
  },
);
