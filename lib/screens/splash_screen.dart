import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chit_fund_flutter/config/constants.dart';
import 'package:chit_fund_flutter/services/auth_service_new.dart';
import 'package:chit_fund_flutter/services/sync_service_new.dart';
import 'package:chit_fund_flutter/screens/login/login_screen.dart';
import 'package:chit_fund_flutter/screens/dashboard/dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isLoading = true;
  String _statusMessage = 'Initializing...';
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Check authentication status
      final authService = Provider.of<AuthService>(context, listen: false);
      
      setState(() {
        _statusMessage = 'Checking authentication...';
      });
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (authService.isLoggedIn) {
        // User is logged in, sync data
        setState(() {
          _statusMessage = 'Synchronizing data...';
        });
        
        final syncService = Provider.of<SyncService>(context, listen: false);
        final syncResult = await syncService.syncWithDrive();
        
        if (!syncResult) {
          setState(() {
            _hasError = true;
            _errorMessage = 'Failed to synchronize data: ${syncService.lastError}';
          });
          return;
        }
        
        if (!mounted) return;
        
        // Navigate to dashboard
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      } else {
        // User is not logged in, navigate to login screen
        if (!mounted) return;
        
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'An error occurred: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo
                const Icon(
                  Icons.account_balance,
                  size: 80,
                  color: primaryColor,
                ),
                const SizedBox(height: 24),
                
                // App Name
                const Text(
                  appName,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                
                // App Version
                Text(
                  'v$appVersion',
                  style: const TextStyle(
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 48),
                
                // Loading Indicator or Error
                if (_isLoading) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ] else if (_hasError) ...[
                  const Icon(
                    Icons.error_outline,
                    color: errorColor,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: errorColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage ?? 'An unknown error occurred',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: errorColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _initialize,
                    child: const Text('Retry'),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}