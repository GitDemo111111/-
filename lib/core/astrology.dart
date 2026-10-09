/// 星座与生肖（纯计算，方便单测）。
library;

/// 每个星座的起始日期（公历）。摩羯座跨越年尾年初，所以放在最后兜底。
const List<(int month, int day, String name)> _zodiacStarts =
    <(int, int, String)>[
      (1, 20, '水瓶座'),
      (2, 19, '双鱼座'),
      (3, 21, '白羊座'),
      (4, 20, '金牛座'),
      (5, 21, '双子座'),
      (6, 22, '巨蟹座'),
      (7, 23, '狮子座'),
      (8, 23, '处女座'),
      (9, 23, '天秤座'),
      (10, 24, '天蝎座'),
      (11, 23, '射手座'),
      (12, 22, '摩羯座'),
    ];

/// 根据公历月/日返回星座名。
String constellationOf(int month, int day) {
  for (int i = _zodiacStarts.length - 1; i >= 0; i--) {
    final (int m, int d, String name) = _zodiacStarts[i];
    if (month > m || (month == m && day >= d)) return name;
  }
  // 1 月 1 日 ~ 1 月 19 日 属于摩羯座
  return '摩羯座';
}

const List<String> _shengXiao = <String>[
  '鼠',
  '牛',
  '虎',
  '兔',
  '龙',
  '蛇',
  '马',
  '羊',
  '猴',
  '鸡',
  '狗',
  '猪',
];

/// 根据年份返回生肖。1900 年为鼠年，因此以 4 为偏移。
String chineseZodiacOf(int year) {
  final int index = ((year - 4) % 12 + 12) % 12;
  return _shengXiao[index];
}
