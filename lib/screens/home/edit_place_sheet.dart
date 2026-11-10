import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../models/place.dart';

class EditPlaceSheet extends StatefulWidget {
  final Place place;
  final VoidCallback onUpdated;

  const EditPlaceSheet({
    super.key,
    required this.place,
    required this.onUpdated,
  });

  @override
  EditPlaceSheetState createState() => EditPlaceSheetState();
}

class EditPlaceSheetState extends State<EditPlaceSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  XFile? _selectedImage;
  bool _isSubmitting = false;

  String _selectedType = '谷店';
  final List<String> _placeTypes = const ['谷店', '牌店', '快闪', '主题餐厅', '桌游店'];

  List<dynamic> _addressSearchResults = [];
  bool _isSearchingAddress = false;
  Timer? _addressDebounce;
  late LatLng _currentPosition;

  static const String _amapKey = '2411588fd073e335c671b17068f81460';

  @override
  void initState() {
    super.initState();
    // 预填数据
    _nameController.text = widget.place.name;
    _addressController.text = widget.place.address;
    _tagsController.text = widget.place.tags.join(', ');
    _selectedType = widget.place.type.isNotEmpty ? widget.place.type : '谷店';
    _currentPosition = LatLng(widget.place.lat, widget.place.lng);

    _addressController.addListener(() {
      _addressDebounce?.cancel();
      _addressDebounce = Timer(const Duration(milliseconds: 500), () {
        _searchAddress(_addressController.text);
      });
    });
  }

  @override
  void dispose() {
    _addressDebounce?.cancel();
    super.dispose();
  }

  Future<void> _searchAddress(String keyword) async {
    if (keyword.trim().isEmpty) {
      if (mounted) setState(() => _addressSearchResults.clear());
      return;
    }
    if (mounted) setState(() => _isSearchingAddress = true);
    try {
      final dio = Dio();
      final response = await dio.get(
        'https://restapi.amap.com/v3/place/text',
        queryParameters: {
          'key': _amapKey,
          'keywords': keyword,
          'city': '上海',
          'output': 'JSON',
        },
      );
      if (response.data['status'] == '1') {
      if (mounted) {
          setState(() => _addressSearchResults = response.data['pois'] ?? []);
        }
      } else {
        if (mounted) setState(() => _addressSearchResults.clear());
      }
    } catch (e) {
      if (mounted) setState(() => _addressSearchResults.clear());
    } finally {
      if (mounted) setState(() => _isSearchingAddress = false);
    }
  }

  void _selectAddress(Map<String, dynamic> poi) {
    final lng = double.parse(poi['location'].split(',')[0]);
    final lat = double.parse(poi['location'].split(',')[1]);
    setState(() {
      _currentPosition = LatLng(lat, lng);
      _addressController.text = poi['name'] ?? '';
      _addressSearchResults.clear();
    });
  }

  Future<void> _relocate() async {
    if (_addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先输入地址')),
      );
      return;
    }
    if (mounted) setState(() => _isSearchingAddress = true);
    try {
      final dio = Dio();
      final response = await dio.get(
        'https://restapi.amap.com/v3/geocode/geo',
        queryParameters: {
          'key': _amapKey,
          'address': _addressController.text,
          'output': 'JSON',
        },
      );
      if (response.data['status'] == '1' &&
          response.data['geocodes'].isNotEmpty) {
        final location = response.data['geocodes'][0]['location'] as String;
        final parts = location.split(',');
        final lng = double.parse(parts[0]);
        final lat = double.parse(parts[1]);
        if (mounted) {
          setState(() => _currentPosition = LatLng(lat, lng));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('位置已更新')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未找到该地址')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('定位失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearchingAddress = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      CroppedFile? cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: '裁剪图片',
            toolbarColor: const Color(0xFF0C1018),
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: true,
          ),
          IOSUiSettings(title: '裁剪图片'),
        ],
      );
      if (cropped != null) {
        if (mounted) setState(() => _selectedImage = XFile(cropped.path));
      }
    }
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写地点名称')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      List<String> photoUrls = [];
      if (_selectedImage != null) {
        final url = await ApiService.uploadImage(_selectedImage!);
        photoUrls.add(url);
      } else if (widget.place.photos.isNotEmpty) {
        photoUrls = List<String>.from(widget.place.photos);
      }

      List<String> tags = [];
      if (_tagsController.text.trim().isNotEmpty) {
        tags = _tagsController.text
            .split(',')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toList();
      }

      final placeData = {
        'name': _nameController.text,
        'address': _addressController.text,
        'lat': _currentPosition.latitude,
        'lng': _currentPosition.longitude,
        'type': _selectedType,
        'photos': photoUrls,
        'tags': tags,
      };

      await ApiService.editPlace(widget.place.id, placeData);
      if (mounted) {
        Navigator.pop(context);
        widget.onUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('地点已更新')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('编辑失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.6), width: 1),
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
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    '编辑地点',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: '地点名称',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedType,
                    items: _placeTypes.map((type) {
                      return DropdownMenuItem(value: type, child: Text(type));
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedType = value!);
                    },
                    decoration: const InputDecoration(
                      labelText: '店铺类型',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _tagsController,
                    decoration: const InputDecoration(
                      labelText: '标签（多个标签用英文逗号分隔）',
                      hintText: '例如：扭蛋,手办,限定',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      labelText: '地址',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.my_location),
                        onPressed: _relocate,
                        tooltip: '重新定位',
                      ),
                    ),
                  ),
                  if (_isSearchingAddress)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (_addressSearchResults.isNotEmpty)
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        itemCount: _addressSearchResults.length,
                        itemBuilder: (context, index) {
                          final poi = _addressSearchResults[index];
                          return ListTile(
                            title: Text(poi['name'] ?? ''),
                            subtitle: Text(poi['address'] ?? ''),
                            onTap: () => _selectAddress(poi),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '坐标: ${_currentPosition.latitude.toStringAsFixed(6)}, ${_currentPosition.longitude.toStringAsFixed(6)}',
                          style:
                              const TextStyle(fontSize: 12, color: const Color(0xFFB8860B)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 150,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFB8860B)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _selectedImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(_selectedImage!.path),
                                fit: BoxFit.cover,
                              ),
                            )
                          : widget.place.photos.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    widget.place.photos.first,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : const Center(child: Text('点击上传照片')),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const CircularProgressIndicator()
                        : const Text('提交修改'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
