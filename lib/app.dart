import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'state/contact_controller.dart';
import 'state/root_tab_controller.dart';
import 'state/settings_controller.dart';
import 'theme/app_theme.dart';
import 'ui/pages/root_page.dart';

/// 应用根组件。
///
/// 控制器由外部注入，测试里可以换成内存实现 + 假的提醒调度器。
class BirthdayKeeperApp extends StatelessWidget {
  const BirthdayKeeperApp({
    super.key,
    required this.contactController,
    required this.settingsController,
    this.rootTabController,
  });

  final ContactController contactController;
  final SettingsController settingsController;

  /// 底部导航状态；不传就自己建一个（测试里可以直接断言它）。
  final RootTabController? rootTabController;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<SettingsController>.value(
          value: settingsController,
        ),
        ChangeNotifierProvider<ContactController>.value(
          value: contactController,
        ),
        ChangeNotifierProvider<RootTabController>.value(
          value: rootTabController ?? RootTabController(),
        ),
      ],
      child: MaterialApp(
        title: '生日管家',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        locale: const Locale('zh', 'CN'),
        supportedLocales: const <Locale>[
          Locale('zh', 'CN'),
          Locale('en', 'US'),
        ],
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const RootPage(),
      ),
    );
  }
}
