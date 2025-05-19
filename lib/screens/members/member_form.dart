import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chit_fund_flutter/models/member.dart';
import 'package:chit_fund_flutter/services/database_service.dart';
import 'package:chit_fund_flutter/services/sync_service_new.dart';
import 'package:chit_fund_flutter/services/utility_service.dart';
import 'package:chit_fund_flutter/widgets/form_fields.dart';
import 'package:chit_fund_flutter/widgets/image_picker_widget.dart';

class MemberForm extends StatefulWidget {
  final Member? member;
  final Function? onSuccess;

  const MemberForm({
    Key? key,
    this.member,
    this.onSuccess,
  }) : super(key: key);

  @override
  State<MemberForm> createState() => _MemberFormState();
}

class _MemberFormState extends State<MemberForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _joinDateController = TextEditingController();
  final _coAadhaarController = TextEditingController();
  final _coNameController = TextEditingController();
  final _coPhoneController = TextEditingController();

  Uint8List? _photo;
  Uint8List? _aadhaarDoc;
  Uint8List? _coPhoto;
  Uint8List? _coAadhaarDoc;

  bool _isLoading = false;
  bool _hasCoApplicant = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    if (widget.member != null) {
      _nameController.text = widget.member!.name;
      _aadhaarController.text = widget.member!.aadhaar;
      _phoneController.text = widget.member!.phone;
      _addressController.text = widget.member!.address;
      _joinDateController.text = widget.member!.joinDate;
      _photo = widget.member!.photo;
      _aadhaarDoc = widget.member!.aadhaarDoc;

      if (widget.member!.coAadhaar != null && widget.member!.coAadhaar!.isNotEmpty) {
        _hasCoApplicant = true;
        _coAadhaarController.text = widget.member!.coAadhaar!;
        _coNameController.text = widget.member!.coName ?? '';
        _coPhoneController.text = widget.member!.coPhone ?? '';
        _coPhoto = widget.member!.coPhoto;
        _coAadhaarDoc = widget.member!.coAadhaarDoc;
      }
    } else {
      // Set default join date to today
      _joinDateController.text = UtilityService.getCurrentDate();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aadhaarController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _joinDateController.dispose();
    _coAadhaarController.dispose();
    _coNameController.dispose();
    _coPhoneController.dispose();
    super.dispose();
  }

  Future<void> _saveMember() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final member = Member(
        aadhaar: _aadhaarController.text.trim(),
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        joinDate: _joinDateController.text,
        photo: _photo,
        aadhaarDoc: _aadhaarDoc,
        coAadhaar: _hasCoApplicant ? _coAadhaarController.text.trim() : null,
        coName: _hasCoApplicant ? _coNameController.text.trim() : null,
        coPhone: _hasCoApplicant ? _coPhoneController.text.trim() : null,
        coPhoto: _hasCoApplicant ? _coPhoto : null,
        coAadhaarDoc: _hasCoApplicant ? _coAadhaarDoc : null,
      );

      final dbService = DatabaseService();
      await dbService.insertMember(member);

      // Sync changes to Drive
      final syncService = Provider.of<SyncService>(context, listen: false);
      await syncService.syncAfterChanges();

      if (widget.onSuccess != null) {
        widget.onSuccess!();
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Member saved successfully'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error saving member: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.member != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Member' : 'Add Member'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
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

                    // Member details section
                    const Text(
                      'Member Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Member photo
                    Center(
                      child: ImagePickerWidget(
                        initialImage: _photo,
                        onImageSelected: (image) {
                          setState(() {
                            _photo = image;
                          });
                        },
                        title: 'Member Photo',
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Member form fields
                    FormTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      hint: 'Enter member\'s full name',
                      prefixIcon: Icons.person,
                      isRequired: true,
                    ),
                    FormAadhaarField(
                      controller: _aadhaarController,
                      isRequired: true,
                      enabled: !isEditing, // Can't edit Aadhaar if updating
                    ),
                    FormPhoneField(
                      controller: _phoneController,
                      isRequired: true,
                    ),
                    FormTextField(
                      controller: _addressController,
                      label: 'Address',
                      hint: 'Enter member\'s address',
                      prefixIcon: Icons.home,
                      isRequired: true,
                      maxLines: 3,
                    ),
                    FormDateField(
                      controller: _joinDateController,
                      label: 'Join Date',
                      isRequired: true,
                      lastDate: DateTime.now(),
                    ),

                    // Aadhaar document
                    const SizedBox(height: 16),
                    Center(
                      child: ImagePickerWidget(
                        initialImage: _aadhaarDoc,
                        onImageSelected: (image) {
                          setState(() {
                            _aadhaarDoc = image;
                          });
                        },
                        title: 'Aadhaar Document',
                        allowDocument: true,
                        height: 200,
                        width: double.infinity,
                      ),
                    ),

                    // Co-applicant section
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Checkbox(
                          value: _hasCoApplicant,
                          onChanged: (value) {
                            setState(() {
                              _hasCoApplicant = value ?? false;
                            });
                          },
                        ),
                        const Text('Add Co-applicant'),
                      ],
                    ),

                    if (_hasCoApplicant) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Co-applicant Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Co-applicant photo
                      Center(
                        child: ImagePickerWidget(
                          initialImage: _coPhoto,
                          onImageSelected: (image) {
                            setState(() {
                              _coPhoto = image;
                            });
                          },
                          title: 'Co-applicant Photo',
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Co-applicant form fields
                      FormTextField(
                        controller: _coNameController,
                        label: 'Co-applicant Name',
                        hint: 'Enter co-applicant\'s full name',
                        prefixIcon: Icons.person,
                        isRequired: _hasCoApplicant,
                      ),
                      FormAadhaarField(
                        controller: _coAadhaarController,
                        label: 'Co-applicant Aadhaar',
                        isRequired: _hasCoApplicant,
                      ),
                      FormPhoneField(
                        controller: _coPhoneController,
                        label: 'Co-applicant Phone',
                        isRequired: _hasCoApplicant,
                      ),

                      // Co-applicant Aadhaar document
                      const SizedBox(height: 16),
                      Center(
                        child: ImagePickerWidget(
                          initialImage: _coAadhaarDoc,
                          onImageSelected: (image) {
                            setState(() {
                              _coAadhaarDoc = image;
                            });
                          },
                          title: 'Co-applicant Aadhaar Document',
                          allowDocument: true,
                          height: 200,
                          width: double.infinity,
                        ),
                      ),
                    ],

                    // Submit button
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveMember,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(isEditing ? 'Update Member' : 'Save Member'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}