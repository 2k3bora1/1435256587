import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:chit_fund_flutter/config/constants.dart';
import 'package:chit_fund_flutter/config/themes.dart';
import 'package:chit_fund_flutter/config/routes.dart';
import 'package:chit_fund_flutter/services/auth_service_new.dart';
import 'package:chit_fund_flutter/services/sync_service_new.dart';
import 'package:chit_fund_flutter/services/database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize sqflite_ffi for Windows
  if (Platform.isWindows || Platform.isLinux) {
    // Initialize FFI
    sqfliteFfiInit();
    // Change the default factory
    databaseFactory = databaseFactoryFfi;
  }
  
  // Initialize services
  final authService = AuthService();
  await authService.init();
  
  final syncService = SyncService();
  await syncService.init();
  
  // Initialize database
  final dbService = DatabaseService();
  await dbService.database;
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>(create: (_) => authService),
        ChangeNotifierProvider<SyncService>(create: (_) => syncService),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void dispose() {
    // Make sure to dispose the sync service to cancel the timer
    final syncService = Provider.of<SyncService>(context, listen: false);
    syncService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Access providers from the context
    final authService = Provider.of<AuthService>(context);
    final syncService = Provider.of<SyncService>(context);
    
    return MaterialApp(
      title: appName,
      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.splash,
      routes: AppRoutes.getRoutes(),
      debugShowCheckedModeBanner: false,
    );
  }
}
