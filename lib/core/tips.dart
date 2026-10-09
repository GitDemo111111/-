import 'package:flutter/material.dart';

/// 一条「使用提示」。
@immutable
class AppTip {
  const AppTip({
    required this.id,
    required this.icon,
    required this.title,
    required this.body,
  });

  /// 稳定 id，用于记住「不再提示」。
  final String id;
  final IconData icon;
  final String title;
  final String body;
}

/// 内置的使用提示。首页的提示卡片会轮换展示，也可以在「设置 -> 使用提示」里全部查看。
const List<AppTip> kAppTips = <AppTip>[
  AppTip(
    id: 'reminder_3days',
    icon: Icons.notifications_active_rounded,
    title: '默认提前 3 天提醒',
    body:
        '每位联系人都默认在「生日前 3 天」和「生日当天」上午 9:00 提醒你。'
        '想改成别的天数或时间，进联系人的编辑页，在「提醒」里单独设置即可。',
  ),
  AppTip(
    id: 'paste_import',
    icon: Icons.content_paste_go_rounded,
    title: '文本直接粘贴，自动填好',
    body:
        '「联系人」页搜索框旁的粘贴图标，可以把一整段文字（一行一个字段，'
        '如「姓名：张三 / 生日：农历八月十五」）自动识别成联系人，'
        '一次还能粘贴多位、自动合并重复的。编辑页右上角也能用文本直接填充表单。',
  ),
  AppTip(
    id: 'lunar_calendar',
    icon: Icons.nightlight_round,
    title: '农历生日也能记',
    body:
        '生日可以选「新历」或「农历」，农历还支持闰月。'
        '填了农历会自动换算成新历显示，闰月生日和平年也不会算错。',
  ),
  AppTip(
    id: 'auto_constellation',
    icon: Icons.auto_awesome_rounded,
    title: '星座、生肖是自动算出来的',
    body:
        '只要填了生日，星座立刻就能识别；填了出生年份还会显示生肖。'
        '这些都不需要你手动填，选完生日在编辑页就能看到。',
  ),
  AppTip(
    id: 'relationship_roles',
    icon: Icons.family_restroom_rounded,
    title: '关系可以选到很具体',
    body:
        '关系不只是「家人」，还能直接选爸爸、妈妈、爷爷、奶奶、外公、外婆、'
        '哥哥、姐姐、弟弟、妹妹等。列表按「家人 / 亲戚 / 朋友 / 同事 / 同学 / 其他」分组筛选。',
  ),
  AppTip(
    id: 'backup',
    icon: Icons.backup_rounded,
    title: '记得偶尔导出备份',
    body:
        '「设置 -> 数据」里可以导出全部联系人（含生日与提醒设置）。'
        '数据只存在这台设备上，不联网、不上传，换手机前记得导出一份。',
  ),
  AppTip(
    id: 'hobbies_gift',
    icon: Icons.card_giftcard_rounded,
    title: '记下爱好，挑礼物不发愁',
    body:
        '给联系人填上「爱好」和「礼物灵感」，'
        '临近生日时就能直接看到对方喜欢什么，不用临时想。',
  ),
  AppTip(
    id: 'unknown_fields',
    icon: Icons.help_outline_rounded,
    title: '不知道的信息可以不填',
    body:
        '除了姓名，其它全都可以留空 —— 出生年份不知道就不填，'
        '年龄相关的内容会自动隐藏，不会显示成错的。',
  ),
];

/// 按当前日期挑一条提示（同一天固定同一条）。
AppTip tipForDate(DateTime date) {
  final int dayOfYear = date.difference(DateTime(date.year)).inDays;
  return kAppTips[dayOfYear % kAppTips.length];
}
