import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chit_fund_flutter/models/loan.dart';
import 'package:chit_fund_flutter/models/member.dart';
import 'package:chit_fund_flutter/services/database_service.dart';
import 'package:chit_fund_flutter/services/sync_service_new.dart';
import 'package:chit_fund_flutter/services/utility_service.dart';
import 'package:chit_fund_flutter/widgets/form_fields.dart';
import 'package:chit_fund_flutter/widgets/image_picker_widget.dart';

class LoanForm extends StatefulWidget {
  final Loan? loan;
  final Function? onSuccess;

  const LoanForm({
    Key? key,
    this.loan,
    this.onSuccess,
  }) : super(key: key);

  @override
  State<LoanForm> createState() => _LoanFormState();
}

class _LoanFormState extends State<LoanForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _interestRateController = TextEditingController();
  final _durationController = TextEditingController();
  final _startDateController = TextEditingController();
  final _disbursedAmountController = TextEditingController();
  final _chequeNumberController = TextEditingController();
  final _bankNameController = TextEditingController();

  String? _selectedMemberAadhaar;
  String? _selectedCoApplicantAadhaar;
  List<Member> _members = [];
  List<Member> _coApplicants = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  Uint8List? _chequeFile;
  List<Uint8List> _assetFiles = [];

  // EMI calculation preview
  double _emiAmount = 0;
  double _disbursedAmount = 0;
  double _totalInterest = 0;
  bool _useCustomEMI = true; // Default to custom EMI calculation
  List<Map<String, dynamic>> _emiSchedule = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbService = DatabaseService();
      final members = await dbService.getAllMembers();

      setState(() {
        _members = members;
        _coApplicants = members;
      });

      if (widget.loan != null) {
        // Initialize form with loan data
        _selectedMemberAadhaar = widget.loan!.memberAadhaar;
        _selectedCoApplicantAadhaar = widget.loan!.coApplicantAadhaar;
        _amountController.text = widget.loan!.amount.toString();
        _interestRateController.text = widget.loan!.interestRate.toString();
        _durationController.text = widget.loan!.duration.toString();
        _startDateController.text = widget.loan!.startDate;
        _disbursedAmountController.text = widget.loan!.disbursedAmount.toString();

        // Load cheque details
        final cheques = await dbService.getLoanCheques(widget.loan!.loanId!);
        if (cheques.isNotEmpty) {
          final cheque = cheques.first;
          _chequeNumberController.text = cheque.chequeNumber;
          _bankNameController.text = cheque.bankName;
          _chequeFile = cheque.file;
        }

        // Load asset files
        final assets = await dbService.getLoanAssets(widget.loan!.loanId!);
        _assetFiles = assets.map((asset) => asset.file!).toList();

        // Calculate EMI preview
        _calculateEMI();
      } else {
        // Set default start date to today
        _startDateController.text = UtilityService.getCurrentDate();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading data: $e';
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
    _interestRateController.dispose();
    _durationController.dispose();
    _startDateController.dispose();
    _disbursedAmountController.dispose();
    _chequeNumberController.dispose();
    _bankNameController.dispose();
    super.dispose();
  }

  void _calculateEMI() {
    try {
      final amount = double.tryParse(_amountController.text) ?? 0;
      final rate = double.tryParse(_interestRateController.text) ?? 0;
      final duration = int.tryParse(_durationController.text) ?? 0;
      final startDate = _startDateController.text;

      if (amount > 0 && rate > 0 && duration > 0 && startDate.isNotEmpty) {
        if (_useCustomEMI) {
          // Use custom EMI calculation with prepaid interest
          final emiDetails = UtilityService.calculateCustomEMI(amount, rate, duration);
          final schedule = UtilityService.generateCustomEMISchedule(
            amount,
            rate,
            duration,
            startDate,
          );

          setState(() {
            _emiAmount = emiDetails["emi"];
            _disbursedAmount = emiDetails["disbursed_amount"];
            _totalInterest = emiDetails["total_interest"];
            _emiSchedule = schedule;
            _disbursedAmountController.text = _disbursedAmount.toStringAsFixed(2);
          });
        } else {
          // Use standard EMI calculation
          final emi = UtilityService.calculateEMI(amount, rate, duration);
          final schedule = UtilityService.generateAmortizationSchedule(
            amount,
            rate,
            duration,
            startDate,
          );

          setState(() {
            _emiAmount = emi;
            _disbursedAmount = amount;
            _totalInterest = emi * duration - amount;
            _emiSchedule = schedule;
            _disbursedAmountController.text = amount.toStringAsFixed(2);
          });
        }
      }
    } catch (e) {
      debugPrint('Error calculating EMI: $e');
    }
  }

  Future<void> _saveLoan() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedMemberAadhaar == null) {
      setState(() {
        _errorMessage = 'Please select a member';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final dbService = DatabaseService();

      // Create loan object
      final loan = Loan(
        memberAadhaar: _selectedMemberAadhaar!,
        coApplicantAadhaar: _selectedCoApplicantAadhaar,
        amount: double.parse(_amountController.text),
        interestRate: double.parse(_interestRateController.text),
        duration: int.parse(_durationController.text),
        startDate: _startDateController.text,
        disbursedAmount: double.parse(_disbursedAmountController.text),
      );

      // Save loan
      final loanId = await dbService.insertLoan(loan);

      // Save cheque if provided
      if (_chequeNumberController.text.isNotEmpty && _bankNameController.text.isNotEmpty) {
        final cheque = LoanCheque(
          loanId: loanId,
          chequeNumber: _chequeNumberController.text,
          bankName: _bankNameController.text,
          file: _chequeFile,
        );
        await dbService.insertLoanCheque(cheque);
      }

      // Save asset files
      for (final assetFile in _assetFiles) {
        final asset = LoanAsset(
          loanId: loanId,
          file: assetFile,
        );
        await dbService.insertLoanAsset(asset);
      }

      // Generate EMI schedule
      for (final emi in _emiSchedule) {
        final loanEmi = LoanEMI(
          loanId: loanId,
          dueDate: emi['due_date'],
          amount: emi['emi'],
          principal: emi['principal'],
          interest: emi['interest'],
          balance: emi['balance'],
        );
        await dbService.insertLoanEMI(loanEmi);
      }

      // Sync changes to Drive
      final syncService = Provider.of<SyncService>(context, listen: false);
      await syncService.syncAfterChanges();

      if (widget.onSuccess != null) {
        widget.onSuccess!();
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loan saved successfully'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error saving loan: $e';
      });
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _addAssetFile() async {
    final assetFile = await UtilityService.pickDocument();
    if (assetFile != null) {
      setState(() {
        _assetFiles.add(assetFile);
      });
    }
  }

  void _removeAssetFile(int index) {
    setState(() {
      _assetFiles.removeAt(index);
    });
  }
  
  void _showEMIPreview() {
    if (_emiAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter loan details first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('EMI Preview'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Loan summary
              const Text(
                'Loan Summary',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              
              // Loan amount
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Loan Amount:'),
                  Text(
                    UtilityService.formatCurrency(
                      double.tryParse(_amountController.text) ?? 0
                    ),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              
              // Interest rate
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Interest Rate:'),
                  Text(
                    '${_interestRateController.text}%',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              
              // Duration
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Duration:'),
                  Text(
                    '${_durationController.text} months',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              
              // Total interest
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Interest:'),
                  Text(
                    UtilityService.formatCurrency(_totalInterest),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              
              // Disbursed amount
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Disbursed Amount:'),
                  Text(
                    UtilityService.formatCurrency(_disbursedAmount),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              
              // Monthly EMI
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Monthly EMI:'),
                  Text(
                    UtilityService.formatCurrency(_emiAmount),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4), // Added space
              
              // Last EMI Due Date
              if (_emiSchedule.isNotEmpty) // Only show if schedule is generated
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Last EMI Due Date:'),
                    Text(
                      UtilityService.formatDate(_emiSchedule.last['due_date']),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              
              const Divider(height: 24),
              
              // EMI Schedule
              const Text(
                'EMI Schedule',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              
              // Schedule headers
              Row(
                children: const [
                  Expanded(
                    flex: 1,
                    child: Text(
                      'Month',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Due Date',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'EMI',
                      style: TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              
              // Schedule rows (show first 5 months)
              ..._emiSchedule.take(5).map((emi) => Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Text(emi['month'].toString()),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(UtilityService.formatDate(emi['due_date'])),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      UtilityService.formatCurrency(emi['emi']),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              )).toList(),
              
              // Show more indicator if there are more than 5 months
              if (_emiSchedule.length > 5)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Center(child: Text('...')),
                ),
              
              // Explanation of prepaid interest model
              if (_useCustomEMI)
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Note: This loan uses a prepaid interest model. The interest is deducted from the loan amount upfront, and you will receive the disbursed amount.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _saveLoan();
            },
            child: const Text('Confirm & Create Loan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.loan != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Loan' : 'Create Loan'),
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
                      Text('Saving loan data...'),
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

                        // Member selection
                        const Text(
                          'Loan Applicant',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Select Member *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          value: _selectedMemberAadhaar,
                          items: _members.map((member) {
                            return DropdownMenuItem<String>(
                              value: member.aadhaar,
                              child: Text('${member.name} (${member.phone})'),
                            );
                          }).toList(),
                          onChanged: isEditing
                              ? null
                              : (value) {
                                  setState(() {
                                    _selectedMemberAadhaar = value;
                                    // Update co-applicants list to exclude selected member
                                    _coApplicants = _members
                                        .where((m) => m.aadhaar != value)
                                        .toList();
                                  });
                                },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a member';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Co-applicant selection
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Select Co-Applicant (Optional)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          value: _selectedCoApplicantAadhaar,
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('None'),
                            ),
                            ..._coApplicants.map((member) {
                              return DropdownMenuItem<String>(
                                value: member.aadhaar,
                                child: Text('${member.name} (${member.phone})'),
                              );
                            }).toList(),
                          ],
                          onChanged: isEditing
                              ? null
                              : (value) {
                                  setState(() {
                                    _selectedCoApplicantAadhaar = value;
                                  });
                                },
                        ),
                        const SizedBox(height: 24),

                        // Loan details
                        const Text(
                          'Loan Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // EMI calculation type toggle
                        Row(
                          children: [
                            Checkbox(
                              value: _useCustomEMI,
                              onChanged: (value) {
                                setState(() {
                                  _useCustomEMI = value ?? true;
                                  // Recalculate EMI with the new method
                                  _calculateEMI();
                                });
                              },
                            ),
                            const Text('Use prepaid interest model'),
                            Tooltip(
                              message: 'In this model, interest is deducted upfront from the loan amount',
                              child: Icon(Icons.info_outline, size: 16, color: Colors.blue.shade300),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        FormNumberField(
                          controller: _amountController,
                          label: 'Loan Amount',
                          hint: 'Enter loan amount',
                          prefixIcon: Icons.currency_rupee,
                          isRequired: true,
                          allowDecimal: true,
                          onChanged: (_) => _calculateEMI(),
                        ),
                        FormNumberField(
                          controller: _interestRateController,
                          label: 'Interest Rate (%)',
                          hint: 'Enter annual interest rate',
                          prefixIcon: Icons.percent,
                          isRequired: true,
                          allowDecimal: true,
                          onChanged: (_) => _calculateEMI(),
                        ),
                        FormNumberField(
                          controller: _durationController,
                          label: 'Duration (Months)',
                          hint: 'Enter loan duration in months',
                          prefixIcon: Icons.calendar_month,
                          isRequired: true,
                          onChanged: (_) => _calculateEMI(),
                        ),
                        FormDateField(
                          controller: _startDateController,
                          label: 'Start Date',
                          isRequired: true,
                          onDateSelected: (_) => _calculateEMI(),
                        ),
                        FormNumberField(
                          controller: _disbursedAmountController,
                          label: 'Disbursed Amount',
                          hint: 'Enter amount actually disbursed',
                          prefixIcon: Icons.money,
                          isRequired: true,
                          allowDecimal: true,
                          enabled: !_useCustomEMI, // Disable when using custom EMI
                        ),
                        
                        // EMI Preview Card
                        if (_emiAmount > 0)
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'EMI Preview',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Monthly EMI:'),
                                    Text(
                                      UtilityService.formatCurrency(_emiAmount),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Disbursed Amount:'),
                                    Text(
                                      UtilityService.formatCurrency(_disbursedAmount),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Center(
                                  child: ElevatedButton.icon(
                                    onPressed: _showEMIPreview,
                                    icon: const Icon(Icons.preview),
                                    label: const Text('View Full EMI Schedule'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 24),

                        // Cheque details
                        const Text(
                          'Cheque Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        FormTextField(
                          controller: _chequeNumberController,
                          label: 'Cheque Number',
                          hint: 'Enter cheque number',
                          prefixIcon: Icons.payment,
                        ),
                        FormTextField(
                          controller: _bankNameController,
                          label: 'Bank Name',
                          hint: 'Enter bank name',
                          prefixIcon: Icons.account_balance,
                        ),
                        const SizedBox(height: 16),

                        // Cheque image
                        Center(
                          child: ImagePickerWidget(
                            initialImage: _chequeFile,
                            onImageSelected: (image) {
                              setState(() {
                                _chequeFile = image;
                              });
                            },
                            title: 'Cheque Image',
                            allowDocument: true,
                            height: 200,
                            width: double.infinity,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Asset files
                        const Text(
                          'Asset Documents',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Asset files list
                        if (_assetFiles.isNotEmpty) ...[
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _assetFiles.length,
                            itemBuilder: (context, index) {
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: const Icon(Icons.file_present),
                                  title: Text('Asset Document ${index + 1}'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _removeAssetFile(index),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Add asset button
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: _addAssetFile,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Asset Document'),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // EMI Preview
                        if (_emiAmount > 0) ...[
                          const Text(
                            'EMI Preview',
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
                                    'Monthly EMI: ${UtilityService.formatCurrency(_emiAmount)}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Total Repayment: ${UtilityService.formatCurrency(_emiAmount * int.parse(_durationController.text))}',
                                  ),
                                  Text(
                                    'Total Interest: ${UtilityService.formatCurrency((_emiAmount * int.parse(_durationController.text)) - double.parse(_amountController.text))}',
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Show first few EMIs
                          ExpansionTile(
                            title: const Text('View EMI Schedule'),
                            children: [
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('Month')),
                                    DataColumn(label: Text('Due Date')),
                                    DataColumn(label: Text('EMI')),
                                    DataColumn(label: Text('Principal')),
                                    DataColumn(label: Text('Interest')),
                                    DataColumn(label: Text('Balance')),
                                  ],
                                  rows: _emiSchedule
                                      .take(5) // Show first 5 EMIs
                                      .map((emi) {
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(emi['month'].toString())),
                                        DataCell(Text(UtilityService.formatDate(emi['due_date']))),
                                        DataCell(Text(UtilityService.formatCurrency(emi['emi']))),
                                        DataCell(Text(UtilityService.formatCurrency(emi['principal']))),
                                        DataCell(Text(UtilityService.formatCurrency(emi['interest']))),
                                        DataCell(Text(UtilityService.formatCurrency(emi['balance']))),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                              if (_emiSchedule.length > 5)
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    '... and ${_emiSchedule.length - 5} more EMIs',
                                    style: const TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 32),

                        // Submit button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _showEMIPreview,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(isEditing ? 'Preview & Update Loan' : 'Preview & Create Loan'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
