import 'package:flutter/material.dart';
import 'package:chit_fund_flutter/models/group.dart';
import 'package:chit_fund_flutter/services/database_service.dart';
import 'package:chit_fund_flutter/services/utility_service.dart';
import 'package:chit_fund_flutter/screens/groups/group_form.dart';
import 'package:chit_fund_flutter/screens/groups/group_details.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({Key? key}) : super(key: key);

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<Group> _groups = [];
  bool _isLoading = true;
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _loadGroups();
  }
  
  Future<void> _loadGroups() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final groups = await _dbService.getAllGroups();
      setState(() {
        _groups = groups;
      });
    } catch (e) {
      debugPrint('Error loading groups: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  List<Group> get _filteredGroups {
    if (_searchQuery.isEmpty) {
      return _groups;
    }
    
    final query = _searchQuery.toLowerCase();
    return _groups.where((group) {
      return group.groupName.toLowerCase().contains(query) ||
          (group.description ?? '').toLowerCase().contains(query);
    }).toList();
  }
  
  void _navigateToAddGroup() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GroupForm(
          onSuccess: _loadGroups,
        ),
      ),
    );
  }
  
  void _navigateToGroupDetails(Group group) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GroupDetails(
          group: group,
          onUpdate: _loadGroups,
        ),
      ),
    );
  }
  
  void _showGroupOptions(Group group) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  group.groupName,
                  style: const TextStyle(
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
                leading: const Icon(Icons.edit),
                title: const Text('Edit Group'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GroupForm(
                        group: group,
                        onSuccess: _loadGroups,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Delete Group'),
                onTap: () async {
                  Navigator.pop(context);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Group'),
                      content: const Text(
                        'Are you sure you want to delete this group? This action cannot be undone.',
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
                  
                  if (confirmed == true) {
                    try {
                      await _dbService.deleteGroup(group.groupId!);
                      _loadGroups();
                      
                      if (!mounted) return;
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Group deleted successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error deleting group: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
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
                hintText: 'Search groups...',
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
          
          // Groups List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredGroups.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.group_off,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No groups found',
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
                                'Create a group to get started',
                                style: TextStyle(
                                  color: Colors.grey,
                                ),
                              ),
                            const SizedBox(height: 24),
                            if (_searchQuery.isEmpty)
                              ElevatedButton.icon(
                                onPressed: _navigateToAddGroup,
                                icon: const Icon(Icons.add),
                                label: const Text('Create Group'),
                              ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadGroups,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredGroups.length,
                          itemBuilder: (context, index) {
                            final group = _filteredGroups[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: InkWell(
                                onTap: () => _navigateToGroupDetails(group),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: Theme.of(context).primaryColor,
                                            child: Text(
                                              group.groupName.isNotEmpty
                                                  ? group.groupName[0].toUpperCase()
                                                  : 'G',
                                              style: const TextStyle(color: Colors.white),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  group.groupName,
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  'Created: ${UtilityService.formatDate(group.createdDate.toString())}',
                                                  style: const TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.more_vert),
                                            onPressed: () => _showGroupOptions(group),
                                          ),
                                        ],
                                      ),
                                      if (group.description != null && group.description!.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          group.description!,
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      const SizedBox(height: 16),
                                      FutureBuilder<int>(
                                        future: _getGroupMemberCount(group.groupId!),
                                        builder: (context, snapshot) {
                                          final memberCount = snapshot.data ?? 0;
                                          return Row(
                                            children: [
                                              _buildInfoItem(
                                                'Members',
                                                memberCount.toString(),
                                                Icons.people,
                                              ),
                                              const SizedBox(width: 24),
                                              FutureBuilder<int>(
                                                future: _getPendingEMICount(group.groupId!),
                                                builder: (context, snapshot) {
                                                  final emiCount = snapshot.data ?? 0;
                                                  return _buildInfoItem(
                                                    'Pending EMIs',
                                                    emiCount.toString(),
                                                    Icons.calendar_today,
                                                    color: emiCount > 0 ? Colors.red : null,
                                                  );
                                                },
                                              ),
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
        onPressed: _navigateToAddGroup,
        child: const Icon(Icons.add),
      ),
    );
  }
  
  Future<int> _getGroupMemberCount(int groupId) async {
    try {
      final members = await _dbService.getGroupMembers(groupId);
      return members.length;
    } catch (e) {
      debugPrint('Error getting group member count: $e');
      return 0;
    }
  }
  
  Future<int> _getPendingEMICount(int groupId) async {
    try {
      final emis = await _dbService.getEMIsByGroup(groupId);
      return emis.where((emi) => emi.paid == 0).length;
    } catch (e) {
      debugPrint('Error getting pending EMI count: $e');
      return 0;
    }
  }
  
  Widget _buildInfoItem(String label, String value, IconData icon, {Color? color}) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: color ?? Colors.grey),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: TextStyle(
              color: color ?? Colors.grey,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
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
                  'Filter Groups',
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
                    _groups.sort((a, b) => a.groupName.compareTo(b.groupName));
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Sort by Creation Date (Newest)'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _groups.sort((a, b) => b.createdDate.compareTo(a.createdDate));
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Sort by Creation Date (Oldest)'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _groups.sort((a, b) => a.createdDate.compareTo(b.createdDate));
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.people),
                title: const Text('Sort by Member Count'),
                onTap: () async {
                  Navigator.pop(context);
                  
                  // This is more complex as we need to fetch member counts first
                  final groupsWithCounts = await Future.wait(
                    _groups.map((group) async {
                      final count = await _getGroupMemberCount(group.groupId!);
                      return {'group': group, 'count': count};
                    }),
                  );
                  
                  groupsWithCounts.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
                  
                  setState(() {
                    _groups = groupsWithCounts.map((item) => item['group'] as Group).toList();
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
