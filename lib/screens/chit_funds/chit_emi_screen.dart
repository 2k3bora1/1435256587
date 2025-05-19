import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:chit_fund_flutter/config/constants.dart';
import 'package:chit_fund_flutter/models/chit_fund.dart';
import 'package:chit_fund_flutter/models/member.dart';
import 'package:chit_fund_flutter/models/payment.dart';
import 'package:chit_fund_flutter/models/group.dart' as group;
import 'package:chit_fund_flutter/services/database_service.dart';
import 'package:chit_fund_flutter/services/sync_service_new.dart';
import 'package:chit_fund_flutter/widgets/custom_alert_dialog.dart';
import 'package:chit_fund_flutter/widgets/loading_indicator.dart';

class ChitEMIScreen extends StatefulWidget {
  final ChitFund chitFund;

  const ChitEMIScreen({
    Key? key,
    required this.chitFund,
  }) : super(key: key);

  @override
  State<ChitEMIScreen> createState() => _ChitEMIScreenState();
}

class _ChitEMIScreenState extends State<ChitEMIScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<ChitEMI> _emis = [];
  List<Member> _members = [];
  bool _isLoading = true;
  bool _showPaymentForm = false;
  
  // Selected EMI for payment
  ChitEMI? _selectedEMI;
  
  // Payment form controllers
  final TextEditingController _paymentDateController = TextEditingController();
  final TextEditingController _paymentAmountController = TextEditingController();
  final TextEditingController _receiptNumberController = TextEditingController();
  String _paymentType = 'Cash';

  @override
  void initState() {
    super.initState();
    _loadData();
    
    // Set default payment date to today
    _paymentDateController.text = DateTime.now().toIso8601String().split('T')[0];
  }

  @override
  void dispose() {
    _paymentDateController.dispose();
    _paymentAmountController.dispose();
    _receiptNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load EMIs for this chit fund
      final emis = await _dbService.getChitEMIs(widget.chitFund.chitId!);
      
      // Load member details
      final Set<String> memberAadhaarSet = emis.map((e) => e.aadhaar).toSet();
      List<Member> members = [];
      
      for (var aadhaar in memberAadhaarSet) {
        final member = await _dbService.getMember(aadhaar);
        if (member != null) {
          members.add(member);
        }
      }

      setState(() {
        _emis = emis;
        _members = members;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Error loading EMI data: $e');
    }
  }

  Future<void> _recordPayment() async {
    if (_selectedEMI == null) {
      _showErrorDialog('No EMI selected for payment');
      return;
    }

    if (_paymentDateController.text.isEmpty) {
      _showErrorDialog('Please select a payment date');
      return;
    }

    if (_paymentAmountController.text.isEmpty) {
      _showErrorDialog('Please enter a payment amount');
      return;
    }

    final paymentAmount = double.tryParse(_paymentAmountController.text);
    if (paymentAmount == null || paymentAmount <= 0) {
      _showErrorDialog('Please enter a valid payment amount');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Update the EMI as paid
      final updatedEMI = ChitEMI(
        emiId: _selectedEMI!.emiId,
        chitId: _selectedEMI!.chitId,
        aadhaar: _selectedEMI!.aadhaar,
        dueDate: _selectedEMI!.dueDate,
        amount: _selectedEMI!.amount,
        paid: 1,
        paymentDate: _paymentDateController.text,
      );

      await _dbService.updateChitEMI(updatedEMI);
      
      // Create a payment record
      final payment = group.EMIPayment(
        emiId: _selectedEMI!.emiId!,
        paymentDate: _paymentDateController.text,
        amount: paymentAmount,
        paymentType: _paymentType,
        receiptNumber: _receiptNumberController.text,
      );
      
      await _dbService.addChitEMIPayment(payment);
      
      // Mark changes as pending for sync
      final syncService = Provider.of<SyncService>(context, listen: false);
      await syncService.markChangesAsPending();

      // Reload data
      await _loadData();
      
      setState(() {
        _showPaymentForm = false;
        _selectedEMI = null;
        _paymentAmountController.clear();
        _receiptNumberController.clear();
        _paymentDateController.text = DateTime.now().toIso8601String().split('T')[0];
        _paymentType = 'Cash';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment recorded successfully')),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Error recording payment: $e');
    }
  }

  String _getMemberName(String aadhaar) {
    final member = _members.firstWhere(
      (m) => m.aadhaar == aadhaar,
      orElse: () => Member(
        aadhaar: aadhaar,
        name: 'Unknown Member',
        phone: '',
        address: '',
        joinDate: '',
      ),
    );
    
    return member.name;
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPaymentFormForEMI(ChitEMI emi) {
    setState(() {
      _selectedEMI = emi;
      _showPaymentForm = true;
      _paymentAmountController.text = emi.amount.toString();
      _paymentDateController.text = DateTime.now().toIso8601String().split('T')[0];
      _receiptNumberController.clear();
      _paymentType = 'Cash';
    });
  }

  @override
  Widget build(BuildContext context) {
    // Group EMIs by member
    final Map<String, List<ChitEMI>> emisByMember = {};
    for (var emi in _emis) {
      if (!emisByMember.containsKey(emi.aadhaar)) {
        emisByMember[emi.aadhaar] = [];
      }
      emisByMember[emi.aadhaar]!.add(emi);
    }
    
    // Count pending EMIs
    final int pendingEMIs = _emis.where((emi) => emi.paid == 0).length;
    
    // Calculate total amount collected and pending
    double totalCollected = 0;
    double totalPending = 0;
    
    for (var emi in _emis) {
      if (emi.paid == 1) {
        totalCollected += emi.amount;
      } else {
        totalPending += emi.amount;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.chitFund.chitName} - EMIs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Summary card
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.chitFund.chitName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total EMIs:'),
                            Text(
                              '${_emis.length}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Pending EMIs:'),
                            Text(
                              '$pendingEMIs',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: pendingEMIs > 0 ? Colors.orange : Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Amount Collected:'),
                            Text(
                              NumberFormat.currency(
                                symbol: '₹',
                                locale: 'en_IN',
                                decimalDigits: 0,
                              ).format(totalCollected),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Amount Pending:'),
                            Text(
                              NumberFormat.currency(
                                symbol: '₹',
                                locale: 'en_IN',
                                decimalDigits: 0,
                              ).format(totalPending),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: totalPending > 0 ? Colors.orange : Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                // EMIs by member
                Expanded(
                  child: _emis.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.payment,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No EMIs found',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'EMIs will be generated after auctions',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: emisByMember.length,
                          itemBuilder: (context, index) {
                            final aadhaar = emisByMember.keys.elementAt(index);
                            final memberEMIs = emisByMember[aadhaar]!;
                            final memberName = _getMemberName(aadhaar);
                            
                            // Count pending EMIs for this member
                            final pendingCount = memberEMIs.where((emi) => emi.paid == 0).length;
                            
                            return ExpansionTile(
                              title: Text(memberName),
                              subtitle: Text('$pendingCount pending EMIs'),
                              leading: CircleAvatar(
                                child: Text(memberName.isNotEmpty
                                    ? memberName[0].toUpperCase()
                                    : '?'),
                              ),
                              children: memberEMIs.map((emi) {
                                final isPaid = emi.paid == 1;
                                final isOverdue = !isPaid && 
                                    DateTime.parse(emi.dueDate).isBefore(DateTime.now());
                                
                                return ListTile(
                                  title: Text(
                                    'Due: ${DateFormat('dd MMM yyyy').format(DateTime.parse(emi.dueDate))}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isOverdue ? Colors.red : null,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Amount: ${NumberFormat.currency(symbol: '₹', locale: 'en_IN', decimalDigits: 0).format(emi.amount)}',
                                      ),
                                      if (isPaid)
                                        Text(
                                          'Paid on: ${DateFormat('dd MMM yyyy').format(DateTime.parse(emi.paymentDate!))}',
                                          style: const TextStyle(
                                            color: Colors.green,
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: isPaid
                                      ? const Icon(Icons.check_circle, color: Colors.green)
                                      : TextButton(
                                          onPressed: () => _showPaymentFormForEMI(emi),
                                          child: const Text('Record Payment'),
                                        ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                ),
              ],
            ),
      
      // Payment form
      bottomSheet: _showPaymentForm
          ? Container(
              height: MediaQuery.of(context).size.height * 0.6,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Record Payment',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () {
                            setState(() {
                              _showPaymentForm = false;
                              _selectedEMI = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  // EMI details
                  if (_selectedEMI != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Member: ${_getMemberName(_selectedEMI!.aadhaar)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Due Date: ${DateFormat('dd MMM yyyy').format(DateTime.parse(_selectedEMI!.dueDate))}',
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Amount: ${NumberFormat.currency(symbol: '₹', locale: 'en_IN', decimalDigits: 0).format(_selectedEMI!.amount)}',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  
                  // Form
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Payment date
                          const Text(
                            'Payment Date',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _paymentDateController,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Select date',
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            readOnly: true,
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                lastDate: DateTime.now(),
                              );
                              
                              if (date != null) {
                                setState(() {
                                  _paymentDateController.text = date.toIso8601String().split('T')[0];
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Payment amount
                          const Text(
                            'Payment Amount',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _paymentAmountController,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Enter amount',
                              prefixIcon: Icon(Icons.currency_rupee),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 16),
                          
                          // Payment type
                          const Text(
                            'Payment Type',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _paymentType,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.payment),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Cash',
                                child: Text('Cash'),
                              ),
                              DropdownMenuItem(
                                value: 'Cheque',
                                child: Text('Cheque'),
                              ),
                              DropdownMenuItem(
                                value: 'Bank Transfer',
                                child: Text('Bank Transfer'),
                              ),
                              DropdownMenuItem(
                                value: 'UPI',
                                child: Text('UPI'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _paymentType = value ?? 'Cash';
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Receipt number
                          const Text(
                            'Receipt Number (Optional)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _receiptNumberController,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Enter receipt number',
                              prefixIcon: Icon(Icons.receipt),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Record button
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _recordPayment,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Record Payment'),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}

class EMIPayment {
  final int? paymentId;
  final int emiId;
  final String paymentDate;
  final double amount;
  final String paymentType;
  final String receiptNumber;

  EMIPayment({
    this.paymentId,
    required this.emiId,
    required this.paymentDate,
    required this.amount,
    required this.paymentType,
    this.receiptNumber = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'payment_id': paymentId,
      'emi_id': emiId,
      'payment_date': paymentDate,
      'amount': amount,
      'payment_type': paymentType,
      'receipt_number': receiptNumber,
    };
  }

  factory EMIPayment.fromMap(Map<String, dynamic> map) {
    return EMIPayment(
      paymentId: map['payment_id'],
      emiId: map['emi_id'],
      paymentDate: map['payment_date'],
      amount: map['amount'],
      paymentType: map['payment_type'],
      receiptNumber: map['receipt_number'] ?? '',
    );
  }
}