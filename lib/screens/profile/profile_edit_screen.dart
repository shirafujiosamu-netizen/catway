import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/api_service.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../widgets/glass_container.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ProfileEditScreenState createState() => ProfileEditScreenState();
}

class ProfileEditScreenState extends State<ProfileEditScreen> {
  late TextEditingController _nicknameController;
  late TextEditingController _bioController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<UserProvider>(context, listen: false).user;
    _nicknameController = TextEditingController(text: user?.nickname ?? '');
    _bioController = TextEditingController(text: user?.bio ?? '');
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.updateProfile(
        nickname: _nicknameController.text,
        bio: _bioController.text,
      );
      // 同步更新 AuthProvider 中的用户信息（避免下次登录时数据不一致）
      if (!mounted) return;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final updatedUser = userProvider.user;
      if (updatedUser != null) {
        // 注意：AuthProvider 中的 user 是私有变量，需要通过内部方法更新
        // 这里我们直接刷新 AuthProvider 的自动登录缓存（重新保存）
        await authProvider.refreshUser(updatedUser);
      }
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('资料更新成功')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新失败: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<XFile?> _pickImage() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
    return picked;
  }

  Future<XFile?> _cropImage(XFile file) async {
    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: file.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: '裁剪头像',
          toolbarColor: const Color(0xFFB8860B),
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(title: '裁剪头像'),
      ],
    );
    if (croppedFile == null) return null;
    return XFile(croppedFile.path);
  }

  Future<void> _uploadImage(XFile file, String type) async {
    final croppedFile = await _cropImage(file);
    if (croppedFile == null) return;

    setState(() => _isLoading = true);
    try {
      final imageUrl = await ApiService.uploadImage(croppedFile);
      if (!mounted) return;
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.updateProfile(
        nickname: _nicknameController.text,
        bio: _bioController.text,
        avatar: type == 'avatar' ? imageUrl : null,
        coverImage: type == 'coverImage' ? imageUrl : null,
      );
      // 同步更新 AuthProvider
      if (!mounted) return;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final updatedUser = userProvider.user;
      if (updatedUser != null) {
        await authProvider.refreshUser(updatedUser);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${type == 'avatar' ? '头像' : '背景'}更新成功')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('上传失败: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const GlassAppBarBackground(),
        title: const Text('编辑资料'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nicknameController,
              decoration: const InputDecoration(labelText: '昵称'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bioController,
              decoration: const InputDecoration(labelText: '个人简介'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('更换头像'),
              onTap: () async {
                final file = await _pickImage();
                if (file != null) {
                  await _uploadImage(file, 'avatar');
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('更换主页背景'),
              onTap: () async {
                final file = await _pickImage();
                if (file != null) {
                  await _uploadImage(file, 'coverImage');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
