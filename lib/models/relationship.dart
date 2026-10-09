/// 关系的分组。
///
/// 用于「联系人」页的筛选，以及编辑页的分组选择 —— 家人下面会包含
/// 爸爸、妈妈、爷爷、奶奶等具体角色。
enum RelationshipGroup {
  family('家人'),
  relative('亲戚'),
  friend('朋友'),
  colleague('同事'),
  classmate('同学'),
  other('其他');

  const RelationshipGroup(this.label);

  /// 界面上展示的中文名。
  final String label;

  /// 该分组下的所有具体关系。
  List<Relationship> get members =>
      Relationship.values.where((Relationship e) => e.group == this).toList();

  static RelationshipGroup? fromName(String? name) {
    if (name == null || name.isEmpty) return null;
    for (final RelationshipGroup value in RelationshipGroup.values) {
      if (value.name == name) return value;
    }
    return null;
  }
}

/// 与联系人之间的关系 / 身份。
///
/// 这是一组内置的常用选项，**用户可以不选**。除了这些具体角色，
/// 还可以通过 `Contact.relationLabel` 写一个自由文本的身份
/// （例如「大学室友」「产品经理」）。
enum Relationship {
  // ---- 家人 ----
  father('爸爸', RelationshipGroup.family),
  mother('妈妈', RelationshipGroup.family),
  grandpa('爷爷', RelationshipGroup.family),
  grandma('奶奶', RelationshipGroup.family),
  maternalGrandpa('外公', RelationshipGroup.family),
  maternalGrandma('外婆', RelationshipGroup.family),
  husband('老公', RelationshipGroup.family),
  wife('老婆', RelationshipGroup.family),
  son('儿子', RelationshipGroup.family),
  daughter('女儿', RelationshipGroup.family),
  elderBrother('哥哥', RelationshipGroup.family),
  elderSister('姐姐', RelationshipGroup.family),
  youngerBrother('弟弟', RelationshipGroup.family),
  youngerSister('妹妹', RelationshipGroup.family),
  family('家人', RelationshipGroup.family),

  // ---- 亲戚 ----
  uncle('叔叔', RelationshipGroup.relative),
  aunt('阿姨', RelationshipGroup.relative),
  maternalUncle('舅舅', RelationshipGroup.relative),
  paternalAunt('姑姑', RelationshipGroup.relative),
  cousin('表亲', RelationshipGroup.relative),
  relative('亲戚', RelationshipGroup.relative),

  // ---- 朋友 ----
  friend('朋友', RelationshipGroup.friend),
  bestie('闺蜜', RelationshipGroup.friend),
  buddy('兄弟', RelationshipGroup.friend),

  // ---- 同事 / 同学 ----
  colleague('同事', RelationshipGroup.colleague),
  boss('领导', RelationshipGroup.colleague),
  classmate('同学', RelationshipGroup.classmate),

  // ---- 其他 ----
  partner('伴侣', RelationshipGroup.other),
  client('客户', RelationshipGroup.other),
  neighbor('邻居', RelationshipGroup.other),
  teacher('老师', RelationshipGroup.other),
  other('其他', RelationshipGroup.other);

  const Relationship(this.label, this.group);

  /// 界面上展示的中文名。
  final String label;

  /// 所属分组（用于筛选）。
  final RelationshipGroup group;

  /// 从持久化名称还原；为空或无法识别时返回 `null`，表示「未填写」。
  static Relationship? fromName(String? name) {
    if (name == null || name.isEmpty) return null;
    for (final Relationship value in Relationship.values) {
      if (value.name == name) return value;
    }
    return null;
  }

  /// 从中文标签还原（例如「爸爸」）。识别不了返回 `null`。
  static Relationship? fromLabel(String? label) {
    if (label == null || label.isEmpty) return null;
    final String trimmed = label.trim();
    for (final Relationship value in Relationship.values) {
      if (value.label == trimmed) return value;
    }
    return null;
  }
}
