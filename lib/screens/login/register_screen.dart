import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chit_fund_flutter/config/constants.dart';
import 'package:chit_fund_flutter/services/auth_service_new.dart';
import 'package:chit_fund_flutter/services/sync_service_new.dart';
import 'package:chit_fund_flutter/screens/dashboard/dashboard_screen.dart';

class RegisterScreen extends StatefulWidget {
  final bool hasExistingUsers;
  
  const RegisterScreen({
    Key? key, 
    this.hasExistingUsers = true,
  }) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _phoneController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  String _pageTitle = 'Create Account';
  
  @override
  void initState() {
    super.initState();
    if (!widget.hasExistingUsers) {
      setState(() {
        _pageTitle = 'Create First Admin Account';
      });
    }
  }
  
  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _companyNameController.dispose();
    _aadhaarController.dispose();
    _phoneController.dispose();
    _adminPasswordController.dispose();
    super.dispose();
  }
  
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      // If there are existing users, verify admin password first
      if (widget.hasExistingUsers) {
        // Get the first user (admin)
        final users = await authService.getAllUsers();
        if (users.isNotEmpty) {
          final adminUser = users.first;
          
          // Verify admin password
          final passwordMatch = await authService.verifyPassword(
            adminUser.username,
            _adminPasswordController.text,
          );
          
          if (!passwordMatch) {
            setState(() {
              _errorMessage = 'Invalid admin password';
              _isLoading = false;
            });
            return;
          }
        }
      }
      
      // Register the new user
      final success = await authService.register(
        _usernameController.text.trim(),
        _passwordController.text,
        _companyNameController.text.trim(),
        _aadhaarController.text.trim(),
        _phoneController.text.trim(),
      );
      
      if (success) {
        // Sync database after registration
        final syncService = Provider.of<SyncService>(context, listen: false);
        await syncService.syncAfterChanges();
        
        if (!mounted) return;
        
        // Navigate to dashboard
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      } else {
        setState(() {
          _errorMessage = 'Username already exists or registration failed';
        });
      }
    } catch (e) {
      setState(() {
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
      appBar: AppBar(
        title: Text(_pageTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Username Field
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a username';
                  }
                  if (value.length < 4) {
                    return 'Username must be at least 4 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Password Field
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Confirm Password Field
              TextFormField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your password';
                  }
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              
              // Company Name Field
              TextFormField(
                controller: _companyNameController,
                decoration: const InputDecoration(
                  labelText: 'Company Name',
                  prefixIcon: Icon(Icons.business),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your company name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Aadhaar Field
              TextFormField(
                controller: _aadhaarController,
                decoration: const InputDecoration(
                  labelText: 'Aadhaar Number',
                  prefixIcon: Icon(Icons.credit_card),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your Aadhaar number';
                  }
                  if (value.length != 12) {
                    return 'Aadhaar number must be 12 digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Phone Field
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  if (value.length < 10) {
                    return 'Please enter a valid phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              
              // Admin Password Field (only shown if there are existing users)
              if (widget.hasExistingUsers) ...[
                TextFormField(
                  controller: _adminPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Admin Password',
                    prefixIcon: Icon(Icons.admin_panel_settings),
                    helperText: 'Required for creating additional accounts',
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the admin password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
              ],
              
              // Error Message
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              
              // Register Button
              ElevatedButton(
                onPressed: _isLoading ? null : _register,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create Account'),
              ),
              const SizedBox(height: 16),
              
              // Back to Login
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Already have an account? Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}