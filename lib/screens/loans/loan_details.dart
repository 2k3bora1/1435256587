import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:chit_fund_flutter/models/loan.dart';
import 'package:chit_fund_flutter/models/member.dart';
import 'package:chit_fund_flutter/services/database_service.dart';
import 'package:chit_fund_flutter/services/sync_service.dart';
import 'package:chit_fund_flutter/services/utility_service.dart';
import 'package:chit_fund_flutter/screens/payments/emi_payment_screen.dart';
import 'package:chit_fund_flutter/screens/loans/loan_form.dart';

class LoanDetails extends StatefulWidget {
  final Loan loan;
  final Member? member;
  final Function? onUpdate;

  const LoanDetails({
    Key? key,
    required this.loan,
    this.member,
    this.onUpdate,
  }) : super(key: key);

  @override
  State<LoanDetails> createState() => _LoanDetailsState();
}

class _LoanDetailsState extends State<LoanDetails> with SingleTickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();
  late TabController _tabController;
  
  Member? _member;
  List<LoanEMI> _emis = [];
  List<LoanDocument> _documents = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadLoanDetails();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadLoanDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Load member if not provided
      if (widget.member == null) {
        final member = await _dbService.getMember(widget.loan.memberAadhaar);
        setState(() {
          _member = member;
        });
      } else {
        setState(() {
          _member = widget.member;
        });
      }
      
      // Load EMIs
      final emis = await _dbService.getLoanEMIsByLoan(widget.loan.loanId!);
      
      // Load documents
      final documents = await _dbService.getLoanDocuments(widget.loan.loanId!);
      
      setState(() {
        _emis = emis;
        _documents = documents;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading loan details: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _editLoan() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LoanForm(
          loan: widget.loan,
          onSuccess: () {
            if (widget.onUpdate != null) {
              widget.onUpdate!();
            }
          },
        ),
      ),
    );
    
    if (result == true) {
      _loadLoanDetails();
    }
  }
  
  Future<void> _deleteLoan() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Loan'),
        content: const Text(
          'Are you sure you want to delete this loan? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      await _dbService.deleteLoan(widget.loan.loanId!);
      
      // Sync changes to Drive
      final syncService = Provider.of<SyncService>(context, listen: false);
      await syncService.syncAfterChanges();
      
      if (widget.onUpdate != null) {
        widget.onUpdate!();
      }
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loan deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting loan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _collectEMIPayment(LoanEMI emi) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EMIPaymentScreen(
          emi: emi,
          loan: widget.loan,
          member: _member,
        ),
      ),
    );
    
    if (result == true) {
      _loadLoanDetails();
      if (widget.onUpdate != null) {
        widget.onUpdate!();
      }
    }
  }
  
  Future<void> _uploadDocument() async {
    final docType = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Document Type'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'Loan Agreement'),
            child: const Text('Loan Agreement'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'ID Proof'),
            child: const Text('ID Proof'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'Address Proof'),
            child: const Text('Address Proof'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'Income Proof'),
            child: const Text('Income Proof'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'Collateral Document'),
            child: const Text('Collateral Document'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'Other'),
            child: const Text('Other'),
          ),
        ],
      ),
    );
    
    if (docType == null) return;
    
    try {
      final bytes = await UtilityService.pickDocument();
      if (bytes == null) return;
      
      final document = LoanDocument(
        loanId: widget.loan.loanId!,
        fileName: 'Document_${DateTime.now().millisecondsSinceEpoch}.pdf',
        file: bytes,
      );
      
      await _dbService.insertLoanDocument(document);
      
      // Sync changes to Drive
      final syncService = Provider.of<SyncService>(context, listen: false);
      await syncService.syncAfterChanges();
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document uploaded successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      _loadLoanDetails();
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading document: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _viewDocument(LoanDocument document) async {
    try {
      if (document.file != null && document.fileName != null) {
        await UtilityService.viewDocument(document.file!, document.fileName!);
      } else {
        throw Exception('Document or filename is missing');
      }
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error viewing document: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _deleteDocument(LoanDocument document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: const Text(
          'Are you sure you want to delete this document? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      await _dbService.deleteLoanDocument(document.documentId!);
      
      // Sync changes to Drive
      final syncService = Provider.of<SyncService>(context, listen: false);
      await syncService.syncAfterChanges();
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      _loadLoanDetails();
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting document: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loan Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editLoan,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteLoan,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'EMIs'),
            Tab(text: 'Documents'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadLoanDetails,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildEMIsTab(),
                    _buildDocumentsTab(),
                  ],
                ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton(
              onPressed: () {
                final unpaidEMIs = _emis.where((emi) => emi.paid == 0).toList();
                if (unpaidEMIs.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All EMIs are already paid'),
                    ),
                  );
                  return;
                }
                
                // Sort by due date
                unpaidEMIs.sort((a, b) => a.dueDate.compareTo(b.dueDate));
                _collectEMIPayment(unpaidEMIs.first);
              },
              child: const Icon(Icons.payment),
            )
          : _tabController.index == 2
              ? FloatingActionButton(
                  onPressed: _uploadDocument,
                  child: const Icon(Icons.upload_file),
                )
              : null,
    );
  }
  
  Widget _buildOverviewTab() {
    final paidEMIs = _emis.where((emi) => emi.paid == 1).length;
    final totalEMIs = _emis.length;
    final progress = totalEMIs == 0 ? 0.0 : paidEMIs / totalEMIs;
    
    final totalPaid = _emis
        .where((emi) => emi.paid == 1)
        .fold(0.0, (sum, emi) => sum + emi.amount);
    
    final totalRemaining = widget.loan.amount - totalPaid;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Member info
          if (_member != null) ...[
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
                                radius: 30,
                                backgroundImage: MemoryImage(_member!.photo!),
                              )
                            : CircleAvatar(
                                radius: 30,
                                child: Text(
                                  _member!.name.isNotEmpty
                                      ? _member!.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(fontSize: 24),
                                ),
                              ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _member!.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _member!.phone,
                                style: const TextStyle(
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Aadhaar: ${_member!.aadhaar}',
                                style: const TextStyle(
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildActionButton(
                          icon: Icons.call,
                          label: 'Call',
                          onTap: () => UtilityService.makePhoneCall(_member!.phone),
                        ),
                        _buildActionButton(
                          icon: Icons.message,
                          label: 'SMS',
                          onTap: () => UtilityService.sendSMS(_member!.phone),
                        ),
                        _buildActionButton(
                          icon: Icons.chat,
                          label: 'WhatsApp',
                          onTap: () => UtilityService.openWhatsApp(_member!.phone),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Loan summary
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Loan Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoItem(
                          'Loan Amount',
                          UtilityService.formatCurrency(widget.loan.amount),
                        ),
                      ),
                      Expanded(
                        child: _buildInfoItem(
                          'Interest Rate',
                          '${widget.loan.interestRate}%',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoItem(
                          'Duration',
                          '${widget.loan.duration} months',
                        ),
                      ),
                      Expanded(
                        child: _buildInfoItem(
                          'Start Date',
                          UtilityService.formatDate(widget.loan.startDate),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoItem(
                          'Purpose',
                          "Loan Purpose",
                        ),
                      ),
                      Expanded(
                        child: _buildInfoItem(
                          'Status',
                          paidEMIs == totalEMIs ? 'Completed' : 'Active',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Payment progress
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment Progress',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'EMIs Paid: $paidEMIs/$totalEMIs',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.withOpacity(0.2),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoItem(
                          'Total Paid',
                          UtilityService.formatCurrency(totalPaid),
                          valueColor: Colors.green,
                        ),
                      ),
                      Expanded(
                        child: _buildInfoItem(
                          'Remaining',
                          UtilityService.formatCurrency(totalRemaining),
                          valueColor: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Next payment
          if (paidEMIs < totalEMIs) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Next Payment',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<LoanEMI?>(
                      future: _getNextDueEMI(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        
                        if (!snapshot.hasData) {
                          return const Text('No pending EMIs');
                        }
                        
                        final nextEMI = snapshot.data!;
                        final dueDate = DateTime.parse(nextEMI.dueDate);
                        final now = DateTime.now();
                        final isOverdue = dueDate.isBefore(now);
                        
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInfoItem(
                                    'Due Date',
                                    UtilityService.formatDate(nextEMI.dueDate),
                                    valueColor: isOverdue ? Colors.red : null,
                                  ),
                                ),
                                Expanded(
                                  child: _buildInfoItem(
                                    'Amount',
                                    UtilityService.formatCurrency(nextEMI.amount),
                                    valueColor: isOverdue ? Colors.red : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => _collectEMIPayment(nextEMI),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isOverdue ? Colors.red : null,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: Text(
                                  isOverdue ? 'Pay Overdue EMI' : 'Pay EMI',
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildEMIsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _emis.length,
      itemBuilder: (context, index) {
        final emi = _emis[index];
        final dueDate = DateTime.parse(emi.dueDate);
        final now = DateTime.now();
        final isOverdue = emi.paid == 0 && dueDate.isBefore(now);
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: InkWell(
            onTap: emi.paid == 0 ? () => _collectEMIPayment(emi) : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: emi.paid == 1
                              ? Colors.green.withOpacity(0.1)
                              : isOverdue
                                  ? Colors.red.withOpacity(0.1)
                                  : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          emi.paid == 1
                              ? Icons.check_circle
                              : isOverdue
                                  ? Icons.warning
                                  : Icons.schedule,
                          color: emi.paid == 1
                              ? Colors.green
                              : isOverdue
                                  ? Colors.red
                                  : Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'EMI #${index + 1}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Due: ${UtilityService.formatDate(emi.dueDate)}',
                              style: TextStyle(
                                color: isOverdue ? Colors.red : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            UtilityService.formatCurrency(emi.amount),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            emi.paid == 1
                                ? 'Paid on ${UtilityService.formatDate(emi.paymentDate ?? '')}'
                                : isOverdue
                                    ? 'Overdue'
                                    : 'Pending',
                            style: TextStyle(
                              color: emi.paid == 1
                                  ? Colors.green
                                  : isOverdue
                                      ? Colors.red
                                      : Colors.orange,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildEMIInfoItem(
                        'Principal',
                        UtilityService.formatCurrency(emi.principal),
                      ),
                      _buildEMIInfoItem(
                        'Interest',
                        UtilityService.formatCurrency(emi.interest),
                      ),
                      _buildEMIInfoItem(
                        'Balance',
                        UtilityService.formatCurrency(emi.balance),
                      ),
                    ],
                  ),
                  if (emi.paid == 0) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _collectEMIPayment(emi),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isOverdue ? Colors.red : null,
                        ),
                        child: Text(isOverdue ? 'Pay Overdue EMI' : 'Pay EMI'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildDocumentsTab() {
    return _documents.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.description_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No documents found',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Upload loan documents to get started',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _uploadDocument,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload Document'),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _documents.length,
            itemBuilder: (context, index) {
              final document = _documents[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: InkWell(
                  onTap: () => _viewDocument(document),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.description,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                document.fileName ?? "Document",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Document',
                                style: const TextStyle(
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.visibility),
                          onPressed: () => _viewDocument(document),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteDocument(document),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
  }
  
  Widget _buildInfoItem(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
  
  Widget _buildEMIInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
  
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Icon(icon),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
  
  Future<LoanEMI?> _getNextDueEMI() async {
    final unpaidEMIs = _emis.where((e) => e.paid == 0).toList();
    if (unpaidEMIs.isEmpty) return null;
    
    // Sort by due date
    unpaidEMIs.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return unpaidEMIs.first;
  }
}
