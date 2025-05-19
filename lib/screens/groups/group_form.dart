import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chit_fund_flutter/models/group.dart';
import 'package:chit_fund_flutter/services/database_service.dart';
import 'package:chit_fund_flutter/services/sync_service.dart';
import 'package:chit_fund_flutter/widgets/form_fields.dart';

class GroupForm extends StatefulWidget {
  final Group? group;
  final Function? onSuccess;

  const GroupForm({
    Key? key,
    this.group,
    this.onSuccess,
  }) : super(key: key);

  @override
  State<GroupForm> createState() => _GroupFormState();
}

class _GroupFormState extends State<GroupForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _initializeForm();
  }
  
  void _initializeForm() {
    if (widget.group != null) {
      _nameController.text = widget.group!.groupName;
      _descriptionController.text = widget.group!.description ?? '';
    }
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
  
  Future<void> _saveGroup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    
    try {
      final dbService = DatabaseService();
      
      // Create group object
      final group = Group(
        groupId: widget.group?.groupId,
        groupName: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        createdDate: widget.group?.createdDate ?? DateTime.now(),
      );
      
      // Save group
      await dbService.insertGroup(group);
      
      // Sync changes to Drive
      final syncService = Provider.of<SyncService>(context, listen: false);
      await syncService.syncAfterChanges();
      
      if (widget.onSuccess != null) {
        widget.onSuccess!();
      }
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Group saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error saving group: $e';
      });
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isEditing = widget.group != null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Group' : 'Create Group'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isSaving
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Saving group...'),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Error message
                        if (_errorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error, color: Colors.red),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        // Group Information
                        const Text(
                          'Group Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        FormTextField(
                          controller: _nameController,
                          label: 'Group Name',
                          hint: 'Enter group name',
                          prefixIcon: Icons.group,
                          isRequired: true,
                        ),
                        
                        FormTextField(
                          controller: _descriptionController,
                          label: 'Description',
                          hint: 'Enter description (optional)',
                          prefixIcon: Icons.description,
                          maxLines: 3,
                        ),
                        
                        // Submit button
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _saveGroup,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(isEditing ? 'Update Group' : 'Create Group'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
