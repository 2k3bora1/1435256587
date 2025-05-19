import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:chit_fund_flutter/models/chit_fund.dart';
import 'package:chit_fund_flutter/services/database_service.dart';
import 'package:chit_fund_flutter/services/utility_service.dart';
import 'package:chit_fund_flutter/screens/chit_funds/chit_fund_form.dart';
import 'package:chit_fund_flutter/screens/chit_funds/chit_fund_details.dart';

class ChitFundsScreen extends StatefulWidget {
  const ChitFundsScreen({Key? key}) : super(key: key);

  @override
  State<ChitFundsScreen> createState() => _ChitFundsScreenState();
}

class _ChitFundsScreenState extends State<ChitFundsScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<ChitFund> _chitFunds = [];
  bool _isLoading = true;
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _loadChitFunds();
  }
  
  Future<void> _loadChitFunds() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final chitFunds = await _dbService.getAllChitFunds();
      setState(() {
        _chitFunds = chitFunds;
      });
    } catch (e) {
      debugPrint('Error loading chit funds: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading chit funds: $e'),
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
  
  List<ChitFund> get _filteredChitFunds {
    if (_searchQuery.isEmpty) {
      return _chitFunds;
    }
    
    final query = _searchQuery.toLowerCase();
    return _chitFunds.where((chitFund) {
      return chitFund.chitName.toLowerCase().contains(query) ||
          chitFund.status.toLowerCase().contains(query);
    }).toList();
  }
  
  void _navigateToAddChitFund() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChitFundForm(
          onSuccess: _loadChitFunds,
        ),
      ),
    );
  }
  
  void _navigateToChitFundDetails(ChitFund chitFund) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChitFundDetails(
          chitFund: chitFund,
          onUpdate: _loadChitFunds,
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
                hintText: 'Search chit funds...',
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
          
          // Chit Funds List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredChitFunds.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.monetization_on,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No chit funds found',
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
                                'Create a chit fund to get started',
                                style: TextStyle(color: Colors.grey),
                              ),
                            const SizedBox(height: 24),
                            if (_searchQuery.isEmpty)
                              ElevatedButton.icon(
                                onPressed: _navigateToAddChitFund,
                                icon: const Icon(Icons.add),
                                label: const Text('Create Chit Fund'),
                              ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadChitFunds,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredChitFunds.length,
                          itemBuilder: (context, index) {
                            final chitFund = _filteredChitFunds[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: InkWell(
                                onTap: () => _navigateToChitFundDetails(chitFund),
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
                                              color: _getStatusColor(chitFund.status).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.monetization_on,
                                              color: _getStatusColor(chitFund.status),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  chitFund.chitName,
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  'Started on ${UtilityService.formatDate(chitFund.startDate)}',
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
                                              color: _getStatusColor(chitFund.status).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              chitFund.status.toUpperCase(),
                                              style: TextStyle(
                                                color: _getStatusColor(chitFund.status),
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
                                          _buildChitFundInfoItem(
                                            'Total Amount',
                                            UtilityService.formatCurrency(chitFund.totalAmount),
                                          ),
                                          _buildChitFundInfoItem(
                                            'Duration',
                                            '${chitFund.duration} months',
                                          ),
                                          _buildChitFundInfoItem(
                                            'Members',
                                            chitFund.memberCount.toString(),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      FutureBuilder<List<ChitMember>>(
                                        future: _dbService.getChitMembers(chitFund.chitId!),
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
                                          
                                          final members = snapshot.data!;
                                          final memberCount = members.length;
                                          final progress = chitFund.memberCount == 0 
                                              ? 0.0 
                                              : memberCount / chitFund.memberCount;
                                          
                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    'Member Enrollment: $memberCount/${chitFund.memberCount}',
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
                                              
                                              // Next auction date
                                              if (chitFund.status.toLowerCase() == 'active') ...[
                                                const SizedBox(height: 16),
                                                const Divider(),
                                                const SizedBox(height: 8),
                                                
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.event,
                                                      size: 16,
                                                      color: Colors.blue,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'Next Auction: ${UtilityService.formatDate(chitFund.nextAuctionDate ?? '')}',
                                                      style: const TextStyle(
                                                        color: Colors.blue,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
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
        onPressed: _navigateToAddChitFund,
        child: const Icon(Icons.add),
      ),
    );
  }
  
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }
  
  Widget _buildChitFundInfoItem(String label, String value) {
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
                  'Filter Chit Funds',
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
                title: const Text('Sort by Name'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _chitFunds.sort((a, b) => a.chitName.compareTo(b.chitName));
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Sort by Start Date (Newest)'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _chitFunds.sort((a, b) => b.startDate.compareTo(a.startDate));
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Sort by Start Date (Oldest)'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _chitFunds.sort((a, b) => a.startDate.compareTo(b.startDate));
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.money),
                title: const Text('Sort by Amount (Highest)'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _chitFunds.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.filter_alt),
                title: const Text('Show Active Only'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _searchQuery = 'active';
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.filter_alt_outlined),
                title: const Text('Show All'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _searchQuery = '';
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