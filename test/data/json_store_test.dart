import 'dart:convert';
import 'dart:io';

import 'package:birthday_keeper/data/json_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('birthday_keeper_store');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  JsonStore storeFor(String relativePath) =>
      JsonStore(resolveFile: () async => File('${tempDir.path}/$relativePath'));

  File fileFor(String relativePath) => File('${tempDir.path}/$relativePath');

  test('文件不存在时返回 null', () async {
    expect(await storeFor('missing.json').read(), isNull);
  });

  test('写入后能原样读回', () async {
    final JsonStore store = storeFor('data.json');
    await store.write(<String, Object?>{
      'schemaVersion': 1,
      'items': <Object?>['a', 'b'],
      'nested': <String, Object?>{'k': 1},
    });

    final Map<String, Object?>? read = await store.read();
    expect(read, isNotNull);
    expect(read!['schemaVersion'], 1);
    expect(read['items'], <Object?>['a', 'b']);
    expect((read['nested']! as Map<String, Object?>)['k'], 1);
  });

  test('写入会自动创建父目录', () async {
    final JsonStore store = storeFor('a/b/c/data.json');
    await store.write(<String, Object?>{'ok': true});
    expect(fileFor('a/b/c/data.json').existsSync(), isTrue);
  });

  test('覆盖写入不会残留旧内容', () async {
    final JsonStore store = storeFor('data.json');
    await store.write(<String, Object?>{'a': 1, 'b': 2});
    await store.write(<String, Object?>{'a': 9});
    final Map<String, Object?> read = (await store.read())!;
    expect(read, <String, Object?>{'a': 9});
  });

  test('空文件返回 null', () async {
    final File file = fileFor('empty.json');
    await file.writeAsString('   ');
    expect(await storeFor('empty.json').read(), isNull);
  });

  test('损坏的 JSON 会被隔离，读取返回 null', () async {
    final File file = fileFor('broken.json');
    await file.writeAsString('{ this is not json');

    expect(await storeFor('broken.json').read(), isNull);
    // 原文件被改名成 .corrupt，不会再次影响启动。
    expect(fileFor('broken.json').existsSync(), isFalse);
    expect(fileFor('broken.json.corrupt').existsSync(), isTrue);
    // 第二次读取是「文件不存在」，同样返回 null。
    expect(await storeFor('broken.json').read(), isNull);
  });

  test('顶层不是对象时返回 null', () async {
    await fileFor('array.json').writeAsString(jsonEncode(<int>[1, 2, 3]));
    expect(await storeFor('array.json').read(), isNull);
  });

  test('写入的是 UTF-8，中文能正确读回', () async {
    final JsonStore store = storeFor('cn.json');
    await store.write(<String, Object?>{'name': '张三', 'note': '生日快乐🎂'});
    final Map<String, Object?> read = (await store.read())!;
    expect(read['name'], '张三');
    expect(read['note'], '生日快乐🎂');
  });
}
