class EMIPayment {
  final int? paymentId;
  final int emiId;
  final String paymentDate;
  final double amountPaid;
  final String paymentType;
  final String? receiptNumber;

  EMIPayment({
    this.paymentId,
    required this.emiId,
    required this.paymentDate,
    required this.amountPaid,
    required this.paymentType,
    this.receiptNumber,
  });

  // Convert EMIPayment object to a Map
  Map<String, dynamic> toMap() {
    return {
      'payment_id': paymentId,
      'emi_id': emiId,
      'payment_date': paymentDate,
      'amount_paid': amountPaid,
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
      amountPaid: map['amount_paid'],
      paymentType: map['payment_type'],
      receiptNumber: map['receipt_number'],
    );
  }
}

class LoanPayment {
  final int? paymentId;
  final int emiId;
  final String paymentDate;
  final double amountPaid;
  final String paymentType;
  final String? receiptNumber;

  LoanPayment({
    this.paymentId,
    required this.emiId,
    required this.paymentDate,
    required this.amountPaid,
    required this.paymentType,
    this.receiptNumber,
  });

  // Convert LoanPayment object to a Map
  Map<String, dynamic> toMap() {
    return {
      'payment_id': paymentId,
      'emi_id': emiId,
      'payment_date': paymentDate,
      'amount_paid': amountPaid,
      'payment_type': paymentType,
      'receipt_number': receiptNumber,
    };
  }

  // Create LoanPayment object from a Map
  factory LoanPayment.fromMap(Map<String, dynamic> map) {
    return LoanPayment(
      paymentId: map['payment_id'],
      emiId: map['emi_id'],
      paymentDate: map['payment_date'],
      amountPaid: map['amount_paid'],
      paymentType: map['payment_type'],
      receiptNumber: map['receipt_number'],
    );
  }
}