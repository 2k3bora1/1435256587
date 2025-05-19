import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:chit_fund_flutter/config/constants.dart';
import 'package:chit_fund_flutter/models/chit_fund.dart';
import 'package:chit_fund_flutter/models/member.dart';
import 'package:chit_fund_flutter/services/database_service.dart';
import 'package:chit_fund_flutter/services/sync_service_new.dart';
import 'package:chit_fund_flutter/config/routes.dart';
import 'package:chit_fund_flutter/widgets/custom_alert_dialog.dart';
import 'package:chit_fund_flutter/widgets/loading_indicator.dart';

class ChitMembersScreen extends StatefulWidget {
  final ChitFund chitFund;

  const ChitMembersScreen({
    Key? key,
    required this.chitFund,
  }) : super(key: key);

  @override
  State<ChitMembersScreen> createState() => _ChitMembersScreenState();
}

class _ChitMembersScreenState extends State<ChitMembersScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<ChitMember> _chitMembers = [];
  List<Member> _members = [];
  bool _isLoading = true;
  String? _selectedMemberAadhaar;
  final TextEditingController _searchController = TextEditingController();
  List<Member> _filteredMembers = [];
  bool _showAddMemberDialog = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load chit members
      final chitMembers = await _dbService.getChitMembers(widget.chitFund.chitId!);
      
      // Load all members for adding new members
      final allMembers = await _dbService.getAllMembers();
      
      // Get full member details for each chit member
      List<Member> members = [];
      for (var chitMember in chitMembers) {
        final member = await _dbService.getMember(chitMember.aadhaar);
        if (member != null) {
          members.add(member);
        }
      }

      setState(() {
        _chitMembers = chitMembers;
        _members = members;
        _isLoading = false;
        
        // Initialize filtered members list
        _filteredMembers = allMembers.where((member) {
          // Filter out members who are already in the chit fund
          return !_chitMembers.any((chitMember) => chitMember.aadhaar == member.aadhaar);
        }).toList();
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Error loading members: $e');
    }
  }

  void _filterMembers(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredMembers = _members.where((member) {
          return !_chitMembers.any((chitMember) => chitMember.aadhaar == member.aadhaar);
        }).toList();
      });
      return;
    }

    final lowerCaseQuery = query.toLowerCase();
    setState(() {
      _filteredMembers = _members.where((member) {
        final nameMatches = member.name.toLowerCase().contains(lowerCaseQuery);
        final aadhaarMatches = member.aadhaar.toLowerCase().contains(lowerCaseQuery);
        final phoneMatches = member.phone.toLowerCase().contains(lowerCaseQuery);
        
        // Only include members not already in the chit fund
        final notAlreadyInChit = !_chitMembers.any((chitMember) => chitMember.aadhaar == member.aadhaar);
        
        return (nameMatches || aadhaarMatches || phoneMatches) && notAlreadyInChit;
      }).toList();
    });
  }

  Future<void> _addMember() async {
    if (_selectedMemberAadhaar == null) {
      _showErrorDialog('Please select a member to add');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Create a new chit member
      final chitMember = ChitMember(
        chitId: widget.chitFund.chitId!,
        aadhaar: _selectedMemberAadhaar!,
        joinDate: DateTime.now().toIso8601String().split('T')[0],
      );

      // Add to database
      await _dbService.addChitMember(chitMember);
      
      // Mark changes as pending for sync
      final syncService = Provider.of<SyncService>(context, listen: false);
      await syncService.markChangesAsPending();

      // Reload data
      await _loadData();
      
      setState(() {
        _showAddMemberDialog = false;
        _selectedMemberAadhaar = null;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Member added successfully')),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Error adding member: $e');
    }
  }

  Future<void> _removeMember(ChitMember chitMember) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: const Text('Are you sure you want to remove this member from the chit fund?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Remove from database
      await _dbService.removeChitMember(chitMember.id!);
      
      // Mark changes as pending for sync
      final syncService = Provider.of<SyncService>(context, listen: false);
      await syncService.markChangesAsPending();

      // Reload data
      await _loadData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Member removed successfully')),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Error removing member: $e');
    }
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

  void _openAddMemberDialog() {
    setState(() {
      _showAddMemberDialog = true;
      _searchController.clear();
      _filterMembers('');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.chitFund.chitName} - Members'),
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
                            const Text('Total Amount:'),
                            Text(
                              NumberFormat.currency(
                                symbol: '₹',
                                locale: 'en_IN',
                                decimalDigits: 0,
                              ).format(widget.chitFund.totalAmount),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Duration:'),
                            Text(
                              '${widget.chitFund.duration} months',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Members:'),
                            Text(
                              _chitMembers.length.toString(),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Members list
                Expanded(
                  child: _chitMembers.isEmpty
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
                                'No members added yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _openAddMemberDialog,
                                icon: const Icon(Icons.add),
                                label: const Text('Add Member'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _chitMembers.length,
                          itemBuilder: (context, index) {
                            final chitMember = _chitMembers[index];
                            final member = _members.firstWhere(
                              (m) => m.aadhaar == chitMember.aadhaar,
                              orElse: () => Member(
                                aadhaar: chitMember.aadhaar,
                                name: 'Unknown Member',
                                phone: '',
                                address: '',
                                joinDate: '',
                              ),
                            );
                            
                            return ListTile(
                              leading: CircleAvatar(
                                child: Text(member.name.isNotEmpty
                                    ? member.name[0].toUpperCase()
                                    : '?'),
                              ),
                              title: Text(member.name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Aadhaar: ${member.aadhaar}'),
                                  Text('Joined: ${DateFormat('dd MMM yyyy').format(DateTime.parse(chitMember.joinDate))}'),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _removeMember(chitMember),
                              ),
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.memberDetails,
                                  arguments: member.aadhaar,
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: _chitMembers.length < widget.chitFund.memberCount
          ? FloatingActionButton(
              onPressed: _openAddMemberDialog,
              child: const Icon(Icons.add),
            )
          : null,
      
      // Add member dialog
      bottomSheet: _showAddMemberDialog
          ? Container(
              height: MediaQuery.of(context).size.height * 0.7,
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
                          'Add Member',
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
                              _showAddMemberDialog = false;
                              _selectedMemberAadhaar = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search members...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: _filterMembers,
                    ),
                  ),
                  
                  // Members list
                  Expanded(
                    child: _filteredMembers.isEmpty
                        ? const Center(
                            child: Text('No members found'),
                          )
                        : ListView.builder(
                            itemCount: _filteredMembers.length,
                            itemBuilder: (context, index) {
                              final member = _filteredMembers[index];
                              final isSelected = _selectedMemberAadhaar == member.aadhaar;
                              
                              return ListTile(
                                leading: CircleAvatar(
                                  child: Text(member.name.isNotEmpty
                                      ? member.name[0].toUpperCase()
                                      : '?'),
                                ),
                                title: Text(member.name),
                                subtitle: Text('Aadhaar: ${member.aadhaar}'),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle, color: primaryColor)
                                    : null,
                                selected: isSelected,
                                onTap: () {
                                  setState(() {
                                    _selectedMemberAadhaar = member.aadhaar;
                                  });
                                },
                              );
                            },
                          ),
                  ),
                  
                  // Add button
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _selectedMemberAadhaar != null ? _addMember : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Add Member'),
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
