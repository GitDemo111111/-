import 'dart:convert';
import 'dart:io';

/// 解析数据文件路径的注入点。
///
/// 之所以用函数而不是直接依赖 `path_provider`，是为了让单元测试可以指向
/// 一个临时目录，从而真正跑一遍文件读写。
typedef FileResolver = Future<File> Function();

/// 极简的 JSON 文件存储：读、写、损坏自愈。
class JsonStore {
  JsonStore({required this.resolveFile});

  final FileResolver resolveFile;

  /// 读取内容；文件不存在、为空或已损坏时返回 `null`。
  Future<Map<String, Object?>?> read() async {
    final File file = await resolveFile();
    if (!await file.exists()) return null;
    try {
      final String text = await file.readAsString();
      if (text.trim().isEmpty) return null;
      final Object? decoded = jsonDecode(text);
      if (decoded is Map) return decoded.cast<String, Object?>();
      return null;
    } on FormatException {
      // 文件损坏时先隔离，保证 App 还能正常启动。
      await _quarantine(file);
      return null;
    } on FileSystemException {
      return null;
    }
  }

  /// 原子写入：先写临时文件，再改名覆盖，避免写到一半掉电丢数据。
  Future<void> write(Map<String, Object?> data) async {
    final File file = await resolveFile();
    await file.parent.create(recursive: true);
    final File temp = File('${file.path}.tmp');
    await temp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
      flush: true,
    );
    try {
      await temp.rename(file.path);
    } on FileSystemException {
      // 个别平台覆盖已存在的文件会失败，退化成「先删后改」。
      if (await file.exists()) await file.delete();
      await temp.rename(file.path);
    }
  }

  Future<void> _quarantine(File file) async {
    try {
      final File backup = File('${file.path}.corrupt');
      if (await backup.exists()) await backup.delete();
      await file.rename(backup.path);
    } on FileSystemException {
      // 隔离失败也不能影响启动。
    }
  }
}
