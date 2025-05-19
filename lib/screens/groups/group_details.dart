import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chit_fund_flutter/models/group.dart';
import 'package:chit_fund_flutter/models/member.dart';
import 'package:chit_fund_flutter/services/database_service.dart';
import 'package:chit_fund_flutter/services/sync_service.dart';
import 'package:chit_fund_flutter/services/utility_service.dart';
import 'package:chit_fund_flutter/screens/groups/group_form.dart';
import 'package:chit_fund_flutter/screens/members/members_screen.dart';

class GroupDetails extends StatefulWidget {
  final Group group;
  final Function? onUpdate;

  const GroupDetails({
    Key? key,
    required this.group,
    this.onUpdate,
  }) : super(key: key);

  @override
  State<GroupDetails> createState() => _GroupDetailsState();
}

class _GroupDetailsState extends State<GroupDetails> {
  final DatabaseService _dbService = DatabaseService();
  
  List<Member> _groupMembers = [];
  Map<String, Member> _memberDetails = {};
  bool _isLoading = true;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _loadGroupDetails();
  }
  
  Future<void> _loadGroupDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Load group members
      final groupMembers = await _dbService.getGroupMembers(widget.group.groupId!);
      
      setState(() {
        _groupMembers = groupMembers.values.toList();
        _memberDetails = groupMembers;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading group details: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _editGroup() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupForm(
          group: widget.group,
          onSuccess: () {
            if (widget.onUpdate != null) {
              widget.onUpdate!();
            }
          },
        ),
      ),
    );
    
    if (result == true) {
      _loadGroupDetails();
    }
  }
  
  Future<void> _deleteGroup() async {
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
    
    if (confirmed != true) return;
    
    try {
      await _dbService.deleteGroup(widget.group.groupId!);
      
      // Sync changes to Drive
      final syncService = Provider.of<SyncService>(context, listen: false);
      await syncService.syncAfterChanges();
      
      if (widget.onUpdate != null) {
        widget.onUpdate!();
      }
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Group deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.pop(context);
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
  
  Future<void> _addMember() async {
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
      
      // Create group member
      final groupMember = GroupMember(
        groupId: widget.group.groupId!,
        aadhaar: selectedMember.aadhaar,
      );
      
      await _dbService.addMemberToGroup(groupMember);
      
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
      
      _loadGroupDetails();
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
  
  Future<void> _removeMember(GroupMember groupMember) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: const Text(
          'Are you sure you want to remove this member from the group?',
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
      await _dbService.removeMemberFromGroup(widget.group.groupId!, groupMember.aadhaar);
      
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
      
      _loadGroupDetails();
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
  
  Future<void> _sendGroupMessage() async {
    if (_groupMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No members in the group'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final message = await showDialog<String>(
      context: context,
      builder: (context) => _MessageDialog(),
    );
    
    if (message == null || message.isEmpty) return;
    
    try {
      // Get all phone numbers
      final phoneNumbers = _groupMembers
          .map((gm) => _memberDetails[gm.aadhaar]?.phone)
          .where((phone) => phone != null && phone.isNotEmpty)
          .toList();
      
      if (phoneNumbers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No valid phone numbers found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Send message to all members
      await UtilityService.sendGroupSMS(phoneNumbers as List<String>, message);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message sent successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.groupName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editGroup,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteGroup,
          ),
        ],
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
                        onPressed: _loadGroupDetails,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Group info card
                    Card(
                      margin: const EdgeInsets.all(16),
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
                                    widget.group.groupName.isNotEmpty
                                        ? widget.group.groupName[0].toUpperCase()
                                        : 'G',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.group.groupName,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Created: ${UtilityService.formatDate(widget.group.createdDate.toString())}',
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
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${_groupMembers.length} members',
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (widget.group.description != null &&
                                widget.group.description!.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 8),
                              Text(
                                widget.group.description!,
                                style: const TextStyle(
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildActionButton(
                                  icon: Icons.person_add,
                                  label: 'Add Member',
                                  onTap: _addMember,
                                ),
                                _buildActionButton(
                                  icon: Icons.message,
                                  label: 'Send Message',
                                  onTap: _sendGroupMessage,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Members list
                    Expanded(
                      child: _groupMembers.isEmpty
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
                                    'No members in this group',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Add members to get started',
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
                              itemCount: _groupMembers.length,
                              itemBuilder: (context, index) {
                                final groupMember = _groupMembers[index];
                                final memberDetail = _memberDetails[groupMember.aadhaar];
                                
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
                                                'Joined: ${UtilityService.formatDate(groupMember.joinDate)}',
                                                style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.call),
                                              onPressed: () => UtilityService.makePhoneCall(memberDetail.phone),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.message),
                                              onPressed: () => UtilityService.sendSMS(memberDetail.phone),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete),
                                              onPressed: () {
                                                final gm = GroupMember(
                                                  groupId: widget.group.groupId!,
                                                  aadhaar: memberDetail.aadhaar
                                                );
                                                _removeMember(gm);
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
      floatingActionButton: _groupMembers.isNotEmpty
          ? FloatingActionButton(
              onPressed: _addMember,
              child: const Icon(Icons.person_add),
            )
          : null,
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
}

class _MessageDialog extends StatefulWidget {
  @override
  State<_MessageDialog> createState() => _MessageDialogState();
}

class _MessageDialogState extends State<_MessageDialog> {
  final _messageController = TextEditingController();
  
  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Send Group Message'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _messageController,
            decoration: const InputDecoration(
              labelText: 'Message',
              hintText: 'Enter your message',
              border: OutlineInputBorder(),
            ),
            maxLines: 5,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _messageController.text),
          child: const Text('Send'),
        ),
      ],
    );
  }
}
