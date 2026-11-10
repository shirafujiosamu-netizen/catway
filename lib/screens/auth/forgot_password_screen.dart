import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/config_service.dart';
import '../../widgets/glass_container.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ForgotPasswordScreenState createState() => ForgotPasswordScreenState();
}

class ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isSendingCode = false;
  bool _isSubmitting = false;
  int _countdown = 0;
  String _message = '';

  Color get _primaryColor {
    return Color(int.parse(ConfigService.primaryColor.substring(1), radix: 16) +
        0xFF000000);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    setState(() {
      _countdown = 60;
    });
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (_countdown == 0) return false;
      if (mounted) setState(() => _countdown--);
      return true;
    });
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage('请输入邮箱地址');
      return;
    }
    setState(() {
      _isSendingCode = true;
      _message = '';
    });
    try {
      await ApiService.forgotPassword(email);
      if (mounted) {
        _showMessage('验证码已发送，请查收邮箱');
        _startCountdown();
      }
    } catch (e) {
      String errorMsg = '发送失败';
      if (e.toString().contains('404')) {
        errorMsg = '该邮箱未注册';
      } else if (e.toString().contains('timeout')) {
        errorMsg = '网络超时，请稍后重试';
      } else {
        errorMsg = '发送失败: $e';
      }
      _showMessage(errorMsg);
    } finally {
      if (mounted) setState(() => _isSendingCode = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _message = '';
    });
    try {
      await ApiService.resetPassword(
        _emailController.text.trim(),
        _codeController.text.trim(),
        _passwordController.text.trim(),
      );
      if (mounted) {
        _showMessage('密码重置成功，请返回登录');
        // 延迟返回登录页
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      String errorMsg = '重置失败';
      if (e.toString().contains('400')) {
        errorMsg = '验证码错误或已过期';
      } else {
        errorMsg = '重置失败: $e';
      }
      _showMessage(errorMsg);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showMessage(String msg) {
    setState(() => _message = msg);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const GlassAppBarBackground(),
        title: const Text('忘记密码'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Text(
                '重置密码',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '请输入注册时使用的邮箱，我们将发送验证码',
                style: TextStyle(color: const Color(0xFFB8860B)),
              ),
              const SizedBox(height: 30),
              // 邮箱输入框 + 发送验证码按钮
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: '邮箱',
                  hintText: '输入注册邮箱',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入邮箱';
                  }
                  if (!value.contains('@')) {
                    return '请输入有效邮箱';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed:
                    (_isSendingCode || _countdown > 0) ? null : _sendCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: const Color(0xFF0a0e1a),
                ),
                child: Text(_countdown > 0 ? '$_countdown秒后重新发送' : '获取验证码'),
              ),
              const SizedBox(height: 24),
              // 验证码输入框
              TextFormField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '验证码',
                  hintText: '输入6位验证码',
                  prefixIcon: Icon(Icons.security),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入验证码';
                  }
                  if (value.trim().length != 6) {
                    return '验证码为6位数字';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // 新密码输入框
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '新密码',
                  hintText: '输入新密码',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入新密码';
                  }
                  if (value.trim().length < 6) {
                    return '密码长度至少6位';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              // 提示信息
              if (_message.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _message,
                    style: TextStyle(
                      color:
                          _message.contains('成功') ? Colors.green : Colors.red,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              // 提交按钮
              ElevatedButton(
                onPressed: _isSubmitting ? null : _resetPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: const Color(0xFF0a0e1a),
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(color: const Color(0xFF0a0e1a)),
                      )
                    : const Text('重置密码'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('返回登录'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
