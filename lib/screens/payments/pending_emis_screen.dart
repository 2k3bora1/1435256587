import 'package:flutter/material.dart';
import 'package:chit_fund_flutter/models/loan.dart';
import 'package:chit_fund_flutter/models/member.dart';
import 'package:chit_fund_flutter/services/database_service.dart';
import 'package:chit_fund_flutter/services/utility_service.dart';
import 'package:chit_fund_flutter/screens/payments/emi_payment_screen.dart';

class PendingEMIsScreen extends StatefulWidget {
  const PendingEMIsScreen({Key? key}) : super(key: key);

  @override
  State<PendingEMIsScreen> createState() => _PendingEMIsScreenState();
}

class _PendingEMIsScreenState extends State<PendingEMIsScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<Map<String, dynamic>> _pendingEMIs = [];
  bool _isLoading = true;
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _loadPendingEMIs();
  }
  
  Future<void> _loadPendingEMIs() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final loans = await _dbService.getAllLoans();
      final List<Map<String, dynamic>> pendingEMIs = [];
      
      for (final loan in loans) {
        final emis = await _dbService.getLoanEMIsByLoan(loan.loanId!);
        final member = await _dbService.getMember(loan.memberAadhaar);
        
        if (member == null) continue;
        
        for (final emi in emis) {
          if (emi.paid == 0) {
            pendingEMIs.add({
              'emi': emi,
              'loan': loan,
              'member': member,
            });
          }
        }
      }
      
      // Sort by due date (oldest first)
      pendingEMIs.sort((a, b) {
        final emiA = a['emi'] as LoanEMI;
        final emiB = b['emi'] as LoanEMI;
        return emiA.dueDate.compareTo(emiB.dueDate);
      });
      
      setState(() {
        _pendingEMIs = pendingEMIs;
      });
    } catch (e) {
      debugPrint('Error loading pending EMIs: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading pending EMIs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  List<Map<String, dynamic>> get _filteredEMIs {
    if (_searchQuery.isEmpty) {
      return _pendingEMIs;
    }
    
    final query = _searchQuery.toLowerCase();
    return _pendingEMIs.where((item) {
      final member = item['member'] as Member;
      return member.name.toLowerCase().contains(query) ||
          member.phone.toLowerCase().contains(query) ||
          member.aadhaar.toLowerCase().contains(query);
    }).toList();
  }
  
  void _navigateToPayment(Map<String, dynamic> emiData) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EMIPaymentScreen(
          emi: emiData['emi'] as LoanEMI,
          loan: emiData['loan'] as Loan,
          member: emiData['member'] as Member,
        ),
      ),
    );
    
    if (result == true) {
      // Payment was successful, reload data
      _loadPendingEMIs();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending EMIs'),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search members...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: () {
                    // Show filter options
                    _showFilterOptions();
                  },
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          
          // EMIs List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredEMIs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              size: 64,
                              color: Colors.green,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No pending EMIs found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_searchQuery.isNotEmpty)
                              const Text(
                                'Try a different search term',
                                style: TextStyle(color: Colors.grey),
                              )
                            else
                              const Text(
                                'All EMIs are paid',
                                style: TextStyle(color: Colors.grey),
                              ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadPendingEMIs,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredEMIs.length,
                          itemBuilder: (context, index) {
                            final emiData = _filteredEMIs[index];
                            final emi = emiData['emi'] as LoanEMI;
                            final loan = emiData['loan'] as Loan;
                            final member = emiData['member'] as Member;
                            
                            final dueDate = DateTime.parse(emi.dueDate);
                            final now = DateTime.now();
                            final isOverdue = dueDate.isBefore(now);
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: InkWell(
                                onTap: () => _navigateToPayment(emiData),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          member.photo != null
                                              ? CircleAvatar(
                                                  backgroundImage: MemoryImage(member.photo!),
                                                )
                                              : CircleAvatar(
                                                  child: Text(
                                                    member.name.isNotEmpty
                                                        ? member.name[0].toUpperCase()
                                                        : '?',
                                                  ),
                                                ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  member.name,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  member.phone,
                                                  style: const TextStyle(
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isOverdue
                                                  ? Colors.red.withOpacity(0.1)
                                                  : Colors.orange.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              isOverdue ? 'OVERDUE' : 'PENDING',
                                              style: TextStyle(
                                                color: isOverdue ? Colors.red : Colors.orange,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Due Date',
                                                style: TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              Text(
                                                UtilityService.formatDate(emi.dueDate),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: isOverdue ? Colors.red : null,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              const Text(
                                                'EMI Amount',
                                                style: TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              Text(
                                                UtilityService.formatCurrency(emi.amount),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 24),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Loan: ${UtilityService.formatCurrency(loan.amount)} @ ${loan.interestRate}%',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => _navigateToPayment(emiData),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isOverdue ? Colors.red : null,
                                            ),
                                            child: const Text('Collect'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
  
  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text(
                  'Filter EMIs',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.sort_by_alpha),
                title: const Text('Sort by Member Name'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _pendingEMIs.sort((a, b) {
                      final memberA = a['member'] as Member;
                      final memberB = b['member'] as Member;
                      return memberA.name.compareTo(memberB.name);
                    });
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Sort by Due Date (Oldest First)'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _pendingEMIs.sort((a, b) {
                      final emiA = a['emi'] as LoanEMI;
                      final emiB = b['emi'] as LoanEMI;
                      return emiA.dueDate.compareTo(emiB.dueDate);
                    });
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Sort by Due Date (Newest First)'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _pendingEMIs.sort((a, b) {
                      final emiA = a['emi'] as LoanEMI;
                      final emiB = b['emi'] as LoanEMI;
                      return emiB.dueDate.compareTo(emiA.dueDate);
                    });
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.money),
                title: const Text('Sort by Amount (Highest First)'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _pendingEMIs.sort((a, b) {
                      final emiA = a['emi'] as LoanEMI;
                      final emiB = b['emi'] as LoanEMI;
                      return emiB.amount.compareTo(emiA.amount);
                    });
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.warning),
                title: const Text('Show Overdue First'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _pendingEMIs.sort((a, b) {
                      final emiA = a['emi'] as LoanEMI;
                      final emiB = b['emi'] as LoanEMI;
                      final dueDateA = DateTime.parse(emiA.dueDate);
                      final dueDateB = DateTime.parse(emiB.dueDate);
                      final now = DateTime.now();
                      final isOverdueA = dueDateA.isBefore(now);
                      final isOverdueB = dueDateB.isBefore(now);
                      
                      if (isOverdueA && !isOverdueB) {
                        return -1;
                      } else if (!isOverdueA && isOverdueB) {
                        return 1;
                      } else {
                        return emiA.dueDate.compareTo(emiB.dueDate);
                      }
                    });
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }
}