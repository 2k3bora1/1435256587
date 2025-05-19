import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:chit_fund_flutter/config/constants.dart';
import 'package:chit_fund_flutter/models/chit_fund.dart';
import 'package:chit_fund_flutter/models/member.dart';
import 'package:chit_fund_flutter/services/database_service.dart';
import 'package:chit_fund_flutter/services/sync_service_new.dart';
import 'package:chit_fund_flutter/widgets/custom_alert_dialog.dart';
import 'package:chit_fund_flutter/widgets/loading_indicator.dart';

class ChitAuctionScreen extends StatefulWidget {
  final ChitFund chitFund;

  const ChitAuctionScreen({
    Key? key,
    required this.chitFund,
  }) : super(key: key);

  @override
  State<ChitAuctionScreen> createState() => _ChitAuctionScreenState();
}

class _ChitAuctionScreenState extends State<ChitAuctionScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<ChitAuction> _auctions = [];
  List<ChitMember> _chitMembers = [];
  List<Member> _members = [];
  bool _isLoading = true;
  bool _showNewAuctionForm = false;
  bool _showBiddingForm = false;
  
  // Form controllers
  final TextEditingController _auctionDateController = TextEditingController();
  final TextEditingController _bidAmountController = TextEditingController();
  String? _selectedWinnerAadhaar;
  
  // Bidding form
  final TextEditingController _bidderAadhaarController = TextEditingController();
  final TextEditingController _bidderAmountController = TextEditingController();
  
  // Current auction
  ChitAuction? _currentAuction;
  List<ChitBid> _currentBids = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    
    // Set default auction date to today
    _auctionDateController.text = DateTime.now().toIso8601String().split('T')[0];
  }

  @override
  void dispose() {
    _auctionDateController.dispose();
    _bidAmountController.dispose();
    _bidderAadhaarController.dispose();
    _bidderAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load auctions
      final auctions = await _dbService.getChitAuctions(widget.chitFund.chitId!);
      
      // Load chit members
      final chitMembers = await _dbService.getChitMembers(widget.chitFund.chitId!);
      
      // Get full member details for each chit member
      List<Member> members = [];
      for (var chitMember in chitMembers) {
        final member = await _dbService.getMember(chitMember.aadhaar);
        if (member != null) {
          members.add(member);
        }
      }
      
      // Load current auction and bids if available
      ChitAuction? currentAuction;
      List<ChitBid> currentBids = [];
      
      if (auctions.isNotEmpty) {
        // Find the latest auction
        auctions.sort((a, b) => b.auctionDate.compareTo(a.auctionDate));
        currentAuction = auctions.first;
        
        // Load bids for the current auction
        currentBids = await _dbService.getChitBids(currentAuction.chitId, currentAuction.cycle);
      }

      setState(() {
        _auctions = auctions;
        _chitMembers = chitMembers;
        _members = members;
        _currentAuction = currentAuction;
        _currentBids = currentBids;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Error loading auction data: $e');
    }
  }

  Future<void> _createAuction() async {
    if (_auctionDateController.text.isEmpty) {
      _showErrorDialog('Please select an auction date');
      return;
    }

    if (_selectedWinnerAadhaar == null) {
      _showErrorDialog('Please select a winner');
      return;
    }

    if (_bidAmountController.text.isEmpty) {
      _showErrorDialog('Please enter a bid amount');
      return;
    }

    final bidAmount = double.tryParse(_bidAmountController.text);
    if (bidAmount == null || bidAmount <= 0) {
      _showErrorDialog('Please enter a valid bid amount');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Determine the current cycle
      int currentCycle = widget.chitFund.currentCycle + 1;
      
      // Create a new auction
      final auction = ChitAuction(
        chitId: widget.chitFund.chitId!,
        auctionDate: _auctionDateController.text,
        winnerAadhaar: _selectedWinnerAadhaar!,
        bidAmount: bidAmount,
        cycle: currentCycle,
        status: 'Completed',
      );

      // Add to database
      final auctionId = await _dbService.addChitAuction(auction);
      
      // Update the chit fund's current cycle and next auction date
      final nextAuctionDate = DateTime.parse(_auctionDateController.text)
          .add(const Duration(days: 30))
          .toIso8601String()
          .split('T')[0];
      
      final updatedChitFund = widget.chitFund.copyWith(
        currentCycle: currentCycle,
        nextAuctionDate: nextAuctionDate,
      );
      
      await _dbService.updateChitFund(updatedChitFund);
      
      // Create a winning bid
      final winningBid = ChitBid(
        chitId: widget.chitFund.chitId!,
        aadhaar: _selectedWinnerAadhaar!,
        bidDate: _auctionDateController.text,
        bidAmount: bidAmount,
        won: 1,
      );
      
      await _dbService.addChitBid(winningBid);
      
      // Generate EMIs for all members
      final monthlyContribution = widget.chitFund.totalAmount / widget.chitFund.memberCount;
      
      for (var chitMember in _chitMembers) {
        // Skip the winner for this cycle's EMI
        if (chitMember.aadhaar == _selectedWinnerAadhaar) continue;
        
        final emiDueDate = DateTime.parse(_auctionDateController.text)
            .add(const Duration(days: 15))
            .toIso8601String()
            .split('T')[0];
        
        final emi = ChitEMI(
          chitId: widget.chitFund.chitId!,
          aadhaar: chitMember.aadhaar,
          dueDate: emiDueDate,
          amount: monthlyContribution,
        );
        
        await _dbService.addChitEMI(emi);
      }
      
      // Mark changes as pending for sync
      final syncService = Provider.of<SyncService>(context, listen: false);
      await syncService.markChangesAsPending();

      // Reload data
      await _loadData();
      
      setState(() {
        _showNewAuctionForm = false;
        _selectedWinnerAadhaar = null;
        _auctionDateController.text = DateTime.now().toIso8601String().split('T')[0];
        _bidAmountController.clear();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Auction created successfully')),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Error creating auction: $e');
    }
  }

  Future<void> _addBid() async {
    if (_bidderAadhaarController.text.isEmpty) {
      _showErrorDialog('Please select a bidder');
      return;
    }

    if (_bidderAmountController.text.isEmpty) {
      _showErrorDialog('Please enter a bid amount');
      return;
    }

    final bidAmount = double.tryParse(_bidderAmountController.text);
    if (bidAmount == null || bidAmount <= 0) {
      _showErrorDialog('Please enter a valid bid amount');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Create a new bid
      final bid = ChitBid(
        chitId: widget.chitFund.chitId!,
        aadhaar: _bidderAadhaarController.text,
        bidDate: DateTime.now().toIso8601String().split('T')[0],
        bidAmount: bidAmount,
      );

      // Add to database
      await _dbService.addChitBid(bid);
      
      // Mark changes as pending for sync
      final syncService = Provider.of<SyncService>(context, listen: false);
      await syncService.markChangesAsPending();

      // Reload data
      await _loadData();
      
      setState(() {
        _showBiddingForm = false;
        _bidderAadhaarController.clear();
        _bidderAmountController.clear();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bid added successfully')),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Error adding bid: $e');
    }
  }

  Future<void> _selectWinningBid(ChitBid bid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Winner'),
        content: Text('Are you sure you want to select this bid as the winner?\n\nBidder: ${_getMemberName(bid.aadhaar)}\nBid Amount: ${NumberFormat.currency(symbol: '₹', locale: 'en_IN', decimalDigits: 0).format(bid.bidAmount)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Select'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Update the bid as won
      final updatedBid = bid.copyWith(won: 1);
      await _dbService.updateChitBid(updatedBid);
      
      // Update all other bids for this auction as not won
      for (var otherBid in _currentBids) {
        if (otherBid.bidId != bid.bidId) {
          final updatedOtherBid = otherBid.copyWith(won: 0);
          await _dbService.updateChitBid(updatedOtherBid);
        }
      }
      
      // Update the auction with the winner
      if (_currentAuction != null) {
        final updatedAuction = ChitAuction(
          auctionId: _currentAuction!.auctionId,
          chitId: _currentAuction!.chitId,
          auctionDate: _currentAuction!.auctionDate,
          winnerAadhaar: bid.aadhaar,
          bidAmount: bid.bidAmount,
          cycle: _currentAuction!.cycle,
          status: 'Completed',
        );
        
        await _dbService.updateChitAuction(updatedAuction);
      }
      
      // Mark changes as pending for sync
      final syncService = Provider.of<SyncService>(context, listen: false);
      await syncService.markChangesAsPending();

      // Reload data
      await _loadData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Winner selected successfully')),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Error selecting winner: $e');
    }
  }

  String _getMemberName(String aadhaar) {
    final member = _members.firstWhere(
      (m) => m.aadhaar == aadhaar,
      orElse: () => Member(
        aadhaar: aadhaar,
        name: 'Unknown Member',
        phone: '',
        address: '',
        joinDate: '',
      ),
    );
    
    return member.name;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.chitFund.chitName} - Auctions'),
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
                            const Text('Current Cycle:'),
                            Text(
                              '${widget.chitFund.currentCycle} / ${widget.chitFund.duration}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Next Auction:'),
                            Text(
                              widget.chitFund.nextAuctionDate != null
                                  ? DateFormat('dd MMM yyyy').format(DateTime.parse(widget.chitFund.nextAuctionDate!))
                                  : 'Not scheduled',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Members:'),
                            Text(
                              '${_chitMembers.length} / ${widget.chitFund.memberCount}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _chitMembers.length < widget.chitFund.memberCount
                                    ? Colors.orange
                                    : Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Current auction section
                if (_currentAuction != null)
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Current Auction',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Date:'),
                              Text(
                                DateFormat('dd MMM yyyy').format(DateTime.parse(_currentAuction!.auctionDate)),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Cycle:'),
                              Text(
                                '${_currentAuction!.cycle}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Status:'),
                              Text(
                                _currentAuction!.status,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _currentAuction!.status == 'Completed'
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                              ),
                            ],
                          ),
                          if (_currentAuction!.status == 'Completed')
                            Column(
                              children: [
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Winner:'),
                                    Text(
                                      _getMemberName(_currentAuction!.winnerAadhaar),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Bid Amount:'),
                                    Text(
                                      NumberFormat.currency(
                                        symbol: '₹',
                                        locale: 'en_IN',
                                        decimalDigits: 0,
                                      ).format(_currentAuction!.bidAmount),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (_currentAuction!.status != 'Completed')
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _showBiddingForm = true;
                                    });
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Bid'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Bids list
                if (_currentAuction != null && _currentBids.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bids',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _currentBids.length,
                          itemBuilder: (context, index) {
                            final bid = _currentBids[index];
                            final isWinner = bid.won == 1;
                            
                            return Card(
                              color: isWinner ? Colors.green.shade50 : null,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isWinner ? Colors.green : Colors.blue,
                                  child: Icon(
                                    isWinner ? Icons.emoji_events : Icons.person,
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(_getMemberName(bid.aadhaar)),
                                subtitle: Text(
                                  'Bid: ${NumberFormat.currency(symbol: '₹', locale: 'en_IN', decimalDigits: 0).format(bid.bidAmount)}\nDate: ${DateFormat('dd MMM yyyy').format(DateTime.parse(bid.bidDate))}',
                                ),
                                trailing: _currentAuction!.status != 'Completed'
                                    ? TextButton(
                                        onPressed: () => _selectWinningBid(bid),
                                        child: const Text('Select Winner'),
                                      )
                                    : isWinner
                                        ? const Icon(Icons.check_circle, color: Colors.green)
                                        : null,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                
                // Past auctions
                if (_auctions.length > 1)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Past Auctions',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _auctions.length - 1, // Skip the current auction
                              itemBuilder: (context, index) {
                                // Skip the current auction
                                final auction = _auctions[index + 1];
                                
                                return Card(
                                  child: ListTile(
                                    title: Text('Cycle ${auction.cycle}'),
                                    subtitle: Text(
                                      'Date: ${DateFormat('dd MMM yyyy').format(DateTime.parse(auction.auctionDate))}\nWinner: ${_getMemberName(auction.winnerAadhaar)}\nBid: ${NumberFormat.currency(symbol: '₹', locale: 'en_IN', decimalDigits: 0).format(auction.bidAmount)}',
                                    ),
                                    trailing: const Icon(Icons.emoji_events, color: Colors.amber),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // No auctions yet
                if (_auctions.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.gavel,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No auctions yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _showNewAuctionForm = true;
                              });
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Create First Auction'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
      floatingActionButton: _auctions.isEmpty || (_currentAuction != null && _currentAuction!.cycle < widget.chitFund.duration)
          ? FloatingActionButton(
              onPressed: () {
                setState(() {
                  _showNewAuctionForm = true;
                });
              },
              child: const Icon(Icons.add),
            )
          : null,
      
      // New auction form
      bottomSheet: _showNewAuctionForm
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
                          'New Auction',
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
                              _showNewAuctionForm = false;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  // Form
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Auction date
                          const Text(
                            'Auction Date',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _auctionDateController,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Select date',
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            readOnly: true,
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                lastDate: DateTime.now().add(const Duration(days: 30)),
                              );
                              
                              if (date != null) {
                                setState(() {
                                  _auctionDateController.text = date.toIso8601String().split('T')[0];
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Winner selection
                          const Text(
                            'Winner',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _selectedWinnerAadhaar,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Select winner',
                              prefixIcon: Icon(Icons.person),
                            ),
                            items: _chitMembers.map((chitMember) {
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
                              
                              return DropdownMenuItem<String>(
                                value: chitMember.aadhaar,
                                child: Text(member.name),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedWinnerAadhaar = value;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Bid amount
                          const Text(
                            'Bid Amount',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _bidAmountController,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Enter bid amount',
                              prefixIcon: Icon(Icons.currency_rupee),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 16),
                          
                          // Info text
                          const Text(
                            'Note: Creating an auction will automatically generate EMIs for all members except the winner.',
                            style: TextStyle(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Create button
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _createAuction,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Create Auction'),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : _showBiddingForm
              ? Container(
                  height: MediaQuery.of(context).size.height * 0.5,
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
                              'Add Bid',
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
                                  _showBiddingForm = false;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      
                      // Form
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Bidder selection
                              const Text(
                                'Bidder',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: _bidderAadhaarController.text.isNotEmpty
                                    ? _bidderAadhaarController.text
                                    : null,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  hintText: 'Select bidder',
                                  prefixIcon: Icon(Icons.person),
                                ),
                                items: _chitMembers.map((chitMember) {
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
                                  
                                  return DropdownMenuItem<String>(
                                    value: chitMember.aadhaar,
                                    child: Text(member.name),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _bidderAadhaarController.text = value ?? '';
                                  });
                                },
                              ),
                              const SizedBox(height: 16),
                              
                              // Bid amount
                              const Text(
                                'Bid Amount',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _bidderAmountController,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  hintText: 'Enter bid amount',
                                  prefixIcon: Icon(Icons.currency_rupee),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Add button
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _addBid,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Add Bid'),
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