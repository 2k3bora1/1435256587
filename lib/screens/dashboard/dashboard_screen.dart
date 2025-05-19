import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:chit_fund_flutter/config/constants.dart';
import 'package:chit_fund_flutter/config/routes.dart';
import 'package:chit_fund_flutter/services/auth_service_new.dart';
import 'package:chit_fund_flutter/services/database_service.dart';
import 'package:chit_fund_flutter/services/sync_service_new.dart';
import 'package:chit_fund_flutter/screens/login/login_screen.dart';
import 'package:chit_fund_flutter/screens/members/members_screen.dart';
import 'package:chit_fund_flutter/screens/members/member_form.dart';
import 'package:chit_fund_flutter/screens/groups/groups_screen.dart';
import 'package:chit_fund_flutter/screens/loans/loans_screen.dart';
import 'package:chit_fund_flutter/screens/loans/loan_form.dart';
import 'package:chit_fund_flutter/screens/chit_funds/chit_funds_screen.dart';
import 'package:chit_fund_flutter/screens/chit_funds/chit_fund_form.dart';
import 'package:chit_fund_flutter/screens/groups/group_form.dart';
import 'package:chit_fund_flutter/screens/payments/pending_emis_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  bool _isSyncing = false;
  
  final List<Widget> _screens = [
    const DashboardHomeScreen(),
    const MembersScreen(),
    const GroupsScreen(),
    const LoansScreen(),
    const ChitFundsScreen(),
  ];
  
  @override
  void initState() {
    super.initState();
    _syncData();
  }
  
  Future<void> _syncData() async {
    setState(() {
      _isSyncing = true;
    });
    
    try {
      final syncService = Provider.of<SyncService>(context, listen: false);
      await syncService.syncWithDrive();
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }
  
  Future<void> _logout() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.logout();
    
    if (!mounted) return;
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).currentUser;
    final syncService = Provider.of<SyncService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? 'Dashboard' : _getTitle()),
        actions: [
          // Sync Status Indicator
          if (_isSyncing || syncService.status == SyncStatus.syncing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else if (syncService.status == SyncStatus.pendingChanges || syncService.hasPendingChanges)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.sync),
                  onPressed: _syncData,
                  tooltip: 'Sync pending changes',
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            )
          else
            IconButton(
              icon: const Icon(Icons.sync),
              onPressed: _syncData,
              tooltip: 'Sync data',
            ),
          
          // User Menu
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _logout();
              } else if (value == 'database_reset') {
                Navigator.pushNamed(context, AppRoutes.databaseReset);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    const Icon(Icons.person, color: primaryColor),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.username ?? 'User'),
                        if (Provider.of<AuthService>(context).isGoogleSignedIn)
                          const Text(
                            'Google Account',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, color: primaryColor),
                    SizedBox(width: 8),
                    Text('Settings'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'database_reset',
                child: Row(
                  children: [
                    Icon(Icons.restore, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Reset Database'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: primaryColor),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Members',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group_work),
            label: 'Groups',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance),
            label: 'Loans',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.monetization_on),
            label: 'Chit Funds',
          ),
        ],
      ),
    );
  }
  
  String _getTitle() {
    switch (_selectedIndex) {
      case 1:
        return 'Members';
      case 2:
        return 'Groups';
      case 3:
        return 'Loans';
      case 4:
        return 'Chit Funds';
      default:
        return 'Dashboard';
    }
  }
}

class DashboardHomeScreen extends StatefulWidget {
  const DashboardHomeScreen({Key? key}) : super(key: key);

  @override
  State<DashboardHomeScreen> createState() => _DashboardHomeScreenState();
}

class _DashboardHomeScreenState extends State<DashboardHomeScreen> {
  int _memberCount = 0;
  int _groupCount = 0;
  int _loanCount = 0;
  int _chitFundCount = 0;
  int _pendingEMIs = 0;
  double _totalOutstanding = 0;
  
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }
  
  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final dbService = DatabaseService();
      
      // Get counts
      final members = await dbService.getAllMembers();
      final groups = await dbService.getAllGroups();
      final loans = await dbService.getAllLoans();
      final chitFunds = await dbService.getAllChitFunds();
      
      // Calculate pending EMIs and outstanding amount
      double outstanding = 0;
      int pendingCount = 0;
      
      for (final loan in loans) {
        final emis = await dbService.getLoanEMIsByLoan(loan.loanId!);
        for (final emi in emis) {
          if (emi.paid == 0) {
            pendingCount++;
            outstanding += emi.amount;
          }
        }
      }
      
      setState(() {
        _memberCount = members.length;
        _groupCount = groups.length;
        _loanCount = loans.length;
        _chitFundCount = chitFunds.length;
        _pendingEMIs = pendingCount;
        _totalOutstanding = outstanding;
      });
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).currentUser;
    final syncService = Provider.of<SyncService>(context);
    final lastSyncTime = syncService.lastSyncTime;
    
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Company Info Card
                  Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.business, size: 24, color: primaryColor),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  user?.companyName ?? 'Company Name',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(),
                          Row(
                            children: [
                              const Icon(Icons.person, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text(user?.username ?? 'Username'),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.phone, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text(user?.phone ?? 'Phone'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                syncService.hasPendingChanges ? Icons.sync_problem : Icons.sync,
                                size: 16,
                                color: syncService.hasPendingChanges ? Colors.red : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                syncService.hasPendingChanges
                                    ? 'Pending changes - Sync required'
                                    : lastSyncTime != null
                                        ? 'Last sync: ${DateFormat('dd MMM yyyy, HH:mm').format(lastSyncTime)}'
                                        : 'Not synced yet',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: syncService.hasPendingChanges ? Colors.red : Colors.grey,
                                  fontWeight: syncService.hasPendingChanges ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Summary Cards
                  Row(
                    children: [
                      _buildSummaryCard(
                        'Members',
                        _memberCount.toString(),
                        Icons.people,
                        Colors.blue,
                      ),
                      const SizedBox(width: 16),
                      _buildSummaryCard(
                        'Groups',
                        _groupCount.toString(),
                        Icons.group_work,
                        Colors.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildSummaryCard(
                        'Loans',
                        _loanCount.toString(),
                        Icons.account_balance,
                        Colors.green,
                      ),
                      const SizedBox(width: 16),
                      _buildSummaryCard(
                        'Chit Funds',
                        _chitFundCount.toString(),
                        Icons.monetization_on,
                        Colors.purple,
                      ),
                    ],
                  ),
                  
                  // Financial Summary
                  const SizedBox(height: 24),
                  const Text(
                    'Financial Summary',
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
                          _buildFinancialItem(
                            'Pending EMIs',
                            _pendingEMIs.toString(),
                            Icons.calendar_today,
                            Colors.orange,
                          ),
                          const Divider(),
                          _buildFinancialItem(
                            'Outstanding Amount',
                            '₹${_totalOutstanding.toStringAsFixed(2)}',
                            Icons.money,
                            Colors.red,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Quick Actions
                  const SizedBox(height: 24),
                  const Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildQuickAction(
                        'Add Member',
                        Icons.person_add,
                        () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MemberForm(
                                onSuccess: () {
                                  _loadDashboardData();
                                },
                              ),
                            ),
                          );
                        },
                      ),
                      _buildQuickAction(
                        'New Loan',
                        Icons.add_card,
                        () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => LoanForm(
                                onSuccess: () {
                                  _loadDashboardData();
                                },
                              ),
                            ),
                          );
                        },
                      ),
                      _buildQuickAction(
                        'Collect EMI',
                        Icons.payments,
                        () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PendingEMIsScreen(),
                            ),
                          );
                        },
                      ),
                      _buildQuickAction(
                        'New Chit Fund',
                        Icons.monetization_on,
                        () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChitFundForm(
                                onSuccess: () {
                                  _loadDashboardData();
                                },
                              ),
                            ),
                          );
                        },
                      ),
                      _buildQuickAction(
                        'New Group',
                        Icons.group_add,
                        () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => GroupForm(
                                onSuccess: () {
                                  _loadDashboardData();
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
  
  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildFinancialItem(String title, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickAction(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: primaryColor,
                size: 28,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}