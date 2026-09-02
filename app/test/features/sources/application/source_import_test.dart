import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/features/sources/application/source_import.dart';
import 'package:source_reader/features/sources/codec/xbs_codec.dart';
import 'package:source_reader/features/sources/data/source_repository.dart';
import 'package:source_reader/features/sources/domain/source_document.dart';

void main() {
  group('SourceImportService', () {
    test('JSON 单对象导入为一个 StandarReader 书源', () async {
      final repository = FakeSourceRepository();
      final service = SourceImportService(repository);

      final result = await service.importPayload(
        SourceImportPayload(
          name: 'single.json',
          bytes: _utf8Bytes(
            '{"sourceName":"单个书源","enable":"1","futureField":{"x":1}}',
          ),
        ),
      );

      expect(result.importedCount, 1);
      expect(repository.insertCalls, 1);
      expect(repository.capturedPlatform, 'StandarReader');
      expect(repository.capturedDocuments, hasLength(1));
      expect(repository.capturedDocuments.single.sourceName, '单个书源');
      expect(
        repository.capturedDocuments.single.toRaw()['futureField'],
        <String, Object?>{'x': 1},
      );
    });

    test('JSON 数组按原顺序批量导入', () async {
      final repository = FakeSourceRepository();
      final service = SourceImportService(repository);

      final result = await service.importPayload(
        SourceImportPayload(
          name: 'sources.json',
          bytes: _utf8Bytes(
            '[{"sourceName":"A"},{"sourceName":"B"}]',
          ),
        ),
      );

      expect(result.importedCount, 2);
      expect(
        repository.capturedDocuments.map((document) => document.sourceName),
        <String?>['A', 'B'],
      );
    });

    test('JSON UTF-8 BOM 可正常导入', () async {
      final repository = FakeSourceRepository();
      final service = SourceImportService(repository);

      final result = await service.importPayload(
        SourceImportPayload(
          name: 'bom.json',
          bytes: _utf8Bytes('\ufeff{"sourceName":"BOM 书源"}'),
        ),
      );

      expect(result.importedCount, 1);
      expect(repository.capturedDocuments.single.sourceName, 'BOM 书源');
    });

    test('XBS 先解密再按 UTF-8 JSON 导入', () async {
      final repository = FakeSourceRepository();
      final service = SourceImportService(repository);
      final encrypted = encodeXbs(
        _utf8Bytes('[{"sourceName":"XBS 甲"},{"sourceName":"XBS 乙"}]'),
      );

      final result = await service.importPayload(
        SourceImportPayload(name: 'sources.xbs', bytes: encrypted),
      );

      expect(result.importedCount, 2);
      expect(
        repository.capturedDocuments.map((document) => document.sourceName),
        <String?>['XBS 甲', 'XBS 乙'],
      );
    });

    test('文件扩展名大小写不敏感', () async {
      final repository = FakeSourceRepository();
      final service = SourceImportService(repository);

      final result = await service.importPayload(
        SourceImportPayload(
          name: 'SOURCE.JSON',
          bytes: _utf8Bytes('{"sourceName":"大写扩展名"}'),
        ),
      );

      expect(result.importedCount, 1);
      expect(repository.capturedDocuments.single.sourceName, '大写扩展名');
    });

    test('拒绝不支持的文件扩展名', () async {
      final repository = FakeSourceRepository();
      final service = SourceImportService(repository);

      await expectLater(
        service.importPayload(
          SourceImportPayload(
            name: 'source.txt',
            bytes: _utf8Bytes('{"sourceName":"不会导入"}'),
          ),
        ),
        throwsA(isA<FormatException>()),
      );

      expect(repository.insertCalls, 0);
    });

    test('拒绝空书源数组', () async {
      final repository = FakeSourceRepository();
      final service = SourceImportService(repository);

      await expectLater(
        service.importPayload(
          SourceImportPayload(name: 'empty.json', bytes: _utf8Bytes('[]')),
        ),
        throwsA(isA<FormatException>()),
      );

      expect(repository.insertCalls, 0);
    });

    test('在 Repository 调用前拒绝缺失或空白 sourceName', () async {
      for (final json in <String>[
        '{"enable":"1"}',
        '{"sourceName":"   "}',
        '[{"sourceName":"合法"},{"sourceName":""}]',
      ]) {
        final repository = FakeSourceRepository();
        final service = SourceImportService(repository);

        await expectLater(
          service.importPayload(
            SourceImportPayload(name: 'invalid.json', bytes: _utf8Bytes(json)),
          ),
          throwsA(isA<FormatException>()),
        );

        expect(repository.insertCalls, 0);
      }
    });

    test('Repository 写入失败原样向上传播', () async {
      final error = StateError('database failed');
      final repository = FakeSourceRepository(insertError: error);
      final service = SourceImportService(repository);

      await expectLater(
        service.importPayload(
          SourceImportPayload(
            name: 'source.json',
            bytes: _utf8Bytes('{"sourceName":"数据库失败"}'),
          ),
        ),
        throwsA(same(error)),
      );

      expect(repository.insertCalls, 1);
    });
  });
}

Uint8List _utf8Bytes(String text) => Uint8List.fromList(utf8.encode(text));

final class FakeSourceRepository implements SourceRepository {
  FakeSourceRepository({this.insertError});

  final Object? insertError;
  int insertCalls = 0;
  String? capturedPlatform;
  List<SourceDocument> capturedDocuments = <SourceDocument>[];

  @override
  Future<List<int>> insertSources({
    required String platform,
    required List<SourceDocument> documents,
  }) async {
    insertCalls += 1;
    capturedPlatform = platform;
    capturedDocuments = List<SourceDocument>.of(documents);
    final error = insertError;
    if (error != null) {
      throw error;
    }
    return List<int>.generate(documents.length, (index) => index + 1);
  }

  @override
  Future<List<StoredSource>> listSources() => throw UnimplementedError();

  @override
  Future<StoredSource?> getSource(int id) => throw UnimplementedError();

  @override
  Future<int> insertSource({
    required String platform,
    required SourceDocument document,
  }) => throw UnimplementedError();

  @override
  Future<void> updateSource(int id, SourceDocument document) =>
      throw UnimplementedError();

  @override
  Future<void> deleteSource(int id) => throw UnimplementedError();
}
