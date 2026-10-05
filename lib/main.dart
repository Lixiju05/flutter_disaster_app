import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'admin_APP/screens/login_page.dart';
import 'admin_APP/viewModels/supply_viewmodel.dart';
import 'admin_APP/viewModels/citizen_viewmodel.dart';
import 'admin_APP/viewModels/emergency_viewmodel.dart';
import 'admin_APP/viewModels/allocation_viewmodel.dart';
import 'admin_APP/viewModels/weather_viewmodel.dart'; // 新增

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CitizenViewmodel()),
        ChangeNotifierProvider(create: (_) => EmergencyViewModel()),
        ChangeNotifierProvider(create: (_) => AdminSupplyViewModel()),
        ChangeNotifierProvider(create: (_) => AllocationViewModel()),
        ChangeNotifierProvider(create: (_) => WeatherViewModel()), // 新增
      ],
      child: MaterialApp(
        title: 'Flutter Disaster App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          scaffoldBackgroundColor: const Color(0xFFF4F7FB),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1E3A5F),
          ),
          useMaterial3: true,
        ),
        // 全站文字統一放大 10%，讓管理員閱讀更清楚
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.1),
          ),
          child: child!,
        ),
        home: const LoginPage(),
      ),
    );
  }
}