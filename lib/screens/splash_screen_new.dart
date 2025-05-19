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
      final authService = Provider.of<AuthService>(context, listen: false);
      final syncService = Provider.of<SyncService>(context, listen: false);
      
      // Step 1: Connect to Google Drive or use service account
      setState(() {
        _statusMessage = 'Initializing database access...';
      });
      
      // Try to authenticate silently first
      final silentAuthResult = await authService.silentGoogleSignIn();

      // Step 2: Try to download database from Google Drive
      setState(() {
        _statusMessage = 'Checking for existing database...';
      });

      final downloadResult = await syncService.downloadFromDrive();

      // Step 3: Check if user is logged in
      setState(() {
        _statusMessage = 'Checking authentication...';
      });

      await authService.init(); // Refresh auth state after potential DB download

      if (authService.isLoggedIn) {
        // User is logged in, navigate to dashboard
        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      } else {
        // User is not logged in, check if we have any users in the database
        final hasExistingUsers = await authService.hasExistingUsers();

        if (!mounted) return;

        // Only prompt for Google Sign-In if silent auth failed AND there are no existing users
        if (!silentAuthResult && !hasExistingUsers) {
           setState(() {
             _statusMessage = 'Please authenticate to continue...';
           });

           final manualAuthResult = await authService.signInWithGoogle();

           if (!manualAuthResult) {
             setState(() {
               _hasError = true;
               _errorMessage = 'Authentication is required to use this app';
             });
             return;
           }
           // After successful manual auth, re-check login status
           await authService.init();
           if (authService.isLoggedIn) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const DashboardScreen()),
              );
              return;
           }
        }

        // Navigate to login screen with information about existing users
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => LoginScreen(hasExistingUsers: hasExistingUsers),
          ),
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
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
      ),
    );
  }
}
