import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../models/place.dart';
import '../../services/config_service.dart';
import '../../widgets/glass_container.dart';

class CreatePostScreen extends StatefulWidget {
  final String initialCategory;

  const CreatePostScreen({super.key, required this.initialCategory});

  @override
  CreatePostScreenState createState() => CreatePostScreenState();
}

class CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();
  final TextEditingController _keywordsController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  final List<XFile> _images = [];
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;

  // 扩展后的预设关键词列表
  final List<String> _presetKeywords = [
    // 已有基础词
    '吧唧', '亚克力', '手办', '扭蛋', '一番赏', '一番くじ', '限定', '一番賞', '景品',
    // 服饰/主题
    'Lolita', '汉服', 'jk制服', '主题咖啡厅',
    // 游戏/IP
    '阴阳师', '崩坏星穹铁道', '鸣潮', '偶像梦幻祭', '邦多利', '世界计划', '赛马娘',
    '快闪', '哈利波特', '鬼灭之刃', '咒术回战', '文豪野犬', '诡秘之主', '原神',
    '魔法少女小圆', '明日方舟', '崩铁', '败犬女主'
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _keywordsController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _insertPlaceTag() async {
    final TextEditingController searchController = TextEditingController();
    List<Place> searchResults = [];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateSheet) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(
                top: BorderSide(
                    color: Colors.white.withOpacity(0.6), width: 1),
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -4)),
              ],
            ),
            child: Column(
              children: [
                Container(
                  height: 4,
                  width: 40,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: '搜索地点名称或地址',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => searchController.clear(),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onSubmitted: (value) async {
                      if (value.trim().isEmpty) return;
                      setStateSheet(() => searchResults.clear());
                      try {
                        final places = await ApiService.searchPlaces(
                            keyword: value.trim());
                        setStateSheet(() => searchResults = places);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('搜索失败: $e')),
                        );
                      }
                    },
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      final place = searchResults[index];
                      return ListTile(
                        leading: place.photos.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(place.photos.first,
                                    width: 40, height: 40, fit: BoxFit.cover),
                              )
                            : const Icon(Icons.store),
                        title: Text(place.name),
                        subtitle: Text(place.address),
                        trailing: const Icon(Icons.add_location_alt),
                        onTap: () {
                          final marker = '[[place:${place.id}:${place.name}]]';
                          final text = _contentController.text;
                          final selection = _contentController.selection;
                          final newText = text.replaceRange(
                            selection.start,
                            selection.end,
                            marker,
                          );
                          _contentController.value = TextEditingValue(
                            text: newText,
                            selection: TextSelection.collapsed(
                                offset: selection.start + marker.length),
                          );
                          Navigator.pop(context);
                          _showSnackBar('已插入地点「${place.name}」');
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> selectedImages = await _picker.pickMultiImage();
      if (selectedImages.isNotEmpty) {
        setState(() {
          _images.addAll(selectedImages);
          if (_images.length > ConfigService.maxPostImages) {
            _images.removeRange(ConfigService.maxPostImages, _images.length);
          }
        });
      }
    } catch (e) {
      _showSnackBar('选择图片失败: $e');
    }
  }

  void _addKeyword(String keyword) {
    final current = _keywordsController.text.trim();
    if (current.isEmpty) {
      _keywordsController.text = keyword;
    } else {
      final keywordsSet = current.split(RegExp(r'\s+')).toSet();
      if (!keywordsSet.contains(keyword)) {
        _keywordsController.text = '$current $keyword';
      }
    }
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty) {
      _showSnackBar('请填写标题');
      return;
    }
    if (_keywordsController.text.trim().isEmpty) {
      _showSnackBar('请填写关键词');
      return;
    }
    if (_contentController.text.length > ConfigService.maxPostContentLength) {
      _showSnackBar('正文不能超过${ConfigService.maxPostContentLength}字');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      List<String> imageUrls = [];
      for (var img in _images) {
        final url = await ApiService.uploadImage(img);
        imageUrls.add(url);
      }

      final Map<String, dynamic> postData = {
        'title': _titleController.text.trim(),
        'summary': _summaryController.text.trim(),
        'keywords': _keywordsController.text.trim(),
        'content': _contentController.text.trim(),
        'category': widget.initialCategory,
        'images': imageUrls,
      };

      await ApiService.createPost(postData);
      if (mounted) {
        Navigator.pop(context);
        _showSnackBar('发布成功');
      }
    } catch (e) {
      _showSnackBar('发布失败: $e');
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
        title: Text('发布${widget.initialCategory}帖子'),
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
                // 标题
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: '标题 *',
                    hintText: '请输入标题',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 50,
                ),
                const SizedBox(height: 16),
                // 简介
                TextField(
                  controller: _summaryController,
                  decoration: const InputDecoration(
                    labelText: '简介（选填）',
                    hintText: '一句话概括',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  maxLength: 200,
                ),
                const SizedBox(height: 16),
                // 关键词输入 + 预设快捷选择（水平滚动）
                const Text('关键词 *',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: _keywordsController,
                  decoration: const InputDecoration(
                    hintText: '多个关键词用空格分隔，例如：吧唧 明日方舟 限定',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                // 水平滚动区域，限制高度
                SizedBox(
                  height: 80,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _presetKeywords.map((keyword) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(keyword),
                            onPressed: () => _addKeyword(keyword),
                            backgroundColor: const Color(0xFFFFF0B3),
                            labelStyle:
                                const TextStyle(color: Color(0xFF8B6508)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 正文 + @按钮
                Row(
                  children: [
                    const Expanded(
                      child: Text('正文 *',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.alternate_email,
                          color: Color(0xFFB8860B)),
                      onPressed: _insertPlaceTag,
                      tooltip: '插入地点',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _contentController,
                  decoration: InputDecoration(
                    hintText:
                        '最多${ConfigService.maxPostContentLength}字，点击 @ 按钮可插入地点卡片',
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 10,
                  maxLength: ConfigService.maxPostContentLength,
                ),
                const SizedBox(height: 16),
                // 图片上传
                Text(
                  '上传图片（最多${ConfigService.maxPostImages}张）',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
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
