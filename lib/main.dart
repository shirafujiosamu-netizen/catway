import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/config_service.dart';
import 'services/api_service.dart';
import 'providers/auth_provider.dart';
import 'providers/user_provider.dart';
import 'screens/auth/splash_screen.dart'; // 新增
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';

/// 全局导航键，供 ApiService 在收到 401（登录态失效）时跳回登录页
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// 金色系调色板（白金配色：白底 + 金色点缀）
const Color kGold = Color(0xFFD4AF37);       // 主金（亮金色，标题/图标/强调）
const Color kGoldDark = Color(0xFFB8860B);   // 次金（暗金，次要文字/低对比场景）
const Color kGoldLight = Color(0xFFE8C547);  // 亮金（高亮/点缀）
const Color kWarmWhite = Color(0xFFFAF9F6);   // 暖白背景
const Color kSurface = Color(0xFFFFFFFF);      // 纯白面板

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ConfigService.loadConfig();
  ApiService.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

/// 白金全局背景（暖白渐变 + 极淡金色光晕）
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 暖白渐变基底
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF7F5F0), // 暖白
                Color(0xFFFAF9F6), // 近纯白
                Color(0xFFF5F3EE), // 微暖灰白
              ],
            ),
          ),
        ),
        // 极淡金色光斑（右上角）
        Positioned(
          top: -60,
          right: -80,
          child: Container(
            width: 300,
            height: 300,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0x10B8860B), Color(0x00000000)], // 金色 6% → 透明
              ),
            ),
          ),
        ),
        // 极淡金色光斑（左下角）
        Positioned(
          bottom: -100,
          left: -60,
          child: Container(
            width: 280,
            height: 280,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0x08B8860B), Color(0x00000000)], // 金色 3% → 透明
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    // 收到 401 时清空登录态并跳回登录页（token 失效/过期后让用户重新登录一次）
    ApiService.onUnauthorized = () {
      final a = Provider.of<AuthProvider>(context, listen: false);
      a.logout();
      navigatorKey.currentState
          ?.pushNamedAndRemoveUntil('/login', (route) => false);
    };
    if (auth.isLoading) {
      return MaterialApp(
        home: Scaffold(
          backgroundColor: kWarmWhite,
          body: const Center(child: CircularProgressIndicator(color: kGold)),
        ),
      );
    }

    return MaterialApp(
      title: ConfigService.appName,
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: kWarmWhite,
        // 金色主调
        primaryColor: kGold,
        primaryColorDark: kGoldDark,
        primaryColorLight: kGoldLight,
        splashColor: kGold.withOpacity(0.15),
        hoverColor: kGold.withOpacity(0.08),
        hintColor: const Color(0xFFB0A898),
        dividerColor: kGold.withOpacity(0.15),
        iconTheme: const IconThemeData(color: kGoldDark),
        primaryIconTheme: const IconThemeData(color: kGold),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: kGoldDark),
          actionsIconTheme: const IconThemeData(color: kGoldDark),
          titleTextStyle: const TextStyle(
              color: Color(0xFF2D2D2D), fontSize: 20, fontWeight: FontWeight.w600),
          toolbarTextStyle: const TextStyle(color: Color(0xFF4A4A4A), fontSize: 16),
        ),
        colorScheme: ColorScheme.light(
          primary: kGold,
          secondary: kGoldLight,
          onPrimary: Colors.white,
          onSurface: const Color(0xFF2D2D2D),
          surface: kSurface,
          background: kWarmWhite,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: Color(0xFF1A1A1A)),
          displayMedium: TextStyle(color: Color(0xFF1A1A1A)),
          displaySmall: TextStyle(color: Color(0xFF333333)),
          headlineLarge: TextStyle(color: kGoldDark, fontWeight: FontWeight.w700),
          headlineMedium: TextStyle(color: kGoldDark, fontWeight: FontWeight.w600),
          headlineSmall: TextStyle(color: kGoldDark, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(color: Color(0xFF2D2D2D), fontWeight: FontWeight.w600),
          titleMedium: TextStyle(color: Color(0xFF444444)),
          titleSmall: TextStyle(color: Color(0xFF555555)),
          bodyLarge: TextStyle(color: Color(0xFF333333)),
          bodyMedium: TextStyle(color: Color(0xFF555555)),
          bodySmall: TextStyle(color: Color(0xFF777777)),
          labelLarge: TextStyle(color: kGold, fontWeight: FontWeight.bold),
          labelMedium: TextStyle(color: kGoldDark),
          labelSmall: TextStyle(color: Color(0xFF999999)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kGold,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: kGold,
            side: BorderSide(color: kGold.withOpacity(0.5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: kGold),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: kGold,
          foregroundColor: Colors.white,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: kGold,
          unselectedItemColor: Color(0xFFAAAAAA),
          selectedIconTheme: IconThemeData(color: kGold, size: 26),
          unselectedIconTheme: IconThemeData(color: Color(0xFFBBBBBB), size: 22),
          selectedLabelStyle: TextStyle(color: kGold, fontWeight: FontWeight.w600),
          unselectedLabelStyle: TextStyle(color: Color(0xFFAAAAAA)),
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        dialogTheme: DialogTheme(
          backgroundColor: Colors.white,
          titleTextStyle:
              const TextStyle(color: Color(0xFF1A1A1A), fontSize: 20, fontWeight: FontWeight.w600),
          contentTextStyle: const TextStyle(color: Color(0xFF444444), fontSize: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: kGold.withOpacity(0.25)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          labelStyle: const TextStyle(color: kGoldDark),
          hintStyle: const TextStyle(color: Color(0xFFBBBBBB)),
          prefixIconColor: kGold,
          suffixIconColor: kGold,
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: kGold.withOpacity(0.30)),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: kGold, width: 2),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: kGold.withOpacity(0.30)),
          ),
        ),
        cardTheme: CardTheme(
          color: Colors.white,
          elevation: 1,
          shadowColor: Colors.black.withOpacity(0.06),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: kGold.withOpacity(0.15)),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: kGold.withOpacity(0.08),
          selectedColor: kGold.withOpacity(0.12),
          disabledColor: kGold.withOpacity(0.1),
          labelStyle: const TextStyle(color: kGoldDark),
          secondaryLabelStyle: const TextStyle(color: Color(0xFF666666)),
          brightness: Brightness.light,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: kGold.withOpacity(0.25)),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          textColor: Color(0xFF333333),
          iconColor: kGoldDark,
        ),
      ),
      builder: (context, child) => AppBackground(child: child!),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}
