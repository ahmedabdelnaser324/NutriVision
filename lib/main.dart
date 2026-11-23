import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_theme.dart';
import 'firebase_options.dart';
import 'screens/analyze_screen.dart';
import 'screens/barcode_screen.dart';
import 'screens/diary_screen.dart';
import 'screens/home_screen.dart';
import 'screens/meal_detail_screen.dart';
import 'screens/nutrition_summary_screen.dart';
import 'screens/review_screen.dart';
import 'screens/splash_screen.dart';
import 'services/diary_controller.dart';
import 'services/meal_repository.dart';
import 'services/user_profile.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ربط متحكم اليومية بقاعدة بيانات Firestore
  DiaryController.instance = DiaryController(FirestoreMealRepository());

  // تحميل بيانات اليومية والبروفايل بأمان لو في مستخدم مسجل دخول
  try {
    await Future.wait([
      DiaryController.instance.load(),
      UserProfile.load(),
    ]);
  } catch (_) {}

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const SofrahApp());
}

class SofrahApp extends StatelessWidget {
  const SofrahApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'سفرة',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: const Locale('ar'),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: const SplashScreen(),
      routes: {
        '/main': (_) => const HomeScreen(),
        '/diary': (_) => const DiaryScreen(),
        '/stats': (_) => NutritionSummaryScreen(),
        '/account': (_) => const _AccountPlaceholderScreen(),
        '/analyze': (_) => const AnalyzeScreen(),
        '/review': (_) => const ReviewScreen(),
        '/barcode': (_) => const BarcodeScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/meal-detail') {
          final mealId = settings.arguments as String? ?? '';
          return MaterialPageRoute(
            builder: (_) => MealDetailScreen(mealId: mealId),
          );
        }
        return null;
      },
    );
  }
}

/// شاشة مؤقتة لحسابي لحين تنفيذ شاشة الحساب الكاملة
class _AccountPlaceholderScreen extends StatelessWidget {
  const _AccountPlaceholderScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('حسابي', style: AppText.title(18)),
      ),
      body: Center(
        child: Text(
          'شاشة حسابي قيد التنفيذ حالياً',
          style: AppText.body(15, color: AppColors.textSoft),
        ),
      ),
    );
  }
}