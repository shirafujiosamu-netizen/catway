import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // 等待 AuthProvider 的 autoLogin 完成，然后自动导航
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndNavigate();
    });
  }

  Future<void> _checkAuthAndNavigate() async {
    // 防止 widget 已卸载后仍尝试使用 context（导致 Unhandled Exception）
    if (!mounted) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    // autoLogin 已在 AuthProvider 构造函数中启动，这里只需等待它的结果
    // 通过监听 auth 的状态变化，当 isLoading 变为 false 时说明 autoLogin 完毕
    // 为了简单，延迟一小段时间以确保 autoLogin 执行完毕（或使用 Future.delayed 等待）
    // 更稳健的做法是监听 auth 的变化，但这里我们直接使用通知机制
    await Future.delayed(const Duration(milliseconds: 100)); // 给 autoLogin 一点时间
    if (!mounted) return;

    if (auth.isLoading) {
      // 如果还在加载，监听直到完成
      auth.addListener(_onAuthStateChanged);
    } else {
      _navigateBasedOnAuth(auth.isAuthenticated);
    }
  }

  void _onAuthStateChanged() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isLoading) {
      auth.removeListener(_onAuthStateChanged);
      if (mounted) _navigateBasedOnAuth(auth.isAuthenticated);
    }
  }

  void _navigateBasedOnAuth(bool isAuthenticated) {
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(
      isAuthenticated ? '/home' : '/login',
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 可替换为应用 Logo
            Icon(Icons.map, size: 80, color: Color(0xFFB8860B)),
            SizedBox(height: 16),
            Text(
              '猫径CatWay',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFB8860B)),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
