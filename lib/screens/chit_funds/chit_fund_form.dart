import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chit_fund_flutter/models/chit_fund.dart';
import 'package:chit_fund_flutter/services/database_service.dart';
import 'package:chit_fund_flutter/services/sync_service.dart';
import 'package:chit_fund_flutter/services/utility_service.dart';
import 'package:chit_fund_flutter/widgets/form_fields.dart';

class ChitFundForm extends StatefulWidget {
  final ChitFund? chitFund;
  final Function? onSuccess;

  const ChitFundForm({
    Key? key,
    this.chitFund,
    this.onSuccess,
  }) : super(key: key);

  @override
  State<ChitFundForm> createState() => _ChitFundFormState();
}

class _ChitFundFormState extends State<ChitFundForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _totalAmountController = TextEditingController();
  final _durationController = TextEditingController();
  final _memberCountController = TextEditingController();
  final _startDateController = TextEditingController();
  final _commissionRateController = TextEditingController();
  
  String _status = 'Active';
  final List<String> _statusOptions = ['Active', 'Completed', 'Cancelled', 'Pending'];
  
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _initializeForm();
  }
  
  void _initializeForm() {
    if (widget.chitFund != null) {
      _nameController.text = widget.chitFund!.chitName;
      _descriptionController.text = widget.chitFund!.description ?? '';
      _totalAmountController.text = widget.chitFund!.totalAmount.toString();
      _durationController.text = widget.chitFund!.duration.toString();
      _memberCountController.text = widget.chitFund!.memberCount.toString();
      _startDateController.text = widget.chitFund!.startDate;
      _commissionRateController.text = widget.chitFund!.commissionRate.toString();
      _status = widget.chitFund!.status;
    } else {
      // Set default values for new chit fund
      _startDateController.text = UtilityService.getCurrentDate();
      _commissionRateController.text = '5.0'; // Default commission rate
      _status = 'Active';
    }
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _totalAmountController.dispose();
    _durationController.dispose();
    _memberCountController.dispose();
    _startDateController.dispose();
    _commissionRateController.dispose();
    super.dispose();
  }
  
  Future<void> _saveChitFund() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    
    try {
      final dbService = DatabaseService();
      
      // Calculate monthly amount
      final totalAmount = double.parse(_totalAmountController.text);
      final duration = int.parse(_durationController.text);
      final memberCount = int.parse(_memberCountController.text);
      final monthlyAmount = totalAmount / duration;
      
      // Create chit fund object
      final chitFund = ChitFund(
        chitId: widget.chitFund?.chitId,
        chitName: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        totalAmount: totalAmount,
        duration: duration,
        memberCount: memberCount,
        startDate: _startDateController.text,
        commissionRate: double.parse(_commissionRateController.text),
        status: _status,
        currentCycle: widget.chitFund?.currentCycle ?? 0,
        nextAuctionDate: _calculateNextAuctionDate(),
      );
      
      // Save chit fund
      await dbService.insertChitFund(chitFund);
      
      // Sync changes to Drive
      final syncService = Provider.of<SyncService>(context, listen: false);
      await syncService.syncAfterChanges();
      
      if (widget.onSuccess != null) {
        widget.onSuccess!();
      }
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chit fund saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error saving chit fund: $e';
      });
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }
  
  String _calculateNextAuctionDate() {
    if (_status.toLowerCase() != 'active') {
      return '';
    }
    
    try {
      final startDate = DateTime.parse(_startDateController.text);
      // Set next auction date to 30 days from start date
      final nextAuctionDate = startDate.add(const Duration(days: 30));
      return nextAuctionDate.toIso8601String().split('T')[0];
    } catch (e) {
      return '';
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isEditing = widget.chitFund != null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Chit Fund' : 'Create Chit Fund'),
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
                      Text('Saving chit fund...'),
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
                        
                        // Basic Information
                        const Text(
                          'Basic Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        FormTextField(
                          controller: _nameController,
                          label: 'Chit Fund Name',
                          hint: 'Enter chit fund name',
                          prefixIcon: Icons.group_work,
                          isRequired: true,
                        ),
                        
                        FormTextField(
                          controller: _descriptionController,
                          label: 'Description',
                          hint: 'Enter description (optional)',
                          prefixIcon: Icons.description,
                          maxLines: 3,
                        ),
                        
                        FormDropdownField<String>(
                          label: 'Status',
                          value: _status,
                          items: _statusOptions.map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _status = value;
                              });
                            }
                          },
                          isRequired: true,
                        ),
                        
                        // Financial Details
                        const SizedBox(height: 24),
                        const Text(
                          'Financial Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        FormNumberField(
                          controller: _totalAmountController,
                          label: 'Total Amount',
                          hint: 'Enter total chit fund amount',
                          prefixIcon: Icons.currency_rupee,
                          isRequired: true,
                          allowDecimal: true,
                        ),
                        
                        FormNumberField(
                          controller: _durationController,
                          label: 'Duration (Months)',
                          hint: 'Enter duration in months',
                          prefixIcon: Icons.calendar_month,
                          isRequired: true,
                        ),
                        
                        FormNumberField(
                          controller: _memberCountController,
                          label: 'Number of Members',
                          hint: 'Enter number of members',
                          prefixIcon: Icons.people,
                          isRequired: true,
                        ),
                        
                        FormNumberField(
                          controller: _commissionRateController,
                          label: 'Commission Rate (%)',
                          hint: 'Enter commission percentage',
                          prefixIcon: Icons.percent,
                          isRequired: true,
                          allowDecimal: true,
                        ),
                        
                        FormDateField(
                          controller: _startDateController,
                          label: 'Start Date',
                          isRequired: true,
                        ),
                        
                        // Monthly contribution preview
                        if (_totalAmountController.text.isNotEmpty &&
                            _durationController.text.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const Text(
                            'Contribution Preview',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Monthly Contribution: ${UtilityService.formatCurrency(double.parse(_totalAmountController.text) / double.parse(_durationController.text))}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Per Member: ${UtilityService.formatCurrency(double.parse(_totalAmountController.text) / (double.parse(_durationController.text) * (_memberCountController.text.isNotEmpty ? double.parse(_memberCountController.text) : 1)))}',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        
                        // Submit button
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _saveChitFund,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(isEditing ? 'Update Chit Fund' : 'Create Chit Fund'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
