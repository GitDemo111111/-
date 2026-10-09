import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/astrology.dart';
import '../../core/birthday_calculator.dart';
import '../../models/contact.dart';
import '../../models/relationship.dart';
import '../../state/contact_controller.dart';
import '../../theme/app_theme.dart';
import '../navigation.dart';
import '../widgets/common.dart';
import '../widgets/contact_tiles.dart';
import '../widgets/forms.dart';
import 'contact_import_page.dart';

/// 「联系人」页：搜索 + 关系/爱好筛选 + 完整列表。
class ContactsPage extends StatelessWidget {
  const ContactsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ContactController controller = context.watch<ContactController>();

    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final Map<String, UpcomingBirthday> byId = <String, UpcomingBirthday>{
      for (final UpcomingBirthday item in controller.upcoming)
        item.contact.id: item,
    };
    final List<Contact> visible = controller.visibleContacts;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      key: const Key('searchField'),
                      onChanged: controller.setQuery,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: '搜索姓名、关系、爱好、备注…',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: controller.searchQuery.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                onPressed: () => controller.setQuery(''),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    key: const Key('importFromTextButton'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext _) => const ContactImportPage(),
                      ),
                    ),
                    icon: const Icon(Icons.content_paste_go_rounded),
                    tooltip: '从文本导入',
                  ),
                  const SizedBox(width: 8),
                  _FilterButton(controller: controller),
                ],
              ),
            ),
            _FilterChips(controller: controller),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: Row(
                children: <Widget>[
                  Text(
                    '共 ${visible.length} 位',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    controller.settings.sortMode.label,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: visible.isEmpty
                  ? EmptyState(
                      icon: controller.contacts.isEmpty
                          ? Icons.people_outline_rounded
                          : Icons.search_off_rounded,
                      title: controller.contacts.isEmpty
                          ? '还没有联系人'
                          : '没有符合条件的联系人',
                      message: controller.contacts.isEmpty
                          ? '点右下角「添加」新建一位，\n或点搜索框旁的粘贴图标批量导入。'
                          : '试试换个关键词或清除筛选条件。',
                      action: controller.hasActiveFilters
                          ? OutlinedButton(
                              onPressed: controller.clearFilters,
                              child: const Text('清除筛选'),
                            )
                          : null,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                      itemCount: visible.length,
                      separatorBuilder: (BuildContext _, int index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (BuildContext context, int index) {
                        final Contact contact = visible[index];
                        final UpcomingBirthday? item = byId[contact.id];
                        return ContactTile(
                          contact: contact,
                          daysUntil: item?.daysUntil,
                          turningAge: item?.turningAge,
                          // 星座由生日自动推导（农历会先换算成公历）
                          constellation: item == null
                              ? null
                              : constellationOf(
                                  item.occurrence.date.month,
                                  item.occurrence.date.day,
                                ),
                          onTap: () => openContactDetail(context, contact.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        // 与「即将到来」页的 FAB 用不同的 heroTag，避免 Hero 冲突。
        heroTag: 'fab-contacts',
        onPressed: () => openContactEditor(context),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('添加'),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.controller});

  final ContactController controller;

  @override
  Widget build(BuildContext context) {
    final List<FilterOption> relations = controller.relationshipFacets;
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: <Widget>[
          SelectableChip(
            key: const Key('favoriteFilterChip'),
            label: '星标',
            icon: Icons.star_rounded,
            dense: true,
            selected: controller.favoritesOnly,
            onTap: () => controller.setFavoritesOnly(!controller.favoritesOnly),
          ),
          const SizedBox(width: 8),
          for (final FilterOption option in relations) ...<Widget>[
            SelectableChip(
              key: Key('relationFilter-${option.label}'),
              label: '${option.label} ${option.count}',
              dense: true,
              selected: controller.relationshipFilter?.label == option.label,
              onTap: () {
                final Relationship? current = controller.relationshipFilter;
                controller.setRelationshipFilter(
                  current?.label == option.label
                      ? null
                      : Relationship.values.firstWhere(
                          (Relationship e) => e.label == option.label,
                        ),
                );
              },
            ),
            const SizedBox(width: 8),
          ],
          if (controller.hasActiveFilters)
            SelectableChip(
              label: '清除',
              icon: Icons.close_rounded,
              dense: true,
              selected: false,
              onTap: controller.clearFilters,
            ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.controller});

  final ContactController controller;

  @override
  Widget build(BuildContext context) {
    final int active = controller.hobbyFilters.length;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        IconButton.filledTonal(
          key: const Key('hobbyFilterButton'),
          onPressed: () => _openSheet(context),
          icon: const Icon(Icons.tune_rounded),
          tooltip: '按爱好筛选',
        ),
        if (active > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: const BoxDecoration(
                color: AppColors.celebrate,
                borderRadius: BorderRadius.all(Radius.circular(999)),
              ),
              child: Text(
                '$active',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) =>
          ChangeNotifierProvider<ContactController>.value(
            value: controller,
            child: const _HobbyFilterSheet(),
          ),
    );
  }
}

class _HobbyFilterSheet extends StatelessWidget {
  const _HobbyFilterSheet();

  @override
  Widget build(BuildContext context) {
    final ContactController controller = context.watch<ContactController>();
    final List<FilterOption> hobbies = controller.hobbyFacets;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '按爱好筛选',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            '可以多选，只会显示同时包含这些爱好的联系人',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          if (hobbies.isEmpty)
            const Text(
              '还没有人填写爱好',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final FilterOption option in hobbies)
                  SelectableChip(
                    key: Key('hobbyFilter-${option.label}'),
                    label: '${option.label} ${option.count}',
                    dense: true,
                    selected: controller.hobbyFilters.contains(option.label),
                    onTap: () => controller.toggleHobbyFilter(option.label),
                  ),
              ],
            ),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: controller.hobbyFilters.isEmpty
                      ? null
                      : () => controller.clearFilters(),
                  child: const Text('清除全部筛选'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('完成'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
