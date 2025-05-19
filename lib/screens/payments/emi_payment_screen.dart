import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'package:chit_fund_flutter/models/loan.dart';
import 'package:chit_fund_flutter/models/member.dart';
import 'package:chit_fund_flutter/services/database_service.dart';
import 'package:chit_fund_flutter/services/sync_service.dart';
import 'package:chit_fund_flutter/services/utility_service.dart';
import 'package:chit_fund_flutter/widgets/form_fields.dart';

class EMIPaymentScreen extends StatefulWidget {
  final LoanEMI? emi;
  final Loan? loan;
  final Member? member;

  const EMIPaymentScreen({
    Key? key,
    this.emi,
    this.loan,
    this.member,
  }) : super(key: key);

  @override
  State<EMIPaymentScreen> createState() => _EMIPaymentScreenState();
}

class _EMIPaymentScreenState extends State<EMIPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _paymentDateController = TextEditingController();
  final _receiptNumberController = TextEditingController();
  
  String _paymentType = 'Cash';
  final List<String> _paymentTypes = ['Cash', 'Cheque', 'Bank Transfer', 'UPI'];
  
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  
  LoanEMI? _emi;
  Loan? _loan;
  Member? _member;
  
  @override
  void initState() {
    super.initState();
    _initializeForm();
  }
  
  Future<void> _initializeForm() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      _emi = widget.emi;
      _loan = widget.loan;
      _member = widget.member;
      
      // If EMI is provided but not loan or member, fetch them
      if (_emi != null) {
        if (_loan == null) {
          final dbService = DatabaseService();
          _loan = await dbService.getLoan(_emi!.loanId);
        }
        
        if (_member == null && _loan != null) {
          final dbService = DatabaseService();
          _member = await dbService.getMember(_loan!.memberAadhaar);
        }
        
        // Set default amount to EMI amount
        _amountController.text = _emi!.amount.toString();
      }
      
      // Set default payment date to today
      _paymentDateController.text = UtilityService.getCurrentDate();
      
      // Generate receipt number
      _receiptNumberController.text = UtilityService.generateReceiptNumber();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error initializing form: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  void dispose() {
    _amountController.dispose();
    _paymentDateController.dispose();
    _receiptNumberController.dispose();
    super.dispose();
  }
  
  Future<void> _savePayment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (_emi == null || _loan == null || _member == null) {
      setState(() {
        _errorMessage = 'Missing required data for payment';
      });
      return;
    }
    
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    
    try {
      final dbService = DatabaseService();
      
      // Create payment record
      final payment = LoanEMIPayment(
        emiId: _emi!.emiId!,
        paymentDate: _paymentDateController.text,
        amount: double.parse(_amountController.text),
        paymentType: _paymentType,
        receiptNumber: _receiptNumberController.text,
      );
      
      await dbService.insertLoanEMIPayment(payment);
      
      // Update EMI as paid
      final updatedEMI = _emi!.copyWith(
        paid: 1,
        paymentDate: _paymentDateController.text,
      );
      
      await dbService.updateLoanEMI(updatedEMI);
      
      // Sync changes to Drive
      final syncService = Provider.of<SyncService>(context, listen: false);
      await syncService.syncAfterChanges();
      
      // Generate receipt PDF
      final receiptData = await UtilityService.generateReceiptPDF(
        receiptNumber: _receiptNumberController.text,
        date: _paymentDateController.text,
        memberName: _member!.name,
        memberAadhaar: _member!.aadhaar,
        paymentType: _paymentType,
        amount: double.parse(_amountController.text),
        description: 'Loan EMI Payment for ${DateFormat('MMMM yyyy').format(DateTime.parse(_emi!.dueDate))}',
      );
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Show receipt and options
      _showReceiptOptions(receiptData);
    } catch (e) {
      setState(() {
        _errorMessage = 'Error saving payment: $e';
      });
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }
  
  void _showReceiptOptions(Uint8List receiptData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Successful'),
        content: const Text('What would you like to do with the receipt?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, true); // Return success to previous screen
            },
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await UtilityService.printPDF(receiptData);
              if (!mounted) return;
              Navigator.pop(context, true); // Return success to previous screen
            },
            child: const Text('Print Receipt'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final path = await UtilityService.savePDF(
                receiptData,
                'receipt_${_receiptNumberController.text}.pdf',
              );
              if (!mounted) return;
              
              if (path != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Receipt saved to: $path'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to save receipt'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
              
              Navigator.pop(context, true); // Return success to previous screen
            },
            child: const Text('Save Receipt'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collect EMI Payment'),
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
                      Text('Processing payment...'),
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
                        
                        // Member and Loan Info
                        if (_member != null && _loan != null) ...[
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      _member!.photo != null
                                          ? CircleAvatar(
                                              backgroundImage: MemoryImage(_member!.photo!),
                                            )
                                          : CircleAvatar(
                                              child: Text(
                                                _member!.name.isNotEmpty
                                                    ? _member!.name[0].toUpperCase()
                                                    : '?',
                                              ),
                                            ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _member!.name,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              _member!.phone,
                                              style: const TextStyle(
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 24),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Loan Amount',
                                              style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12,
                                              ),
                                            ),
                                            Text(
                                              UtilityService.formatCurrency(_loan!.amount),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Interest Rate',
                                              style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12,
                                              ),
                                            ),
                                            Text(
                                              '${_loan!.interestRate}%',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Duration',
                                              style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12,
                                              ),
                                            ),
                                            Text(
                                              '${_loan!.duration} months',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        
                        // EMI Info
                        if (_emi != null) ...[
                          const Text(
                            'EMI Details',
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
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Due Date:'),
                                      Text(
                                        UtilityService.formatDate(_emi!.dueDate),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 24),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('EMI Amount:'),
                                      Text(
                                        UtilityService.formatCurrency(_emi!.amount),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 24),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Principal:'),
                                      Text(
                                        UtilityService.formatCurrency(_emi!.principal),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Interest:'),
                                      Text(
                                        UtilityService.formatCurrency(_emi!.interest),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Remaining Balance:'),
                                      Text(
                                        UtilityService.formatCurrency(_emi!.balance),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        
                        // Payment Form
                        const Text(
                          'Payment Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        FormNumberField(
                          controller: _amountController,
                          label: 'Payment Amount',
                          hint: 'Enter payment amount',
                          prefixIcon: Icons.currency_rupee,
                          isRequired: true,
                          allowDecimal: true,
                        ),
                        
                        FormDropdownField<String>(
                          label: 'Payment Method',
                          value: _paymentType,
                          items: _paymentTypes.map((type) {
                            return DropdownMenuItem<String>(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _paymentType = value;
                              });
                            }
                          },
                          isRequired: true,
                        ),
                        
                        FormDateField(
                          controller: _paymentDateController,
                          label: 'Payment Date',
                          isRequired: true,
                        ),
                        
                        FormTextField(
                          controller: _receiptNumberController,
                          label: 'Receipt Number',
                          hint: 'Enter receipt number',
                          prefixIcon: Icons.receipt,
                          isRequired: true,
                        ),
                        
                        // Submit button
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _savePayment,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Process Payment'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
