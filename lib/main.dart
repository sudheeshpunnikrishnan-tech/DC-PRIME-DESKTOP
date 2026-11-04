import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() {
  runApp(const MultiBillApp());
}

String sheetApiUrl =
    "https://script.google.com/macros/s/AKfycbzFDW5eeT4abGSRNLHlKs43JJ81YiKt0UrNEbbK2_cQIylsU_zGylqE8IMBqtpmXsjOEg/exec";

class UltraSmoothScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }
}

class CompanyConfig {
  static String name = "ANDROCODE SOFTWARE SOLUTIONS";
  static String tradeSubtitle = "Enterprise ERP & Billing Suite";
  static String address = "Market Road, Aluva, Ernakulam, Kerala - 683101";
  static String phone = "+91 98470 12345";
  static String email = "androcode.solutions@gmail.com";
  static String gstin = "32AABCD1234E1Z5";
  static String regType = "Regular";
  static String stateCode = "Kerala (32)";
  static String logoUrl = "";
  static double defaultGstRate = 5.0;
}

DateTime? parseUniversalDate(String dateStr) {
  if (dateStr.trim().isEmpty) return null;
  final s = dateStr.trim();
  try {
    if (s.contains('/')) {
      final parts = s.split(' ');
      final dateParts = parts[0].split('/');
      if (dateParts.length >= 3) {
        int day = int.parse(dateParts[0]);
        int month = int.parse(dateParts[1]);
        int year = int.parse(dateParts[2]);
        if (parts.length > 1 && parts[1].contains(':')) {
          final timeParts = parts[1].split(':');
          int hour = int.parse(timeParts[0]);
          int min = int.parse(timeParts[1]);
          if (parts.length > 2 && parts[2].toUpperCase() == 'PM' && hour < 12) hour += 12;
          if (parts.length > 2 && parts[2].toUpperCase() == 'AM' && hour == 12) hour = 0;
          return DateTime(year, month, day, hour, min);
        }
        return DateTime(year, month, day);
      }
    }

    final months = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12
    };
    final tokens = s.split(RegExp(r'[\s,]+'));
    if (tokens.length >= 4) {
      String? mToken;
      int? dToken;
      int? yToken;
      String? timeToken;

      for (var t in tokens) {
        final low = t.toLowerCase();
        if (months.containsKey(low)) {
          mToken = low;
        } else if (int.tryParse(t) != null) {
          int val = int.parse(t);
          if (val > 1900 && val < 2100) {
            yToken = val;
          } else if (val >= 1 && val <= 31 && dToken == null) {
            dToken = val;
          }
        } else if (t.contains(':') && t.split(':').length >= 2) {
          timeToken = t;
        }
      }

      if (mToken != null && dToken != null && yToken != null) {
        int h = 0;
        int m = 0;
        if (timeToken != null) {
          final tp = timeToken.split(':');
          h = int.tryParse(tp[0]) ?? 0;
          m = int.tryParse(tp[1]) ?? 0;
        }
        return DateTime(yToken, months[mToken]!, dToken, h, m);
      }
    }

    return DateTime.tryParse(s);
  } catch (_) {
    return null;
  }
}

String formatDisplayDateTime(String dateStr) {
  final dt = parseUniversalDate(dateStr);
  if (dt == null) return dateStr.split("GMT")[0].trim();
  final d = dt.day.toString().padLeft(2, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final y = dt.year;
  int hour = dt.hour;
  final ampm = hour >= 12 ? 'PM' : 'AM';
  hour = hour % 12;
  if (hour == 0) hour = 12;
  final hStr = hour.toString().padLeft(2, '0');
  final minStr = dt.minute.toString().padLeft(2, '0');
  return "$d/$m/$y $hStr:$minStr $ampm";
}

String getCurrentFormattedDateTime() {
  final now = DateTime.now();
  final d = now.day.toString().padLeft(2, '0');
  final m = now.month.toString().padLeft(2, '0');
  final y = now.year;
  int hour = now.hour;
  final ampm = hour >= 12 ? 'PM' : 'AM';
  hour = hour % 12;
  if (hour == 0) hour = 12;
  final hStr = hour.toString().padLeft(2, '0');
  final minStr = now.minute.toString().padLeft(2, '0');
  return "$d/$m/$y $hStr:$minStr $ampm";
}

class DCItem {
  int rowIndex;
  dynamic no;
  String name;
  String rateType;
  String rate;
  dynamic qty;
  String tallyName;
  String billedIn;
  bool isTaxable;

  DCItem({
    required this.rowIndex,
    required this.no,
    required this.name,
    required this.rateType,
    required this.rate,
    required this.qty,
    required this.tallyName,
    required this.billedIn,
    required this.isTaxable,
  });

  static final DCItem endOfList = DCItem(
    rowIndex: -999,
    no: '',
    name: 'End of List',
    rateType: '',
    rate: '',
    qty: '',
    tallyName: '',
    billedIn: '',
    isTaxable: false,
  );

  factory DCItem.fromJson(Map<String, dynamic> json) {
    return DCItem(
      rowIndex: json['rowIndex'] ?? 0,
      no: json['no'] ?? '',
      name: json['name'] ?? '',
      rateType: json['rateType'] ?? '',
      rate: json['rate']?.toString() ?? '0',
      qty: json['qty'] ?? '',
      tallyName: json['tallyName'] ?? '',
      billedIn: json['billedIn'] ?? '',
      isTaxable: json['isTaxable'] ?? false,
    );
  }
}

class DCCustomer {
  int rowIndex;
  dynamic slNo;
  String name;
  String contact;
  String address;
  String b2c;
  String b2b;
  String remarks;

  DCCustomer({
    required this.rowIndex,
    required this.slNo,
    required this.name,
    required this.contact,
    required this.address,
    required this.b2c,
    required this.b2b,
    required this.remarks,
  });

  factory DCCustomer.fromJson(Map<String, dynamic> json) {
    return DCCustomer(
      rowIndex: json['rowIndex'] ?? 0,
      slNo: json['slNo'] ?? '',
      name: json['name'] ?? '',
      contact: json['contact']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      b2c: json['b2c'] ?? '',
      b2b: json['b2b'] ?? '',
      remarks: json['remarks'] ?? '',
    );
  }

  String get billingTag {
    final r = remarks.toUpperCase();
    if (r.contains('CREDIT')) return 'CREDIT';
    if (r.contains('VAZHI BILL') || r.contains('VAZHIBILL')) return 'VAZHI BILL';
    if (r.contains('NO COOLI')) return 'NO COOLI';
    return 'REGULAR';
  }
}

class DCEstimate {
  final int rowIndex;
  final dynamic slNo;
  final String date;
  final String customer;
  final String itemSummary;
  final String coolie;
  final String sgst;
  final String cgst;
  final String roundOff;
  final String grandTotal;
  String status;

  DCEstimate({
    required this.rowIndex,
    required this.slNo,
    required this.date,
    required this.customer,
    required this.itemSummary,
    required this.coolie,
    required this.sgst,
    required this.cgst,
    required this.roundOff,
    required this.grandTotal,
    this.status = 'ACTIVE',
  });

  factory DCEstimate.fromJson(Map<String, dynamic> json) {
    return DCEstimate(
      rowIndex: json['rowIndex'] ?? 0,
      slNo: json['slNo'] ?? '',
      date: json['date'] ?? '',
      customer: json['customer'] ?? '',
      itemSummary: json['itemSummary'] ?? '',
      coolie: json['coolie']?.toString() ?? '0',
      sgst: json['sgst']?.toString() ?? '0',
      cgst: json['cgst']?.toString() ?? '0',
      roundOff: json['roundOff']?.toString() ?? '0',
      grandTotal: json['grandTotal']?.toString() ?? '0',
      status: json['status']?.toString() ?? 'ACTIVE',
    );
  }
}

class LoadingEntry {
  final String customerName;
  final String place;
  final String summary;
  final int bags;

  LoadingEntry({
    required this.customerName,
    required this.place,
    required this.summary,
    required this.bags,
  });
}

class InvoiceRowItem {
  DCItem? item;
  double rate;
  double qty;
  String unit;
  int bags;
  final FocusNode itemSearchFocus = FocusNode();
  final FocusNode rateFocus = FocusNode();
  final FocusNode qtyFocus = FocusNode();
  final FocusNode unitFocus = FocusNode();
  final FocusNode bagsFocus = FocusNode();

  final TextEditingController textCtrl = TextEditingController();
  final TextEditingController rateCtrl = TextEditingController();
  final TextEditingController qtyCtrl = TextEditingController();
  final TextEditingController bagsCtrl = TextEditingController();
  final LayerLink layerLink = LayerLink();

  InvoiceRowItem({
    this.item,
    this.rate = 0.0,
    this.qty = 1.0,
    this.unit = '',
    this.bags = 1,
  }) {
    if (item != null) {
      textCtrl.text = item!.name;
      rateCtrl.text = rate > 0 ? rate.toStringAsFixed(2) : '';
      qtyCtrl.text = qty > 0 ? qty.toStringAsFixed(0) : '1';
      bagsCtrl.text = bags > 0 ? bags.toString() : '1';
    }
  }

  double get amount => qty * rate;
}

Future<Uint8List> generateTallyPdf({
  required PdfPageFormat format,
  required String billNo,
  required String dateStr,
  required DCCustomer customer,
  required List<InvoiceRowItem> items,
  required double subTotal,
  required double coolie,
  required double sgst,
  required double cgst,
  required double roundOff,
  required double grandTotal,
}) async {
  final doc = pw.Document();

  pw.ImageProvider? logoImage;
  if (CompanyConfig.logoUrl.isNotEmpty) {
    try {
      final res = await http.get(Uri.parse(CompanyConfig.logoUrl));
      if (res.statusCode == 200) {
        logoImage = pw.MemoryImage(res.bodyBytes);
      }
    } catch (_) {}
  }

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (pw.Context context) {
        return pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                alignment: pw.Alignment.center,
                decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1))),
                child: pw.Row(
                  children: [
                    if (logoImage != null)
                      pw.Container(
                        width: 50,
                        height: 50,
                        margin: const pw.EdgeInsets.only(right: 12),
                        child: pw.Image(logoImage),
                      ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: logoImage != null ? pw.CrossAxisAlignment.start : pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text("TAX INVOICE", style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 2),
                          pw.Text(CompanyConfig.name, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                          pw.Text("${CompanyConfig.tradeSubtitle}, ${CompanyConfig.address}", style: const pw.TextStyle(fontSize: 9)),
                          pw.Text("GSTIN/UIN: ${CompanyConfig.gstin} | State: ${CompanyConfig.stateCode} | Ph: ${CompanyConfig.phone}", style: const pw.TextStyle(fontSize: 9)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.Container(
                decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1))),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 6,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 1))),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text("Buyer / Consignee:", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                            pw.Text(customer.name, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                            if (customer.b2b.isNotEmpty) pw.Text("Trade Name: ${customer.b2b}", style: const pw.TextStyle(fontSize: 9)),
                            if (customer.address.isNotEmpty) pw.Text("Address: ${customer.address}", style: const pw.TextStyle(fontSize: 9)),
                            if (customer.contact.isNotEmpty) pw.Text("Phone: ${customer.contact}", style: const pw.TextStyle(fontSize: 9)),
                          ],
                        ),
                      ),
                    ),
                    pw.Expanded(
                      flex: 4,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text("Invoice No: $billNo", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 4),
                            pw.Text("Dated: $dateStr", style: const pw.TextStyle(fontSize: 9)),
                            pw.SizedBox(height: 4),
                            pw.Text("Place of Supply: ${CompanyConfig.stateCode}", style: const pw.TextStyle(fontSize: 9)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              pw.Container(
                color: PdfColors.grey200,
                decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1))),
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: pw.Row(
                  children: [
                    pw.SizedBox(width: 25, child: pw.Text("Sl", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(flex: 5, child: pw.Text("Description of Goods", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                    pw.SizedBox(width: 50, child: pw.Text("Rate", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                    pw.SizedBox(width: 40, child: pw.Text("Qty", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                    pw.SizedBox(width: 35, child: pw.Text("Unit", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                    pw.SizedBox(width: 35, child: pw.Text("Bags", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                    pw.SizedBox(width: 70, child: pw.Text("Amount", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.ListView.builder(
                  padding: pw.EdgeInsets.zero,
                  itemCount: items.length,
                  itemBuilder: (ctx, idx) {
                    final itm = items[idx];
                    return pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey400))),
                      child: pw.Row(
                        children: [
                          pw.SizedBox(width: 25, child: pw.Text("${idx + 1}", style: const pw.TextStyle(fontSize: 9))),
                          pw.Expanded(flex: 5, child: pw.Text(itm.item?.name ?? '', style: const pw.TextStyle(fontSize: 9))),
                          pw.SizedBox(width: 50, child: pw.Text(itm.rate.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9))),
                          pw.SizedBox(width: 40, child: pw.Text("${itm.qty.toInt()}", textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9))),
                          pw.SizedBox(width: 35, child: pw.Text(itm.unit, textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9))),
                          pw.SizedBox(width: 35, child: pw.Text("${itm.bags}", textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9))),
                          pw.SizedBox(width: 70, child: pw.Text(itm.amount.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9))),
                        ],
                      ),
                    );
                  },
                ),
              ),
              pw.Container(
                decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 1))),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Expanded(
                      flex: 5,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text("Bank: SBI Aluva Branch", style: const pw.TextStyle(fontSize: 8)),
                            pw.Text("A/c No: 12345678901 | IFS Code: SBIN0001234", style: const pw.TextStyle(fontSize: 8)),
                            pw.SizedBox(height: 25),
                            pw.Text("for ${CompanyConfig.name}", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 15),
                            pw.Text("Authorised Signatory", style: const pw.TextStyle(fontSize: 8)),
                            pw.SizedBox(height: 5),
                            pw.Text("Powered by MULTIBILL ERP • ANDROCODE SOFTWARE SOLUTIONS", style: const pw.TextStyle(fontSize: 5, color: PdfColors.grey600)),
                          ],
                        ),
                      ),
                    ),
                    pw.Expanded(
                      flex: 5,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        decoration: const pw.BoxDecoration(border: pw.Border(left: pw.BorderSide(width: 1))),
                        child: pw.Column(
                          children: [
                            _pdfSummaryRow("Sub Total (Taxable Base)", "Rs ${subTotal.toStringAsFixed(2)}"),
                            if (coolie > 0) _pdfSummaryRow("Coolie Charges", "Rs ${coolie.toStringAsFixed(2)}"),
                            if (sgst > 0) _pdfSummaryRow("Incl. SGST @ 2.5%", "Rs ${sgst.toStringAsFixed(2)}"),
                            if (cgst > 0) _pdfSummaryRow("Incl. CGST @ 2.5%", "Rs ${cgst.toStringAsFixed(2)}"),
                            _pdfSummaryRow("Round Off", "Rs ${roundOff.toStringAsFixed(2)}"),
                            pw.Divider(thickness: 1),
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text("Total Amount:", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                                pw.Text("Rs ${grandTotal.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  return doc.save();
}

pw.Widget _pdfSummaryRow(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
        pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
      ],
    ),
  );
}

final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier<ThemeMode>(ThemeMode.dark);

class MultiBillApp extends StatelessWidget {
  const MultiBillApp({super.key});

  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1A73E8),
      brightness: brightness,
      surface: dark ? const Color(0xFF111418) : const Color(0xFFF8F9FA),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? const Color(0xFF0C0E11) : const Color(0xFFF1F3F4),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: dark ? const Color(0xFF171A1F) : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF1D2128) : const Color(0xFFF1F5FB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant.withOpacity(0.4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant.withOpacity(0.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, mode, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'MULTIBILL ERP',
        scrollBehavior: UltraSmoothScrollBehavior(),
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        themeMode: mode,
        home: const MainDashboard(),
      ),
    );
  }
}

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  // 0: Sales (F8), 1: Purchase (F9), 2: Receipt (F6), 3: Payment (F5), 4: Price List, 5: Customers, 6: Packing Slip, 7: Invoices, 8: Reports, 9: Settings
  int _navIndex = 0;
  List<DCItem> _items = [];
  List<DCCustomer> _customers = [];
  List<DCEstimate> _estimates = [];
  List<Map<String, dynamic>> _allVouchers = [];
  final List<LoadingEntry> _loadingSlip = [];
  List<dynamic> _suppliers = [];
  bool _isLoading = true;
  bool _isBackgroundSyncing = false;

  DCEstimate? _invoiceToEdit;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    } else {
      setState(() => _isBackgroundSyncing = true);
    }

    try {
      final res = await http.get(Uri.parse(sheetApiUrl));
      if (res.statusCode == 200 || res.statusCode == 302) {
        final data = jsonDecode(res.body);
        final List itemList = data['items'] ?? [];
        final List custList = data['customers'] ?? [];
        final List estList = data['estimates'] ?? [];
        final List suppList = data['suppliers'] ?? [];
        final List purchaseList = data['purchases'] ?? [];
        final List receiptList = data['receipts'] ?? [];
        final List paymentList = data['payments'] ?? [];

        String valOf(Map row, List<String> keys, [String fallback = '']) {
          for (final key in keys) {
            final value = row[key];
            if (value != null && value.toString().trim().isNotEmpty) return value.toString();
          }
          return fallback;
        }
        Map<String, dynamic> voucher(String type, Map row, List<String> noKeys, List<String> partyKeys, List<String> amountKeys, List<String> summaryKeys) => {
          'type': type,
          'number': valOf(row, noKeys, '-'),
          'date': valOf(row, ['date', 'Date']),
          'party': valOf(row, partyKeys, '-'),
          'amount': valOf(row, amountKeys, '0'),
          'summary': valOf(row, summaryKeys),
          'mode': valOf(row, ['mode', 'paymentMode', 'Payment Mode']),
          'reference': valOf(row, ['reference', 'referenceNo', 'Reference No']),
          'status': valOf(row, ['status', 'Status'], 'ACTIVE'),
        };
        final List<Map<String, dynamic>> voucherRows = [
          ...estList.map((e) => voucher('SALES', e as Map, ['slNo', 'voucherNo', 'invoiceNo'], ['customer'], ['grandTotal'], ['itemSummary'])),
          ...purchaseList.map((e) => voucher('PURCHASE', e as Map, ['voucherNo', 'purchaseNo'], ['supplier'], ['grandTotal'], ['itemSummary'])),
          ...receiptList.map((e) => voucher('RECEIPT', e as Map, ['receiptNo', 'voucherNo'], ['customer'], ['amount'], ['narration'])),
          ...paymentList.map((e) => voucher('PAYMENT', e as Map, ['paymentNo', 'voucherNo'], ['paidTo'], ['amount'], ['narration'])),
        ];
        // Newer Apps Script deployments may also expose a pre-combined vouchers array.
        // Prefer that payload when it contains records; otherwise use the four sheet arrays above.
        final List combinedVoucherList = data['vouchers'] is List ? data['vouchers'] as List : [];
        if (combinedVoucherList.isNotEmpty) {
          voucherRows
            ..clear()
            ..addAll(combinedVoucherList.whereType<Map>().map((row) {
              final rawType = valOf(row, ['type', 'voucherType', 'category'], 'SALES').toUpperCase();
              final type = rawType.contains('PUR') ? 'PURCHASE' : rawType.contains('REC') ? 'RECEIPT' : rawType.contains('PAY') ? 'PAYMENT' : 'SALES';
              return voucher(type, row, ['number', 'voucherNo', 'receiptNo', 'paymentNo', 'slNo'], ['party', 'customer', 'supplier', 'paidTo'], ['amount', 'grandTotal'], ['summary', 'itemSummary', 'narration']);
            }));
        }
        voucherRows.sort((a, b) => (parseUniversalDate(b['date'] ?? '') ?? DateTime(2000)).compareTo(parseUniversalDate(a['date'] ?? '') ?? DateTime(2000)));

        if (data['company'] != null) {
          final comp = data['company'];
          CompanyConfig.logoUrl = comp['logoUrl'] ?? CompanyConfig.logoUrl;
          CompanyConfig.name = comp['name'] ?? CompanyConfig.name;
          CompanyConfig.tradeSubtitle = comp['tradeSubtitle'] ?? CompanyConfig.tradeSubtitle;
          CompanyConfig.address = comp['address'] ?? CompanyConfig.address;
          CompanyConfig.phone = comp['phone'] ?? CompanyConfig.phone;
          CompanyConfig.email = comp['email'] ?? CompanyConfig.email;
          CompanyConfig.gstin = comp['gstin'] ?? CompanyConfig.gstin;
          CompanyConfig.regType = comp['regType'] ?? CompanyConfig.regType;
        }

        setState(() {
          _items = itemList.map((i) => DCItem.fromJson(i)).toList();
          _customers = custList.map((c) => DCCustomer.fromJson(c)).toList();
          _estimates = estList.map((e) => DCEstimate.fromJson(e)).toList();
          _allVouchers = voucherRows;
          _suppliers = suppList;
          _isLoading = false;
          _isBackgroundSyncing = false;
        });
      }
    } catch (_) {
      setState(() {
        _isLoading = false;
        _isBackgroundSyncing = false;
      });
    }
  }

  void _onLoadInvoiceToEdit(DCEstimate est) {
    setState(() {
      _invoiceToEdit = est;
      _navIndex = 0; // Billing screen
    });
  }

  void _openCompanyProfileDialog() {
    final nameCtrl = TextEditingController(text: CompanyConfig.name);
    final subCtrl = TextEditingController(text: CompanyConfig.tradeSubtitle);
    final addrCtrl = TextEditingController(text: CompanyConfig.address);
    final phoneCtrl = TextEditingController(text: CompanyConfig.phone);
    final emailCtrl = TextEditingController(text: CompanyConfig.email);
    final gstinCtrl = TextEditingController(text: CompanyConfig.gstin);
    final regTypeCtrl = TextEditingController(text: CompanyConfig.regType);
    String logoBase64 = "";
    String logoPathLocal = "";

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.business_rounded, color: Color(0xFF1A73E8)),
              SizedBox(width: 10),
              Text('Company Profile & Header', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          backgroundImage: logoPathLocal.isNotEmpty
                              ? FileImage(File(logoPathLocal))
                              : (CompanyConfig.logoUrl.isNotEmpty ? NetworkImage(CompanyConfig.logoUrl) as ImageProvider : null),
                          child: (logoPathLocal.isEmpty && CompanyConfig.logoUrl.isEmpty)
                              ? const Text('AC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(logoPathLocal.isNotEmpty
                                  ? logoPathLocal.split(Platform.pathSeparator).last
                                  : (CompanyConfig.logoUrl.isNotEmpty ? 'Cloud Logo Synced' : 'Default Brand Logo')),
                              const SizedBox(height: 2),
                              const Text('Upload PNG or JPG', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.file_upload_outlined, size: 16),
                          label: const Text('Browse'),
                          onPressed: () async {
                            final res = await FilePicker.platform.pickFiles(type: FileType.image);
                            if (res != null && res.files.single.path != null) {
                              final filePath = res.files.single.path!;
                              final bytes = await File(filePath).readAsBytes();
                              setDlgState(() {
                                logoPathLocal = filePath;
                                logoBase64 = base64Encode(bytes);
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Company / Firm Name')),
                  const SizedBox(height: 10),
                  TextField(controller: subCtrl, decoration: const InputDecoration(labelText: 'Trade Subtitle / Slogan')),
                  const SizedBox(height: 10),
                  TextField(controller: addrCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Full Address')),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Contact Phone'))),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email Address'))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: gstinCtrl, decoration: const InputDecoration(labelText: 'GSTIN / UIN Number'))),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: regTypeCtrl, decoration: const InputDecoration(labelText: 'Reg. Type'))),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() => _isBackgroundSyncing = true);

                try {
                  final resp = await http.post(
                    Uri.parse(sheetApiUrl),
                    body: jsonEncode({
                      "action": "SAVE_COMPANY_DETAILS",
                      "name": nameCtrl.text.trim(),
                      "tradeSubtitle": subCtrl.text.trim(),
                      "address": addrCtrl.text.trim(),
                      "phone": phoneCtrl.text.trim(),
                      "email": emailCtrl.text.trim(),
                      "gstin": gstinCtrl.text.trim(),
                      "regType": regTypeCtrl.text.trim(),
                      "imageBase64": logoBase64,
                      "logoUrl": CompanyConfig.logoUrl,
                    }),
                  );
                  if (resp.statusCode == 200 || resp.statusCode == 302) {
                    final resData = jsonDecode(resp.body);
                    if (resData['logoUrl'] != null && resData['logoUrl'].toString().isNotEmpty) {
                      CompanyConfig.logoUrl = resData['logoUrl'];
                    }
                  }
                } catch (_) {}

                CompanyConfig.name = nameCtrl.text.trim();
                CompanyConfig.tradeSubtitle = subCtrl.text.trim();
                CompanyConfig.address = addrCtrl.text.trim();
                CompanyConfig.phone = phoneCtrl.text.trim();
                CompanyConfig.email = emailCtrl.text.trim();
                CompanyConfig.gstin = gstinCtrl.text.trim();
                CompanyConfig.regType = regTypeCtrl.text.trim();

                setState(() => _isBackgroundSyncing = false);
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSearchBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withOpacity(0.4),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: scheme.outlineVariant.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, size: 20, color: Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search menu (Billing, Price List, Customers, Reports)...',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  onSubmitted: (value) {
                    final q = value.toLowerCase();
                    if (q.contains('bill') || q.contains('sale')) {
                      setState(() => _navIndex = 0);
                    } else if (q.contains('pur')) {
                      setState(() => _navIndex = 1);
                    } else if (q.contains('rec')) {
                      setState(() => _navIndex = 2);
                    } else if (q.contains('pay')) {
                      setState(() => _navIndex = 3);
                    } else if (q.contains('item') || q.contains('price')) {
                      setState(() => _navIndex = 4);
                    } else if (q.contains('cust') || q.contains('part')) {
                      setState(() => _navIndex = 5);
                    } else if (q.contains('pack') || q.contains('load')) {
                      setState(() => _navIndex = 6);
                    } else if (q.contains('invo') || q.contains('hist')) {
                      setState(() => _navIndex = 7);
                    } else if (q.contains('voucher') || q.contains('history') || q.contains('view')) {
                      setState(() => _navIndex = 10);
                    } else if (q.contains('rep')) {
                      setState(() => _navIndex = 8);
                    } else if (q.contains('set') || q.contains('prof')) {
                      setState(() => _navIndex = 9);
                    }
                  },
                ),
              ),
              IconButton(
                icon: Icon(
                  appThemeMode.value == ThemeMode.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  size: 20,
                ),
                tooltip: 'Toggle Theme',
                onPressed: () => appThemeMode.value =
                    appThemeMode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
              ),
              IconButton(
                icon: const Icon(Icons.sync_rounded, size: 20),
                tooltip: 'Sync Google Sheet',
                onPressed: () => _fetchData(silent: true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveBodyContent() {
    switch (_navIndex) {
      case 0:
        return TallyBillingScreen(
          items: _items,
          customers: _customers,
          nextBillNo: _estimates.length + 1,
          invoiceToEdit: _invoiceToEdit,
          onClearEditInvoice: () => setState(() => _invoiceToEdit = null),
          onSaved: () => _fetchData(silent: true),
          onSetSyncing: (val) => setState(() => _isBackgroundSyncing = val),
        );
      case 1:
        return PurchaseVoucherScreen(
          items: _items,
          suppliers: _suppliers,
          onSaved: () => _fetchData(silent: true),
          onSetSyncing: (val) => setState(() => _isBackgroundSyncing = val),
        );
      case 2:
        return ReceiptVoucherScreen(
          customers: _customers,
          onSaved: () => _fetchData(silent: true),
          onSetSyncing: (val) => setState(() => _isBackgroundSyncing = val),
        );
      case 3:
        return PaymentVoucherScreen(
          suppliers: _suppliers,
          onSaved: () => _fetchData(silent: true),
          onSetSyncing: (val) => setState(() => _isBackgroundSyncing = val),
        );
      case 4:
        return PriceListDesktopView(
          items: _items,
          onRefreshRequired: () => _fetchData(silent: true),
        );
      case 5:
        return CustomerDesktopView(
          customers: _customers,
          onRefreshRequired: () => _fetchData(silent: true),
        );
      case 6:
        return LoadingSlipView(
          loadingSlip: _loadingSlip,
          items: _items,
          customers: _customers,
        );
      case 7:
        return InvoiceHistoryView(
          estimates: _estimates,
          items: _items,
          customers: _customers,
          onEditInvoice: _onLoadInvoiceToEdit,
          onRefreshRequired: () => _fetchData(silent: true),
        );
      case 8:
        return EnterpriseReportsView(
          estimates: _estimates,
          items: _items,
          customers: _customers,
          onEditInvoice: _onLoadInvoiceToEdit,
          onRefreshRequired: () => _fetchData(silent: true),
        );
      case 9:
        return SettingsDesktopView(
          onReloadSheet: () => _fetchData(silent: true),
          onOpenProfile: _openCompanyProfileDialog,
        );
      case 10:
        return AllVoucherHistoryView(
          vouchers: _allVouchers,
          onRefresh: () => _fetchData(silent: true),
        );
      default:
        return TallyBillingScreen(
          items: _items,
          customers: _customers,
          nextBillNo: _estimates.length + 1,
          invoiceToEdit: _invoiceToEdit,
          onClearEditInvoice: () => setState(() => _invoiceToEdit = null),
          onSaved: () => _fetchData(silent: true),
          onSetSyncing: (val) => setState(() => _isBackgroundSyncing = val),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: const Color(0xFF1A73E8),
                child: const Text('AC', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
              const SizedBox(height: 20),
              const Text('MULTIBILL ERP', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const SizedBox(height: 4),
              const Text('ANDROCODE SOFTWARE SOLUTIONS', style: TextStyle(fontSize: 11, color: Colors.grey, letterSpacing: 1.5)),
              const SizedBox(height: 24),
              const SizedBox(width: 140, child: LinearProgressIndicator(minHeight: 3)),
            ],
          ),
        ),
      );
    }

    // Global Key Bindings for F-keys & Esc
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f8): () => setState(() => _navIndex = 0),
        const SingleActivator(LogicalKeyboardKey.f9): () => setState(() => _navIndex = 1),
        const SingleActivator(LogicalKeyboardKey.f6): () => setState(() => _navIndex = 2),
        const SingleActivator(LogicalKeyboardKey.f5): () => setState(() => _navIndex = 3),
      },
      child: FocusScope(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
              return KeyEventResult.handled;
            } else if (_navIndex != 0) {
              setState(() => _navIndex = 0);
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                NavigationRail(
                  selectedIndex: _navIndex,
                  onDestinationSelected: (int index) => setState(() => _navIndex = index),
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: scheme.surface,
                  indicatorColor: scheme.primaryContainer,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setState(() => _navIndex = 0),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A73E8),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'AC',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.receipt_long_outlined),
                      selectedIcon: Icon(Icons.receipt_long_rounded),
                      label: Text('Sales (F8)'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.shopping_cart_outlined),
                      selectedIcon: Icon(Icons.shopping_cart_rounded),
                      label: Text('Purchase (F9)'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.download_rounded),
                      selectedIcon: Icon(Icons.download_done_rounded),
                      label: Text('Receipt (F6)'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.upload_rounded),
                      selectedIcon: Icon(Icons.payments_rounded),
                      label: Text('Payment (F5)'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      selectedIcon: Icon(Icons.inventory_2_rounded),
                      label: Text('Price List'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.people_alt_outlined),
                      selectedIcon: Icon(Icons.people_alt_rounded),
                      label: Text('Customers'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.local_shipping_outlined),
                      selectedIcon: Icon(Icons.local_shipping_rounded),
                      label: Text('Packing Slip'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.history_rounded),
                      selectedIcon: Icon(Icons.description_rounded),
                      label: Text('Invoices'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.bar_chart_outlined),
                      selectedIcon: Icon(Icons.bar_chart_rounded),
                      label: Text('Reports'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings_rounded),
                      label: Text('Settings'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.receipt_long_outlined),
                      selectedIcon: Icon(Icons.history_rounded),
                      label: Text('Vouchers'),
                    ),
                  ],
                  trailing: Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: IconButton(
                          tooltip: 'Sync Google Sheet',
                          icon: const Icon(Icons.sync_rounded),
                          onPressed: () => _fetchData(silent: true),
                        ),
                      ),
                    ),
                  ),
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: Column(
                    children: [
                      if (_isBackgroundSyncing) const LinearProgressIndicator(minHeight: 2.5),
                      _buildTopSearchBar(context),
                      Expanded(child: _buildActiveBodyContent()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- 1. BILLING SCREEN (SALES F8) ----------------

class TallyBillingScreen extends StatefulWidget {
  final List<DCItem> items;
  final List<DCCustomer> customers;
  final int nextBillNo;
  final DCEstimate? invoiceToEdit;
  final VoidCallback onClearEditInvoice;
  final VoidCallback onSaved;
  final Function(bool) onSetSyncing;

  const TallyBillingScreen({
    super.key,
    required this.items,
    required this.customers,
    required this.nextBillNo,
    this.invoiceToEdit,
    required this.onClearEditInvoice,
    required this.onSaved,
    required this.onSetSyncing,
  });

  @override
  State<TallyBillingScreen> createState() => _TallyBillingScreenState();
}

class _TallyBillingScreenState extends State<TallyBillingScreen> {
  final _coolieCtrl = TextEditingController(text: '0.00');
  final _partyTextCtrl = TextEditingController();
  String _invoiceType = 'Regular B2C';
  DCCustomer? _selectedParty;

  final FocusNode _partyFocus = FocusNode();
  final FocusNode _coolieFocus = FocusNode();
  final LayerLink _partyLayerLink = LayerLink();

  final List<InvoiceRowItem> _rows = [];

  OverlayEntry? _partyOverlay;
  int _partySelectedIndex = 0;
  List<DCCustomer> _filteredParties = [];
  final ScrollController _partyScrollCtrl = ScrollController();

  OverlayEntry? _itemOverlay;
  int _itemSelectedIndex = 0;
  List<DCItem> _filteredItems = [];
  final ScrollController _itemScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _filteredParties = widget.customers;
    _initBillingData();
  }

  @override
  void didUpdateWidget(covariant TallyBillingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.invoiceToEdit != null && widget.invoiceToEdit != oldWidget.invoiceToEdit) {
      _loadInvoiceForEditing(widget.invoiceToEdit!);
    }
  }

  void _initBillingData() {
    if (widget.invoiceToEdit != null) {
      _loadInvoiceForEditing(widget.invoiceToEdit!);
    } else {
      _addRow();
    }
  }

  void _loadInvoiceForEditing(DCEstimate est) {
    _rows.clear();
    _selectedParty = widget.customers.firstWhere(
      (c) => c.name.toLowerCase() == est.customer.toLowerCase(),
      orElse: () => DCCustomer(rowIndex: 0, slNo: 0, name: est.customer, contact: '', address: '', b2c: '', b2b: '', remarks: ''),
    );
    _partyTextCtrl.text = est.customer;
    _coolieCtrl.text = est.coolie;

    final parts = est.itemSummary.split(',');
    for (var part in parts) {
      if (part.trim().isNotEmpty) {
        final raw = part.trim();
        String itemName = raw;
        double qty = 1.0;
        String unit = 'KG';
        double rate = 0.0;
        int bags = 1;

        try {
          if (raw.contains('(') && raw.contains(')')) {
            itemName = raw.substring(0, raw.indexOf('(')).trim();
            final inside = raw.substring(raw.indexOf('(') + 1, raw.indexOf(')'));
            final xParts = inside.split('x');
            if (xParts.length == 2) {
              final qParts = xParts[0].trim().split(' ');
              qty = double.tryParse(qParts[0]) ?? 1.0;
              if (qParts.length > 1) unit = qParts[1];
              rate = double.tryParse(xParts[1].trim()) ?? 0.0;
            }
          }
          if (raw.contains('[') && raw.contains(']')) {
            final bStr = raw.substring(raw.indexOf('[') + 1, raw.indexOf(']')).replaceAll('B', '').trim();
            bags = int.tryParse(bStr) ?? 1;
          }
        } catch (_) {}

        final matchedItem = widget.items.firstWhere(
          (i) => i.name.toLowerCase() == itemName.toLowerCase(),
          orElse: () => DCItem(rowIndex: 0, no: 0, name: itemName, rateType: 'KG', rate: rate.toString(), qty: '1', tallyName: '', billedIn: '', isTaxable: false),
        );

        final row = InvoiceRowItem(item: matchedItem, rate: rate, qty: qty, unit: unit, bags: bags);
        _rows.add(row);
      }
    }

    if (_rows.isEmpty) _addRow();
    setState(() {});
  }

  void _addRow() {
    setState(() {
      final row = InvoiceRowItem(item: null, rate: 0.0, qty: 0.0, unit: '', bags: 0);
      _rows.add(row);
      final newIdx = _rows.length - 1;
      row.itemSearchFocus.addListener(() {
        if (row.itemSearchFocus.hasFocus) {
          _filterItemsForQuery(row.textCtrl.text);
          _showItemOverlay(newIdx);
        } else {
          _hideItemOverlay();
        }
      });
    });
  }

  void _removeRow(int idx) {
    _hideItemOverlay();
    if (_rows.length > 1) {
      setState(() => _rows.removeAt(idx));
    }
  }

  void _clearBilling() {
    _hidePartyOverlay();
    _hideItemOverlay();
    widget.onClearEditInvoice();
    setState(() {
      _selectedParty = null;
      _partyTextCtrl.clear();
      _coolieCtrl.text = '0.00';
      _rows.clear();
      _addRow();
    });
    _partyFocus.requestFocus();
  }

  double get _grossItemsTotal => _rows.where((r) => r.item != null).fold(0.0, (sum, r) => sum + r.amount);

  double get _taxableItemsGross {
    double sum = 0.0;
    for (var r in _rows) {
      if (r.item != null && r.item!.isTaxable) {
        sum += r.amount;
      }
    }
    return sum;
  }

  double get _taxableBaseAmount => _taxableItemsGross > 0 ? (_taxableItemsGross / (1 + (CompanyConfig.defaultGstRate / 100.0))) : 0.0;
  double get _totalGst => _taxableItemsGross - _taxableBaseAmount;
  double get _sgst => _totalGst / 2.0;
  double get _cgst => _totalGst / 2.0;
  double get _coolie => double.tryParse(_coolieCtrl.text.trim()) ?? 0.0;

  double get _exactTotal => _grossItemsTotal + _coolie;
  double get _grandTotal => _exactTotal.roundToDouble();
  double get _roundOff => _grandTotal - _exactTotal;
  int get _totalBags => _rows.where((r) => r.item != null).fold(0, (sum, r) => sum + r.bags);

  void _showPartyOverlay() {
    _hidePartyOverlay();
    if (_filteredParties.isEmpty) return;

    final overlay = Overlay.of(context);
    _partyOverlay = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _hidePartyOverlay,
            ),
          ),
          Positioned(
            width: 460,
            child: CompositedTransformFollower(
              link: _partyLayerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 52),
              child: Material(
                elevation: 14,
                color: const Color(0xFF171A1F),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 220),
                  decoration: BoxDecoration(
                    color: const Color(0xFF171A1F),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1A73E8), width: 1.2),
                  ),
                  child: ListView.builder(
                    controller: _partyScrollCtrl,
                    padding: EdgeInsets.zero,
                    itemCount: _filteredParties.length,
                    itemBuilder: (context, index) {
                      final p = _filteredParties[index];
                      final isSelected = index == _partySelectedIndex;
                      return InkWell(
                        onTap: () => _selectParty(p),
                        child: Container(
                          color: isSelected ? const Color(0xFF1A73E8).withOpacity(0.25) : null,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              if (isSelected)
                                const Text('> ', style: TextStyle(color: Color(0xFF8AB4F8), fontWeight: FontWeight.bold)),
                              Expanded(
                                child: Text(
                                  "${p.name} ${p.b2b.isNotEmpty ? '(${p.b2b})' : ''}",
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? const Color(0xFF8AB4F8) : Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_partyOverlay!);
  }

  void _hidePartyOverlay() {
    _partyOverlay?.remove();
    _partyOverlay = null;
  }

  KeyEventResult _handlePartyKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (_partyOverlay != null && _filteredParties.isNotEmpty) {
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          setState(() {
            _partySelectedIndex = (_partySelectedIndex + 1).clamp(0, _filteredParties.length - 1);
          });
          _scrollListTo(_partyScrollCtrl, _partySelectedIndex, 40.0);
          _partyOverlay?.markNeedsBuild();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          setState(() {
            _partySelectedIndex = (_partySelectedIndex - 1).clamp(0, _filteredParties.length - 1);
          });
          _scrollListTo(_partyScrollCtrl, _partySelectedIndex, 40.0);
          _partyOverlay?.markNeedsBuild();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.enter) {
          _selectParty(_filteredParties[_partySelectedIndex]);
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  void _selectParty(DCCustomer cust) {
    _hidePartyOverlay();
    setState(() {
      _selectedParty = cust;
      _partyTextCtrl.text = cust.name;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_rows.isNotEmpty) {
        _rows[0].itemSearchFocus.requestFocus();
      }
    });
  }

  void _filterItemsForQuery(String val) {
    final query = val.toLowerCase().trim();
    final itemsList = widget.items.where((i) {
      return i.name.toLowerCase().contains(query) || i.tallyName.toLowerCase().contains(query);
    }).toList();

    if (query.isEmpty || 'end of list'.startsWith(query) || 'end'.startsWith(query)) {
      _filteredItems = [DCItem.endOfList, ...itemsList];
      _itemSelectedIndex = 0; // Lock on End of List by default
    } else {
      _filteredItems = itemsList;
      _itemSelectedIndex = 0; // Lock on first matched item
    }
  }

  void _showItemOverlay(int rowIdx) {
    _hideItemOverlay();
    if (_filteredItems.isEmpty) return;

    final renderBox = _rows[rowIdx].itemSearchFocus.context?.findRenderObject() as RenderBox?;
    double offsetY = 48.0;
    const double popupHeight = 220.0;

    if (renderBox != null) {
      final position = renderBox.localToGlobal(Offset.zero);
      final screenHeight = MediaQuery.of(context).size.height;
      final spaceBelow = screenHeight - position.dy - renderBox.size.height;
      if (spaceBelow < 240) {
        offsetY = -(popupHeight + 8);
      }
    }

    final overlay = Overlay.of(context);
    _itemOverlay = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _hideItemOverlay,
            ),
          ),
          Positioned(
            width: 380,
            child: CompositedTransformFollower(
              link: _rows[rowIdx].layerLink,
              showWhenUnlinked: false,
              offset: Offset(0, offsetY),
              child: Material(
                elevation: 16,
                color: const Color(0xFF171A1F),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: popupHeight,
                  decoration: BoxDecoration(
                    color: const Color(0xFF171A1F),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1A73E8), width: 1.2),
                  ),
                  child: ListView.builder(
                    controller: _itemScrollCtrl,
                    padding: EdgeInsets.zero,
                    itemCount: _filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];
                      final isSelected = index == _itemSelectedIndex;
                      final isEndOfList = item.rowIndex == -999;

                      return InkWell(
                        onTap: () => _selectItem(rowIdx, item),
                        child: Container(
                          color: isSelected
                              ? const Color(0xFF1A73E8).withOpacity(0.3)
                              : (isEndOfList ? const Color(0xFFD93025).withOpacity(0.12) : null),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  if (isSelected)
                                    const Text('> ', style: TextStyle(color: Color(0xFF8AB4F8), fontWeight: FontWeight.bold)),
                                  Text(
                                    item.name,
                                    style: TextStyle(
                                      fontWeight: isEndOfList || isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isEndOfList
                                          ? const Color(0xFFF28B82)
                                          : (isSelected ? const Color(0xFF8AB4F8) : Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                              if (!isEndOfList)
                                Text('₹${item.rate}', style: const TextStyle(color: Color(0xFF8AB4F8), fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_itemOverlay!);
  }

  void _scrollListTo(ScrollController ctrl, int index, double itemHeight) {
    if (!ctrl.hasClients) return;
    final targetOffset = index * itemHeight;
    final maxScroll = ctrl.position.maxScrollExtent;
    final minScroll = ctrl.position.minScrollExtent;
    final clamped = targetOffset.clamp(minScroll, maxScroll);
    ctrl.animateTo(clamped, duration: const Duration(milliseconds: 100), curve: Curves.easeOut);
  }

  void _hideItemOverlay() {
    _itemOverlay?.remove();
    _itemOverlay = null;
  }

  KeyEventResult _handleItemKeyEvent(int rowIdx, FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (_itemOverlay != null && _filteredItems.isNotEmpty) {
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          setState(() {
            _itemSelectedIndex = (_itemSelectedIndex + 1).clamp(0, _filteredItems.length - 1);
          });
          _scrollListTo(_itemScrollCtrl, _itemSelectedIndex, 38.0);
          _itemOverlay?.markNeedsBuild();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          setState(() {
            _itemSelectedIndex = (_itemSelectedIndex - 1).clamp(0, _filteredItems.length - 1);
          });
          _scrollListTo(_itemScrollCtrl, _itemSelectedIndex, 38.0);
          _itemOverlay?.markNeedsBuild();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.enter) {
          _selectItem(rowIdx, _filteredItems[_itemSelectedIndex]);
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  void _selectItem(int rowIdx, DCItem itm) {
    _hideItemOverlay();

    if (itm.rowIndex == -999) {
      if (_rows.length > 1 && _rows[rowIdx].item == null) {
        setState(() {
          _rows.removeAt(rowIdx);
        });
      } else {
        setState(() {
          _rows[rowIdx].textCtrl.clear();
          _rows[rowIdx].rateCtrl.clear();
          _rows[rowIdx].qtyCtrl.clear();
          _rows[rowIdx].bagsCtrl.clear();
          _rows[rowIdx].item = null;
          _rows[rowIdx].unit = '';
        });
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusScope.of(context).requestFocus(_coolieFocus);
        _coolieCtrl.selection = TextSelection(baseOffset: 0, extentOffset: _coolieCtrl.text.length);
      });
      return;
    }

    setState(() {
      _rows[rowIdx].item = itm;
      _rows[rowIdx].textCtrl.text = itm.name;
      final parsedRate = double.tryParse(itm.rate) ?? 0.0;
      _rows[rowIdx].rate = parsedRate;
      _rows[rowIdx].rateCtrl.text = itm.rate;

      _rows[rowIdx].qty = 1.0;
      _rows[rowIdx].qtyCtrl.text = '1';

      _rows[rowIdx].bags = 1;
      _rows[rowIdx].bagsCtrl.text = '1';

      if (itm.billedIn.toUpperCase().contains('KILO')) {
        _rows[rowIdx].unit = 'KG';
      } else {
        _rows[rowIdx].unit = 'NOS';
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rows[rowIdx].rateFocus.requestFocus();
    });
  }

  KeyEventResult _handleUnitKeyEvent(int rowIdx, FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown || event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          _rows[rowIdx].unit = _rows[rowIdx].unit == 'KG' ? 'NOS' : 'KG';
        });
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        _rows[rowIdx].bagsFocus.requestFocus();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  Future<void> _saveInvoice() async {
    _hidePartyOverlay();
    _hideItemOverlay();

    if (_selectedParty == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Party / Customer')),
      );
      return;
    }

    final validRows = _rows.where((r) => r.item != null).toList();
    if (validRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item')),
      );
      return;
    }

    final isUpdating = widget.invoiceToEdit != null;
    final exactFormattedTime = getCurrentFormattedDateTime();
    final summary = validRows.map((r) => "${r.item!.name} (${r.qty} ${r.unit} x ${r.rate}) [${r.bags}B]").join(", ");

    widget.onSetSyncing(true);

    final billNoToUse = isUpdating ? widget.invoiceToEdit!.slNo : widget.nextBillNo;

    await http.post(
      Uri.parse(sheetApiUrl),
      body: jsonEncode({
        "action": isUpdating ? "UPDATE_ESTIMATE" : "ADD_ESTIMATE",
        if (isUpdating) "rowIndex": widget.invoiceToEdit!.rowIndex,
        "slNo": billNoToUse,
        "date": isUpdating ? widget.invoiceToEdit!.date : exactFormattedTime,
        "customer": _selectedParty!.name,
        "itemSummary": summary,
        "coolie": _coolie.toStringAsFixed(2),
        "sgst": _sgst.toStringAsFixed(2),
        "cgst": _cgst.toStringAsFixed(2),
        "roundOff": _roundOff.toStringAsFixed(2),
        "grandTotal": _grandTotal.toStringAsFixed(2),
      }),
    );

    widget.onSaved();
    _showTallyPrintPreview(
      billNo: billNoToUse.toString(),
      dateStr: isUpdating ? formatDisplayDateTime(widget.invoiceToEdit!.date) : exactFormattedTime,
      customer: _selectedParty!,
      items: validRows,
      subTotal: _taxableBaseAmount > 0 ? _taxableBaseAmount : _grossItemsTotal,
      coolie: _coolie,
      sgst: _sgst,
      cgst: _cgst,
      roundOff: _roundOff,
      grandTotal: _grandTotal,
    );
    _clearBilling();
  }

  void _showTallyPrintPreview({
    required String billNo,
    required String dateStr,
    required DCCustomer customer,
    required List<InvoiceRowItem> items,
    required double subTotal,
    required double coolie,
    required double sgst,
    required double cgst,
    required double roundOff,
    required double grandTotal,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.all(20),
        child: SizedBox(
          width: 920,
          height: 720,
          child: Column(
            children: [
              AppBar(
                title: Text('Invoice #$billNo (Tally Prime Format)'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              Expanded(
                child: PdfPreview(
                  build: (format) => generateTallyPdf(
                    format: format,
                    billNo: billNo,
                    dateStr: dateStr,
                    customer: customer,
                    items: items,
                    subTotal: subTotal,
                    coolie: coolie,
                    sgst: sgst,
                    cgst: cgst,
                    roundOff: roundOff,
                    grandTotal: grandTotal,
                  ),
                  allowPrinting: true,
                  allowSharing: true,
                  canChangePageFormat: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.invoiceToEdit != null;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): _saveInvoice,
      },
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(isEditing ? 'Edit Customer Bill' : 'Customer Bill (Sales - F8)',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                Chip(
                  label: Text(isEditing ? 'Bill #${widget.invoiceToEdit!.slNo}' : 'Bill #${widget.nextBillNo}'),
                  visualDensity: VisualDensity.compact,
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: Text(isEditing ? 'Cancel Edit' : 'Cancel'),
                  onPressed: _clearBilling,
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: Text(isEditing ? 'Update & Print' : 'Save & Print (Ctrl + S)'),
                  onPressed: _saveInvoice,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: CompositedTransformTarget(
                        link: _partyLayerLink,
                        child: Focus(
                          onKeyEvent: _handlePartyKeyEvent,
                          child: TextField(
                            controller: _partyTextCtrl,
                            focusNode: _partyFocus,
                            decoration: const InputDecoration(
                              labelText: 'Party / Customer Name',
                              hintText: 'Search customer...',
                              prefixIcon: Icon(Icons.person_search_rounded),
                            ),
                            onChanged: (val) {
                              setState(() {
                                _partySelectedIndex = 0;
                                _filteredParties = widget.customers.where((c) {
                                  return c.name.toLowerCase().contains(val.toLowerCase()) ||
                                      c.b2b.toLowerCase().contains(val.toLowerCase());
                                }).toList();
                              });
                              _showPartyOverlay();
                            },
                            onSubmitted: (val) {
                              if (_filteredParties.isNotEmpty) {
                                _selectParty(_filteredParties[_partySelectedIndex.clamp(0, _filteredParties.length - 1)]);
                              }
                            },
                            onTap: () {
                              setState(() {
                                _filteredParties = widget.customers;
                              });
                              _showPartyOverlay();
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 160,
                      child: DropdownButtonFormField<String>(
                        value: _invoiceType,
                        decoration: const InputDecoration(labelText: 'Supply Type'),
                        items: const [
                          DropdownMenuItem(value: 'Regular B2C', child: Text('Regular B2C')),
                          DropdownMenuItem(value: 'Regular B2B', child: Text('Regular B2B')),
                        ],
                        onChanged: (v) => setState(() => _invoiceType = v!),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Card(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: const Row(
                        children: [
                          SizedBox(width: 35, child: Text('No', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                          SizedBox(width: 10),
                          Expanded(flex: 5, child: Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                          SizedBox(width: 10),
                          SizedBox(width: 100, child: Text('Rate (₹)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                          SizedBox(width: 10),
                          SizedBox(width: 90, child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                          SizedBox(width: 10),
                          SizedBox(width: 80, child: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                          SizedBox(width: 10),
                          SizedBox(width: 75, child: Text('Bags', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                          SizedBox(width: 10),
                          SizedBox(width: 100, child: Text('Net (₹)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                          SizedBox(width: 36),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(10),
                        itemCount: _rows.length,
                        separatorBuilder: (ctx, i) => const Divider(height: 10),
                        itemBuilder: (ctx, idx) {
                          final row = _rows[idx];

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: SizedBox(width: 35, child: Text('${idx + 1}', style: const TextStyle(color: Colors.grey))),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 5,
                                child: CompositedTransformTarget(
                                  link: row.layerLink,
                                  child: Focus(
                                    onKeyEvent: (node, event) => _handleItemKeyEvent(idx, node, event),
                                    child: TextField(
                                      controller: row.textCtrl,
                                      focusNode: row.itemSearchFocus,
                                      decoration: const InputDecoration(
                                        hintText: 'Search item (or End of List)...',
                                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      ),
                                      onChanged: (val) {
                                        setState(() {
                                          _filterItemsForQuery(val);
                                        });
                                        _showItemOverlay(idx);
                                      },
                                      onSubmitted: (val) {
                                        if (_filteredItems.isNotEmpty) {
                                          _selectItem(idx, _filteredItems[_itemSelectedIndex.clamp(0, _filteredItems.length - 1)]);
                                        }
                                      },
                                      onTap: () {
                                        setState(() {
                                          _filterItemsForQuery(row.textCtrl.text);
                                        });
                                        _showItemOverlay(idx);
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 100,
                                child: TextField(
                                  controller: row.rateCtrl,
                                  focusNode: row.rateFocus,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                  onChanged: (val) {
                                    setState(() {
                                      row.rate = double.tryParse(val) ?? 0.0;
                                    });
                                  },
                                  onSubmitted: (_) => row.qtyFocus.requestFocus(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 90,
                                child: TextField(
                                  controller: row.qtyCtrl,
                                  focusNode: row.qtyFocus,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                  onChanged: (val) {
                                    setState(() {
                                      row.qty = double.tryParse(val) ?? 0.0;
                                    });
                                  },
                                  onSubmitted: (_) => row.unitFocus.requestFocus(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 80,
                                child: Focus(
                                  focusNode: row.unitFocus,
                                  onKeyEvent: (node, event) => _handleUnitKeyEvent(idx, node, event),
                                  child: Builder(
                                    builder: (fCtx) {
                                      final hasFocus = Focus.of(fCtx).hasFocus;
                                      return InkWell(
                                        onTap: () {
                                          setState(() {
                                            row.unit = row.unit == 'KG' ? 'NOS' : 'KG';
                                          });
                                          row.unitFocus.requestFocus();
                                        },
                                        child: Container(
                                          height: 44,
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: hasFocus ? const Color(0xFF1A73E8) : Colors.transparent,
                                              width: 1.2,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(row.unit.isNotEmpty ? row.unit : '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                              const Icon(Icons.swap_vert, size: 16, color: Colors.grey),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 75,
                                child: TextField(
                                  controller: row.bagsCtrl,
                                  focusNode: row.bagsFocus,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                  onChanged: (val) {
                                    setState(() {
                                      row.bags = int.tryParse(val) ?? 0;
                                    });
                                  },
                                  onSubmitted: (_) {
                                    if (idx == _rows.length - 1) {
                                      _addRow();
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        _rows[idx + 1].itemSearchFocus.requestFocus();
                                      });
                                    } else {
                                      _rows[idx + 1].itemSearchFocus.requestFocus();
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: SizedBox(
                                  width: 100,
                                  child: Text('₹${row.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                ),
                              ),
                              SizedBox(
                                width: 36,
                                child: IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                                  onPressed: () => _removeRow(idx),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          FilledButton.tonalIcon(
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Add Row'),
                            onPressed: _addRow,
                          ),
                          const Spacer(),
                          Text('Bags in Bill: $_totalBags', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          SizedBox(
                            width: 130,
                            child: Focus(
                              onKeyEvent: (node, event) {
                                if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
                                  _saveInvoice();
                                  return KeyEventResult.handled;
                                }
                                return KeyEventResult.ignored;
                              },
                              child: TextField(
                                controller: _coolieCtrl,
                                focusNode: _coolieFocus,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Coolie (Enter to Save)'),
                                onChanged: (_) => setState(() {}),
                                onSubmitted: (_) => _saveInvoice(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Tax (5%): ₹${_totalGst.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF29900), fontSize: 13)),
                              Text('Taxable: ₹${_taxableBaseAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Subtotal: ₹${_grossItemsTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 2),
                        Text('Grand Total: ₹${_grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A73E8))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- 2. PURCHASE VOUCHER (F9) ----------------

class PurchaseVoucherScreen extends StatefulWidget {
  final List<DCItem> items;
  final List<dynamic> suppliers;
  final VoidCallback onSaved;
  final Function(bool) onSetSyncing;

  const PurchaseVoucherScreen({
    super.key,
    required this.items,
    required this.suppliers,
    required this.onSaved,
    required this.onSetSyncing,
  });

  @override
  State<PurchaseVoucherScreen> createState() => _PurchaseVoucherScreenState();
}

class _PurchaseVoucherScreenState extends State<PurchaseVoucherScreen> {
  final _supplierCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  final _supplierFocus = FocusNode();
  final _amountFocus = FocusNode();
  final _remarksFocus = FocusNode();

  Future<void> _savePurchase() async {
    if (_supplierCtrl.text.trim().isEmpty || _amountCtrl.text.trim().isEmpty) return;
    widget.onSetSyncing(true);

    await http.post(
      Uri.parse(sheetApiUrl),
      body: jsonEncode({
        "action": "ADD_PURCHASE",
        "voucherNo": DateTime.now().millisecondsSinceEpoch.toString().substring(7),
        "date": getCurrentFormattedDateTime(),
        "supplier": _supplierCtrl.text.trim(),
        "itemSummary": _remarksCtrl.text.trim(),
        "coolie": "0.00",
        "sgst": "0.00",
        "cgst": "0.00",
        "roundOff": "0.00",
        "grandTotal": _amountCtrl.text.trim(),
      }),
    );

    widget.onSaved();
    _supplierCtrl.clear();
    _amountCtrl.clear();
    _remarksCtrl.clear();
    _supplierFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Purchase Voucher (F9 - Stock In)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: _supplierCtrl,
                focusNode: _supplierFocus,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Supplier / Mill Name (Enter to jump)'),
                onSubmitted: (_) => _amountFocus.requestFocus(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountCtrl,
                focusNode: _amountFocus,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Total Purchase Amount (Enter to jump)'),
                onSubmitted: (_) => _remarksFocus.requestFocus(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _remarksCtrl,
                focusNode: _remarksFocus,
                decoration: const InputDecoration(labelText: 'Item Summary / Lorry Load Details (Enter to Save)'),
                onSubmitted: (_) => _savePurchase(),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Save Purchase Entry'),
                onPressed: _savePurchase,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- 3. RECEIPT VOUCHER (F6) ----------------

class ReceiptVoucherScreen extends StatefulWidget {
  final List<DCCustomer> customers;
  final VoidCallback onSaved;
  final Function(bool) onSetSyncing;

  const ReceiptVoucherScreen({
    super.key,
    required this.customers,
    required this.onSaved,
    required this.onSetSyncing,
  });

  @override
  State<ReceiptVoucherScreen> createState() => _ReceiptVoucherScreenState();
}

class _ReceiptVoucherScreenState extends State<ReceiptVoucherScreen> {
  final _customerCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _narrationCtrl = TextEditingController();
  String _mode = 'Cash';

  final _custFocus = FocusNode();
  final _amountFocus = FocusNode();
  final _refFocus = FocusNode();
  final _narrationFocus = FocusNode();

  Future<void> _saveReceipt() async {
    if (_customerCtrl.text.trim().isEmpty || _amountCtrl.text.trim().isEmpty) return;
    widget.onSetSyncing(true);

    await http.post(
      Uri.parse(sheetApiUrl),
      body: jsonEncode({
        "action": "ADD_RECEIPT",
        "receiptNo": DateTime.now().millisecondsSinceEpoch.toString().substring(7),
        "date": getCurrentFormattedDateTime(),
        "customer": _customerCtrl.text.trim(),
        "mode": _mode,
        "amount": _amountCtrl.text.trim(),
        "reference": _refCtrl.text.trim(),
        "narration": _narrationCtrl.text.trim(),
      }),
    );

    widget.onSaved();
    _customerCtrl.clear();
    _amountCtrl.clear();
    _refCtrl.clear();
    _narrationCtrl.clear();
    _custFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Receipt Voucher (F6 - Money In)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: _customerCtrl,
                focusNode: _custFocus,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Received From (Customer Name - Enter to jump)'),
                onSubmitted: (_) => _amountFocus.requestFocus(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _amountCtrl,
                      focusNode: _amountFocus,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Amount (₹) - Enter to jump'),
                      onSubmitted: (_) => _refFocus.requestFocus(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 140,
                    child: DropdownButtonFormField<String>(
                      value: _mode,
                      decoration: const InputDecoration(labelText: 'Mode'),
                      items: const [
                        DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                        DropdownMenuItem(value: 'Bank/UPI', child: Text('Bank / UPI')),
                      ],
                      onChanged: (v) => setState(() => _mode = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _refCtrl,
                focusNode: _refFocus,
                decoration: const InputDecoration(labelText: 'UPI Ref / Cheque No (Enter to jump)'),
                onSubmitted: (_) => _narrationFocus.requestFocus(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _narrationCtrl,
                focusNode: _narrationFocus,
                decoration: const InputDecoration(labelText: 'Narration / Notes (Enter to Save)'),
                onSubmitted: (_) => _saveReceipt(),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Save Receipt'),
                onPressed: _saveReceipt,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- 4. PAYMENT VOUCHER (F5) ----------------

class PaymentVoucherScreen extends StatefulWidget {
  final List<dynamic> suppliers;
  final VoidCallback onSaved;
  final Function(bool) onSetSyncing;

  const PaymentVoucherScreen({
    super.key,
    required this.suppliers,
    required this.onSaved,
    required this.onSetSyncing,
  });

  @override
  State<PaymentVoucherScreen> createState() => _PaymentVoucherScreenState();
}

class _PaymentVoucherScreenState extends State<PaymentVoucherScreen> {
  final _paidToCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _narrationCtrl = TextEditingController();
  String _mode = 'Cash';

  final _paidToFocus = FocusNode();
  final _amountFocus = FocusNode();
  final _narrationFocus = FocusNode();

  Future<void> _savePayment() async {
    if (_paidToCtrl.text.trim().isEmpty || _amountCtrl.text.trim().isEmpty) return;
    widget.onSetSyncing(true);

    await http.post(
      Uri.parse(sheetApiUrl),
      body: jsonEncode({
        "action": "ADD_PAYMENT",
        "paymentNo": DateTime.now().millisecondsSinceEpoch.toString().substring(7),
        "date": getCurrentFormattedDateTime(),
        "paidTo": _paidToCtrl.text.trim(),
        "mode": _mode,
        "amount": _amountCtrl.text.trim(),
        "narration": _narrationCtrl.text.trim(),
      }),
    );

    widget.onSaved();
    _paidToCtrl.clear();
    _amountCtrl.clear();
    _narrationCtrl.clear();
    _paidToFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Payment Voucher (F5 - Money Out)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: _paidToCtrl,
                focusNode: _paidToFocus,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Paid To (Supplier / Vadaka / Coolie / Rent - Enter to jump)'),
                onSubmitted: (_) => _amountFocus.requestFocus(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _amountCtrl,
                      focusNode: _amountFocus,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Amount (₹) - Enter to jump'),
                      onSubmitted: (_) => _narrationFocus.requestFocus(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 140,
                    child: DropdownButtonFormField<String>(
                      value: _mode,
                      decoration: const InputDecoration(labelText: 'Mode'),
                      items: const [
                        DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                        DropdownMenuItem(value: 'Bank/UPI', child: Text('Bank / UPI')),
                      ],
                      onChanged: (v) => setState(() => _mode = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _narrationCtrl,
                focusNode: _narrationFocus,
                decoration: const InputDecoration(labelText: 'Narration / Notes (Enter to Save)'),
                onSubmitted: (_) => _savePayment(),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Save Payment'),
                onPressed: _savePayment,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- 5. PRICE LIST VIEW ----------------

class PriceListDesktopView extends StatefulWidget {
  final List<DCItem> items;
  final VoidCallback onRefreshRequired;
  const PriceListDesktopView({
    super.key,
    required this.items,
    required this.onRefreshRequired,
  });

  @override
  State<PriceListDesktopView> createState() => _PriceListDesktopViewState();
}

class _PriceListDesktopViewState extends State<PriceListDesktopView> {
  String _query = '';
  int _selectedIndex = 0;
  final FocusNode _searchFocus = FocusNode();
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  void _showItemPreviewModal(DCItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19))),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              icon: const Icon(Icons.delete_forever, size: 18),
              label: const Text('Delete Item'),
              onPressed: () {
                Navigator.pop(ctx);
                _confirmDeleteItem(item);
              },
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(),
              _buildModalRow('Current Rate:', '₹${item.rate}', isColor: true),
              _buildModalRow('Rate Unit:', item.rateType),
              _buildModalRow('Quantity / Pack Size:', '${item.qty} KG/Bag'),
              _buildModalRow('Item Name on Tally:', item.tallyName),
              _buildModalRow('Billed Unit:', item.billedIn),
              _buildModalRow('Tax Status:', item.isTaxable ? 'TAXABLE (5% INCL)' : 'NON-TAXABLE'),
            ],
          ),
        ),
        actions: [
          FilledButton.icon(
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Edit Item Details'),
            onPressed: () {
              Navigator.pop(ctx);
              _openEditItemDialog(item: item);
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteItem(DCItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Delete Item'),
        content: Text('Are you sure you want to permanently remove "${item.name}" from Google Sheet?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await http.post(
                Uri.parse(sheetApiUrl),
                body: jsonEncode({
                  "action": "DELETE_ITEM",
                  "rowIndex": item.rowIndex,
                }),
              );
              widget.onRefreshRequired();
            },
            child: const Text('Delete from Sheet'),
          ),
        ],
      ),
    );
  }

  void _openEditItemDialog({DCItem? item}) {
    final isNew = item == null;
    final nameCtrl = TextEditingController(text: isNew ? '' : item.name);
    final rateCtrl = TextEditingController(text: isNew ? '' : item.rate);
    final rateTypeCtrl = TextEditingController(text: isNew ? 'RATE PER KG' : item.rateType);
    final qtyCtrl = TextEditingController(text: isNew ? '50' : '${item.qty}');
    final tallyCtrl = TextEditingController(text: isNew ? '' : item.tallyName);
    final billedCtrl = TextEditingController(text: isNew ? 'KILOGRAM' : item.billedIn);
    bool isTaxable = isNew ? false : item.isTaxable;

    final nameFocus = FocusNode();
    final rateFocus = FocusNode();
    final rateTypeFocus = FocusNode();
    final qtyFocus = FocusNode();
    final billedFocus = FocusNode();
    final tallyFocus = FocusNode();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isNew ? 'Add Item' : 'Edit Item'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    focusNode: nameFocus,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Item Name'),
                    onSubmitted: (_) => rateFocus.requestFocus(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: rateCtrl,
                          focusNode: rateFocus,
                          decoration: const InputDecoration(labelText: 'Rate (₹)'),
                          onSubmitted: (_) => rateTypeFocus.requestFocus(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: rateTypeCtrl,
                          focusNode: rateTypeFocus,
                          decoration: const InputDecoration(labelText: 'Rate Type'),
                          onSubmitted: (_) => qtyFocus.requestFocus(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: qtyCtrl,
                          focusNode: qtyFocus,
                          decoration: const InputDecoration(labelText: 'Qty'),
                          onSubmitted: (_) => billedFocus.requestFocus(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: billedCtrl,
                          focusNode: billedFocus,
                          decoration: const InputDecoration(labelText: 'Billed In'),
                          onSubmitted: (_) => tallyFocus.requestFocus(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: tallyCtrl,
                    focusNode: tallyFocus,
                    decoration: const InputDecoration(labelText: 'Tally Name'),
                    onSubmitted: (_) async {
                      if (nameCtrl.text.trim().isNotEmpty) {
                        Navigator.pop(ctx);
                        await http.post(
                          Uri.parse(sheetApiUrl),
                          body: jsonEncode({
                            "action": isNew ? "ADD_ITEM" : "EDIT_ITEM",
                            if (!isNew) "rowIndex": item.rowIndex,
                            "name": nameCtrl.text.trim(),
                            "rateType": rateTypeCtrl.text.trim(),
                            "rate": rateCtrl.text.trim(),
                            "qty": qtyCtrl.text.trim(),
                            "tallyName": tallyCtrl.text.trim(),
                            "billedIn": billedCtrl.text.trim(),
                            "isTaxable": isTaxable,
                          }),
                        );
                        widget.onRefreshRequired();
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: const Text('Taxable (5% Inclusive)'),
                    value: isTaxable,
                    onChanged: (v) => setDialogState(() => isTaxable = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isNotEmpty) {
                  Navigator.pop(ctx);
                  await http.post(
                    Uri.parse(sheetApiUrl),
                    body: jsonEncode({
                      "action": isNew ? "ADD_ITEM" : "EDIT_ITEM",
                      if (!isNew) "rowIndex": item.rowIndex,
                      "name": nameCtrl.text.trim(),
                      "rateType": rateTypeCtrl.text.trim(),
                      "rate": rateCtrl.text.trim(),
                      "qty": qtyCtrl.text.trim(),
                      "tallyName": tallyCtrl.text.trim(),
                      "billedIn": billedCtrl.text.trim(),
                      "isTaxable": isTaxable,
                    }),
                  );
                  widget.onRefreshRequired();
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalRow(String title, String val, {bool isColor = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 160, child: Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13.5))),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              val,
              softWrap: true,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isColor ? const Color(0xFF1A73E8) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.items
        .where((i) => i.name.toLowerCase().contains(_query.toLowerCase()) || i.tallyName.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          _searchFocus.requestFocus();
          _searchCtrl.selection = TextSelection(baseOffset: 0, extentOffset: _searchCtrl.text.length);
        },
      },
      child: FocusScope(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowDown && filtered.isNotEmpty) {
              setState(() {
                _selectedIndex = (_selectedIndex + 1).clamp(0, filtered.length - 1);
              });
              _scrollCtrl.animateTo(_selectedIndex * 68.0, duration: const Duration(milliseconds: 100), curve: Curves.easeOut);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowUp && filtered.isNotEmpty) {
              setState(() {
                _selectedIndex = (_selectedIndex - 1).clamp(0, filtered.length - 1);
              });
              _scrollCtrl.animateTo(_selectedIndex * 68.0, duration: const Duration(milliseconds: 100), curve: Curves.easeOut);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.enter && filtered.isNotEmpty && !_searchFocus.hasFocus) {
              _showItemPreviewModal(filtered[_selectedIndex]);
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      focusNode: _searchFocus,
                      onChanged: (v) => setState(() {
                        _query = v;
                        _selectedIndex = 0;
                      }),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'Search items (Ctrl + F)...',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Item'),
                    onPressed: () => _openEditItemDialog(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.separated(
                  controller: _scrollCtrl,
                  physics: const BouncingScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                  itemBuilder: (ctx, idx) {
                    final item = filtered[idx];
                    final isFocused = idx == _selectedIndex;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: isFocused ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.35) : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isFocused ? const Color(0xFF1A73E8) : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          setState(() => _selectedIndex = idx);
                          _showItemPreviewModal(item);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                child: Text(
                                  '${item.no}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            item.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1A73E8).withOpacity(0.18),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFF1A73E8), width: 1),
                                          ),
                                          child: Text(
                                            '₹${item.rate}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: Color(0xFF8AB4F8),
                                            ),
                                          ),
                                        ),
                                        if (item.isTaxable) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF38230B),
                                              borderRadius: BorderRadius.circular(5),
                                              border: Border.all(color: const Color(0xFFF59E0B), width: 0.8),
                                            ),
                                            child: const Text(
                                              'TAX 5%',
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFFFCD34D),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${item.qty} ${item.billedIn} • Rate Unit: ${item.rateType} • Tally: ${item.tallyName}',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                tooltip: 'Edit Item',
                                onPressed: () => _openEditItemDialog(item: item),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- 6. CUSTOMERS VIEW ----------------

class CustomerDesktopView extends StatefulWidget {
  final List<DCCustomer> customers;
  final VoidCallback onRefreshRequired;
  const CustomerDesktopView({
    super.key,
    required this.customers,
    required this.onRefreshRequired,
  });

  @override
  State<CustomerDesktopView> createState() => _CustomerDesktopViewState();
}

class _CustomerDesktopViewState extends State<CustomerDesktopView> {
  String _query = '';
  int _selectedIndex = 0;
  final FocusNode _searchFocus = FocusNode();
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  Widget _buildTagChip(String tag) {
    Color bg;
    Color border;
    Color text;

    if (tag == 'VAZHI BILL') {
      bg = const Color(0xFF38230B);
      border = const Color(0xFFF59E0B);
      text = const Color(0xFFFCD34D);
    } else if (tag == 'CREDIT') {
      bg = const Color(0xFF28183B);
      border = const Color(0xFF8B5CF6);
      text = const Color(0xFFC4B5FD);
    } else if (tag == 'NO COOLI') {
      bg = const Color(0xFF1E1B4B);
      border = const Color(0xFF6366F1);
      text = const Color(0xFFA5B4FC);
    } else {
      bg = const Color(0xFF0F291E);
      border = const Color(0xFF10B981);
      text = const Color(0xFF6EE7B7);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 1.0),
      ),
      child: Text(
        tag,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: text),
      ),
    );
  }

  void _showCustomerPreviewModal(DCCustomer customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19))),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              icon: const Icon(Icons.person_remove, size: 18),
              label: const Text('Delete Party'),
              onPressed: () {
                Navigator.pop(ctx);
                _confirmDeleteCustomer(customer);
              },
            ),
          ],
        ),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(),
              _buildCustomerModalRow('Customer Name:', customer.name),
              _buildCustomerModalRow('Contact Number:', customer.contact.isEmpty ? '-' : customer.contact),
              _buildCustomerModalRow('Address:', customer.address.isEmpty ? '-' : customer.address),
              _buildCustomerModalRow('B2B Firm Name:', customer.b2b.isEmpty ? '-' : customer.b2b, isB2B: true),
              _buildCustomerModalRow('B2C Reference:', customer.b2c.isEmpty ? '-' : customer.b2c),
              _buildCustomerModalRow('Billing Category:', customer.billingTag),
              if (customer.remarks.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Delivery & Special Billing Rules:', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF231908),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
                  ),
                  child: Text(customer.remarks, style: const TextStyle(color: Color(0xFFFDE68A), fontWeight: FontWeight.bold, fontSize: 13, height: 1.4)),
                ),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton.icon(
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Edit Customer Details'),
            onPressed: () {
              Navigator.pop(ctx);
              _openEditCustomerDialog(customer: customer);
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCustomer(DCCustomer customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Delete Customer'),
        content: Text('Are you sure you want to permanently delete party "${customer.name}" from Google Sheet?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await http.post(
                Uri.parse(sheetApiUrl),
                body: jsonEncode({
                  "action": "DELETE_CUSTOMER",
                  "rowIndex": customer.rowIndex,
                }),
              );
              widget.onRefreshRequired();
            },
            child: const Text('Delete from Sheet'),
          ),
        ],
      ),
    );
  }

  void _openEditCustomerDialog({DCCustomer? customer}) {
    final isNew = customer == null;
    final nameCtrl = TextEditingController(text: isNew ? '' : customer.name);
    final contactCtrl = TextEditingController(text: isNew ? '' : customer.contact);
    final addressCtrl = TextEditingController(text: isNew ? '' : customer.address);
    final b2bCtrl = TextEditingController(text: isNew ? '' : customer.b2b);
    final b2cCtrl = TextEditingController(text: isNew ? '' : customer.b2c);
    final remarksCtrl = TextEditingController(text: isNew ? '' : customer.remarks);

    final nameFocus = FocusNode();
    final contactFocus = FocusNode();
    final addressFocus = FocusNode();
    final b2bFocus = FocusNode();
    final b2cFocus = FocusNode();
    final remarksFocus = FocusNode();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isNew ? 'Add Customer' : 'Edit Customer'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  focusNode: nameFocus,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Party Name'),
                  onSubmitted: (_) => contactFocus.requestFocus(),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: contactCtrl,
                        focusNode: contactFocus,
                        decoration: const InputDecoration(labelText: 'Contact'),
                        onSubmitted: (_) => addressFocus.requestFocus(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: addressCtrl,
                        focusNode: addressFocus,
                        decoration: const InputDecoration(labelText: 'Address'),
                        onSubmitted: (_) => b2bFocus.requestFocus(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: b2bCtrl,
                  focusNode: b2bFocus,
                  decoration: const InputDecoration(labelText: 'Trade Name (B2B)'),
                  onSubmitted: (_) => b2cFocus.requestFocus(),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: b2cCtrl,
                  focusNode: b2cFocus,
                  decoration: const InputDecoration(labelText: 'B2C Ref'),
                  onSubmitted: (_) => remarksFocus.requestFocus(),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: remarksCtrl,
                  focusNode: remarksFocus,
                  decoration: const InputDecoration(labelText: 'Delivery Rules / Remarks'),
                  onSubmitted: (_) async {
                    if (nameCtrl.text.trim().isNotEmpty) {
                      Navigator.pop(ctx);
                      await http.post(
                        Uri.parse(sheetApiUrl),
                        body: jsonEncode({
                          "action": isNew ? "ADD_CUSTOMER" : "EDIT_CUSTOMER",
                          if (!isNew) "rowIndex": customer.rowIndex,
                          "name": nameCtrl.text.trim(),
                          "contact": contactCtrl.text.trim(),
                          "address": addressCtrl.text.trim(),
                          "b2b": b2bCtrl.text.trim(),
                          "b2c": b2cCtrl.text.trim(),
                          "remarks": remarksCtrl.text.trim(),
                        }),
                      );
                      widget.onRefreshRequired();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isNotEmpty) {
                Navigator.pop(ctx);
                await http.post(
                  Uri.parse(sheetApiUrl),
                  body: jsonEncode({
                    "action": isNew ? "ADD_CUSTOMER" : "EDIT_CUSTOMER",
                    if (!isNew) "rowIndex": customer.rowIndex,
                    "name": nameCtrl.text.trim(),
                    "contact": contactCtrl.text.trim(),
                    "address": addressCtrl.text.trim(),
                    "b2b": b2bCtrl.text.trim(),
                    "b2c": b2cCtrl.text.trim(),
                    "remarks": remarksCtrl.text.trim(),
                  }),
                );
                widget.onRefreshRequired();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerModalRow(String title, String val, {bool isB2B = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 150, child: Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              val,
              softWrap: true,
              style: TextStyle(
                fontWeight: isB2B ? FontWeight.bold : FontWeight.normal,
                fontSize: 13.5,
                color: isB2B ? const Color(0xFF1A73E8) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.customers.where((c) {
      return c.name.toLowerCase().contains(_query.toLowerCase()) ||
          c.b2b.toLowerCase().contains(_query.toLowerCase()) ||
          c.contact.contains(_query);
    }).toList();

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          _searchFocus.requestFocus();
          _searchCtrl.selection = TextSelection(baseOffset: 0, extentOffset: _searchCtrl.text.length);
        },
      },
      child: FocusScope(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowDown && filtered.isNotEmpty) {
              setState(() {
                _selectedIndex = (_selectedIndex + 1).clamp(0, filtered.length - 1);
              });
              _scrollCtrl.animateTo(_selectedIndex * 68.0, duration: const Duration(milliseconds: 100), curve: Curves.easeOut);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowUp && filtered.isNotEmpty) {
              setState(() {
                _selectedIndex = (_selectedIndex - 1).clamp(0, filtered.length - 1);
              });
              _scrollCtrl.animateTo(_selectedIndex * 68.0, duration: const Duration(milliseconds: 100), curve: Curves.easeOut);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.enter && filtered.isNotEmpty && !_searchFocus.hasFocus) {
              _showCustomerPreviewModal(filtered[_selectedIndex]);
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      focusNode: _searchFocus,
                      onChanged: (v) => setState(() {
                        _query = v;
                        _selectedIndex = 0;
                      }),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'Search parties (Ctrl + F)...',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    icon: const Icon(Icons.person_add_rounded),
                    label: const Text('Add Party'),
                    onPressed: () => _openEditCustomerDialog(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.separated(
                  controller: _scrollCtrl,
                  physics: const BouncingScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final c = filtered[i];
                    final isFocused = i == _selectedIndex;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: isFocused ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.35) : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isFocused ? const Color(0xFF1A73E8) : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          setState(() => _selectedIndex = i);
                          _showCustomerPreviewModal(c);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                child: Text(
                                  '${c.slNo}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            c.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _buildTagChip(c.billingTag),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 2,
                                      children: [
                                        if (c.b2b.trim().isNotEmpty)
                                          Text(
                                            'B2B: ${c.b2b}',
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF90CAF9), fontWeight: FontWeight.w600),
                                          ),
                                        if (c.b2c.trim().isNotEmpty)
                                          Text(
                                            'B2C: ${c.b2c}',
                                            style: const TextStyle(fontSize: 12, color: Color(0xFFA7F3D0), fontWeight: FontWeight.w600),
                                          ),
                                        if (c.contact.trim().isNotEmpty)
                                          Text(
                                            '📞 ${c.contact}',
                                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                        if (c.address.trim().isNotEmpty)
                                          Text(
                                            '📍 ${c.address}',
                                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                      ],
                                    ),
                                    if (c.remarks.trim().isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(Icons.info_outline_rounded, size: 13, color: Colors.amber.shade400),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Click to preview for remarks',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: Colors.amber.shade300,
                                              fontStyle: FontStyle.italic,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                tooltip: 'Edit Party',
                                onPressed: () => _openEditCustomerDialog(customer: c),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- 7. PACKING SLIP VIEW ----------------

class LoadingSlipView extends StatefulWidget {
  final List<LoadingEntry> loadingSlip;
  final List<DCItem> items;
  final List<DCCustomer> customers;

  const LoadingSlipView({
    super.key,
    required this.loadingSlip,
    required this.items,
    required this.customers,
  });

  @override
  State<LoadingSlipView> createState() => _LoadingSlipViewState();
}

class _LoadingSlipViewState extends State<LoadingSlipView> {
  void _openAddPackingSlipDialog() {
    String? selectedCust = widget.customers.isNotEmpty ? widget.customers.first.name : null;
    final placeCtrl = TextEditingController();
    final summaryCtrl = TextEditingController();
    final bagsCtrl = TextEditingController(text: '10');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Entry to Slip'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedCust,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Party / Customer Name'),
                    items: widget.customers.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))).toList(),
                    onChanged: (v) => setDialogState(() => selectedCust = v),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: placeCtrl, decoration: const InputDecoration(labelText: 'Place')),
                  const SizedBox(height: 10),
                  TextField(controller: summaryCtrl, decoration: const InputDecoration(labelText: 'Item Summary')),
                  const SizedBox(height: 10),
                  TextField(controller: bagsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Bags')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (selectedCust != null && bagsCtrl.text.trim().isNotEmpty) {
                  final party = selectedCust!;
                  final place = placeCtrl.text.trim();
                  final summary = summaryCtrl.text.trim();
                  final bags = int.tryParse(bagsCtrl.text.trim()) ?? 0;

                  Navigator.pop(ctx);
                  setState(() {
                    widget.loadingSlip.add(LoadingEntry(
                      customerName: party,
                      place: place,
                      summary: summary.isEmpty ? 'Rice Bags' : summary,
                      bags: bags,
                    ));
                  });

                  await http.post(
                    Uri.parse(sheetApiUrl),
                    body: jsonEncode({
                      "action": "ADD_PACKING_SLIP",
                      "party": party,
                      "place": place,
                      "itemSummary": summary,
                      "totalBags": bags,
                    }),
                  );
                }
              },
              child: const Text('Save Entry'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalBags = widget.loadingSlip.fold(0, (sum, entry) => sum + entry.bags);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Text('Total Load: $totalBags Bags', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              FilledButton.icon(
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Entry'),
                onPressed: _openAddPackingSlipDialog,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: widget.loadingSlip.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 8),
              itemBuilder: (ctx, idx) {
                final entry = widget.loadingSlip[idx];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Text('${idx + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    title: Text(entry.customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${entry.place} • ${entry.summary}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${entry.bags} Bags', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFF29900))),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => setState(() => widget.loadingSlip.removeAt(idx)),
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
    );
  }
}

// ---------------- ALL VOUCHER HISTORY ----------------

class AllVoucherHistoryView extends StatefulWidget {
  final List<Map<String, dynamic>> vouchers;
  final VoidCallback onRefresh;
  const AllVoucherHistoryView({super.key, required this.vouchers, required this.onRefresh});

  @override
  State<AllVoucherHistoryView> createState() => _AllVoucherHistoryViewState();
}

class _AllVoucherHistoryViewState extends State<AllVoucherHistoryView> {
  String _filter = 'ALL';
  String _query = '';

  Color _typeColor(String type) {
    switch (type) {
      case 'SALES': return const Color(0xFF1A73E8);
      case 'PURCHASE': return const Color(0xFF0F9D58);
      case 'RECEIPT': return const Color(0xFF00A6A6);
      default: return const Color(0xFFE37400);
    }
  }

  void _showDetails(Map<String, dynamic> v) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('${v['type']} • ${v['number']}', style: const TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(width: 480, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        _detail('Date', formatDisplayDateTime('${v['date'] ?? ''}')),
        _detail(v['type'] == 'PAYMENT' ? 'Paid To' : (v['type'] == 'PURCHASE' ? 'Supplier' : 'Party'), '${v['party'] ?? '-'}'),
        _detail('Amount', '₹${v['amount'] ?? '0'}'),
        if ('${v['mode'] ?? ''}'.isNotEmpty) _detail('Mode', '${v['mode']}'),
        if ('${v['reference'] ?? ''}'.isNotEmpty) _detail('Reference', '${v['reference']}'),
        if ('${v['summary'] ?? ''}'.isNotEmpty) _detail('Details', '${v['summary']}'),
        _detail('Status', '${v['status'] ?? 'ACTIVE'}'),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
    ));
  }

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 105, child: Text(label, style: const TextStyle(color: Colors.grey))), Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))) ]),
  );

  @override
  Widget build(BuildContext context) {
    final visible = widget.vouchers.where((v) {
      final matchesType = _filter == 'ALL' || v['type'] == _filter;
      final q = _query.toLowerCase();
      final matchesQuery = q.isEmpty || ['number', 'party', 'summary', 'date', 'type'].any((k) => '${v[k] ?? ''}'.toLowerCase().contains(q));
      return matchesType && matchesQuery;
    }).toList();
    final total = visible.fold<double>(0, (sum, v) => sum + (double.tryParse('${v['amount'] ?? 0}') ?? 0));
    return Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(child: Text('VOUCHER HISTORY', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 0.5))),
        OutlinedButton.icon(onPressed: widget.onRefresh, icon: const Icon(Icons.sync, size: 18), label: const Text('Refresh')),
      ]),
      const SizedBox(height: 6),
      Text('${visible.length} vouchers  •  Total ₹${total.toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
      const SizedBox(height: 14),
      TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search voucher no, party, details...'), onChanged: (v) => setState(() => _query = v)),
      const SizedBox(height: 12),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
        for (final f in ['ALL', 'SALES', 'PURCHASE', 'RECEIPT', 'PAYMENT'])
          Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(f), selected: _filter == f, onSelected: (_) => setState(() => _filter = f))),
      ])),
      const SizedBox(height: 10),
      Expanded(child: visible.isEmpty
        ? const Center(child: Text('No vouchers found. Sync and try again.', style: TextStyle(color: Colors.grey)))
        : ListView.separated(itemCount: visible.length, separatorBuilder: (_, __) => const SizedBox(height: 7), itemBuilder: (ctx, i) {
            final v = visible[i]; final type = '${v['type']}'; final color = _typeColor(type);
            return Card(child: ListTile(
              onTap: () => _showDetails(v),
              leading: CircleAvatar(backgroundColor: color.withOpacity(.14), child: Icon(Icons.receipt_long, color: color)),
              title: Row(children: [Expanded(child: Text('${v['number']}', style: const TextStyle(fontWeight: FontWeight.bold))), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(.14), borderRadius: BorderRadius.circular(6)), child: Text(type, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)))]),
              subtitle: Text('${v['party']}  •  ${formatDisplayDateTime('${v['date'] ?? ''}')}\n${v['summary'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis),
              isThreeLine: true,
              trailing: Text('₹${v['amount']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ));
          })),
    ]));
  }
}

// ---------------- 8. INVOICE HISTORY VIEW ----------------

// ---------------- 8. INVOICE HISTORY VIEW ----------------

class InvoiceHistoryView extends StatefulWidget {
  final List<DCEstimate> estimates;
  final List<DCItem> items;
  final List<DCCustomer> customers;
  final Function(DCEstimate) onEditInvoice;
  final VoidCallback onRefreshRequired;

  const InvoiceHistoryView({
    super.key,
    required this.estimates,
    required this.items,
    required this.customers,
    required this.onEditInvoice,
    required this.onRefreshRequired,
  });

  @override
  State<InvoiceHistoryView> createState() => _InvoiceHistoryViewState();
}

class _InvoiceHistoryViewState extends State<InvoiceHistoryView> {
  String _selectedFilter = 'ALL';
  DateTimeRange? _customDateRange;

  List<Map<String, dynamic>> _parseSummaryTable(String summary) {
    final List<Map<String, dynamic>> rows = [];
    final parts = summary.split(',');
    for (var part in parts) {
      if (part.trim().isNotEmpty) {
        final raw = part.trim();
        String name = raw;
        String qty = '1';
        String unit = 'KG';
        String rate = '0.00';
        String bags = '1';
        double amount = 0.0;

        try {
          if (raw.contains('(') && raw.contains(')')) {
            name = raw.substring(0, raw.indexOf('(')).trim();
            final inside = raw.substring(raw.indexOf('(') + 1, raw.indexOf(')'));
            final xParts = inside.split('x');
            if (xParts.length == 2) {
              final qParts = xParts[0].trim().split(' ');
              qty = qParts[0];
              if (qParts.length > 1) unit = qParts[1];
              rate = xParts[1].trim();
            }
          }
          if (raw.contains('[') && raw.contains(']')) {
            bags = raw.substring(raw.indexOf('[') + 1, raw.indexOf(']')).replaceAll('B', '').trim();
          }
          amount = (double.tryParse(qty) ?? 1.0) * (double.tryParse(rate) ?? 0.0);
        } catch (_) {}

        rows.add({
          "name": name,
          "qty": qty,
          "unit": unit,
          "rate": rate,
          "bags": bags,
          "amount": amount.toStringAsFixed(2),
        });
      }
    }
    return rows;
  }

  void _showInvoiceDetails(BuildContext context, DCEstimate est) {
    final parsedRows = _parseSummaryTable(est.itemSummary);
    final isCancelled = est.status == 'CANCELLED';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Invoice #${est.slNo}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCancelled ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    est.status,
                    style: TextStyle(
                      color: isCancelled ? Colors.redAccent : Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (!isCancelled) ...[
                  const SizedBox(width: 10),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                    icon: const Icon(Icons.cancel, size: 16),
                    label: const Text('Cancel Bill'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _confirmCancelDialog(context, est);
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
        content: SizedBox(
          width: 760,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Party: ${est.customer}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1A73E8))),
                    Text('Date: ${formatDisplayDateTime(est.date)}', style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        ),
                        child: const Row(
                          children: [
                            SizedBox(width: 35, child: Text('No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                            Expanded(flex: 5, child: Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                            SizedBox(width: 80, child: Text('Rate (₹)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                            SizedBox(width: 60, child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                            SizedBox(width: 60, child: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                            SizedBox(width: 60, child: Text('Bags', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                            SizedBox(width: 90, child: Text('Amount (₹)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(12),
                        itemCount: parsedRows.length,
                        separatorBuilder: (c, i) => const Divider(height: 10),
                        itemBuilder: (c, i) {
                          final r = parsedRows[i];
                          return Row(
                            children: [
                              SizedBox(width: 35, child: Text('${i + 1}', style: const TextStyle(color: Colors.grey, fontSize: 13))),
                              Expanded(flex: 5, child: Text(r['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                              SizedBox(width: 80, child: Text('₹${r['rate']}', style: const TextStyle(fontSize: 13))),
                              SizedBox(width: 60, child: Text(r['qty'], style: const TextStyle(fontSize: 13))),
                              SizedBox(width: 60, child: Text(r['unit'], style: const TextStyle(fontSize: 13, color: Color(0xFF1A73E8)))),
                              SizedBox(width: 60, child: Text(r['bags'], style: const TextStyle(fontSize: 13))),
                              SizedBox(width: 90, child: Text('₹${r['amount']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Coolie: ₹${est.coolie}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    Text('SGST: ₹${est.sgst} | CGST: ₹${est.cgst}', style: const TextStyle(color: Color(0xFFF29900), fontSize: 13)),
                    Text('Round Off: ₹${est.roundOff}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('Grand Total: ₹${est.grandTotal}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A73E8))),
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton.icon(
            icon: const Icon(Icons.print, size: 16),
            label: const Text('Print / View PDF'),
            onPressed: () {
              Navigator.pop(ctx);
              _printHistoryInvoice(context, est);
            },
          ),
          if (!isCancelled)
            OutlinedButton.icon(
              icon: const Icon(Icons.edit_document, size: 16),
              label: const Text('Edit Invoice'),
              onPressed: () {
                Navigator.pop(ctx);
                widget.onEditInvoice(est);
              },
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _confirmCancelDialog(BuildContext context, DCEstimate est) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Confirmation'),
        content: Text('Are you sure you want to CANCEL Invoice #${est.slNo}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('NO (Back)'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await http.post(
                Uri.parse(sheetApiUrl),
                body: jsonEncode({
                  "action": "CANCEL_ESTIMATE",
                  "rowIndex": est.rowIndex,
                }),
              );
              widget.onRefreshRequired();
            },
            child: const Text('YES (Cancel Bill)'),
          ),
        ],
      ),
    );
  }

  void _printHistoryInvoice(BuildContext context, DCEstimate est) {
    final matchedCustomer = widget.customers.firstWhere(
      (c) => c.name.toLowerCase() == est.customer.toLowerCase(),
      orElse: () => DCCustomer(rowIndex: 0, slNo: 0, name: est.customer, contact: '', address: '', b2c: '', b2b: '', remarks: ''),
    );

    final List<InvoiceRowItem> parsedItems = [];
    final itemsParts = est.itemSummary.split(',');
    for (var part in itemsParts) {
      if (part.trim().isNotEmpty) {
        final raw = part.trim();
        String itemName = raw;
        double qty = 1.0;
        String unit = 'KG';
        double rate = 0.0;
        int bags = 1;

        try {
          if (raw.contains('(') && raw.contains(')')) {
            itemName = raw.substring(0, raw.indexOf('(')).trim();
            final inside = raw.substring(raw.indexOf('(') + 1, raw.indexOf(')'));
            final xParts = inside.split('x');
            if (xParts.length == 2) {
              final qParts = xParts[0].trim().split(' ');
              qty = double.tryParse(qParts[0]) ?? 1.0;
              if (qParts.length > 1) unit = qParts[1];
              rate = double.tryParse(xParts[1].trim()) ?? 0.0;
            }
          }
          if (raw.contains('[') && raw.contains(']')) {
            final bStr = raw.substring(raw.indexOf('[') + 1, raw.indexOf(']')).replaceAll('B', '').trim();
            bags = int.tryParse(bStr) ?? 1;
          }
        } catch (_) {}

        final matchedItem = widget.items.firstWhere(
          (i) => i.name.toLowerCase() == itemName.toLowerCase(),
          orElse: () => DCItem(
            rowIndex: 0,
            no: parsedItems.length + 1,
            name: itemName,
            rateType: unit,
            rate: rate.toString(),
            qty: qty.toString(),
            tallyName: itemName,
            billedIn: unit,
            isTaxable: false,
          ),
        );

        parsedItems.add(
          InvoiceRowItem(
            item: matchedItem,
            rate: rate,
            qty: qty,
            unit: unit,
            bags: bags,
          ),
        );
      }
    }

    final double coolie = double.tryParse(est.coolie) ?? 0.0;
    final double sgst = double.tryParse(est.sgst) ?? 0.0;
    final double cgst = double.tryParse(est.cgst) ?? 0.0;
    final double roundOff = double.tryParse(est.roundOff) ?? 0.0;
    final double grandTotal = double.tryParse(est.grandTotal) ?? 0.0;
    final double grossAmount = parsedItems.fold(0.0, (sum, i) => sum + i.amount);
    final double subTotal = (sgst + cgst) > 0 ? (grossAmount - (sgst + cgst)) : grossAmount;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.all(20),
        child: SizedBox(
          width: 920,
          height: 720,
          child: Column(
            children: [
              AppBar(
                title: Text('Invoice #${est.slNo} - Print View'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              Expanded(
                child: PdfPreview(
                  build: (format) => generateTallyPdf(
                    format: format,
                    billNo: est.slNo.toString(),
                    dateStr: formatDisplayDateTime(est.date),
                    customer: matchedCustomer,
                    items: parsedItems,
                    subTotal: subTotal,
                    coolie: coolie,
                    sgst: sgst,
                    cgst: cgst,
                    roundOff: roundOff,
                    grandTotal: grandTotal,
                  ),
                  allowPrinting: true,
                  allowSharing: true,
                  canChangePageFormat: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final sorted = List<DCEstimate>.from(widget.estimates.reversed);
    final filtered = sorted.where((e) {
      final eDate = parseUniversalDate(e.date);
      if (eDate == null) return _selectedFilter != 'TODAY';

      final checkDay = DateTime(eDate.year, eDate.month, eDate.day);
      if (_selectedFilter == 'TODAY') return checkDay.isAtSameMomentAs(today);
      if (_selectedFilter == 'YESTERDAY') return checkDay.isAtSameMomentAs(yesterday);
      if (_selectedFilter == 'CUSTOM' && _customDateRange != null) {
        return checkDay.isAfter(_customDateRange!.start.subtract(const Duration(days: 1))) &&
            checkDay.isBefore(_customDateRange!.end.add(const Duration(days: 1)));
      }
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'ALL', label: Text('All')),
                    ButtonSegment(value: 'TODAY', label: Text('Today')),
                    ButtonSegment(value: 'YESTERDAY', label: Text('Yesterday')),
                    ButtonSegment(value: 'CUSTOM', label: Text('Custom')),
                  ],
                  selected: {_selectedFilter},
                  onSelectionChanged: (val) async {
                    if (val.first == 'CUSTOM') {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() {
                          _customDateRange = picked;
                          _selectedFilter = 'CUSTOM';
                        });
                      }
                    } else {
                      setState(() => _selectedFilter = val.first);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 8),
              itemBuilder: (ctx, idx) {
                final est = filtered[idx];
                final isCancelled = est.status == 'CANCELLED';

                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Row(
                      children: [
                        Text('#${est.slNo}  ${est.customer}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const Spacer(),
                        Text('₹${est.grandTotal}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isCancelled ? Colors.grey : const Color(0xFF1A73E8))),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(formatDisplayDateTime(est.date), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        Text(est.itemSummary, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    onTap: () => _showInvoiceDetails(context, est),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- 9. ENTERPRISE REPORTS VIEW ----------------

// ---------------- 9. ENTERPRISE REPORTS VIEW ----------------

class EnterpriseReportsView extends StatefulWidget {
  final List<DCEstimate> estimates;
  final List<DCItem> items;
  final List<DCCustomer> customers;
  final Function(DCEstimate) onEditInvoice;
  final VoidCallback onRefreshRequired;

  const EnterpriseReportsView({
    super.key,
    required this.estimates,
    required this.items,
    required this.customers,
    required this.onEditInvoice,
    required this.onRefreshRequired,
  });

  @override
  State<EnterpriseReportsView> createState() => _EnterpriseReportsViewState();
}

class _EnterpriseReportsViewState extends State<EnterpriseReportsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _reportFilter = 'ALL';
  DateTimeRange? _reportDateRange;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  void _openDrilldownHistoryModal(String title, List<DCEstimate> bills) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: Color(0xFF1A73E8)),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
          ],
        ),
        content: SizedBox(
          width: 680,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Invoices: ${bills.length}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 380),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: bills.isEmpty
                    ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No billed records found.')))
                    : ListView.separated(
                        itemCount: bills.length,
                        separatorBuilder: (c, i) => const Divider(height: 1),
                        itemBuilder: (c, i) {
                          final b = bills[i];
                          return ListTile(
                            title: Row(
                              children: [
                                Text('#${b.slNo} • ${b.customer}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                const Spacer(),
                                Text('₹${b.grandTotal}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A73E8), fontSize: 15)),
                              ],
                            ),
                            subtitle: Text("${formatDisplayDateTime(b.date)} | ${b.itemSummary}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            onTap: () {
                              Navigator.pop(ctx);
                              widget.onEditInvoice(b);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.estimates.where((e) => e.status != 'CANCELLED').toList();
    final double totalRevenue = active.fold(0.0, (sum, e) => sum + (double.tryParse(e.grandTotal) ?? 0.0));
    final double totalCoolie = active.fold(0.0, (sum, e) => sum + (double.tryParse(e.coolie) ?? 0.0));

    Map<String, int> itemOrderCount = {};
    for (var est in active) {
      for (var item in widget.items) {
        if (est.itemSummary.toLowerCase().contains(item.name.toLowerCase())) {
          itemOrderCount[item.name] = (itemOrderCount[item.name] ?? 0) + 1;
        }
      }
    }
    final sortedItemSales = itemOrderCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    Map<String, double> customerTotalSpend = {};
    for (var est in active) {
      customerTotalSpend[est.customer] = (customerTotalSpend[est.customer] ?? 0.0) + (double.tryParse(est.grandTotal) ?? 0.0);
    }
    final sortedCustSales = customerTotalSpend.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.35),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Invoiced Revenue', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text('₹${totalRevenue.toStringAsFixed(2)}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1A73E8))),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('Active Invoices: ${active.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 20),
                      Text('Coolie Charges: ₹${totalCoolie.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Item Distribution'),
              Tab(text: 'Customer Spend Ledger'),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                ListView.separated(
                  itemCount: sortedItemSales.length,
                  separatorBuilder: (c, i) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final entry = sortedItemSales[idx];
                    return ListTile(
                      title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: Text('${entry.value} Invoices >', style: const TextStyle(color: Color(0xFF1A73E8), fontWeight: FontWeight.bold)),
                      onTap: () {
                        final matchedBills = active.where((e) => e.itemSummary.toLowerCase().contains(entry.key.toLowerCase())).toList();
                        _openDrilldownHistoryModal('Invoices for ${entry.key}', matchedBills);
                      },
                    );
                  },
                ),
                ListView.separated(
                  itemCount: sortedCustSales.length,
                  separatorBuilder: (c, i) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final entry = sortedCustSales[idx];
                    return ListTile(
                      title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: Text('₹${entry.value.toStringAsFixed(2)} >', style: const TextStyle(color: Color(0xFF1A73E8), fontWeight: FontWeight.bold)),
                      onTap: () {
                        final matchedBills = active.where((e) => e.customer.toLowerCase().trim() == entry.key.toLowerCase().trim()).toList();
                        _openDrilldownHistoryModal('Invoices for ${entry.key}', matchedBills);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- 10. SETTINGS VIEW ----------------

class SettingsDesktopView extends StatelessWidget {
  final VoidCallback onReloadSheet;
  final VoidCallback onOpenProfile;

  const SettingsDesktopView({
    super.key,
    required this.onReloadSheet,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.business_rounded, color: Color(0xFF1A73E8)),
            title: const Text('Company & GST Profile', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${CompanyConfig.name} • ${CompanyConfig.gstin}'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onOpenProfile,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.sync_rounded, color: Color(0xFF188038)),
            title: const Text('Force Google Sheet Sync', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Refresh all stock, parties and ledger records'),
            onTap: () {
              onReloadSheet();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Syncing data with Google Sheets...')),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        const Text('About MultiBill ERP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ANDROCODE SOFTWARE SOLUTIONS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                const Text('MULTIBILL ERP Suite • v3.8.0', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const Divider(height: 20),
                const Text('Material 3 Desktop & Mobile UI Engine', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
