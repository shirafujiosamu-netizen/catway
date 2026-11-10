import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

class VersionService {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://theregolithjar.monster/anime-api',
  ));

  static Future<void> checkVersion(BuildContext context) async {
    try {
      final response = await _dio.get('/version');
      final serverVersion = response.data['versionCode'] as int;
      final downloadUrl = response.data['downloadUrl'] as String;
      final force = response.data['forceUpdate'] ?? false;
      final updateLog = response.data['updateLog'] ?? '';

      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = int.tryParse(packageInfo.buildNumber) ?? 0;

      if (serverVersion > currentVersion && context.mounted) {
        _showUpdateDialog(context, downloadUrl, force, updateLog);
      }
    } catch (e) {
      debugPrint('版本检查失败: $e');
    }
  }

  static void _showUpdateDialog(
      BuildContext context, String url, bool force, String log) {
    showDialog(
      context: context,
      barrierDismissible: !force,
      builder: (context) => AlertDialog(
        title: const Text('发现新版本'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('有更好的体验等你！'),
            const SizedBox(height: 8),
            Text('更新内容：\n$log', style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          if (!force)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('以后再说'),
            ),
          ElevatedButton(
            onPressed: () async {
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url));
                if (force && context.mounted) {
                  Navigator.pop(context);
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('无法打开下载链接')),
                  );
                }
              }
            },
            child: const Text('立即更新'),
          ),
        ],
      ),
    );
  }
}
