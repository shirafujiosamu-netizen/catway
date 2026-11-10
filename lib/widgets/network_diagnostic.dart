import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class NetworkDiagnostic {
  static const String baseUrl = 'https://theregolithjar.monster';

  static Future<void> checkBackendHealth(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 5)));
      final response = await dio.get('$baseUrl/health');
      if (response.statusCode == 200 && response.data['status'] == 'OK') {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('后端服务正常'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text('后端返回异常: ${response.data}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('连接失败: $e\n请检查：\n1. 后端是否运行 (pm2 list)\n2. 手机网络是否通畅\n3. 域名证书是否有效'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}
