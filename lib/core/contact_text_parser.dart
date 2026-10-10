import 'package:meta/meta.dart';

import '../models/birthday.dart';
import '../models/contact.dart';
import '../models/relationship.dart';

/// 推荐的粘贴格式示例（界面上直接展示这一段，用户照着填即可）。
const String kContactTextExample = '''姓名：张三
关系：朋友
身份：大学室友
生日：新历1995-05-20
爱好：咖啡、徒步
手机：13800000000
微信：zhangsan_wx
邮箱：zhangsan@example.com
标签：重要
礼物：一直想要个机械键盘
备注：对花生过敏
头像：😀''';

/// 格式说明要点，界面与 README 共用。
const List<String> kContactTextRules = <String>[
  '一行一个字段，写成「字段：值」；冒号中英文都行。',
  '只有「姓名」是必填的，其它行不写就不填。',
  '关系可以直接写爸爸 / 妈妈 / 爷爷 / 奶奶 / 老公 / 老婆 / 哥哥 / 姐姐 等，'
      '也可以写朋友、同事、同学；填别的会自动当作具体身份。',
  '生日支持 1995-05-20、1995/5/20、1995年5月20日、5月20日、5-20 等写法。',
  '没写明历法时按下面选的默认历法理解（默认农历）；要明确就写'
      '「新历」或「农历」，例如「生日：新历1995-05-20」。',
  '农历也可以写成中文：「生日：农历八月十五」「农历腊月初八」，'
      '中文数字、闰月（闰四月）都能识别。',
  '爱好、标签用「、」「,」「/」或空格分隔。',
  '多位联系人：用一行 --- 或空行隔开，每人从「姓名：」重新开始。',
  '认不出的字段不会丢，会原样放进备注并在预览里提示。',
];

/// 解析出来的联系人草稿。
///
/// 和 [Contact] 的区别：没有 id、不带着默认提醒设置，而且允许「缺姓名」，
/// 这样界面可以把解析失败的那一条也展示出来提示用户。
@immutable
class ParsedContact {
  const ParsedContact({
    required this.name,
    this.relationship,
    this.relationLabel,
    this.birthday,
    this.hobbies = const <String>[],
    this.tags = const <String>[],
    this.phone,
    this.email,
    this.wechat,
    this.notes,
    this.giftIdeas,
    this.avatarEmoji,
    this.warnings = const <String>[],
    this.birthdayCalendarFromText = false,
  });

  final String name;
  final Relationship? relationship;
  final String? relationLabel;
  final Birthday? birthday;
  final List<String> hobbies;
  final List<String> tags;
  final String? phone;
  final String? email;
  final String? wechat;
  final String? notes;
  final String? giftIdeas;
  final String? avatarEmoji;

  /// 解析过程中的提醒（认不出的字段、看不懂的日期等）。
  final List<String> warnings;

  /// 生日那一行里**是否明确写了**「新历 / 农历」。
  ///
  /// 写了就以此为准；没写就按导入页选的默认历法（默认农历），
  /// 并允许在预览里逐条切换 —— 用户要求：默认农历，新历自己手动改。
  final bool birthdayCalendarFromText;

  /// 换一种历法理解这个生日（月 / 日不变，只改解释方式）。
  ParsedContact withCalendar(BirthdayCalendar calendar) {
    final Birthday? current = birthday;
    if (current == null || current.calendar == calendar) return this;
    return ParsedContact(
      name: name,
      relationship: relationship,
      relationLabel: relationLabel,
      birthday: current.copyWith(calendar: calendar),
      hobbies: hobbies,
      tags: tags,
      phone: phone,
      email: email,
      wechat: wechat,
      notes: notes,
      giftIdeas: giftIdeas,
      avatarEmoji: avatarEmoji,
      warnings: warnings,
      birthdayCalendarFromText: birthdayCalendarFromText,
    );
  }

  /// 姓名是唯一必填项。
  bool get isValid => name.trim().isNotEmpty;

  /// 除姓名外是否还解析出了别的信息。
  bool get hasDetails =>
      relationship != null ||
      relationLabel != null ||
      birthday != null ||
      hobbies.isNotEmpty ||
      tags.isNotEmpty ||
      phone != null ||
      email != null ||
      wechat != null ||
      notes != null ||
      giftIdeas != null;

  /// 转换成一个真正的 [Contact]。
  Contact toContact({
    required String id,
    required DateTime now,
    ReminderSettings reminder = const ReminderSettings(),
    int colorSeed = 0,
  }) => Contact(
    id: id,
    name: name.trim(),
    relationship: relationship,
    relationLabel: relationLabel,
    birthday: birthday,
    hobbies: hobbies,
    tags: tags,
    phone: phone,
    email: email,
    wechat: wechat,
    notes: notes,
    giftIdeas: giftIdeas,
    avatarEmoji: avatarEmoji,
    colorSeed: colorSeed,
    reminder: reminder,
    createdAt: now,
    updatedAt: now,
  );

  @override
  String toString() => 'ParsedContact($name, birthday=$birthday)';
}

/// 把「一段文字」解析成联系人。
///
/// 目标是让人把微信里收到的信息直接粘进来就能用，所以尽量容错：
/// 标签有别名、冒号全角半角都行、日期多种写法、多个人用空行或 `---` 隔开。
class ContactTextParser {
  const ContactTextParser({this.defaultCalendar = BirthdayCalendar.lunar});

  /// 文本里没写明历法时，按哪种历法理解。
  ///
  /// 默认**农历**（用户要求：家里长辈的生日基本都按农历记）；
  /// 写了「新历 / 公历 / 阳历」的行会覆盖这个默认值，
  /// 界面上还允许**逐条**切换（导入预览里每条都有 新历/农历 按钮）。
  final BirthdayCalendar defaultCalendar;

  /// 解析文本，返回所有解析出来的条目（含缺姓名的无效条目）。
  List<ParsedContact> parse(String text) {
    final List<List<String>> blocks = _splitBlocks(text);
    // 没有任何「文档级推断」：没写历法的一律按 defaultCalendar（默认农历）。
    // 用户原话：我导入的日期都要默认农历，新历我自己会手动更改。
    // 界面上允许逐条切换，但不替用户猜。
    final List<ParsedContact> result = <ParsedContact>[];
    for (final List<String> block in blocks) {
      result.addAll(_parseBlockEntries(block, defaultCalendar));
    }
    return result;
  }

  /// 只取第一条可用于「自动填充表单」的结果。
  ParsedContact? parseFirst(String text) {
    for (final ParsedContact item in parse(text)) {
      if (item.isValid) return item;
    }
    return null;
  }

  /// 解析出所有有效条目。
  List<ParsedContact> parseValid(String text) =>
      parse(text).where((ParsedContact c) => c.isValid).toList();

  // ------------------------------------------------------------ 分块

  static final RegExp _separatorLine = RegExp(r'^[-=*_~—]{3,}$');

  List<List<String>> _splitBlocks(String text) {
    final String normalized = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final List<List<String>> blocks = <List<String>>[];
    List<String> current = <String>[];
    bool currentHasName = false;

    void flush() {
      if (current.isNotEmpty) {
        blocks.add(current);
        current = <String>[];
        currentHasName = false;
      }
    }

    final List<String> rawLines = normalized.split('\n');
    for (int i = 0; i < rawLines.length; i++) {
      final String line = rawLines[i].trim();
      if (line.isEmpty) {
        // 空行只有在「后面紧跟一个新的联系人」时才当分隔，
        // 这样在同一个人的资料里留个空行不会把他拆成两条。
        if (_nextStartsNewContact(rawLines, i + 1)) flush();
        continue;
      }
      if (_separatorLine.hasMatch(line)) {
        flush();
        continue;
      }
      final (String label, String value) = _splitLabel(line);
      final String? field = label.isEmpty ? null : _fieldOf(label);
      // 又出现一个「姓名」而当前块已经有姓名 -> 说明是新的一条。
      if (field == 'name' && currentHasName && value.trim().isNotEmpty) {
        flush();
      }
      if (field == 'name') currentHasName = true;
      current.add(line);
    }
    flush();
    return blocks;
  }

  /// 从 [from] 开始往后看，下一个有内容的行是不是「一个新的联系人」的开头。
  bool _nextStartsNewContact(List<String> lines, int from) {
    for (int i = from; i < lines.length; i++) {
      final String line = lines[i].trim();
      if (line.isEmpty) continue;
      if (_separatorLine.hasMatch(line)) return true;
      final (String label, String value) = _splitLabel(line);
      if (label.isEmpty) return false;
      return _fieldOf(label) == 'name' && value.trim().isNotEmpty;
    }
    return false;
  }

  // ------------------------------------------------------------ 解析单块

  /// 解析一个块，可能得到**多条**（例如微信里很常见的「一行一位」名单）。
  List<ParsedContact> _parseBlockEntries(
    List<String> lines,
    BirthdayCalendar fallback,
  ) {
    if (lines.isEmpty) return const <ParsedContact>[];
    if (!_hasStructuredField(lines)) return _parseLooseEntries(lines, fallback);
    final ParsedContact? one = _parseBlock(lines, fallback);
    return one == null ? const <ParsedContact>[] : <ParsedContact>[one];
  }

  /// 判断这一段是不是「带字段名的格式」。
  ///
  /// 只看「前缀匹配」不算数（例如「喜欢喝咖啡」会被前缀匹配成爱好字段），
  /// 否则一段没有字段名的自由文字会被误判成结构化输入。
  bool _hasStructuredField(List<String> lines) {
    for (final String line in lines) {
      final (String label, String value) = _splitLabel(line);
      if (label.isEmpty) continue;
      final String? field = _fieldOf(label);
      if (field == null) continue;
      if (field == 'name' && value.trim().isNotEmpty) return true;
      if (_hasSeparator(line)) return true;
      // 前缀匹配只对「强字段」算数：手机号/生日/微信 这种；
      // 爱好、备注这类标签经常就是普通句子的开头（喜欢…、备注…），不算。
      if (!_weakPrefixFields.contains(field)) return true;
    }
    return false;
  }

  ParsedContact? _parseBlock(List<String> lines, BirthdayCalendar fallback) {
    if (lines.isEmpty) return null;

    String? name;
    Relationship? relationship;
    String? relationLabel;
    Birthday? birthday;
    BirthdayCalendar? explicitCalendar;
    final List<String> hobbies = <String>[];
    final List<String> tags = <String>[];
    String? phone;
    String? email;
    String? wechat;
    String? giftIdeas;
    String? avatarEmoji;
    final List<String> noteParts = <String>[];
    final List<String> warnings = <String>[];
    bool birthdayFromText = false;

    // 先扫一遍「历法」，这样它写在「生日」后面也能生效；
    // 同时不会覆盖生日行里自己写的「公历/农历」。
    for (final String line in lines) {
      final (String label, String value) = _splitLabel(line);
      if (label.isEmpty || _fieldOf(label) != 'calendar') continue;
      final String trimmed = value.trim();
      explicitCalendar = _parseCalendar(trimmed);
      if (explicitCalendar == null) {
        warnings.add('没看懂历法「$trimmed」，已按新历处理');
      }
    }

    for (final String line in lines) {
      final (String label, String value) = _splitLabel(line);
      final String trimmed = value.trim();
      final String? field = label.isEmpty ? null : _fieldOf(label);

      if (field == null) {
        // 认不出的行：不丢，塞进备注。
        if (label.isEmpty) {
          // 没有冒号的行：可能夹带日期，先试着当生日。
          final Birthday? maybeDate = birthday == null
              ? _parseBirthday(line, explicitCalendar ?? fallback)
              : null;
          if (maybeDate != null) {
            birthday = maybeDate;
            continue;
          }
          if (trimmed.isNotEmpty || line.isNotEmpty) {
            noteParts.add(line);
          }
          continue;
        }
        noteParts.add('$label：$trimmed');
        warnings.add('「$label」不是内置字段，已放进备注');
        continue;
      }

      switch (field) {
        case 'name':
          name = trimmed;
        case 'relationship':
          _applyRelationship(
            trimmed,
            onEnum: (Relationship r) => relationship = r,
            onFreeText: (String text) => relationLabel = text,
          );
        case 'relationLabel':
          relationLabel = trimmed.isEmpty ? null : trimmed;
        case 'calendar':
          // 已经在前面统一扫过了。
          break;
        case 'birthday':
          if (trimmed.isEmpty) break;
          final Birthday? parsed = _parseBirthday(
            trimmed,
            explicitCalendar ?? fallback,
          );
          if (parsed == null) {
            warnings.add('没看懂生日「$trimmed」，请手动选择');
          } else if (parsed.validate() != null) {
            warnings.add('生日「$trimmed」不是有效日期（${parsed.validate()}）');
          } else {
            birthday = parsed;
            birthdayFromText = _parseCalendar(trimmed) != null;
          }
        case 'hobbies':
          hobbies.addAll(_splitList(trimmed));
        case 'tags':
          tags.addAll(_splitList(trimmed));
        case 'phone':
          phone = _orNull(trimmed);
        case 'email':
          email = _orNull(trimmed);
        case 'wechat':
          wechat = _orNull(trimmed);
        case 'giftIdeas':
          giftIdeas = _orNull(trimmed);
        case 'avatarEmoji':
          avatarEmoji = _orNull(trimmed);
        case 'notes':
          if (trimmed.isNotEmpty) noteParts.add(trimmed);
      }
    }

    final List<String> uniqueHobbies = _dedupe(hobbies);
    final List<String> uniqueTags = _dedupe(tags);

    if ((name ?? '').trim().isEmpty) {
      warnings.add('缺少「姓名」，这一条无法导入');
    }

    return ParsedContact(
      name: name ?? '',
      relationship: relationship,
      relationLabel: relationLabel,
      birthday: birthday,
      hobbies: uniqueHobbies,
      tags: uniqueTags,
      phone: phone,
      email: email,
      wechat: wechat,
      notes: noteParts.isEmpty ? null : noteParts.join('\n'),
      giftIdeas: giftIdeas,
      avatarEmoji: avatarEmoji,
      warnings: warnings,
      birthdayCalendarFromText: birthdayFromText,
    );
  }

  /// 没有任何已知标签时的宽松解析。
  ParsedContact? _parseLooseBlock(
    List<String> lines,
    BirthdayCalendar fallback,
  ) {
    final List<String> remaining = <String>[];
    String? name;
    Birthday? birthday;
    bool birthdayFromText = false;
    final List<String> warnings = <String>[];

    for (final String line in lines) {
      if (name == null) {
        // 第一行当姓名；但如果它本身就是一个日期，就当作生日，
        // 避免把「5月20日」这样的行误当成名字。
        final Birthday? asDate = _parseBirthday(line, fallback);
        if (asDate != null && asDate.validate() == null) {
          birthday ??= asDate;
          continue;
        }
        final (String label, String value) = _splitLabel(line);
        final String candidate = (value.trim().isEmpty ? label : value).trim();
        if (candidate.isNotEmpty) {
          name = candidate;
          continue;
        }
      }
      if (birthday == null) {
        final Birthday? parsed = _parseBirthday(line, fallback);
        if (parsed != null && parsed.validate() == null) {
          birthday = parsed;
          birthdayFromText = _parseCalendar(line) != null;
          continue;
        }
      }
      remaining.add(line);
    }

    if (name == null && birthday == null && remaining.isEmpty) return null;
    if (name == null) {
      warnings.add('缺少「姓名」，这一条无法导入');
    } else if (remaining.isNotEmpty) {
      warnings.add('没有识别到字段名，这些内容已放进备注');
    }
    return ParsedContact(
      name: name ?? '',
      birthday: birthday,
      notes: remaining.isEmpty ? null : remaining.join('\n'),
      warnings: warnings,
      birthdayCalendarFromText: birthdayFromText,
    );
  }

  // ------------------------------------------------- 宽松模式：可能是名单

  static final RegExp _phonePattern = RegExp(r'(?<!\d)(\d{7,15})(?!\d)');

  /// 宽松模式：整段没有字段名。
  ///
  /// 关键分支：如果里面有**多行各自带日期**，那多半是微信里常见的名单
  /// （`张三 5月20日` / `张三,5月20日` / `张三：5月20日` / 姓名一行日期一行），
  /// 这时按「一行一位」拆开，而不是把 11 个人当成 1 个人。
  List<ParsedContact> _parseLooseEntries(
    List<String> lines,
    BirthdayCalendar fallback,
  ) {
    final List<String> items = lines
        .map((String l) => l.trim())
        .where((String l) => l.isNotEmpty)
        .toList();
    bool hasDateAt(int i) => i < items.length && _dateMatch(items[i]) != null;

    final List<List<String>> groups = <List<String>>[];
    List<String> current = <String>[];
    bool currentHasDate = false;
    for (int i = 0; i < items.length; i++) {
      final String line = items[i];
      final bool hasDate = hasDateAt(i);
      // 开新一组的两种情况：
      // 1) 这一行是日期，而当前组已经有日期了；
      // 2) 这一行不是日期，但当前组已经有日期，而且**下一行是日期**
      //    —— 说明这是下一位的名字（「姓名一行、日期一行」的写法）。
      final bool startsNew = currentHasDate && (hasDate || hasDateAt(i + 1));
      if (startsNew) {
        groups.add(current);
        current = <String>[];
        currentHasDate = false;
      }
      current.add(line);
      currentHasDate = currentHasDate || hasDate;
    }
    if (current.isNotEmpty) groups.add(current);

    // 只有一段、且不带日期规律 -> 保持原来的「整段一个人」行为
    final int datedGroups = groups
        .where((List<String> g) => g.any((String l) => _dateMatch(l) != null))
        .length;
    if (datedGroups < 2) {
      final ParsedContact? single = _parseLooseBlock(lines, fallback);
      return single == null ? const <ParsedContact>[] : <ParsedContact>[single];
    }

    final List<ParsedContact> result = <ParsedContact>[];
    for (final List<String> group in groups) {
      result.add(_parseLooseGroup(group, fallback));
    }
    return result;
  }

  /// 把「一位联系人」的那一小段文本解析出来。
  ParsedContact _parseLooseGroup(
    List<String> group,
    BirthdayCalendar fallback,
  ) {
    String? name;
    Birthday? birthday;
    String? phone;
    bool birthdayFromText = false;
    final List<String> notes = <String>[];
    final List<String> warnings = <String>[];

    for (final String line in group) {
      final Match? dateMatch = _dateMatch(line);
      if (dateMatch != null && birthday == null) {
        final Birthday? parsed = _parseBirthday(line, fallback);
        if (parsed != null && parsed.validate() == null) {
          birthday = parsed;
          birthdayFromText = _parseCalendar(line) != null;
          final String before = line
              .substring(0, dateMatch.start)
              .replaceAll(RegExp(r'[\s:：,，、;；\-—|]+$'), '')
              .replaceAll(RegExp(r'^[\s:：,，、;；\-—|]+'), '')
              .trim();
          final String after = line
              .substring(dateMatch.end)
              .replaceAll(RegExp(r'^[\s:：,，、;；\-—|]+'), '')
              .trim();
          if (before.isNotEmpty) name = before;
          _absorbRest(after, onPhone: (String p) => phone = p, notes: notes);
          continue;
        }
      }
      // 不是日期：先当姓名，已经有了就当补充信息
      if (name == null) {
        name = line;
        continue;
      }
      _absorbRest(line, onPhone: (String p) => phone = p, notes: notes);
    }

    if (name == null) warnings.add('缺少「姓名」，这一条无法导入');
    if (birthday == null && name != null) {
      // 分组里理论上一定有日期，这里只是兜底
      warnings.add('没看懂生日，请手动选择');
    }
    return ParsedContact(
      name: name ?? '',
      birthday: birthday,
      phone: phone,
      notes: notes.isEmpty ? null : notes.join('\n'),
      warnings: warnings,
      birthdayCalendarFromText: birthdayFromText,
    );
  }

  /// 把日期后面/前面剩下的文本归位：像手机号的当手机号，其余进备注。
  static void _absorbRest(
    String text, {
    required void Function(String) onPhone,
    required List<String> notes,
  }) {
    String rest = text.trim();
    if (rest.isEmpty) return;
    final Match? phone = _phonePattern.firstMatch(rest);
    if (phone != null) {
      onPhone(phone.group(1)!);
      rest = (rest.substring(0, phone.start) + rest.substring(phone.end))
          .replaceAll(RegExp(r'[\s:：,，、;；\-—|]+'), ' ')
          .trim();
    }
    if (rest.isNotEmpty) notes.add(rest);
  }

  /// 这一行里第一个日期片段的位置（顺序和 [_parseBirthday] 一致）。
  static Match? _dateMatch(String text) {
    for (final RegExp pattern in <RegExp>[
      _yearMonthDay,
      _monthDay,
      _chineseDate,
    ]) {
      final Match? match = pattern.firstMatch(text);
      if (match != null) return match;
    }
    // 纯数字 0520 / 520
    final Match? digits = RegExp(
      r'(?<![\d])(\d{3,4})(?![\d])',
    ).firstMatch(text);
    if (digits != null) {
      final String value = digits.group(1)!;
      final int month = value.length == 4
          ? int.parse(value.substring(0, 2))
          : int.parse(value.substring(0, 1));
      final int day = value.length == 4
          ? int.parse(value.substring(2))
          : int.parse(value.substring(1));
      if (month >= 1 && month <= 12 && day >= 1 && day <= 31) return digits;
    }
    return null;
  }

  static void _applyRelationship(
    String value, {
    required void Function(Relationship) onEnum,
    required void Function(String) onFreeText,
  }) {
    if (value.isEmpty) return;
    // 1) 常见同义写法（父亲 / 母亲 / 姥爷 / 丈夫 / 老板 …）
    final Relationship? alias = _relationshipAliases[value];
    if (alias != null) {
      onEnum(alias);
      return;
    }
    // 2) 内置标签或英文枚举名
    for (final Relationship item in Relationship.values) {
      if (item.label == value || item.name == value) {
        onEnum(item);
        return;
      }
    }
    // 3) 「朋友/同事」这类包含写法
    for (final Relationship item in Relationship.values) {
      if (value.contains(item.label)) {
        onEnum(item);
        return;
      }
    }
    onFreeText(value);
  }

  /// 关系的常见同义写法。
  static const Map<String, Relationship> _relationshipAliases =
      <String, Relationship>{
        '父亲': Relationship.father,
        '爸': Relationship.father,
        '老爹': Relationship.father,
        '母亲': Relationship.mother,
        '妈': Relationship.mother,
        '娘': Relationship.mother,
        '祖父': Relationship.grandpa,
        '祖母': Relationship.grandma,
        '外祖父': Relationship.maternalGrandpa,
        '姥爷': Relationship.maternalGrandpa,
        '外祖母': Relationship.maternalGrandma,
        '姥姥': Relationship.maternalGrandma,
        '丈夫': Relationship.husband,
        '妻子': Relationship.wife,
        '媳妇': Relationship.wife,
        '爱人': Relationship.partner,
        '对象': Relationship.partner,
        '男朋友': Relationship.partner,
        '女朋友': Relationship.partner,
        '闺女': Relationship.daughter,
        '大哥': Relationship.elderBrother,
        '大姐': Relationship.elderSister,
        '小弟': Relationship.youngerBrother,
        '小妹': Relationship.youngerSister,
        '老板': Relationship.boss,
        '上司': Relationship.boss,
        '好友': Relationship.friend,
        '发小': Relationship.friend,
        '闺密': Relationship.bestie,
        '舅': Relationship.maternalUncle,
        '舅妈': Relationship.maternalUncle,
        '姑妈': Relationship.paternalAunt,
        '姨妈': Relationship.aunt,
        '表哥': Relationship.cousin,
        '表姐': Relationship.cousin,
        '堂哥': Relationship.cousin,
        '堂姐': Relationship.cousin,
      };

  // ------------------------------------------------------------ 小工具

  static final RegExp _colonPattern = RegExp(r'[：:=]');

  /// 连接词：`生日是...` / `生日为...` / `生日 ...`
  static final RegExp _connector = RegExp(r'^[是为\s]+');

  /// 这一行是否是「已知标签 + 分隔符」的写法。
  static bool _hasSeparator(String line) {
    final Match? match = _colonPattern.firstMatch(line);
    if (match == null) return false;
    final String label = line.substring(0, match.start).trim();
    if (label.isEmpty || label.length > 8) return false;
    return _fieldOf(label) != null;
  }

  /// 把一行拆成「标签, 值」。支持两种写法：
  /// 1. `生日：新历1995-05-20`（有分隔符）
  /// 2. `生日是1995-05-20`、`手机13800000000`（标签直接连值）
  static (String, String) _splitLabel(String line) {
    final Match? match = _colonPattern.firstMatch(line);
    if (match != null) {
      final String label = line.substring(0, match.start).trim();
      // 标签太长（多半是句子里的冒号）就不当标签。
      if (label.isNotEmpty && label.length <= 8) {
        return (label, line.substring(match.end));
      }
      return ('', line);
    }

    // 无分隔符：尝试用已知标签做前缀匹配。
    for (final String label in _prefixLabels) {
      if (!line.startsWith(label)) continue;
      final String rest = line.substring(label.length);
      if (rest.isEmpty) continue;
      final String first = rest[0];
      final bool hasConnector = _connector.hasMatch(rest);
      final bool startsWithLatinOrDigit = RegExp(
        r'[0-9A-Za-z]',
      ).hasMatch(first);
      // 「姓名张三」这种中文直接跟在标签后的写法也认；但对「生日」这类
      // 容易和普通词语混淆的标签不开这个口子，否则「生日蛋糕」会被误判。
      final bool startsWithCjkDirectly =
          !_prefixBlockedLabels.contains(label) &&
          RegExp(r'[\u4e00-\u9fa5]').hasMatch(first);
      if (!hasConnector && !startsWithLatinOrDigit && !startsWithCjkDirectly) {
        continue;
      }
      return (label, rest.replaceFirst(_connector, ''));
    }
    return ('', line);
  }

  /// 这些字段的「前缀匹配」不作为结构化输入的证据。
  static const Set<String> _weakPrefixFields = <String>{
    'hobbies',
    'notes',
    'tags',
    'giftIdeas',
    'avatarEmoji',
  };

  /// 这些标签后面直接跟中文时不当作字段。
  static const Set<String> _prefixBlockedLabels = <String>{
    '生日',
    '出生',
    '出生日期',
    '出生年月',
    '出生年月日',
    '生日日期',
    '礼物',
    '礼物灵感',
    '备注',
    '备注信息',
    '说明',
    '其他',
    '其它',
    '头像',
    '表情',
  };

  /// 可用于「无分隔符前缀匹配」的标签，按长度从长到短。
  static final List<String> _prefixLabels =
      _aliases.keys.where((String key) => key.length >= 2).toList()
        ..sort((String a, String b) => b.length.compareTo(a.length));

  /// 标签 -> 字段名。支持常见别名。
  static String? _fieldOf(String label) {
    final String key = label
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[（(].*?[)）]'), '')
        .replaceAll(RegExp(r'是$'), '')
        .toLowerCase();
    return _aliases[key];
  }

  static const Map<String, String> _aliases = <String, String>{
    '姓名': 'name',
    '名字': 'name',
    '名称': 'name',
    '昵称': 'name',
    '称呼': 'name',
    'name': 'name',
    '关系': 'relationship',
    '关系类型': 'relationship',
    '关系身份': 'relationship',
    '身份': 'relationLabel',
    '具体身份': 'relationLabel',
    '自定义身份': 'relationLabel',
    '职位': 'relationLabel',
    '职业': 'relationLabel',
    'title': 'relationLabel',
    '生日': 'birthday',
    '出生日期': 'birthday',
    '出生年月': 'birthday',
    '出生年月日': 'birthday',
    '生日日期': 'birthday',
    '出生': 'birthday',
    '生日农历': 'birthday',
    '农历生日': 'birthday',
    'birthday': 'birthday',
    '历法': 'calendar',
    '日历': 'calendar',
    '日期类型': 'calendar',
    'calendar': 'calendar',
    '爱好': 'hobbies',
    '兴趣爱好': 'hobbies',
    '兴趣': 'hobbies',
    '喜好': 'hobbies',
    '喜欢': 'hobbies',
    'hobby': 'hobbies',
    'hobbies': 'hobbies',
    '标签': 'tags',
    '分类': 'tags',
    'tag': 'tags',
    'tags': 'tags',
    '手机': 'phone',
    '手机号': 'phone',
    '手机号码': 'phone',
    '电话': 'phone',
    '联系电话': 'phone',
    '号码': 'phone',
    'tel': 'phone',
    'phone': 'phone',
    '微信': 'wechat',
    '微信号': 'wechat',
    'wx': 'wechat',
    'wechat': 'wechat',
    'qq': 'wechat',
    'qq号': 'wechat',
    '邮箱': 'email',
    '电子邮箱': 'email',
    '邮箱地址': 'email',
    '邮件': 'email',
    'email': 'email',
    'mail': 'email',
    '备注': 'notes',
    '说明': 'notes',
    '备注信息': 'notes',
    '其他': 'notes',
    '其它': 'notes',
    'note': 'notes',
    'notes': 'notes',
    '礼物': 'giftIdeas',
    '礼物灵感': 'giftIdeas',
    '送什么': 'giftIdeas',
    'gift': 'giftIdeas',
    '头像': 'avatarEmoji',
    'emoji': 'avatarEmoji',
    '表情': 'avatarEmoji',
  };

  static String? _orNull(String value) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static final RegExp _listSplit = RegExp(r'[、,，;；/|]+|\s+');

  static List<String> _splitList(String value) => value
      .split(_listSplit)
      .map((String e) => e.trim())
      .where((String e) => e.isNotEmpty)
      .toList();

  static List<String> _dedupe(List<String> values) {
    final List<String> result = <String>[];
    for (final String value in values) {
      if (!result.contains(value)) result.add(value);
    }
    return result;
  }

  static BirthdayCalendar? _parseCalendar(String value) {
    if (RegExp(r'农历|阴历|旧历|農曆|lunar').hasMatch(value)) {
      return BirthdayCalendar.lunar;
    }
    if (RegExp(r'公历|阳历|新历|西历|solar').hasMatch(value)) {
      return BirthdayCalendar.solar;
    }
    return null;
  }

  // ------------------------------------------------------------ 日期

  static final RegExp _yearMonthDay = RegExp(
    r'(\d{4})\s*[-/.年]\s*(\d{1,2})\s*[-/.月]\s*(\d{1,2})\s*日?',
  );
  static final RegExp _monthDay = RegExp(
    r'(?<![\d])(\d{1,2})\s*[-/.月]\s*(\d{1,2})\s*日?',
  );
  static final RegExp _chineseDate = RegExp(
    r'(闰)?([正冬腊一二三四五六七八九十])月'
    r'(初[一二三四五六七八九十]|廿[一二三四五六七八九]?|二十[一二三四五六七八九]?'
    r'|三十|十[一二三四五六七八九]?|[一二三四五六七八九十])',
  );

  /// 解析生日。支持数字写法与中文农历写法。
  Birthday? _parseBirthday(String raw, BirthdayCalendar fallback) {
    final String text = raw.trim();
    if (text.isEmpty) return null;

    BirthdayCalendar calendar = fallback;
    final BirthdayCalendar? explicit = _parseCalendar(text);
    if (explicit != null) calendar = explicit;
    final bool isLeapMonth = text.contains('闰');

    // 1) 四位年份 + 月日
    final Match? ymd = _yearMonthDay.firstMatch(text);
    if (ymd != null) {
      final int? year = int.tryParse(ymd.group(1)!);
      final int? month = int.tryParse(ymd.group(2)!);
      final int? day = int.tryParse(ymd.group(3)!);
      if (month != null && day != null) {
        return Birthday(
          month: month,
          day: day,
          year: year,
          calendar: calendar,
          isLeapMonth: isLeapMonth && calendar == BirthdayCalendar.lunar,
        );
      }
    }

    // 2) 只有月日
    final Match? md = _monthDay.firstMatch(text);
    if (md != null) {
      final int? month = int.tryParse(md.group(1)!);
      final int? day = int.tryParse(md.group(2)!);
      if (month != null && day != null && month >= 1 && month <= 12) {
        return Birthday(
          month: month,
          day: day,
          calendar: calendar,
          isLeapMonth: isLeapMonth && calendar == BirthdayCalendar.lunar,
        );
      }
    }

    // 3) 中文农历写法（八月十五 / 腊月初八 / 闰四月十五）
    final Match? cn = _chineseDate.firstMatch(text);
    if (cn != null) {
      final int? month = _chineseMonth(cn.group(2)!);
      final int? day = _chineseDay(cn.group(3)!);
      if (month != null && day != null) {
        return Birthday(
          month: month,
          day: day,
          calendar: calendar == BirthdayCalendar.solar
              ? BirthdayCalendar.lunar
              : calendar,
          isLeapMonth: cn.group(1) != null,
        );
      }
    }

    // 4) 纯数字 0520 / 520
    final Match? digits = RegExp(
      r'(?<![\d])(\d{3,4})(?![\d])',
    ).firstMatch(text);
    if (digits != null) {
      final String value = digits.group(1)!;
      final int month = value.length == 4
          ? int.parse(value.substring(0, 2))
          : int.parse(value.substring(0, 1));
      final int day = value.length == 4
          ? int.parse(value.substring(2))
          : int.parse(value.substring(1));
      if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return Birthday(month: month, day: day, calendar: calendar);
      }
    }
    return null;
  }

  static int? _chineseMonth(String value) => const <String, int>{
    '正': 1,
    '一': 1,
    '二': 2,
    '三': 3,
    '四': 4,
    '五': 5,
    '六': 6,
    '七': 7,
    '八': 8,
    '九': 9,
    '十': 10,
    '冬': 11,
    '腊': 12,
  }[value];

  static const Map<String, int> _digits = <String, int>{
    '一': 1,
    '二': 2,
    '三': 3,
    '四': 4,
    '五': 5,
    '六': 6,
    '七': 7,
    '八': 8,
    '九': 9,
    '十': 10,
  };

  /// 中文数字 -> 整数（支持 1~39）。
  static int? _chineseNumber(String value) {
    if (value.isEmpty) return null;
    if (value.length == 1) return _digits[value];
    final int tenIndex = value.indexOf('十');
    if (tenIndex >= 0) {
      final int tens = tenIndex == 0 ? 1 : (_digits[value[0]] ?? 0);
      final String onesPart = value.substring(tenIndex + 1);
      final int ones = onesPart.isEmpty ? 0 : (_digits[onesPart] ?? 0);
      return tens * 10 + ones;
    }
    return null;
  }

  /// 农历日期写法 -> 整数（初一 / 初十 / 十一 / 二十 / 廿三 / 三十）。
  static int? _chineseDay(String value) {
    if (value.isEmpty) return null;
    if (value.startsWith('初')) return _chineseNumber(value.substring(1));
    if (value.startsWith('廿')) {
      final int? rest = _chineseNumber(value.substring(1));
      return rest == null ? null : 20 + rest;
    }
    if (value.startsWith('二十')) {
      final String rest = value.substring(2);
      if (rest.isEmpty) return 20;
      final int? ones = _chineseNumber(rest);
      return ones == null ? null : 20 + ones;
    }
    if (value == '三十') return 30;
    if (value == '十') return 10;
    if (value.startsWith('十')) {
      final int? ones = _chineseNumber(value.substring(1));
      return ones == null ? null : 10 + ones;
    }
    return _chineseNumber(value);
  }
}
