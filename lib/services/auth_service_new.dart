import 'dart:io';
import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:chit_fund_flutter/models/user.dart';
import 'package:chit_fund_flutter/services/database_service.dart';
import 'package:chit_fund_flutter/services/storage_service.dart';

class AuthService with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final StorageService _storageService = StorageService();
  
  // Only initialize GoogleSignIn on supported platforms
  final GoogleSignIn? _googleSignIn = !kIsWeb && (Platform.isAndroid || Platform.isIOS) 
      ? GoogleSignIn(
          scopes: [
            'email',
            'https://www.googleapis.com/auth/drive.file',
          ],
        ) 
      : null;
  
  User? _currentUser;
  GoogleSignInAccount? _googleUser;
  bool _isAuthenticated = false; // For platforms without Google Sign-In
  
  User? get currentUser => _currentUser;
  GoogleSignInAccount? get googleUser => _googleUser;
  
  bool get isLoggedIn => _currentUser != null;
  bool get isGoogleSignedIn => _googleUser != null || _isAuthenticated;
  bool get isGoogleSignInSupported => _googleSignIn != null;
  
  // Initialize auth state
  Future<void> init() async {
    // Check for stored user credentials
    final username = await _storageService.read(key: 'username');
    if (username != null) {
      final user = await _dbService.getUser(username);
      if (user != null) {
        _currentUser = user;
        notifyListeners();
      }
    }
    
    // Check for Google Sign-In state
    try {
      _googleUser = await _googleSignIn?.signInSilently();
      if (_googleUser != null) {
        // If we have a Google user but no local user, create one
        if (_currentUser == null) {
          final googleEmail = _googleUser!.email;
          final existingUser = await _dbService.getUser(googleEmail);
          
          if (existingUser != null) {
            _currentUser = existingUser;
          } else {
            // Create a new user based on Google account
            final newUser = User(
              username: googleEmail,
              passwordHash: '', // No password for Google users
              companyName: _googleUser!.displayName ?? 'Google User',
              aadhaar: '',
              phone: '',
            );
            
            await _dbService.insertUser(newUser);
            _currentUser = newUser;
            await _storageService.write(key: 'username', value: googleEmail);
          }
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error checking Google Sign-In state: $e');
    }
  }
  
  // Register a new user
  Future<bool> register(String username, String password, String companyName, String aadhaar, String phone) async {
    try {
      // Check if username already exists
      final existingUser = await _dbService.getUser(username);
      if (existingUser != null) {
        return false;
      }
      
      // Hash the password
      final passwordHash = BCrypt.hashpw(password, BCrypt.gensalt());
      
      // Create and save the user
      final user = User(
        username: username,
        passwordHash: passwordHash,
        companyName: companyName,
        aadhaar: aadhaar,
        phone: phone,
      );
      
      await _dbService.insertUser(user);
      
      // Set as current user
      _currentUser = user;
      await _storageService.write(key: 'username', value: username);
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error during registration: $e');
      return false;
    }
  }
  
  // Login with username and password
  Future<bool> login(String username, String password) async {
    try {
      final user = await _dbService.getUser(username);
      if (user == null) {
        return false;
      }
      
      // Verify password
      final passwordMatch = BCrypt.checkpw(password, user.passwordHash);
      if (!passwordMatch) {
        return false;
      }
      
      // Set as current user
      _currentUser = user;
      await _storageService.write(key: 'username', value: username);
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error during login: $e');
      return false;
    }
  }
  
  // Silent Google Sign-In (without UI)
  Future<bool> silentGoogleSignIn() async {
    try {
      // For platforms that support Google Sign-In
      if (_googleSignIn != null) {
        try {
          final googleUser = await _googleSignIn!.signInSilently();
          if (googleUser == null) {
            return false;
          }
          
          _googleUser = googleUser;
          notifyListeners();
          return true;
        } catch (e) {
          debugPrint('Error during Google Sign-In: $e');
          // Fall back to simple authentication for desktop
        }
      }
      
      // For platforms without Google Sign-In support (like Windows)
      // Check if we have a stored authentication state
      final isAuthenticated = await _storageService.read(key: 'isAuthenticated');
      if (isAuthenticated == 'true') {
        _isAuthenticated = true;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error during silent authentication: $e');
      return false;
    }
  }
  
  // Sign in with Google (with UI) or alternative auth for unsupported platforms
  Future<bool> signInWithGoogle() async {
    try {
      // For platforms that support Google Sign-In
      if (_googleSignIn != null) {
        try {
          final googleUser = await _googleSignIn!.signIn();
          if (googleUser == null) {
            // User canceled the sign-in
            return false;
          }
          
          _googleUser = googleUser;
          notifyListeners();
          return true;
        } catch (e) {
          debugPrint('Error during Google Sign-In: $e');
          // Fall back to simple authentication for desktop
        }
      }
      
      // For platforms without Google Sign-In support (like Windows)
      // Just mark as authenticated for drive access
      _isAuthenticated = true;
      await _storageService.write(key: 'isAuthenticated', value: 'true');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error during authentication: $e');
      return false;
    }
  }
  
  // Check if there are any existing users in the database
  Future<bool> hasExistingUsers() async {
    try {
      final users = await _dbService.getAllUsers();
      return users.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking for existing users: $e');
      return false;
    }
  }
  
  // Get all users
  Future<List<User>> getAllUsers() async {
    try {
      return await _dbService.getAllUsers();
    } catch (e) {
      debugPrint('Error getting all users: $e');
      return [];
    }
  }
  
  // Verify password for a specific user
  Future<bool> verifyPassword(String username, String password) async {
    try {
      final user = await _dbService.getUser(username);
      if (user == null) {
        return false;
      }
      
      // Verify password
      return BCrypt.checkpw(password, user.passwordHash);
    } catch (e) {
      debugPrint('Error verifying password: $e');
      return false;
    }
  }
  
  // Logout
  Future<void> logout() async {
    _currentUser = null;
    
    // Sign out from Google if signed in on supported platforms
    if (_googleSignIn != null && _googleUser != null) {
      await _googleSignIn!.signOut();
      _googleUser = null;
    }
    
    // Reset authentication state for platforms without Google Sign-In
    _isAuthenticated = false;
    
    await _storageService.delete(key: 'username');
    await _storageService.delete(key: 'isAuthenticated');
    notifyListeners();
  }
  
  // Update user profile
  Future<bool> updateProfile(String companyName, String aadhaar, String phone) async {
    if (_currentUser == null) {
      return false;
    }
    
    try {
      final updatedUser = _currentUser!.copyWith(
        companyName: companyName,
        aadhaar: aadhaar,
        phone: phone,
      );
      
      await _dbService.updateUser(updatedUser);
      _currentUser = updatedUser;
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      return false;
    }
  }
  
  // Change password
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    if (_currentUser == null) {
      return false;
    }
    
    try {
      // Verify current password
      final passwordMatch = BCrypt.checkpw(currentPassword, _currentUser!.passwordHash);
      if (!passwordMatch) {
        return false;
      }
      
      // Hash the new password
      final newPasswordHash = BCrypt.hashpw(newPassword, BCrypt.gensalt());
      
      // Update user
      final updatedUser = _currentUser!.copyWith(
        passwordHash: newPasswordHash,
      );
      
      await _dbService.updateUser(updatedUser);
      _currentUser = updatedUser;
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error changing password: $e');
      return false;
    }
  }
}