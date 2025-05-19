import 'package:flutter/material.dart';
import 'package:chit_fund_flutter/services/database_service.dart';

class DatabaseResetScreen extends StatefulWidget {
  const DatabaseResetScreen({Key? key}) : super(key: key);

  @override
  State<DatabaseResetScreen> createState() => _DatabaseResetScreenState();
}

class _DatabaseResetScreenState extends State<DatabaseResetScreen> {
  bool _isResetting = false;
  String _message = '';

  Future<void> _resetDatabase() async {
    setState(() {
      _isResetting = true;
      _message = 'Resetting database...';
    });

    try {
      final dbService = DatabaseService();
      await dbService.deleteDatabase();
      
      // Force database recreation
      await dbService.database;
      
      setState(() {
        _message = 'Database reset successfully. Please restart the app.';
      });
    } catch (e) {
      setState(() {
        _message = 'Error resetting database: $e';
      });
    } finally {
      setState(() {
        _isResetting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Reset'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Warning: This will delete all data in the database!',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (_isResetting)
                const CircularProgressIndicator()
              else
                ElevatedButton(
                  onPressed: _resetDatabase,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: const Text('Reset Database'),
                ),
              const SizedBox(height: 24),
              if (_message.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _message.contains('Error')
                        ? Colors.red.shade100
                        : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _message,
                    style: TextStyle(
                      color: _message.contains('Error')
                          ? Colors.red.shade900
                          : Colors.green.shade900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}