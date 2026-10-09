import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'app_bootstrap.dart';
import 'app_dependencies.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final AppDependencies dependencies = await createAppDependencies();

  runApp(
    BirthdayKeeperApp(
      contactController: dependencies.contactController,
      settingsController: dependencies.settingsController,
    ),
  );

  // 首帧先渲染出来，本地数据和提醒在后台加载。
  unawaited(dependencies.start());
}
