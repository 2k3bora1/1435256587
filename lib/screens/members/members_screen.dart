import 'package:flutter/material.dart';
import 'package:chit_fund_flutter/models/member.dart';
import 'package:chit_fund_flutter/services/database_service.dart';
import 'package:chit_fund_flutter/services/utility_service.dart';
import 'package:chit_fund_flutter/screens/members/member_form.dart';
import 'package:chit_fund_flutter/screens/members/member_details.dart';

class MembersScreen extends StatefulWidget {
  final bool selectionMode;

  const MembersScreen({Key? key, this.selectionMode = false}) : super(key: key);

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<Member> _members = [];
  bool _isLoading = true;
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _loadMembers();
  }
  
  Future<void> _loadMembers() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final members = await _dbService.getAllMembers();
      setState(() {
        _members = members;
      });
    } catch (e) {
      debugPrint('Error loading members: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading members: $e'),
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
  
  List<Member> get _filteredMembers {
    if (_searchQuery.isEmpty) {
      return _members;
    }
    
    final query = _searchQuery.toLowerCase();
    return _members.where((member) {
      return member.name.toLowerCase().contains(query) ||
          member.phone.toLowerCase().contains(query) ||
          member.aadhaar.toLowerCase().contains(query);
    }).toList();
  }
  
  void _navigateToAddMember() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MemberForm(
          onSuccess: _loadMembers,
        ),
      ),
    );
  }
  
  void _navigateToMemberDetails(Member member) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MemberDetails(
          member: member,
          onUpdate: _loadMembers,
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
          
          // Members List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredMembers.isEmpty
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
                              'No members found',
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
                                'Add a member to get started',
                                style: TextStyle(color: Colors.grey),
                              ),
                            const SizedBox(height: 24),
                            if (_searchQuery.isEmpty)
                              ElevatedButton.icon(
                                onPressed: _navigateToAddMember,
                                icon: const Icon(Icons.add),
                                label: const Text('Add Member'),
                              ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadMembers,
                        child: ListView.builder(
                          itemCount: _filteredMembers.length,
                          itemBuilder: (context, index) {
                            final member = _filteredMembers[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: ListTile(
                                leading: member.photo != null
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
                                title: Text(member.name),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(member.phone),
                                    Text(
                                      'Joined: ${UtilityService.formatDate(member.joinDate)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                isThreeLine: true,
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _navigateToMemberDetails(member),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddMember,
        child: const Icon(Icons.add),
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
                  'Filter Members',
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
                    _members.sort((a, b) => a.name.compareTo(b.name));
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Sort by Join Date (Newest)'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _members.sort((a, b) => b.joinDate.compareTo(a.joinDate));
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Sort by Join Date (Oldest)'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _members.sort((a, b) => a.joinDate.compareTo(b.joinDate));
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
