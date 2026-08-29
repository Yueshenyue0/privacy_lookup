import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../main.dart' show appNavigatorKey;
import 'ark_service.dart';

/// ARK 公告弹窗（独立于 ThomeAuth，纯图片+标题+按钮）
class ArkAnnouncementDialog {
  ArkAnnouncementDialog._();

  /// 用全局 navigatorKey 弹窗，不依赖页面 context
  static Future<void> show(ArkAnnouncement announcement) async {
    final navState = appNavigatorKey.currentState;
    if (navState == null) return;

    await showDialog<void>(
      context: navState.context,
      barrierDismissible: false, // 点击外部不能关闭，必须点按钮
      builder: (ctx) => _ArkDialogContent(announcement: announcement),
    );
  }
}

class _ArkDialogContent extends StatelessWidget {
  final ArkAnnouncement announcement;

  const _ArkDialogContent({required this.announcement});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // 禁止返回键/手势关闭
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题（写死"公告"）
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                announcement.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            // 正文内容
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                announcement.content,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade800,
                  height: 1.5,
                ),
              ),
            ),
            // 图片
            if (announcement.imageUrl != null &&
                announcement.imageUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: announcement.imageUrl!,
                    fit: BoxFit.contain,
                    placeholder: (ctx, url) => const SizedBox(
                      height: 120,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (ctx, url, err) => const SizedBox(
                      height: 120,
                      child: Center(
                          child: Icon(Icons.broken_image_outlined,
                              color: Colors.grey)),
                    ),
                  ),
                ),
              ),
            // 按钮
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                ),
                child: const Text('好的'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}