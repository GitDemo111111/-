/// 与联系人之间的关系 / 身份。
///
/// 这是一组内置的常用选项，**用户可以不选**。如果内置选项不够贴切，
/// 还可以通过 `Contact.relationLabel` 写一个自由文本的身份（例如
/// 「大学室友」「产品经理」）。
enum Relationship {
  family('家人'),
  relative('亲戚'),
  friend('朋友'),
  colleague('同事'),
  classmate('同学'),
  partner('伴侣'),
  client('客户'),
  neighbor('邻居'),
  teacher('老师'),
  other('其他');

  const Relationship(this.label);

  /// 界面上展示的中文名。
  final String label;

  /// 从持久化名称还原；为空或无法识别时返回 `null`，表示「未填写」。
  static Relationship? fromName(String? name) {
    if (name == null || name.isEmpty) return null;
    for (final Relationship value in Relationship.values) {
      if (value.name == name) return value;
    }
    return null;
  }
}
