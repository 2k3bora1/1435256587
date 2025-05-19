import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/foundation.dart';
import 'package:chit_fund_flutter/models/user.dart';
import 'package:chit_fund_flutter/services/database_service.dart';
import 'package:chit_fund_flutter/services/storage_service.dart';

class AuthService with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final StorageService _storageService = StorageService();
  
  User? _currentUser;
  User? get currentUser => _currentUser;
  
  bool get isLoggedIn => _currentUser != null;
  
  // Initialize auth state
  Future<void> init() async {
    final username = await _storageService.read(key: 'username');
    if (username != null) {
      final user = await _dbService.getUser(username);
      if (user != null) {
        _currentUser = user;
        notifyListeners();
      }
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
  
  // Logout
  Future<void> logout() async {
    _currentUser = null;
    await _storageService.delete(key: 'username');
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