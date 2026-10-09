import 'package:flutter/material.dart';

import '../../models/contact.dart';
import '../../theme/app_theme.dart';

/// 联系人头像：有 emoji 就用 emoji，否则用姓名首字。
class ContactAvatar extends StatelessWidget {
  const ContactAvatar({super.key, required this.contact, this.size = 48});

  final Contact contact;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Color base = AppColors.avatarColorFor(contact.colorSeed);
    final String? emoji = contact.avatarEmoji;
    final String text = (emoji != null && emoji.trim().isNotEmpty)
        ? emoji.trim()
        : contact.initial;
    final bool isEmoji =
        text != contact.initial || (emoji?.isNotEmpty ?? false);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[base, Color.lerp(base, Colors.white, 0.28) ?? base],
        ),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * (isEmoji ? 0.46 : 0.42),
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}
