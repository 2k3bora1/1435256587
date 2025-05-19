import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';

class UtilityService {
  // Date formatting
  static String formatDate(String dateStr, {String format = 'dd/MM/yyyy'}) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat(format).format(date);
    } catch (e) {
      return dateStr;
    }
  }
  
  static String getCurrentDate({String format = 'yyyy-MM-dd'}) {
    return DateFormat(format).format(DateTime.now());
  }
  
  // Currency formatting
  static String formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(2)}';
  }
  
  // Image picking
  static Future<Uint8List?> pickImage({bool fromCamera = false}) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = fromCamera
          ? await picker.pickImage(source: ImageSource.camera)
          : await picker.pickImage(source: ImageSource.gallery);
      
      if (image == null) return null;
      
      return await image.readAsBytes();
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }
  
  // Document picking
  static Future<Uint8List?> pickDocument() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
      );
      
      if (result == null || result.files.isEmpty) return null;
      
      final file = result.files.first;
      
      if (file.bytes != null) {
        // Web platform
        return file.bytes;
      } else if (file.path != null) {
        // Mobile/Desktop platform
        return await File(file.path!).readAsBytes();
      }
      
      return null;
    } catch (e) {
      debugPrint('Error picking document: $e');
      return null;
    }
  }
  
  // EMI calculation
  static double calculateEMI(double principal, double rate, int tenure) {
    // Convert interest rate from percentage to decimal and then to monthly
    double monthlyRate = rate / (12 * 100);
    
    // Calculate EMI using formula: P * r * (1+r)^n / ((1+r)^n - 1)
    double emi = principal * monthlyRate * pow((1 + monthlyRate), tenure) / (pow((1 + monthlyRate), tenure) - 1);
    
    return emi;
  }
  
  // Custom EMI calculation with prepaid interest model
  static Map<String, dynamic> calculateCustomEMI(double loanAmount, double interestRate, int durationMonths) {
    // Calculate monthly interest
    double monthlyInterest = (loanAmount * (interestRate / 100)) / 12;
    
    // Calculate total interest for the loan period
    double totalInterest = monthlyInterest * durationMonths;
    
    // Calculate disbursed amount (loan amount minus total interest)
    double disbursedAmount = loanAmount - totalInterest;
    
    // Calculate EMI (equal monthly installment) and round up to nearest whole number
    double emiExact = loanAmount / durationMonths;
    double emi = (emiExact.ceil()).toDouble();
    
    return {
      "emi": emi,
      "disbursed_amount": disbursedAmount,
      "total_interest": totalInterest
    };
  }
  
  // Generate amortization schedule
  static List<Map<String, dynamic>> generateAmortizationSchedule(
    double principal,
    double rate,
    int tenure,
    String startDate,
  ) {
    List<Map<String, dynamic>> schedule = [];
    
    double monthlyRate = rate / (12 * 100);
    double emi = calculateEMI(principal, rate, tenure);
    double balance = principal;
    
    DateTime dueDate = DateTime.parse(startDate);
    
    for (int i = 1; i <= tenure; i++) {
      // Calculate interest for this month
      double interest = balance * monthlyRate;
      
      // Calculate principal for this month
      double principalPaid = emi - interest;
      
      // Update balance
      balance -= principalPaid;
      if (balance < 0) balance = 0;
      
      // Add one month to due date
      dueDate = DateTime(dueDate.year, dueDate.month + 1, dueDate.day);
      
      // Add to schedule
      schedule.add({
        'month': i,
        'due_date': DateFormat('yyyy-MM-dd').format(dueDate),
        'emi': emi,
        'principal': principalPaid,
        'interest': interest,
        'balance': balance,
      });
    }
    
    return schedule;
  }
  
  // Generate custom EMI schedule with prepaid interest model
  static List<Map<String, dynamic>> generateCustomEMISchedule(
    double loanAmount,
    double interestRate,
    int durationMonths,
    String startDate,
  ) {
    List<Map<String, dynamic>> schedule = [];
    
    // Calculate EMI details using the custom method
    final emiDetails = calculateCustomEMI(loanAmount, interestRate, durationMonths);
    double emi = emiDetails["emi"];
    
    // The interest is prepaid, so each EMI is purely principal
    double remainingBalance = loanAmount;
    
    DateTime dueDate = DateTime.parse(startDate);
    
    for (int i = 1; i <= durationMonths; i++) {
      // Add one month to due date
      dueDate = DateTime(dueDate.year, dueDate.month + 1, dueDate.day);
      
      // For prepaid interest model, each EMI payment reduces the principal directly
      double principalPaid = emi;
      
      // Update remaining balance
      remainingBalance -= principalPaid;
      if (remainingBalance < 0) remainingBalance = 0;
      
      // Add to schedule
      schedule.add({
        'month': i,
        'due_date': DateFormat('yyyy-MM-dd').format(dueDate),
        'emi': emi,
        'principal': principalPaid,
        'interest': 0.0, // Interest is prepaid, so monthly interest is 0
        'balance': remainingBalance,
      });
    }
    
    return schedule;
  }
  
  // Generate receipt PDF
  static Future<Uint8List> generateReceiptPDF({
    required String receiptNumber,
    required String date,
    required String memberName,
    required String memberAadhaar,
    required String paymentType,
    required double amount,
    required String description,
    String? companyName,
  }) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        companyName ?? 'Chit Fund Manager',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'PAYMENT RECEIPT',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                
                // Receipt details
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Receipt No: $receiptNumber'),
                    pw.Text('Date: $date'),
                  ],
                ),
                pw.Divider(),
                pw.SizedBox(height: 10),
                
                // Member details
                pw.Text('Received from: $memberName'),
                pw.Text('Aadhaar: $memberAadhaar'),
                pw.SizedBox(height: 20),
                
                // Payment details
                pw.Row(
                  children: [
                    pw.Text('Amount: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('₹${amount.toStringAsFixed(2)}'),
                  ],
                ),
                pw.SizedBox(height: 5),
                pw.Row(
                  children: [
                    pw.Text('Payment Mode: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(paymentType),
                  ],
                ),
                pw.SizedBox(height: 5),
                pw.Row(
                  children: [
                    pw.Text('Description: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(description),
                  ],
                ),
                pw.SizedBox(height: 30),
                
                // Footer
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Receiver Signature'),
                        pw.SizedBox(height: 20),
                        pw.Container(
                          width: 100,
                          height: 1,
                          color: PdfColors.black,
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Authorized Signature'),
                        pw.SizedBox(height: 20),
                        pw.Container(
                          width: 100,
                          height: 1,
                          color: PdfColors.black,
                        ),
                      ],
                    ),
                  ],
                ),
                pw.Spacer(),
                pw.Center(
                  child: pw.Text(
                    'Thank you for your payment',
                    style: pw.TextStyle(
                      fontStyle: pw.FontStyle.italic,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    
    return pdf.save();
  }
  
  // Print PDF
  static Future<void> printPDF(Uint8List pdfData) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfData,
    );
  }
  
  // Save PDF to file and share
  static Future<String?> savePDF(Uint8List pdfData, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(pdfData);
      
      // Share the file
      final result = await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Payment Receipt',
      );
      
      if (result.status == ShareResultStatus.success) {
        return file.path;
      }
      
      return file.path;
    } catch (e) {
      debugPrint('Error saving PDF: $e');
      return null;
    }
  }
  
  // View a document
  static Future<void> viewDocument(Uint8List documentData, String fileName) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(documentData);
      await OpenFile.open(file.path);
    } catch (e) {
      debugPrint('Error viewing document: $e');
    }
  }
  
  // Generate a unique receipt number
  static String generateReceiptNumber() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch.toString();
    return 'RCT-${timestamp.substring(timestamp.length - 8)}';
  }
  
  // Validate Aadhaar number
  static bool isValidAadhaar(String aadhaar) {
    // Basic validation: 12 digits
    return aadhaar.length == 12 && int.tryParse(aadhaar) != null;
  }
  
  // Validate phone number
  static bool isValidPhone(String phone) {
    // Basic validation: 10 digits
    return phone.length >= 10 && int.tryParse(phone) != null;
  }
  
  // Make a phone call
  static Future<void> makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    await launchUrl(launchUri);
  }
  
  // Send SMS
  static Future<void> sendSMS(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'sms',
      path: phoneNumber,
    );
    await launchUrl(launchUri);
  }
  
  // Open WhatsApp
  static Future<void> openWhatsApp(String phoneNumber) async {
    String formattedNumber = phoneNumber;
    if (formattedNumber.startsWith('+')) {
      formattedNumber = formattedNumber.substring(1);
    } else if (formattedNumber.startsWith('0')) {
      formattedNumber = '91${formattedNumber.substring(1)}';
    } else if (!formattedNumber.startsWith('91')) {
      formattedNumber = '91$formattedNumber';
    }
    
    final url = 'https://wa.me/$formattedNumber';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }
  
  // Send group SMS
  static Future<void> sendGroupSMS(List<String> phoneNumbers, String message) async {
    final Uri launchUri = Uri(
      scheme: 'sms',
      path: phoneNumbers.join(','),
      queryParameters: {'body': message},
    );
    await launchUrl(launchUri);
  }
  
  // Helper for calculating power (for EMI calculation)
  static double pow(double x, int n) {
    double result = 1.0;
    for (int i = 0; i < n; i++) {
      result *= x;
    }
    return result;
  }
}