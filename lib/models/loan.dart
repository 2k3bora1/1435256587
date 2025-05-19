import 'dart:typed_data';

class Loan {
  final int? loanId;
  final String memberAadhaar;
  final String? coApplicantAadhaar;
  final double amount;
  final double interestRate;
  final int duration;
  final String startDate;
  final double disbursedAmount;

  Loan({
    this.loanId,
    required this.memberAadhaar,
    this.coApplicantAadhaar,
    required this.amount,
    required this.interestRate,
    required this.duration,
    required this.startDate,
    required this.disbursedAmount,
  });

  // Convert Loan object to a Map
  Map<String, dynamic> toMap() {
    return {
      'loan_id': loanId,
      'member_aadhaar': memberAadhaar,
      'co_applicant_aadhaar': coApplicantAadhaar,
      'amount': amount,
      'interest_rate': interestRate,
      'duration': duration,
      'start_date': startDate,
      'disbursed_amount': disbursedAmount,
    };
  }

  // Create Loan object from a Map
  factory Loan.fromMap(Map<String, dynamic> map) {
    return Loan(
      loanId: map['loan_id'],
      memberAadhaar: map['member_aadhaar'],
      coApplicantAadhaar: map['co_applicant_aadhaar'],
      amount: map['amount'],
      interestRate: map['interest_rate'],
      duration: map['duration'],
      startDate: map['start_date'],
      disbursedAmount: map['disbursed_amount'],
    );
  }

  // Create a copy of Loan with modified fields
  Loan copyWith({
    int? loanId,
    String? memberAadhaar,
    String? coApplicantAadhaar,
    double? amount,
    double? interestRate,
    int? duration,
    String? startDate,
    double? disbursedAmount,
  }) {
    return Loan(
      loanId: loanId ?? this.loanId,
      memberAadhaar: memberAadhaar ?? this.memberAadhaar,
      coApplicantAadhaar: coApplicantAadhaar ?? this.coApplicantAadhaar,
      amount: amount ?? this.amount,
      interestRate: interestRate ?? this.interestRate,
      duration: duration ?? this.duration,
      startDate: startDate ?? this.startDate,
      disbursedAmount: disbursedAmount ?? this.disbursedAmount,
    );
  }
}

class LoanDocument {
  final int? documentId;
  final int loanId;
  final String? fileName;
  final Uint8List? file;

  LoanDocument({
    this.documentId,
    required this.loanId,
    this.fileName,
    this.file,
  });

  // Convert LoanDocument object to a Map
  Map<String, dynamic> toMap() {
    return {
      'document_id': documentId,
      'loan_id': loanId,
      'file_name': fileName,
      'file': file,
    };
  }

  // Create LoanDocument object from a Map
  factory LoanDocument.fromMap(Map<String, dynamic> map) {
    return LoanDocument(
      documentId: map['document_id'],
      loanId: map['loan_id'],
      fileName: map['file_name'],
      file: map['file'],
    );
  }
}

class LoanCheque {
  final int? chequeId;
  final int loanId;
  final String chequeNumber;
  final String bankName;
  final Uint8List? file;

  LoanCheque({
    this.chequeId,
    required this.loanId,
    required this.chequeNumber,
    required this.bankName,
    this.file,
  });

  // Convert LoanCheque object to a Map
  Map<String, dynamic> toMap() {
    return {
      'cheque_id': chequeId,
      'loan_id': loanId,
      'cheque_number': chequeNumber,
      'bank_name': bankName,
      'file': file,
    };
  }

  // Create LoanCheque object from a Map
  factory LoanCheque.fromMap(Map<String, dynamic> map) {
    return LoanCheque(
      chequeId: map['cheque_id'],
      loanId: map['loan_id'],
      chequeNumber: map['cheque_number'],
      bankName: map['bank_name'],
      file: map['file'],
    );
  }
}

class LoanAsset {
  final int? assetId;
  final int loanId;
  final Uint8List? file;

  LoanAsset({
    this.assetId,
    required this.loanId,
    this.file,
  });

  // Convert LoanAsset object to a Map
  Map<String, dynamic> toMap() {
    return {
      'asset_id': assetId,
      'loan_id': loanId,
      'file': file,
    };
  }

  // Create LoanAsset object from a Map
  factory LoanAsset.fromMap(Map<String, dynamic> map) {
    return LoanAsset(
      assetId: map['asset_id'],
      loanId: map['loan_id'],
      file: map['file'],
    );
  }
}

class LoanEMI {
  final int? emiId;
  final int loanId;
  final String dueDate;
  final double amount;
  final double principal;
  final double interest;
  final double balance;
  final int paid;
  final String? paymentDate;

  LoanEMI({
    this.emiId,
    required this.loanId,
    required this.dueDate,
    required this.amount,
    required this.principal,
    required this.interest,
    required this.balance,
    this.paid = 0,
    this.paymentDate,
  });

  // Convert LoanEMI object to a Map
  Map<String, dynamic> toMap() {
    return {
      'emi_id': emiId,
      'loan_id': loanId,
      'due_date': dueDate,
      'amount': amount,
      'principal': principal,
      'interest': interest,
      'balance': balance,
      'paid': paid,
      'payment_date': paymentDate,
    };
  }

  // Create LoanEMI object from a Map
  factory LoanEMI.fromMap(Map<String, dynamic> map) {
    return LoanEMI(
      emiId: map['emi_id'],
      loanId: map['loan_id'],
      dueDate: map['due_date'],
      amount: map['amount'],
      principal: map['principal'],
      interest: map['interest'],
      balance: map['balance'],
      paid: map['paid'],
      paymentDate: map['payment_date'],
    );
  }

  // Create a copy of LoanEMI with modified fields
  LoanEMI copyWith({
    int? emiId,
    int? loanId,
    String? dueDate,
    double? amount,
    double? principal,
    double? interest,
    double? balance,
    int? paid,
    String? paymentDate,
  }) {
    return LoanEMI(
      emiId: emiId ?? this.emiId,
      loanId: loanId ?? this.loanId,
      dueDate: dueDate ?? this.dueDate,
      amount: amount ?? this.amount,
      principal: principal ?? this.principal,
      interest: interest ?? this.interest,
      balance: balance ?? this.balance,
      paid: paid ?? this.paid,
      paymentDate: paymentDate ?? this.paymentDate,
    );
  }
}

class LoanEMIPayment {
  final int? paymentId;
  final int emiId;
  final String paymentDate;
  final double amount;
  final String paymentType;
  final String? receiptNumber;

  LoanEMIPayment({
    this.paymentId,
    required this.emiId,
    required this.paymentDate,
    required this.amount,
    required this.paymentType,
    this.receiptNumber,
  });

  // Convert LoanEMIPayment object to a Map
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

  // Create LoanEMIPayment object from a Map
  factory LoanEMIPayment.fromMap(Map<String, dynamic> map) {
    return LoanEMIPayment(
      paymentId: map['payment_id'],
      emiId: map['emi_id'],
      paymentDate: map['payment_date'],
      amount: map['amount'],
      paymentType: map['payment_type'],
      receiptNumber: map['receipt_number'],
    );
  }
}
