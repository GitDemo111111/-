import 'package:birthday_keeper/core/contact_text_parser.dart';
import 'package:birthday_keeper/models/birthday.dart';
import 'package:birthday_keeper/models/contact.dart';
import 'package:birthday_keeper/models/relationship.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 默认历法是农历（用户要求）；需要新历时显式指定或写「新历」。
  const ContactTextParser parser = ContactTextParser();
  const ContactTextParser solarParser = ContactTextParser(
    defaultCalendar: BirthdayCalendar.solar,
  );

  ParsedContact one(String text) {
    final List<ParsedContact> all = parser.parse(text);
    expect(all, hasLength(1), reason: '期望解析出 1 条，实际 ${all.length} 条');
    return all.single;
  }

  group('推荐格式：全部字段', () {
    test('官方示例能被完整解析', () {
      final ParsedContact c = one(kContactTextExample);

      expect(c.name, '张三');
      expect(c.relationship, Relationship.friend);
      expect(c.relationLabel, '大学室友');
      expect(c.birthday, const Birthday(year: 1995, month: 5, day: 20));
      expect(c.hobbies, <String>['咖啡', '徒步']);
      expect(c.phone, '13800000000');
      expect(c.wechat, 'zhangsan_wx');
      expect(c.email, 'zhangsan@example.com');
      expect(c.tags, <String>['重要']);
      expect(c.giftIdeas, '一直想要个机械键盘');
      expect(c.notes, '对花生过敏');
      expect(c.avatarEmoji, '😀');
      expect(c.isValid, isTrue);
      expect(c.warnings, isEmpty);
    });

    test('可以转成真正的 Contact', () {
      final ParsedContact c = one(kContactTextExample);
      final DateTime now = DateTime(2026, 10, 9);
      final Contact contact = c.toContact(id: 'x', now: now, colorSeed: 7);

      expect(contact.id, 'x');
      expect(contact.name, '张三');
      expect(contact.hobbies, <String>['咖啡', '徒步']);
      expect(contact.createdAt, now);
      expect(contact.colorSeed, 7);
      expect(contact.reminder.daysBefore, 3);
    });

    test('只有姓名也是合法的', () {
      final ParsedContact c = one('姓名：李四');
      expect(c.name, '李四');
      expect(c.isValid, isTrue);
      expect(c.birthday, isNull);
      expect(c.hasDetails, isFalse);
      expect(c.warnings, isEmpty);
    });
  });

  group('格式容错', () {
    test('全角冒号、半角冒号、等号都行', () {
      expect(one('姓名：王五').name, '王五');
      expect(one('姓名: 王五').name, '王五');
      expect(one('姓名=王五').name, '王五');
    });

    test('没有冒号的写法也能认', () {
      expect(one('姓名王五').name, '王五');
      expect(
        one('生日是1995年5月20日').birthday,
        const Birthday(
          year: 1995,
          month: 5,
          day: 20,
          calendar: BirthdayCalendar.lunar,
        ),
      );
      expect(
        one('生日 5月20日').birthday,
        const Birthday(month: 5, day: 20, calendar: BirthdayCalendar.lunar),
      );
      expect(one('手机13800000000').phone, '13800000000');
      expect(one('微信zhangsan').wechat, 'zhangsan');
    });

    test('不会把普通词语误判成字段', () {
      // 「生日蛋糕」不应被当成生日字段
      final ParsedContact c = one('姓名：张三\n生日蛋糕很好吃');
      expect(c.birthday, isNull);
      expect(c.notes, '生日蛋糕很好吃');
    });

    test('标签大小写与空格无关', () {
      expect(one('QQ：12345').wechat, '12345');
      expect(one('Email: a@b.com').email, 'a@b.com');
      expect(one('姓 名：张三').name, '张三');
    });

    test('标签后的多余空格会被去掉', () {
      expect(one('姓名：   张三   ').name, '张三');
      expect(one('手机： 13800000000 ').phone, '13800000000');
    });

    test('空值不会变成空字符串字段', () {
      final ParsedContact c = one('姓名：张三\n手机：\n备注：');
      expect(c.phone, isNull);
      expect(c.notes, isNull);
    });

    test('爱好/标签支持多种分隔符并去重', () {
      final ParsedContact c = one('姓名：张三\n爱好：咖啡、徒步, 咖啡/摄影 阅读\n标签：重要，重要');
      expect(c.hobbies, <String>['咖啡', '徒步', '摄影', '阅读']);
      expect(c.tags, <String>['重要']);
    });

    test('QQ 会存进「微信/QQ」字段', () {
      expect(one('姓名：张三\nQQ：10001').wechat, '10001');
    });
  });

  group('关系 / 身份', () {
    test('内置关系识别成枚举', () {
      expect(one('姓名：张三\n关系：朋友').relationship, Relationship.friend);
      expect(one('姓名：张三\n关系：家人').relationship, Relationship.family);
      expect(one('姓名：张三\n关系：同事').relationship, Relationship.colleague);
    });

    test('英文枚举名也认', () {
      expect(one('姓名：张三\n关系：family').relationship, Relationship.family);
    });

    test('非内置关系自动当作具体身份', () {
      final ParsedContact c = one('姓名：张三\n关系：大学室友');
      expect(c.relationship, isNull);
      expect(c.relationLabel, '大学室友');
    });

    test('「身份」字段单独写在具体身份里', () {
      final ParsedContact c = one('姓名：张三\n身份：产品经理');
      expect(c.relationLabel, '产品经理');
      expect(c.relationship, isNull);
    });

    test('关系和身份可以同时存在', () {
      final ParsedContact c = one('姓名：张三\n关系：朋友\n身份：大学室友');
      expect(c.relationship, Relationship.friend);
      expect(c.relationLabel, '大学室友');
    });
  });

  group('生日解析', () {
    test('多种数字写法（显式新历）', () {
      for (final String text in <String>[
        '1995-05-20',
        '1995/5/20',
        '1995.5.20',
        '1995年5月20日',
      ]) {
        expect(
          solarParser.parse('姓名：张三\n生日：$text').single.birthday,
          const Birthday(year: 1995, month: 5, day: 20),
          reason: text,
        );
      }
    });

    test('没有年份的写法', () {
      for (final String text in <String>['5月20日', '5-20', '5/20', '0520']) {
        final Birthday? b = one('姓名：张三\n生日：$text').birthday;
        expect(b, isNotNull, reason: text);
        expect(b!.month, 5, reason: text);
        expect(b.day, 20, reason: text);
        expect(b.year, isNull, reason: text);
        expect(b.calendar, BirthdayCalendar.lunar, reason: text);
      }
    });

    test('农历中文写法', () {
      final Birthday? mid = one('姓名：张三\n生日：农历八月十五').birthday;
      expect(mid!.calendar, BirthdayCalendar.lunar);
      expect(mid.month, 8);
      expect(mid.day, 15);

      final Birthday? laba = one('姓名：张三\n生日：农历腊月初八').birthday;
      expect(laba!.month, 12);
      expect(laba.day, 8);

      final Birthday? chuyi = one('姓名：张三\n生日：农历正月初一').birthday;
      expect(chuyi!.month, 1);
      expect(chuyi.day, 1);

      final Birthday? nian = one('姓名：张三\n生日：农历腊月廿三').birthday;
      expect(nian!.month, 12);
      expect(nian.day, 23);

      final Birthday? sanshi = one('姓名：张三\n生日：农历腊月三十').birthday;
      expect(sanshi!.day, 30);
    });

    test('闰月会被标记', () {
      final Birthday? b = one('姓名：张三\n生日：农历闰四月十五').birthday;
      expect(b!.isLeapMonth, isTrue);
      expect(b.month, 4);
      expect(b.day, 15);
    });

    test('历法字段可以单独写一行', () {
      final ParsedContact c = one('姓名：张三\n历法：农历\n生日：八月十五');
      expect(c.birthday!.calendar, BirthdayCalendar.lunar);
      expect(c.birthday!.month, 8);
      expect(c.birthday!.day, 15);
    });

    test('农历数字写法', () {
      final Birthday? b = one('姓名：张三\n生日：农历8-15').birthday;
      expect(b!.calendar, BirthdayCalendar.lunar);
      expect(b.month, 8);
      expect(b.day, 15);
    });

    test('公历前缀会覆盖默认历法', () {
      final Birthday? b = one('姓名：张三\n历法：农历\n生日：公历5月20日').birthday;
      expect(b!.calendar, BirthdayCalendar.solar);
    });

    test('看不懂的生日会给出提示且不写入', () {
      final ParsedContact c = one('姓名：张三\n生日：下个月吧');
      expect(c.birthday, isNull);
      expect(c.warnings.single, contains('没看懂生日'));
    });

    test('非法日期会给出提示', () {
      final ParsedContact c = one('姓名：张三\n生日：新历2月30日');
      expect(c.birthday, isNull);
      expect(c.warnings, isNotEmpty);
    });

    test('2 月 29 日在闰年是合法的', () {
      final ParsedContact c = one('姓名：张三\n生日：新历2000-02-29');
      expect(c.birthday, const Birthday(year: 2000, month: 2, day: 29));
      expect(c.warnings, isEmpty);
    });
  });

  group('多个联系人', () {
    const String two = '''姓名：张三
生日：1995-05-20
手机：13800000001

姓名：李四
生日：6月1日
爱好：音乐''';

    test('空行分隔', () {
      final List<ParsedContact> all = parser.parse(two);
      expect(all, hasLength(2));
      expect(all[0].name, '张三');
      expect(
        all[0].birthday,
        const Birthday(
          year: 1995,
          month: 5,
          day: 20,
          calendar: BirthdayCalendar.lunar,
        ),
      );
      expect(all[1].name, '李四');
      expect(
        all[1].birthday,
        const Birthday(month: 6, day: 1, calendar: BirthdayCalendar.lunar),
      );
      expect(all[1].hobbies, <String>['音乐']);
    });

    test('--- 分隔', () {
      final List<ParsedContact> all = parser.parse('姓名：张三\n---\n姓名：李四');
      expect(all, hasLength(2));
      expect(all.map((ParsedContact c) => c.name), <String>['张三', '李四']);
    });

    test('连续写「姓名」也会自动分块', () {
      final List<ParsedContact> all = parser.parse(
        '姓名：张三\n生日：5月20日\n姓名：李四\n生日：6月1日',
      );
      expect(all, hasLength(2));
      expect(all[0].name, '张三');
      expect(all[1].name, '李四');
    });

    test('块内允许有空行', () {
      final List<ParsedContact> all = parser.parse('姓名：张三\n\n生日：5月20日');
      expect(all, hasLength(1));
      expect(all.single.name, '张三');
      expect(
        all.single.birthday,
        const Birthday(month: 5, day: 20, calendar: BirthdayCalendar.lunar),
      );
    });

    test('parseValid 会过滤掉缺姓名的条目', () {
      final List<ParsedContact> all = parser.parse('生日：5月20日\n\n姓名：李四');
      expect(all, hasLength(2));
      expect(parser.parseValid('生日：5月20日\n\n姓名：李四'), hasLength(1));
    });
  });

  group('宽松模式（整段没有字段名）', () {
    test('第一行当姓名，找得到日期就当生日，其余进备注', () {
      final ParsedContact c = one('张三\n5月20日\n喜欢喝咖啡');
      expect(c.name, '张三');
      expect(
        c.birthday,
        const Birthday(month: 5, day: 20, calendar: BirthdayCalendar.lunar),
      );
      expect(c.notes, '喜欢喝咖啡');
      expect(c.warnings, isNotEmpty);
    });

    test('第一行本身就是日期时不会当成姓名', () {
      final ParsedContact c = parser.parse('5月20日\n张三').single;
      expect(
        c.birthday,
        const Birthday(month: 5, day: 20, calendar: BirthdayCalendar.lunar),
      );
      expect(c.name, '张三');
    });
  });

  group('异常与边界', () {
    test('空空如也返回空列表', () {
      expect(parser.parse(''), isEmpty);
      expect(parser.parse('   \n\n  '), isEmpty);
      expect(parser.parseFirst(''), isNull);
    });

    test('缺姓名时无效并给出提示', () {
      final ParsedContact c = one('生日：5月20日');
      expect(c.isValid, isFalse);
      expect(c.warnings.single, contains('缺少'));
    });

    test('认不出的字段进备注并提示，不丢数据', () {
      final ParsedContact c = one('姓名：张三\n血型：O型\n星座：金牛座');
      expect(c.notes, contains('血型：O型'));
      expect(c.notes, contains('星座：金牛座'));
      expect(c.warnings, hasLength(2));
    });

    test('没有冒号的多余行也会进备注', () {
      final ParsedContact c = one('姓名：张三\n他最近在学吉他');
      expect(c.notes, '他最近在学吉他');
    });

    test('parseFirst 取第一条有效结果', () {
      final ParsedContact? first = parser.parseFirst(
        '生日：5月20日\n\n姓名：李四\n生日：6月1日',
      );
      expect(first!.name, '李四');
    });

    test('CRLF 换行也能解析', () {
      final ParsedContact c = one('姓名：张三\r\n生日：5月20日\r\n手机：13800000000');
      expect(c.name, '张三');
      expect(c.phone, '13800000000');
    });

    test('名字里带冒号不会被拆坏', () {
      final ParsedContact c = one('姓名：李:四');
      expect(c.name, '李:四');
    });

    test('emoji 头像', () {
      expect(one('姓名：张三\n头像：🎂').avatarEmoji, '🎂');
    });

    test('Windows 下常见的多余空白与制表符', () {
      final ParsedContact c = one('\t姓名：张三  \n\t生日：5月20日\t');
      expect(c.name, '张三');
      expect(
        c.birthday,
        const Birthday(month: 5, day: 20, calendar: BirthdayCalendar.lunar),
      );
    });
  });

  group('默认历法（默认农历）', () {
    test('没写历法时按农历理解', () {
      expect(
        one('姓名：张三\n生日：1995-05-20').birthday,
        const Birthday(
          year: 1995,
          month: 5,
          day: 20,
          calendar: BirthdayCalendar.lunar,
        ),
      );
      expect(one('姓名：张三\n生日：5月20日').birthday!.calendar, BirthdayCalendar.lunar);
    });

    test('用户要的是「都默认农历」，新历自己手动改', () {
      // 用户原话：我导入的日期都要默认农历，新历我自己会手动更改。
      // 所以没写历法的日期统一是农历；界面上可以逐条切换（UI 测试覆盖）。
      final List<ParsedContact> all = parser.parseValid(
        '姓名：二姐\n生日：年份不详-农历02-20\n\n'
        '姓名：秦文芳\n生日：1972-09-18',
      );
      expect(all, hasLength(2));
      expect(all[0].birthday!.calendar, BirthdayCalendar.lunar);
      expect(all[1].birthday!.calendar, BirthdayCalendar.lunar);
      // 逐条切换只改历法，月 / 日不动
      final ParsedContact switched = all[1].withCalendar(
        BirthdayCalendar.solar,
      );
      expect(switched.birthday!.calendar, BirthdayCalendar.solar);
      expect(switched.birthday!.month, 9);
      expect(switched.birthday!.day, 18);
      expect(switched.birthday!.year, 1972);
      // 文本里写了历法的条目会被标记，界面上不给切
      expect(all[0].birthdayCalendarFromText, isTrue);
      expect(all[1].birthdayCalendarFromText, isFalse);
    });

    test('写成「新历」就按新历理解', () {
      expect(
        one('姓名：张三\n生日：新历1995-05-20').birthday,
        const Birthday(year: 1995, month: 5, day: 20),
      );
      // 公历 / 阳历 / 西历 这些同义写法也认
      for (final String keyword in <String>['公历', '阳历', '西历', 'solar']) {
        final Birthday? b = one('姓名：张三\n生日：${keyword}5月20日').birthday;
        expect(b!.calendar, BirthdayCalendar.solar, reason: keyword);
      }
    });

    test('默认历法可以按需切换（导入页的开关）', () {
      const ContactTextParser solarDefault = ContactTextParser(
        defaultCalendar: BirthdayCalendar.solar,
      );
      final ParsedContact c = solarDefault.parse('姓名：张三\n生日：5月20日').single;
      expect(c.birthday!.calendar, BirthdayCalendar.solar);
      // 但文本里写了「农历」依然以文本为准
      final ParsedContact forced = solarDefault
          .parse('姓名：张三\n生日：农历八月十五')
          .single;
      expect(forced.birthday!.calendar, BirthdayCalendar.lunar);
      expect(forced.birthday!.month, 8);
    });
  });

  group('关系：家人包含具体角色', () {
    test('爸爸 / 妈妈 / 爷爷 等直接可选', () {
      expect(one('姓名：张三\n关系：爸爸').relationship, Relationship.father);
      expect(one('姓名：张三\n关系：妈妈').relationship, Relationship.mother);
      expect(one('姓名：张三\n关系：爷爷').relationship, Relationship.grandpa);
      expect(one('姓名：张三\n关系：奶奶').relationship, Relationship.grandma);
      expect(one('姓名：张三\n关系：外公').relationship, Relationship.maternalGrandpa);
      expect(one('姓名：张三\n关系：外婆').relationship, Relationship.maternalGrandma);
      expect(one('姓名：张三\n关系：老公').relationship, Relationship.husband);
      expect(one('姓名：张三\n关系：老婆').relationship, Relationship.wife);
      expect(one('姓名：张三\n关系：哥哥').relationship, Relationship.elderBrother);
      expect(one('姓名：张三\n关系：妹妹').relationship, Relationship.youngerSister);
    });

    test('具体角色都归到正确的分组（筛选用）', () {
      expect(Relationship.father.group, RelationshipGroup.family);
      expect(Relationship.mother.group, RelationshipGroup.family);
      expect(Relationship.grandpa.group, RelationshipGroup.family);
      expect(Relationship.uncle.group, RelationshipGroup.relative);
      expect(Relationship.bestie.group, RelationshipGroup.friend);
      expect(Relationship.boss.group, RelationshipGroup.colleague);
      expect(Relationship.classmate.group, RelationshipGroup.classmate);
      expect(Relationship.teacher.group, RelationshipGroup.other);
    });

    test('口语化写法也能识别', () {
      expect(one('姓名：张三\n关系：父亲').relationship, Relationship.father);
      expect(one('姓名：张三\n关系：母亲').relationship, Relationship.mother);
      expect(one('姓名：张三\n关系：姥爷').relationship, Relationship.maternalGrandpa);
      expect(one('姓名：张三\n关系：姥姥').relationship, Relationship.maternalGrandma);
      expect(one('姓名：张三\n关系：丈夫').relationship, Relationship.husband);
      expect(one('姓名：张三\n关系：妻子').relationship, Relationship.wife);
      expect(one('姓名：张三\n关系：老板').relationship, Relationship.boss);
      expect(one('姓名：张三\n关系：好友').relationship, Relationship.friend);
      expect(one('姓名：张三\n关系：表哥').relationship, Relationship.cousin);
    });

    test('实在认不出的还是当具体身份', () {
      final ParsedContact c = one('姓名：张三\n关系：大学室友');
      expect(c.relationship, isNull);
      expect(c.relationLabel, '大学室友');
    });
  });

  group('星座（由生日自动推导，不需要用户填写）', () {
    test('公历生日能推出星座', () {
      // 解析器本身只负责生日，星座由 BirthdayCalculator 推导。
      final ParsedContact c = one('姓名：张三\n生日：5月20日');
      expect(
        c.birthday,
        const Birthday(month: 5, day: 20, calendar: BirthdayCalendar.lunar),
      );
    });

    test('用户粘贴了星座也不会被当成字段（星座是算出来的）', () {
      final ParsedContact c = one('姓名：张三\n生日：5月20日\n星座：金牛座');
      expect(c.notes, contains('星座：金牛座'));
      expect(
        c.birthday,
        const Birthday(month: 5, day: 20, calendar: BirthdayCalendar.lunar),
      );
    });
  });
}
