import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'admin_APP/screens/login_page.dart';
import 'admin_APP/viewModels/supply_viewmodel.dart';
import 'admin_APP/viewModels/citizen_viewmodel.dart';
import 'admin_APP/viewModels/emergency_viewmodel.dart';
import 'admin_APP/viewModels/allocation_viewmodel.dart';

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
        home: const LoginPage(),
      ),
    );
  }
}