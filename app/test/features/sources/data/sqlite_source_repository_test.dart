import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/core/database/app_database.dart';
import 'package:source_reader/features/sources/data/sqlite_source_repository.dart';
import 'package:source_reader/features/sources/domain/source_document.dart';

void main() {
  group('SqliteSourceRepository', () {
    late AppDatabase database;
    late DateTime now;
    late SqliteSourceRepository repository;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      now = DateTime.utc(2026, 9, 2, 8);
      repository = SqliteSourceRepository(database, now: () => now);
    });

    tearDown(() async {
      await database.close();
    });

    test('insert/get 保留 raw JSON 未知字段和历史字段表达', () async {
      final source = _source(
        name: '测试书源',
        extra: <String, Object?>{
          'futureExtension': <String, Object?>{'mode': 'x'},
        },
      );

      final id = await repository.insertSource(
        platform: 'StandarReader',
        document: source,
      );
      final stored = await repository.getSource(id);

      expect(id, greaterThan(0));
      expect(stored, isNotNull);
      expect(stored!.id, id);
      expect(stored.platform, 'StandarReader');
      expect(stored.document.sourceName, '测试书源');
      expect(stored.document.sourceType, 'text');
      expect(stored.document.sourceUrl, 'https://example.com');
      expect(stored.document.enabled, isTrue);
      expect(stored.document.weight, 12);
      expect(
        stored.document.toRaw()['futureExtension'],
        <String, Object?>{'mode': 'x'},
      );
      expect(stored.document.toRaw()['enable'], '1');
      expect(stored.document.toRaw()['weight'], '12');
      expect(stored.createdAt, now);
      expect(stored.updatedAt, now);
    });

    test('listSources 明确按 id 升序返回', () async {
      final firstId = await repository.insertSource(
        platform: 'StandarReader',
        document: _source(name: 'B'),
      );
      final secondId = await repository.insertSource(
        platform: 'StandarReader',
        document: _source(name: 'A'),
      );

      final sources = await repository.listSources();

      expect(sources.map((item) => item.id), <int>[firstId, secondId]);
      expect(
        sources.map((item) => item.document.sourceName),
        <String?>['B', 'A'],
      );
    });

    test('update 保留数据库身份、platform、createdAt 和未知字段', () async {
      final createdAt = now;
      final id = await repository.insertSource(
        platform: 'StandarReader',
        document: _source(
          name: '旧名称',
          extra: <String, Object?>{
            'futureExtension': <String, Object?>{'mode': 'x'},
          },
        ),
      );

      now = DateTime.utc(2026, 9, 2, 9);
      final changed = _source(
        name: '新名称',
        weight: '99',
        extra: <String, Object?>{
          'futureExtension': <String, Object?>{'mode': 'x'},
        },
      );
      await repository.updateSource(id, changed);
      final stored = await repository.getSource(id);

      expect(stored, isNotNull);
      expect(stored!.id, id);
      expect(stored.platform, 'StandarReader');
      expect(stored.createdAt, createdAt);
      expect(stored.updatedAt, now);
      expect(stored.document.sourceName, '新名称');
      expect(stored.document.weight, 99);
      expect(stored.document.toRaw()['weight'], '99');
      expect(
        stored.document.toRaw()['futureExtension'],
        <String, Object?>{'mode': 'x'},
      );
    });

    test('update 不存在的 id 抛出 StateError', () async {
      await expectLater(
        repository.updateSource(404, _source(name: '不存在')),
        throwsA(isA<StateError>()),
      );
    });

    test('delete 删除记录且对不存在 id 保持幂等', () async {
      final id = await repository.insertSource(
        platform: 'StandarReader',
        document: _source(name: '待删除'),
      );

      await repository.deleteSource(id);
      await repository.deleteSource(id);

      expect(await repository.getSource(id), isNull);
    });

    test('insert 拒绝 null、空字符串和纯空白 sourceName', () async {
      for (final name in <String?>[null, '', '   ']) {
        await expectLater(
          repository.insertSource(
            platform: 'StandarReader',
            document: _source(name: name),
          ),
          throwsA(isA<ArgumentError>()),
        );
      }
    });

    test('update 拒绝 null、空字符串和纯空白 sourceName', () async {
      final id = await repository.insertSource(
        platform: 'StandarReader',
        document: _source(name: '有效名称'),
      );

      for (final name in <String?>[null, '', '   ']) {
        await expectLater(
          repository.updateSource(id, _source(name: name)),
          throwsA(isA<ArgumentError>()),
        );
      }
    });

    test('同 platform/sourceName 唯一，不同 platform 允许同名', () async {
      await repository.insertSource(
        platform: 'StandarReader',
        document: _source(name: '同名书源'),
      );

      await expectLater(
        repository.insertSource(
          platform: 'StandarReader',
          document: _source(name: '同名书源'),
        ),
        throwsA(isA<Exception>()),
      );

      final otherPlatformId = await repository.insertSource(
        platform: 'OtherPlatform',
        document: _source(name: '同名书源'),
      );

      expect(otherPlatformId, greaterThan(0));
    });
  });
}

SourceDocument _source({
  required String? name,
  String weight = '12',
  Map<String, Object?> extra = const <String, Object?>{},
}) {
  return SourceDocument.fromRaw(<String, Object?>{
    'sourceName': ?name,
    'sourceType': 'text',
    'sourceUrl': 'https://example.com',
    'enable': '1',
    'weight': weight,
    ...extra,
  });
}
