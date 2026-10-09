/// 按平台选择依赖组装方式。
///
/// - 有 `dart:io`（Android / iOS / 桌面）→ 用 JSON 文件 + 系统本地通知；
/// - 默认（Web）→ 用 localStorage + 空调度器。
///
/// 这样 Web 端不会因为 `dart:io` 而被编译失败，手机端功能也不打折。
library;

export 'app_bootstrap_web.dart' if (dart.library.io) 'app_bootstrap_io.dart';
