import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/features/sources/application/source_export.dart';
import 'package:source_reader/features/sources/codec/source_json_codec.dart';
import 'package:source_reader/features/sources/codec/xbs_codec.dart';
import 'package:source_reader/features/sources/data/source_repository.dart';
import 'package:source_reader/features/sources/domain/source_document.dart';

void main() {
  group('SourceExportService', () {
    test('buildCurrent 重新按 id 读取 Repository 并输出单元素 JSON 数组', () async {
      final stored = _storedSource(
        id: 7,
        platform: 'StandarReader',
        raw: <String, Object?>{
          'sourceName': '测试书源',
          'futureTop': <String, Object?>{'keep': true},
        },
      );
      final repository = _FakeSourceRepository(
        getById: <int, StoredSource>{7: stored},
        listed: <StoredSource>[
          _storedSource(
            id: 7,
            platform: 'StandarReader',
            raw: <String, Object?>{'sourceName': '列表旧值'},
          ),
        ],
      );

      final payload = await SourceExportService(repository).buildCurrent(
        id: 7,
        format: SourceExportFormat.json,
      );

      expect(repository.getCalls, <int>[7]);
      expect(repository.listCalls, 0);
      expect(payload.fileName, '测试书源.json');
      expect(payload.mimeType, 'application/json');
      expect(payload.exportedCount, 1);

      final raw = jsonDecode(utf8.decode(payload.bytes));
      expect(raw, isA<List<Object?>>());
      expect(raw, hasLength(1));

      final decoded = decodeSourceJson(utf8.decode(payload.bytes));
      expect(decoded.single.sourceName, '测试书源');
      expect(
        decoded.single.toRaw()['futureTop'],
        <String, Object?>{'keep': true},
      );
    });

    test('buildCurrent 对不存在记录返回 notFound', () async {
      final service = SourceExportService(_FakeSourceRepository());

      await expectLater(
        service.buildCurrent(id: 404, format: SourceExportFormat.json),
        throwsA(
          isA<SourceExportException>().having(
            (error) => error.reason,
            'reason',
            SourceExportFailureReason.notFound,
          ),
        ),
      );
    });

    test('buildCurrent 拒绝非 StandarReader 平台', () async {
      final repository = _FakeSourceRepository(
        getById: <int, StoredSource>{
          1: _storedSource(
            id: 1,
            platform: 'OtherReader',
            raw: <String, Object?>{'sourceName': '其他平台'},
          ),
        },
      );
      final service = SourceExportService(repository);

      await expectLater(
        service.buildCurrent(id: 1, format: SourceExportFormat.json),
        throwsA(
          isA<SourceExportException>().having(
            (error) => error.reason,
            'reason',
            SourceExportFailureReason.unsupportedPlatform,
          ),
        ),
      );
    });

    test('buildAll 只导出 StandarReader 并保留顺序与未知字段', () async {
      final repository = _FakeSourceRepository(
        listed: <StoredSource>[
          _storedSource(
            id: 1,
            platform: 'StandarReader',
            raw: <String, Object?>{
              'sourceName': 'A',
              'futureA': <String, Object?>{'keep': 1},
            },
          ),
          _storedSource(
            id: 2,
            platform: 'OtherReader',
            raw: <String, Object?>{'sourceName': 'B'},
          ),
          _storedSource(
            id: 3,
            platform: 'StandarReader',
            raw: <String, Object?>{
              'sourceName': 'C',
              'futureC': <Object?>['keep'],
            },
          ),
        ],
      );

      final payload = await SourceExportService(repository).buildAll(
        format: SourceExportFormat.json,
      );
      final decoded = decodeSourceJson(utf8.decode(payload.bytes));

      expect(repository.listCalls, 1);
      expect(repository.getCalls, isEmpty);
      expect(payload.fileName, 'source-reader-export.json');
      expect(payload.mimeType, 'application/json');
      expect(payload.exportedCount, 2);
      expect(
        decoded.map((item) => item.sourceName).toList(),
        <String?>['A', 'C'],
      );
      expect(decoded.first.toRaw()['futureA'], <String, Object?>{'keep': 1});
      expect(decoded.last.toRaw()['futureC'], <Object?>['keep']);
    });

    test('buildAll 过滤后为空返回 empty', () async {
      final repository = _FakeSourceRepository(
        listed: <StoredSource>[
          _storedSource(
            id: 2,
            platform: 'OtherReader',
            raw: <String, Object?>{'sourceName': 'B'},
          ),
        ],
      );
      final service = SourceExportService(repository);

      await expectLater(
        service.buildAll(format: SourceExportFormat.json),
        throwsA(
          isA<SourceExportException>().having(
            (error) => error.reason,
            'reason',
            SourceExportFailureReason.empty,
          ),
        ),
      );
    });

    test('XBS 导出可解密并回到同一份 StandarReader JSON', () async {
      final repository = _FakeSourceRepository(
        listed: <StoredSource>[
          _storedSource(
            id: 1,
            platform: 'StandarReader',
            raw: <String, Object?>{'sourceName': 'A'},
          ),
          _storedSource(
            id: 2,
            platform: 'StandarReader',
            raw: <String, Object?>{'sourceName': 'C'},
          ),
        ],
      );

      final payload = await SourceExportService(repository).buildAll(
        format: SourceExportFormat.xbs,
      );
      final decoded = decodeSourceJson(utf8.decode(decodeXbs(payload.bytes)));

      expect(payload.fileName, 'source-reader-export.xbs');
      expect(payload.mimeType, 'application/octet-stream');
      expect(payload.exportedCount, 2);
      expect(
        decoded.map((item) => item.sourceName).toList(),
        <String?>['A', 'C'],
      );
    });

    test('当前 XBS 文件名使用已保存 sourceName', () async {
      final repository = _FakeSourceRepository(
        getById: <int, StoredSource>{
          9: _storedSource(
            id: 9,
            platform: 'StandarReader',
            raw: <String, Object?>{'sourceName': '当前书源'},
          ),
        },
      );

      final payload = await SourceExportService(repository).buildCurrent(
        id: 9,
        format: SourceExportFormat.xbs,
      );

      expect(payload.fileName, '当前书源.xbs');
    });

    test('编码失败映射为 encodingFailed 并保留 cause', () async {
      final repository = _FakeSourceRepository(
        getById: <int, StoredSource>{
          1: _storedSource(
            id: 1,
            platform: 'StandarReader',
            raw: <String, Object?>{
              'sourceName': '无法编码',
              'futureValue': DateTime.utc(2026, 9, 3),
            },
          ),
        },
      );
      final service = SourceExportService(repository);

      await expectLater(
        service.buildCurrent(id: 1, format: SourceExportFormat.json),
        throwsA(
          isA<SourceExportException>()
              .having(
                (error) => error.reason,
                'reason',
                SourceExportFailureReason.encodingFailed,
              )
              .having((error) => error.cause, 'cause', isNotNull),
        ),
      );
    });

    test('Repository 读取异常原样向上传播', () async {
      final error = StateError('read failed');
      final repository = _FakeSourceRepository(getError: error);
      final service = SourceExportService(repository);

      await expectLater(
        service.buildCurrent(id: 1, format: SourceExportFormat.json),
        throwsA(same(error)),
      );
    });
  });

  group('sanitizeSourceFileBaseName', () {
    test('替换非法字符并清理尾部空格与点', () {
      expect(
        sanitizeSourceFileBaseName('A/B:C*D?E"F<G>H|I'),
        'A_B_C_D_E_F_G_H_I',
      );
      expect(sanitizeSourceFileBaseName('name...   '), 'name');
      expect(sanitizeSourceFileBaseName('\u0001\u0002'), '__');
    });

    test('清理后为空时回退 source', () {
      expect(sanitizeSourceFileBaseName('...   '), 'source');
    });
  });
}

StoredSource _storedSource({
  required int id,
  required String platform,
  required Map<String, Object?> raw,
}) {
  final createdAt = DateTime.utc(2026, 9, 3);
  return StoredSource(
    id: id,
    platform: platform,
    document: SourceDocument.fromRaw(raw),
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

final class _FakeSourceRepository implements SourceRepository {
  _FakeSourceRepository({
    Map<int, StoredSource>? getById,
    List<StoredSource>? listed,
    this.getError,
    this.listError,
  })  : getById = getById ?? <int, StoredSource>{},
        listed = listed ?? <StoredSource>[];

  final Map<int, StoredSource> getById;
  final List<StoredSource> listed;
  final Object? getError;
  final Object? listError;
  final List<int> getCalls = <int>[];
  int listCalls = 0;

  @override
  Future<StoredSource?> getSource(int id) async {
    getCalls.add(id);
    final error = getError;
    if (error != null) {
      throw error;
    }
    return getById[id];
  }

  @override
  Future<List<StoredSource>> listSources() async {
    listCalls += 1;
    final error = listError;
    if (error != null) {
      throw error;
    }
    return List<StoredSource>.of(listed);
  }

  @override
  Future<int> insertSource({
    required String platform,
    required SourceDocument document,
  }) => throw UnimplementedError();

  @override
  Future<List<int>> insertSources({
    required String platform,
    required List<SourceDocument> documents,
  }) => throw UnimplementedError();

  @override
  Future<void> updateSource(int id, SourceDocument document) =>
      throw UnimplementedError();

  @override
  Future<void> deleteSource(int id) => throw UnimplementedError();
}
