import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_container.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  RegisterScreenState createState() => RegisterScreenState();
}

class RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _userCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  final TextEditingController _nickCtrl = TextEditingController();
  final TextEditingController _mailCtrl = TextEditingController();
  final TextEditingController _codeCtrl = TextEditingController();
  bool _isSubmitting = false;
  bool _sendingCode = false;
  int _countdown = 0;

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

  Future<void> _sendVerificationCode() async {
    if (_mailCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("请先填写邮箱")));
      return;
    }
    setState(() => _sendingCode = true);
    try {
      await ApiService.sendVerificationCode(_mailCtrl.text);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("验证码已发送，请查收邮箱")));
        _startCountdown();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("发送失败: $e")));
      }
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  void _doRegister() async {
    setState(() => _isSubmitting = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await auth.register(_userCtrl.text, _passCtrl.text, _nickCtrl.text,
          _mailCtrl.text, _codeCtrl.text);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("注册成功，请登录")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("注册失败: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const GlassAppBarBackground(),title: const Text("注册账号")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            const Text(
              "新成员登记",
              style: TextStyle(
                  fontSize: 24,
                  color: Color(0xFFB8860B),
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            _field("账号", _userCtrl),
            _field("密码", _passCtrl, obs: true),
            _field("昵称", _nickCtrl),
            _field("邮箱", _mailCtrl),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeCtrl,
                    decoration: const InputDecoration(labelText: "验证码"),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: (_sendingCode || _countdown > 0)
                      ? null
                      : _sendVerificationCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB8860B),
                    foregroundColor: const Color(0xFF0a0e1a),
                  ),
                  child: Text(_countdown > 0 ? "$_countdown 秒" : "获取验证码"),
                ),
              ],
            ),
            const SizedBox(height: 50),
            _isSubmitting
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 55)),
                    onPressed: _doRegister,
                    child: const Text("确认注册"),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {bool obs = false}) {
    return TextField(
        controller: ctrl,
        obscureText: obs,
        decoration: InputDecoration(labelText: label));
  }
}
