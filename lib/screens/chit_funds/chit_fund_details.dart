import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:chit_fund_flutter/models/chit_fund.dart';
import 'package:chit_fund_flutter/models/member.dart';
import 'package:chit_fund_flutter/services/database_service.dart';
import 'package:chit_fund_flutter/services/sync_service_new.dart';
import 'package:chit_fund_flutter/services/utility_service.dart';
import 'package:chit_fund_flutter/screens/chit_funds/chit_fund_form.dart';
import 'package:chit_fund_flutter/screens/chit_funds/chit_members_screen.dart';
import 'package:chit_fund_flutter/screens/chit_funds/chit_auction_screen.dart';
import 'package:chit_fund_flutter/screens/chit_funds/chit_emi_screen.dart';
import 'package:chit_fund_flutter/screens/members/members_screen.dart';

class ChitFundDetails extends StatefulWidget {
  final ChitFund chitFund;
  final Function? onUpdate;

  const ChitFundDetails({
    Key? key,
    required this.chitFund,
    this.onUpdate,
  }) : super(key: key);

  @override
  State<ChitFundDetails> createState() => _ChitFundDetailsState();
}

class _ChitFundDetailsState extends State<ChitFundDetails> with SingleTickerProviderStateMixin {
  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
  final DatabaseService _dbService = DatabaseService();
  late TabController _tabController;
  
  List<ChitMember> _members = [];
  List<ChitAuction> _auctions = [];
  Map<String, Member> _memberDetails = {};
  bool _isLoading = true;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadChitFundDetails();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadChitFundDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Load members
      final members = await _dbService.getChitMembers(widget.chitFund.chitId!);
      
      // Load auctions
      final auctions = await _dbService.getChitAuctions(widget.chitFund.chitId!);
      
      // Load member details
      final Map<String, Member> memberDetails = {};
      for (final member in members) {
        final memberDetail = await _dbService.getMember(member.aadhaar);
        if (memberDetail != null) {
          memberDetails[member.aadhaar] = memberDetail;
        }
      }
      
      setState(() {
        _members = members;
        _auctions = auctions;
        _memberDetails = memberDetails;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading chit fund details: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _editChitFund() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChitFundForm(
          chitFund: widget.chitFund,
          onSuccess: () {
            if (widget.onUpdate != null) {
              widget.onUpdate!();
            }
          },
        ),
      ),
    );
    
    if (result == true) {
      _loadChitFundDetails();
    }
  }
  
  Future<void> _deleteChitFund() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chit Fund'),
        content: const Text(
          'Are you sure you want to delete this chit fund? This action cannot be undone.',
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
      await _dbService.deleteChitFund(widget.chitFund.chitId!);
      
      // Sync changes to Drive
      final syncService = Provider.of<SyncService>(context, listen: false);
      await syncService.syncAfterChanges();
      
      if (widget.onUpdate != null) {
        widget.onUpdate!();
      }
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chit fund deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting chit fund: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _addMember() async {
    if (_members.length >= widget.chitFund.memberCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum member limit reached'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MembersScreen(
          selectionMode: true,

        ),
      ),
    );
    
    if (result == null || result is! Member) return;
    
    try {
      final selectedMember = result;
      
      // Create chit member
      final chitMember = ChitMember(
        chitId: widget.chitFund.chitId!,
        aadhaar: selectedMember.aadhaar,
        joinDate: DateTime.now().toIso8601String().split('T')[0],
      );
      
      await _dbService.insertChitMember(chitMember);
      
      // Sync changes to Drive
      final syncService = Provider.of<SyncService>(context, listen: false);
      await syncService.syncAfterChanges();
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Member added successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      _loadChitFundDetails();
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding member: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _removeMember(ChitMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: const Text(
          'Are you sure you want to remove this member from the chit fund?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      await _dbService.removeChitMember(member.id!);
      
      // Sync changes to Drive
      final syncService = Provider.of<SyncService>(context, listen: false);
      await syncService.syncAfterChanges();
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Member removed successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      _loadChitFundDetails();
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing member: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _addAuction() async {
    if (_members.length < widget.chitFund.memberCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All members must be enrolled before starting auctions'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (_auctions.length >= widget.chitFund.duration) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All auctions have been completed'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final auctionDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    
    if (auctionDate == null) return;
    
    // Show auction form dialog
    final formResult = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AuctionFormDialog(
        chitFund: widget.chitFund,
        members: _members,
        memberDetails: _memberDetails,
        auctionDate: auctionDate,
      ),
    );
    
    if (formResult == null) return;
    
    try {
      final winnerAadhaar = formResult['winnerAadhaar'] as String;
      final bidAmount = formResult['bidAmount'] as double;
      
      // Create auction
      final auction = ChitAuction(
        chitId: widget.chitFund.chitId!,
        auctionDate: auctionDate.toIso8601String().split('T')[0],
        winnerAadhaar: winnerAadhaar,
        bidAmount: bidAmount,
        cycle: _auctions.length + 1,
        status: 'Completed',
      );
      
      await _dbService.insertChitAuction(auction);
      
      // Update chit fund current cycle
      final updatedChitFund = widget.chitFund.copyWith(
        currentCycle: _auctions.length + 1,
        nextAuctionDate: _calculateNextAuctionDate(auctionDate),
      );
      
      await _dbService.updateChitFund(updatedChitFund);
      
      // Sync changes to Drive
      final syncService = Provider.of<SyncService>(context, listen: false);
      await syncService.syncAfterChanges();
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Auction added successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      _loadChitFundDetails();
      if (widget.onUpdate != null) {
        widget.onUpdate!();
      }
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding auction: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  String _calculateNextAuctionDate(DateTime lastAuctionDate) {
    // Set next auction date to 30 days from last auction
    final nextAuctionDate = lastAuctionDate.add(const Duration(days: 30));
    return nextAuctionDate.toIso8601String().split('T')[0];
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chitFund.chitName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editChitFund,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteChitFund,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Members'),
            Tab(text: 'Auctions'),
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
                        onPressed: _loadChitFundDetails,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildMembersTab(),
                    _buildAuctionsTab(),
                  ],
                ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton(
              onPressed: _addMember,
              child: const Icon(Icons.person_add),
            )
          : _tabController.index == 2
              ? FloatingActionButton(
                  onPressed: _addAuction,
                  child: const Icon(Icons.add),
                )
              : null,
    );
  }
  
  Widget _buildOverviewTab() {
    final progress = widget.chitFund.duration == 0
        ? 0.0
        : widget.chitFund.currentCycle / widget.chitFund.duration;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chit fund summary
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chit Fund Summary',
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
                          'Total Value',
                          UtilityService.formatCurrency(widget.chitFund.totalAmount),
                        ),
                      ),
                      Expanded(
                        child: _buildInfoItem(
                          'Monthly Amount',
                          UtilityService.formatCurrency(widget.chitFund.totalAmount / widget.chitFund.duration),
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
                          '${widget.chitFund.duration} months',
                        ),
                      ),
                      Expanded(
                        child: _buildInfoItem(
                          'Start Date',
                          UtilityService.formatDate(widget.chitFund.startDate),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoItem(
                          'Commission',
                          '${widget.chitFund.commissionRate}%',
                        ),
                      ),
                      Expanded(
                        child: _buildInfoItem(
                          'Status',
                          widget.chitFund.status,
                          valueColor: _getStatusColor(widget.chitFund.status),
                        ),
                      ),
                    ],
                  ),
                  if (widget.chitFund.description != null && widget.chitFund.description!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'Description',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(widget.chitFund.description ?? ''),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Progress
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Progress',
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
                        'Cycle: ${widget.chitFund.currentCycle}/${widget.chitFund.duration}',
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
                          'Members Enrolled',
                          '${_members.length}/${widget.chitFund.memberCount}',
                        ),
                      ),
                      Expanded(
                        child: _buildInfoItem(
                          'Auctions Completed',
                          '${_auctions.length}/${widget.chitFund.duration}',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Quick Actions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          'Manage Members',
                          Icons.people,
                          Colors.blue,
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChitMembersScreen(
                                  chitFund: widget.chitFund,
                                ),
                              ),
                            ).then((_) => _loadChitFundDetails());
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildActionButton(
                          'Auctions & Bidding',
                          Icons.gavel,
                          Colors.orange,
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChitAuctionScreen(
                                  chitFund: widget.chitFund,
                                ),
                              ),
                            ).then((_) => _loadChitFundDetails());
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          'Manage EMIs',
                          Icons.payment,
                          Colors.green,
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChitEMIScreen(
                                  chitFund: widget.chitFund,
                                ),
                              ),
                            ).then((_) => _loadChitFundDetails());
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildActionButton(
                          'Reports',
                          Icons.bar_chart,
                          Colors.purple,
                          () {
                            // TODO: Implement reports screen
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Reports feature coming soon'),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Next auction
          if (widget.chitFund.status.toLowerCase() == 'active' &&
              widget.chitFund.currentCycle < widget.chitFund.duration) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Next Auction',
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
                            'Date',
                            UtilityService.formatDate(widget.chitFund.nextAuctionDate ?? ''),
                          ),
                        ),
                        Expanded(
                          child: _buildInfoItem(
                            'Cycle',
                            '${widget.chitFund.currentCycle + 1}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _addAuction,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Conduct Auction'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          
          // Recent auctions
          if (_auctions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recent Auctions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._auctions
                        .take(3)
                        .map((auction) => _buildAuctionItem(auction))
                        .toList(),
                    if (_auctions.length > 3) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            _tabController.animateTo(2);
                          },
                          child: const Text('View All Auctions'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildMembersTab() {
    return _members.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.people_outline,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No members enrolled',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add members to the chit fund',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _addMember,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add Member'),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _members.length,
            itemBuilder: (context, index) {
              final member = _members[index];
              final memberDetail = _memberDetails[member.aadhaar];
              
              if (memberDetail == null) {
                return const SizedBox.shrink();
              }
              
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      memberDetail.photo != null
                          ? CircleAvatar(
                              backgroundImage: MemoryImage(memberDetail.photo!),
                            )
                          : CircleAvatar(
                              child: Text(
                                memberDetail.name.isNotEmpty
                                    ? memberDetail.name[0].toUpperCase()
                                    : '?',
                              ),
                            ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              memberDetail.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              memberDetail.phone,
                              style: const TextStyle(
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              'Joined: ${UtilityService.formatDate(member.joinDate)}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
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
                          'Active',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _removeMember(member),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }
  
  Widget _buildAuctionsTab() {
    return _auctions.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.gavel_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No auctions conducted',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Conduct an auction to get started',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _addAuction,
                  icon: const Icon(Icons.add),
                  label: const Text('Conduct Auction'),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _auctions.length,
            itemBuilder: (context, index) {
              final auction = _auctions[index];
              return _buildAuctionItem(auction);
            },
          );
  }
  
  Widget _buildAuctionItem(ChitAuction auction) {
    final winnerDetail = _memberDetails[auction.winnerAadhaar];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
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
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.gavel,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cycle ${auction.cycle}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Date: ${UtilityService.formatDate(auction.auctionDate)}',
                        style: const TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  UtilityService.formatCurrency(auction.bidAmount),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'Winner: ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (winnerDetail != null) ...[
                  winnerDetail.photo != null
                      ? CircleAvatar(
                          radius: 12,
                          backgroundImage: MemoryImage(winnerDetail.photo!),
                        )
                      : CircleAvatar(
                          radius: 12,
                          child: Text(
                            winnerDetail.name.isNotEmpty
                                ? winnerDetail.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                  const SizedBox(width: 8),
                  Text(winnerDetail.name),
                ] else
                  Text(auction.winnerAadhaar),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Discount: ${_calculateDiscount(auction.bidAmount)}%',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Savings: ${UtilityService.formatCurrency(_calculateSavings(auction.bidAmount))}',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
  
  String _calculateDiscount(double bidAmount) {
    final discount = ((widget.chitFund.totalAmount - bidAmount) / widget.chitFund.totalAmount) * 100;
    return discount.toStringAsFixed(2);
  }
  
  double _calculateSavings(double bidAmount) {
    return widget.chitFund.totalAmount - bidAmount;
  }
}

class _AuctionFormDialog extends StatefulWidget {
  final ChitFund chitFund;
  final List<ChitMember> members;
  final Map<String, Member> memberDetails;
  final DateTime auctionDate;

  const _AuctionFormDialog({
    required this.chitFund,
    required this.members,
    required this.memberDetails,
    required this.auctionDate,
  });

  @override
  State<_AuctionFormDialog> createState() => _AuctionFormDialogState();
}

class _AuctionFormDialogState extends State<_AuctionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _bidAmountController = TextEditingController();
  String? _selectedWinner;
  
  @override
  void initState() {
    super.initState();
    // Set default bid amount to 90% of total amount
    _bidAmountController.text = (widget.chitFund.totalAmount * 0.9).toString();
  }
  
  @override
  void dispose() {
    _bidAmountController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Conduct Auction'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Date: ${DateFormat('dd/MM/yyyy').format(widget.auctionDate)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Winner',
                  border: OutlineInputBorder(),
                ),
                value: _selectedWinner,
                items: widget.members.map((member) {
                  final memberDetail = widget.memberDetails[member.aadhaar];
                  return DropdownMenuItem<String>(
                    value: member.aadhaar,
                    child: Text(memberDetail?.name ?? member.aadhaar),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedWinner = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a winner';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bidAmountController,
                decoration: const InputDecoration(
                  labelText: 'Bid Amount',
                  border: OutlineInputBorder(),
                  prefixText: '₹',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter bid amount';
                  }
                  
                  final bidAmount = double.tryParse(value);
                  if (bidAmount == null) {
                    return 'Please enter a valid amount';
                  }
                  
                  if (bidAmount <= 0) {
                    return 'Bid amount must be greater than 0';
                  }
                  
                  if (bidAmount >= widget.chitFund.totalAmount) {
                    return 'Bid amount must be less than total amount';
                  }
                  
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (_selectedWinner != null && _bidAmountController.text.isNotEmpty) ...[
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Preview',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                _buildPreview(),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
  
  Widget _buildPreview() {
    final bidAmount = double.tryParse(_bidAmountController.text) ?? 0.0;
    final discount = ((widget.chitFund.totalAmount - bidAmount) / widget.chitFund.totalAmount) * 100;
    final savings = widget.chitFund.totalAmount - bidAmount;
    
    final winnerDetail = widget.memberDetails[_selectedWinner];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Winner: ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (winnerDetail != null)
              Text(winnerDetail.name)
            else
              Text(_selectedWinner ?? ''),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Bid Amount: ${NumberFormat.currency(symbol: '₹', locale: 'en_IN', decimalDigits: 2).format(bidAmount)}',
            ),
            Text(
              'Discount: ${discount.toStringAsFixed(2)}%',
              style: const TextStyle(
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Savings: ${NumberFormat.currency(symbol: '₹', locale: 'en_IN', decimalDigits: 2).format(savings)}',
          style: const TextStyle(
            color: Colors.green,
          ),
        ),
      ],
    );
  }
  
  void _submit() {
    if (_formKey.currentState!.validate()) {
      final bidAmount = double.parse(_bidAmountController.text);
      
      Navigator.pop(
        context,
        {
          'winnerAadhaar': _selectedWinner,
          'bidAmount': bidAmount,
        },
      );
    }
  }
  

}
