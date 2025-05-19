class ChitFund {
  final int? chitId;
  final String chitName;
  final double totalAmount;
  final int duration;
  final String startDate;
  final int memberCount;
  final String status;
  final String? description;
  final double commissionRate;
  final String? nextAuctionDate;
  final int currentCycle;

  ChitFund({
    this.chitId,
    required this.chitName,
    required this.totalAmount,
    required this.duration,
    required this.startDate,
    required this.memberCount,
    this.status = 'active',
    this.description,
    required this.commissionRate,
    this.nextAuctionDate,
    this.currentCycle = 0,
  });

  // Convert ChitFund object to a Map
  Map<String, dynamic> toMap() {
    return {
      'chit_id': chitId,
      'chit_name': chitName,
      'total_amount': totalAmount,
      'duration': duration,
      'start_date': startDate,
      'member_count': memberCount,
      'status': status,
      'description': description,
      'commission_rate': commissionRate,
      'next_auction_date': nextAuctionDate,
      'current_cycle': currentCycle,
    };
  }

  // Create ChitFund object from a Map
  factory ChitFund.fromMap(Map<String, dynamic> map) {
    return ChitFund(
      chitId: map['chit_id'],
      chitName: map['chit_name'],
      totalAmount: map['total_amount'],
      duration: map['duration'],
      startDate: map['start_date'],
      memberCount: map['member_count'],
      status: map['status'],
      description: map['description'],
      commissionRate: map['commission_rate'],
      nextAuctionDate: map['next_auction_date'],
      currentCycle: map['current_cycle'],
    );
  }

  // Create a copy of ChitFund with modified fields
  ChitFund copyWith({
    int? chitId,
    String? chitName,
    double? totalAmount,
    int? duration,
    String? startDate,
    int? memberCount,
    String? status,
    String? description,
    double? commissionRate,
    String? nextAuctionDate,
    int? currentCycle,
  }) {
    return ChitFund(
      chitId: chitId ?? this.chitId,
      chitName: chitName ?? this.chitName,
      totalAmount: totalAmount ?? this.totalAmount,
      duration: duration ?? this.duration,
      startDate: startDate ?? this.startDate,
      memberCount: memberCount ?? this.memberCount,
      status: status ?? this.status,
      description: description ?? this.description,
      commissionRate: commissionRate ?? this.commissionRate,
      nextAuctionDate: nextAuctionDate ?? this.nextAuctionDate,
      currentCycle: currentCycle ?? this.currentCycle,
    );
  }
}

class ChitAuction {
  final int? auctionId;
  final int chitId;
  final String auctionDate;
  final String winnerAadhaar;
  final double bidAmount;
  final int cycle;
  final String status;

  ChitAuction({
    this.auctionId,
    required this.chitId,
    required this.auctionDate,
    required this.winnerAadhaar,
    required this.bidAmount,
    required this.cycle,
    required this.status,
  });

  // Convert ChitAuction object to a Map
  Map<String, dynamic> toMap() {
    return {
      'auction_id': auctionId,
      'chit_id': chitId,
      'auction_date': auctionDate,
      'winner_aadhaar': winnerAadhaar,
      'bid_amount': bidAmount,
      'cycle': cycle,
      'status': status,
    };
  }

  // Create ChitAuction object from a Map
  factory ChitAuction.fromMap(Map<String, dynamic> map) {
    return ChitAuction(
      auctionId: map['auction_id'],
      chitId: map['chit_id'],
      auctionDate: map['auction_date'],
      winnerAadhaar: map['winner_aadhaar'],
      bidAmount: map['bid_amount'],
      cycle: map['cycle'],
      status: map['status'],
    );
  }
}

class ChitMember {
  final int? id;
  final int chitId;
  final String aadhaar;
  final String joinDate;

  ChitMember({
    this.id,
    required this.chitId,
    required this.aadhaar,
    required this.joinDate,
  });

  // Convert ChitMember object to a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chit_id': chitId,
      'aadhaar': aadhaar,
      'join_date': joinDate,
    };
  }

  // Create ChitMember object from a Map
  factory ChitMember.fromMap(Map<String, dynamic> map) {
    return ChitMember(
      id: map['id'],
      chitId: map['chit_id'],
      aadhaar: map['aadhaar'],
      joinDate: map['join_date'],
    );
  }
}

class ChitBid {
  final int? bidId;
  final int chitId;
  final String aadhaar;
  final String bidDate;
  final double bidAmount;
  final int won;

  ChitBid({
    this.bidId,
    required this.chitId,
    required this.aadhaar,
    required this.bidDate,
    required this.bidAmount,
    this.won = 0,
  });

  // Convert ChitBid object to a Map
  Map<String, dynamic> toMap() {
    return {
      'bid_id': bidId,
      'chit_id': chitId,
      'aadhaar': aadhaar,
      'bid_date': bidDate,
      'bid_amount': bidAmount,
      'won': won,
    };
  }

  // Create ChitBid object from a Map
  factory ChitBid.fromMap(Map<String, dynamic> map) {
    return ChitBid(
      bidId: map['bid_id'],
      chitId: map['chit_id'],
      aadhaar: map['aadhaar'],
      bidDate: map['bid_date'],
      bidAmount: map['bid_amount'],
      won: map['won'],
    );
  }

  // Create a copy of ChitBid with modified fields
  ChitBid copyWith({
    int? bidId,
    int? chitId,
    String? aadhaar,
    String? bidDate,
    double? bidAmount,
    int? won,
  }) {
    return ChitBid(
      bidId: bidId ?? this.bidId,
      chitId: chitId ?? this.chitId,
      aadhaar: aadhaar ?? this.aadhaar,
      bidDate: bidDate ?? this.bidDate,
      bidAmount: bidAmount ?? this.bidAmount,
      won: won ?? this.won,
    );
  }
}

class ChitEMI {
  final int? emiId;
  final int chitId;
  final String aadhaar;
  final String dueDate;
  final double amount;
  final int paid;
  final String? paymentDate;

  ChitEMI({
    this.emiId,
    required this.chitId,
    required this.aadhaar,
    required this.dueDate,
    required this.amount,
    this.paid = 0,
    this.paymentDate,
  });

  // Convert ChitEMI object to a Map
  Map<String, dynamic> toMap() {
    return {
      'emi_id': emiId,
      'chit_id': chitId,
      'aadhaar': aadhaar,
      'due_date': dueDate,
      'amount': amount,
      'paid': paid,
      'payment_date': paymentDate,
    };
  }

  // Create ChitEMI object from a Map
  factory ChitEMI.fromMap(Map<String, dynamic> map) {
    return ChitEMI(
      emiId: map['emi_id'],
      chitId: map['chit_id'],
      aadhaar: map['aadhaar'],
      dueDate: map['due_date'],
      amount: map['amount'],
      paid: map['paid'],
      paymentDate: map['payment_date'],
    );
  }

  // Create a copy of ChitEMI with modified fields
  ChitEMI copyWith({
    int? emiId,
    int? chitId,
    String? aadhaar,
    String? dueDate,
    double? amount,
    int? paid,
    String? paymentDate,
  }) {
    return ChitEMI(
      emiId: emiId ?? this.emiId,
      chitId: chitId ?? this.chitId,
      aadhaar: aadhaar ?? this.aadhaar,
      dueDate: dueDate ?? this.dueDate,
      amount: amount ?? this.amount,
      paid: paid ?? this.paid,
      paymentDate: paymentDate ?? this.paymentDate,
    );
  }
}
