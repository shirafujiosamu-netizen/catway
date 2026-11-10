import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/config_service.dart';
import 'forgot_password_screen.dart'; // 新增导入

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _handleLogin() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final success =
          await auth.login(_usernameController.text, _passwordController.text);
      if (success && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/home');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        // 提取用户友好的错误信息
        String errorMsg = '登录失败';
        final errorStr = e.toString();
        if (errorStr.contains('401') || errorStr.contains('用户名或密码错误')) {
          errorMsg = '用户名或密码错误';
        } else if (errorStr.contains('403') || errorStr.contains('封禁')) {
          errorMsg = '账号已被封禁，请联系管理员';
        } else if (errorStr.contains('500')) {
          errorMsg = '服务器错误，请稍后重试';
        } else if (errorStr.contains('timeout')) {
          errorMsg = '网络超时，请检查网络连接';
        } else if (errorStr.contains('SocketException')) {
          errorMsg = '无法连接服务器，请检查网络';
        } else {
          errorMsg = '登录失败: $e';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final primaryColor = Color(
        int.parse(ConfigService.primaryColor.substring(1), radix: 16) +
            0xFF000000);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 120),
            Text(
              ConfigService.appName,
              style: TextStyle(
                color: primaryColor,
                fontSize: 40,
                fontWeight: FontWeight.w900,
                letterSpacing: 5,
              ),
            ),
            Text(
              ConfigService.loginWelcome,
              style: const TextStyle(
                color: const Color(0xFFB8860B),
                fontSize: 16,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 80),
            _buildInput("账号", _usernameController, Icons.person_outline),
            const SizedBox(height: 30),
            _buildInput("密码", _passwordController, Icons.lock_outline,
                obscure: true),
            const SizedBox(height: 20),
            // 新增：忘记密码链接
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ForgotPasswordScreen()),
                  );
                },
                child: Text(
                  '忘记密码？',
                  style: TextStyle(color: primaryColor),
                ),
              ),
            ),
            const SizedBox(height: 40),
            auth.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5))),
                    onPressed: _handleLogin,
                    child: const Text("登录"),
                  ),
            const SizedBox(height: 20),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pushNamed(context, '/register'),
                child: Text(
                  "注册账号",
                  style: TextStyle(color: primaryColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(
      String label, TextEditingController controller, IconData icon,
      {bool obscure = false}) {
    final primaryColor = Color(
        int.parse(ConfigService.primaryColor.substring(1), radix: 16) +
            0xFF000000);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
              color: primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        TextField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(prefixIcon: Icon(icon, size: 20)),
        ),
      ],
    );
  }
}
