import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:chit_fund_flutter/models/loan.dart';
import 'package:chit_fund_flutter/models/member.dart';
import 'package:chit_fund_flutter/services/database_service.dart';
import 'package:chit_fund_flutter/services/utility_service.dart';
import 'package:chit_fund_flutter/screens/loans/loan_form.dart';
import 'package:chit_fund_flutter/screens/loans/loan_details.dart';

class LoansScreen extends StatefulWidget {
  const LoansScreen({Key? key}) : super(key: key);

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<Loan> _loans = [];
  Map<String, Member> _memberCache = {};
  bool _isLoading = true;
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _loadLoans();
  }
  
  Future<void> _loadLoans() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final loans = await _dbService.getAllLoans();
      setState(() {
        _loans = loans;
      });
      
      // Preload member data for all loans
      for (final loan in loans) {
        if (!_memberCache.containsKey(loan.memberAadhaar)) {
          final member = await _dbService.getMember(loan.memberAadhaar);
          if (member != null) {
            _memberCache[loan.memberAadhaar] = member;
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading loans: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading loans: $e'),
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
  
  List<Loan> get _filteredLoans {
    if (_searchQuery.isEmpty) {
      return _loans;
    }
    
    final query = _searchQuery.toLowerCase();
    return _loans.where((loan) {
      final member = _memberCache[loan.memberAadhaar];
      if (member == null) return false;
      
      return member.name.toLowerCase().contains(query) ||
          member.phone.toLowerCase().contains(query) ||
          member.aadhaar.toLowerCase().contains(query) ||
          loan.amount.toString().contains(query);
    }).toList();
  }
  
  void _navigateToAddLoan() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LoanForm(
          onSuccess: _loadLoans,
        ),
      ),
    );
  }
  
  void _navigateToLoanDetails(Loan loan) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LoanDetails(
          loan: loan,
          member: _memberCache[loan.memberAadhaar],
          onUpdate: _loadLoans,
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search loans...',
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
          
          // Loans List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredLoans.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.account_balance,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No loans found',
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
                                'Create a loan to get started',
                                style: TextStyle(color: Colors.grey),
                              ),
                            const SizedBox(height: 24),
                            if (_searchQuery.isEmpty)
                              ElevatedButton.icon(
                                onPressed: _navigateToAddLoan,
                                icon: const Icon(Icons.add),
                                label: const Text('Create Loan'),
                              ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadLoans,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredLoans.length,
                          itemBuilder: (context, index) {
                            final loan = _filteredLoans[index];
                            final member = _memberCache[loan.memberAadhaar];
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: InkWell(
                                onTap: () => _navigateToLoanDetails(loan),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          member?.photo != null
                                              ? CircleAvatar(
                                                  backgroundImage: MemoryImage(member!.photo!),
                                                )
                                              : CircleAvatar(
                                                  child: Text(
                                                    member?.name.isNotEmpty == true
                                                        ? member!.name[0].toUpperCase()
                                                        : '?',
                                                  ),
                                                ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  member?.name ?? 'Unknown Member',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  member?.phone ?? '',
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
                                              color: Colors.green.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '${loan.interestRate}%',
                                              style: const TextStyle(
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          _buildLoanInfoItem(
                                            'Amount',
                                            UtilityService.formatCurrency(loan.amount),
                                          ),
                                          _buildLoanInfoItem(
                                            'Duration',
                                            '${loan.duration} months',
                                          ),
                                          _buildLoanInfoItem(
                                            'Start Date',
                                            UtilityService.formatDate(loan.startDate),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      FutureBuilder<List<LoanEMI>>(
                                        future: _dbService.getLoanEMIsByLoan(loan.loanId!),
                                        builder: (context, snapshot) {
                                          if (!snapshot.hasData) {
                                            return const SizedBox(
                                              height: 40,
                                              child: Center(
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              ),
                                            );
                                          }
                                          
                                          final emis = snapshot.data!;
                                          final paidCount = emis.where((e) => e.paid == 1).length;
                                          final progress = emis.isEmpty ? 0.0 : paidCount / emis.length;
                                          
                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    'EMI Progress: $paidCount/${emis.length}',
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
                                              ),
                                              
                                              // Next EMI due
                                              if (emis.any((e) => e.paid == 0)) ...[
                                                const SizedBox(height: 16),
                                                const Divider(),
                                                const SizedBox(height: 8),
                                                
                                                FutureBuilder<LoanEMI?>(
                                                  future: _getNextDueEMI(emis),
                                                  builder: (context, snapshot) {
                                                    if (!snapshot.hasData) {
                                                      return const SizedBox.shrink();
                                                    }
                                                    
                                                    final nextEMI = snapshot.data!;
                                                    final dueDate = DateTime.parse(nextEMI.dueDate);
                                                    final now = DateTime.now();
                                                    final isOverdue = dueDate.isBefore(now);
                                                    
                                                    return Row(
                                                      children: [
                                                        Icon(
                                                          Icons.calendar_today,
                                                          size: 16,
                                                          color: isOverdue ? Colors.red : Colors.orange,
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Text(
                                                          'Next EMI: ${UtilityService.formatDate(nextEMI.dueDate)}',
                                                          style: TextStyle(
                                                            color: isOverdue ? Colors.red : Colors.orange,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                        const Spacer(),
                                                        Text(
                                                          UtilityService.formatCurrency(nextEMI.amount),
                                                          style: TextStyle(
                                                            color: isOverdue ? Colors.red : Colors.orange,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                ),
                                              ],
                                            ],
                                          );
                                        },
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
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddLoan,
        child: const Icon(Icons.add),
      ),
    );
  }
  
  Future<LoanEMI?> _getNextDueEMI(List<LoanEMI> emis) async {
    final unpaidEMIs = emis.where((e) => e.paid == 0).toList();
    if (unpaidEMIs.isEmpty) return null;
    
    // Sort by due date
    unpaidEMIs.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return unpaidEMIs.first;
  }
  
  Widget _buildLoanInfoItem(String label, String value) {
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
          ),
        ),
      ],
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
                  'Filter Loans',
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
                    _loans.sort((a, b) {
                      final memberA = _memberCache[a.memberAadhaar];
                      final memberB = _memberCache[b.memberAadhaar];
                      if (memberA == null || memberB == null) return 0;
                      return memberA.name.compareTo(memberB.name);
                    });
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Sort by Start Date (Newest)'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _loans.sort((a, b) => b.startDate.compareTo(a.startDate));
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Sort by Start Date (Oldest)'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _loans.sort((a, b) => a.startDate.compareTo(b.startDate));
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.money),
                title: const Text('Sort by Amount (Highest)'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _loans.sort((a, b) => b.amount.compareTo(a.amount));
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.money_off),
                title: const Text('Sort by Amount (Lowest)'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _loans.sort((a, b) => a.amount.compareTo(b.amount));
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

// Placeholder for LoanDetails until we implement it
class LoanDetails extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Loan Details'),
      ),
      body: Center(
        child: Text('Loan details will be implemented here'),
      ),
    );
  }
}