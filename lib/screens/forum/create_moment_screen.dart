import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../services/config_service.dart';
import '../../widgets/glass_container.dart';

class CreateMomentScreen extends StatefulWidget {
  const CreateMomentScreen({super.key});

  @override
  CreateMomentScreenState createState() => CreateMomentScreenState();
}

class CreateMomentScreenState extends State<CreateMomentScreen> {
  final TextEditingController _contentController = TextEditingController();
  final List<XFile> _images = [];
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;

  Future<void> _pickImages() async {
    try {
      final List<XFile> selectedImages = await _picker.pickMultiImage();
      if (selectedImages.isNotEmpty) {
        setState(() {
          _images.addAll(selectedImages);
          if (_images.length > ConfigService.maxMomentImages) {
            _images.removeRange(ConfigService.maxMomentImages, _images.length);
          }
        });
      }
    } catch (e) {
      _showSnackBar('选择图片失败: $e');
    }
  }

  Future<void> _submit() async {
    debugPrint('开始提交动态');
    // 允许内容为空，只要有图片即可
    if (_contentController.text.trim().isEmpty && _images.isEmpty) {
      _showSnackBar('请填写内容或上传图片');
      return;
    }
    if (_contentController.text.length > ConfigService.maxMomentContentLength) {
      _showSnackBar('内容不能超过${ConfigService.maxMomentContentLength}字');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      List<String> imageUrls = [];
      for (var img in _images) {
        final url = await ApiService.uploadImage(img);
        if (url.isEmpty) {
          throw Exception('图片上传失败，返回空URL');
        }
        imageUrls.add(url);
        debugPrint('图片上传成功: $url');
      }

      final momentData = {
        'content': _contentController.text.trim(),
        'images': imageUrls,
      };
      debugPrint('动态数据: $momentData');
      await ApiService.createMoment(momentData);
      debugPrint('动态发布成功');
      if (mounted) {
        Navigator.pop(context);
        _showSnackBar('动态发布成功');
      }
    } catch (e) {
      debugPrint('发布动态失败: $e');
      // 提供更详细的错误信息
      String errorMsg = '发布失败';
      if (e.toString().contains('500')) {
        errorMsg = '服务器错误，请稍后重试';
      } else if (e.toString().contains('timeout')) {
        errorMsg = '网络超时，请检查网络';
      } else {
        errorMsg = '发布失败: $e';
      }
      _showSnackBar(errorMsg);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const GlassAppBarBackground(),
        title: const Text('发布动态'),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submit,
            child: const Text('发布',
                style: TextStyle(
                    color: Color(0xFFB8860B), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _contentController,
                  decoration: const InputDecoration(
                    hintText: '分享你的想法...（选填）',
                    border: InputBorder.none,
                    counterText: '',
                  ),
                  maxLines: 8,
                  maxLength: ConfigService.maxMomentContentLength,
                ),
                const Divider(),
                Text('图片（最多${ConfigService.maxMomentImages}张）',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _images.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _images.length) {
                      return GestureDetector(
                        onTap: _pickImages,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child:
                              const Icon(Icons.add_photo_alternate, size: 40),
                        ),
                      );
                    }
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(File(_images[index].path),
                            fit: BoxFit.cover),
                        Positioned(
                          right: 0,
                          child: IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            onPressed: () =>
                                setState(() => _images.removeAt(index)),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
          if (_isSubmitting)
            const ModalBarrier(dismissible: false, color: Colors.black54),
          if (_isSubmitting) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
