import 'package:flutter/material.dart';
import '../../main.dart' show appNavigatorKey;
import 'thome_auth_client.dart';

/// 公告弹窗框架（使用全局导航 key，不依赖页面 context）
/// 用法：AnnouncementDialog.showViaKey(announcements)
class AnnouncementDialog {
  AnnouncementDialog._();

  /// 用全局 navigatorKey 弹窗 —— 只要 App 起来就能弹，不依赖任何页面 context，
  /// 彻底规避 "showDialog 时机/context 挂载" 问题。
  static Future<void> showViaKey(List<ThomeAnnouncement> announcements) async {
    if (announcements.isEmpty) return;
    final navState = appNavigatorKey.currentState;
    if (navState == null) {
      debugPrint('[Announcement] 全局 navigatorKey 未就绪，跳过弹窗');
      return;
    }

    // 按优先级排序（高优先级在前）
    final sorted = List<ThomeAnnouncement>.from(announcements)
      ..sort((a, b) => b.priority.compareTo(a.priority));

    for (final ann in sorted) {
      // barrierDismissible: 强制类型不可点外部关闭，其余可点外部关闭
      await showDialog(
        context: navState.context,
        barrierDismissible: !_isForcedType(ann.type),
        builder: (ctx) => _AnnouncementDialogContent(announcement: ann),
      );
    }
  }

  /// 公告类型是否为强制展示（不可点击外部关闭，必须点确认）
  static bool _isForcedType(String type) {
    return type == 'warning' || type == 'notice' || type == 'update';
  }
}

class _AnnouncementDialogContent extends StatelessWidget {
  final ThomeAnnouncement announcement;

  const _AnnouncementDialogContent({required this.announcement});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = _iconFor(announcement.type);
    final color = _colorFor(announcement.type, theme);

    return PopScope(
      canPop: !_isForced(announcement.type),
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                announcement.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            announcement.content,
            style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(announcement.actionText.isEmpty
                ? '知道了'
                : announcement.actionText),
          ),
        ],
      ),
    );
  }

  bool _isForced(String type) {
    return type == 'warning' || type == 'notice' || type == 'update';
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'warning':
      case 'notice':
        return Icons.warning_amber_rounded;
      case 'error':
        return Icons.error_rounded;
      case 'success':
        return Icons.check_circle_rounded;
      case 'update':
        return Icons.system_update_alt_rounded;
      default:
        return Icons.campaign_rounded;
    }
  }

  Color _colorFor(String type, ThemeData theme) {
    switch (type) {
      case 'warning':
      case 'notice':
        return Colors.orange;
      case 'error':
        return theme.colorScheme.error;
      case 'success':
        return Colors.green;
      case 'update':
        return Colors.blue;
      default:
        return theme.colorScheme.primary;
    }
  }
}