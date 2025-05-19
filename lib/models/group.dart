class Group {
  final int? groupId;
  final String groupName;
  final String? description;
  final DateTime createdDate;

  Group({
    this.groupId,
    required this.groupName,
    this.description,
    required this.createdDate,
  });

  // Convert Group object to a Map
  Map<String, dynamic> toMap() {
    return {
      'group_id': groupId,
      'group_name': groupName,
      'description': description,
      'created_date': createdDate.toIso8601String(),
    };
  }

  // Create Group object from a Map
  factory Group.fromMap(Map<String, dynamic> map) {
    return Group(
      groupId: map['group_id'],
      groupName: map['group_name'],
      description: map['description'],
      createdDate: DateTime.parse(map['created_date']),
    );
  }

  // Create a copy of Group with modified fields
  Group copyWith({
    int? groupId,
    String? groupName,
    String? description,
    DateTime? createdDate,
  }) {
    return Group(
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      description: description ?? this.description,
      createdDate: createdDate ?? this.createdDate,
    );
  }
}

class GroupMember {
  final int groupId;
  final String aadhaar;

  GroupMember({
    required this.groupId,
    required this.aadhaar,
  });

  // Convert GroupMember object to a Map
  Map<String, dynamic> toMap() {
    return {
      'group_id': groupId,
      'aadhaar': aadhaar,
    };
  }

  // Create GroupMember object from a Map
  factory GroupMember.fromMap(Map<String, dynamic> map) {
    return GroupMember(
      groupId: map['group_id'],
      aadhaar: map['aadhaar'],
    );
  }
}

class EMI {
  final int? emiId;
  final int groupId;
  final String aadhaar;
  final String dueDate;
  final double amount;
  final int paid;

  EMI({
    this.emiId,
    required this.groupId,
    required this.aadhaar,
    required this.dueDate,
    required this.amount,
    this.paid = 0,
  });

  // Convert EMI object to a Map
  Map<String, dynamic> toMap() {
    return {
      'emi_id': emiId,
      'group_id': groupId,
      'aadhaar': aadhaar,
      'due_date': dueDate,
      'amount': amount,
      'paid': paid,
    };
  }

  // Create EMI object from a Map
  factory EMI.fromMap(Map<String, dynamic> map) {
    return EMI(
      emiId: map['emi_id'],
      groupId: map['group_id'],
      aadhaar: map['aadhaar'],
      dueDate: map['due_date'],
      amount: map['amount'],
      paid: map['paid'],
    );
  }

  // Create a copy of EMI with modified fields
  EMI copyWith({
    int? emiId,
    int? groupId,
    String? aadhaar,
    String? dueDate,
    double? amount,
    int? paid,
  }) {
    return EMI(
      emiId: emiId ?? this.emiId,
      groupId: groupId ?? this.groupId,
      aadhaar: aadhaar ?? this.aadhaar,
      dueDate: dueDate ?? this.dueDate,
      amount: amount ?? this.amount,
      paid: paid ?? this.paid,
    );
  }
}

class EMIPayment {
  final int? paymentId;
  final int emiId;
  final String paymentDate;
  final double amount;
  final String paymentType;
  final String? receiptNumber;

  EMIPayment({
    this.paymentId,
    required this.emiId,
    required this.paymentDate,
    required this.amount,
    required this.paymentType,
    this.receiptNumber,
  });

  // Convert EMIPayment object to a Map
  Map<String, dynamic> toMap() {
    return {
      'payment_id': paymentId,
      'emi_id': emiId,
      'payment_date': paymentDate,
      'amount': amount,
      'payment_type': paymentType,
      'receipt_number': receiptNumber,
    };
  }

  // Create EMIPayment object from a Map
  factory EMIPayment.fromMap(Map<String, dynamic> map) {
    return EMIPayment(
      paymentId: map['payment_id'],
      emiId: map['emi_id'],
      paymentDate: map['payment_date'],
      amount: map['amount'],
      paymentType: map['payment_type'],
      receiptNumber: map['receipt_number'],
    );
  }
}
