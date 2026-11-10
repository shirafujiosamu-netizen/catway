import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'map_screen.dart';
import '../forum/forum_screen.dart';
import '../profile/profile_screen.dart';
import '../../services/version_service.dart';
import '../../services/config_service.dart';
import '../../providers/user_provider.dart'; // 新增引入
import '../../widgets/glass_container.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const MapScreen(),
      const ForumScreen(),
      const ProfileScreen(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      VersionService.checkVersion(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: GlassContainer(
        margin: EdgeInsets.zero,
        padding: EdgeInsets.zero,
        borderRadius: 0,
        tintColor: Colors.white,
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          // 切换到“我的”tab 时，自动刷新用户资料（获赞数、关注数等）
          if (index == 2) {
            final userProvider =
                Provider.of<UserProvider>(context, listen: false);
            userProvider.refreshCurrentUser();
          }
        },
        selectedItemColor: const Color(0xFFB8860B),
        unselectedItemColor: const Color(0x99B8860B),
        items: [
          BottomNavigationBarItem(
              icon: const Icon(Icons.map), label: ConfigService.homeTabMap),
          BottomNavigationBarItem(
              icon: const Icon(Icons.forum), label: ConfigService.homeTabForum),
          BottomNavigationBarItem(
              icon: const Icon(Icons.person),
              label: ConfigService.homeTabProfile),
        ],
        ),
      ),
    );
  }
}
