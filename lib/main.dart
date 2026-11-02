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
  runApp(const BrandBootApp());
}

class BrandBootApp extends StatefulWidget {
  const BrandBootApp({super.key});

  @override
  State<BrandBootApp> createState() => _BrandBootAppState();
}

class _BrandBootAppState extends State<BrandBootApp> {
  bool _showBoot = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _showBoot = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _showBoot ? const BrandBootScreen() : const MultiBillApp();
  }
}

class BrandBootScreen extends StatelessWidget {
  const BrandBootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF1769E0);
    const navy = Color(0xFF102A56);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [blue, navy],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: blue.withOpacity(0.22),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'AC',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                const Text(
                  'MULTIBILLER ERP SUITE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: navy,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'BY ANDROCODE SOFTWARE SOLUTIONS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF53657D),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Every Bill. Every Business. One Smart Suite.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF65748B),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 34),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: blue,
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
  final LayerLink layerLink = LayerLink();

  InvoiceRowItem({
    this.item,
    this.rate = 0.0,
    this.qty = 1.0,
    this.unit = 'KG',
    this.bags = 1,
  });

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

String _m3MonthName(int month) => const [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
][month - 1];

String _m3WeekdayName(int weekday) => const [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday',
  'Friday', 'Saturday', 'Sunday',
][weekday - 1];

String _m3Date(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')} ${_m3MonthName(date.month)} ${date.year}';

String _m3FullDate(DateTime date) =>
    '${_m3WeekdayName(date.weekday)}, ${_m3Date(date)}';

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
  int _navIndex = -1;
  List<DCItem> _items = [];
  List<DCCustomer> _customers = [];
  List<DCEstimate> _estimates = [];
  final List<LoadingEntry> _loadingSlip = [];
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
      _navIndex = 0;
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withOpacity(0.4),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: scheme.outlineVariant.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    'AC',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: scheme.onPrimaryContainer),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search menu (Billing, Items, Customers, Reports)...',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    onSubmitted: (value) {
                      final q = value.toLowerCase();
                      final i = ['billing', 'price', 'customer', 'packing', 'invoice', 'report', 'setting']
                          .indexWhere((s) => s.startsWith(q) || q.startsWith(s));
                      if (i >= 0) setState(() => _navIndex = i);
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
      ),
    );
  }

  Widget _buildGoogleHomeDashboard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final categories = <String, List<({String title, IconData icon, int index, Color tint})>>{
      'MASTERS': [
        (title: 'Customers Directory', icon: Icons.people_alt_rounded, index: 2, tint: const Color(0xFF1A73E8)),
        (title: 'Items / Price List', icon: Icons.inventory_2_rounded, index: 1, tint: const Color(0xFF188038)),
        (title: 'Company Setup & Header', icon: Icons.business_rounded, index: 6, tint: const Color(0xFF9334E6)),
      ],
      'TRANSACTIONS': [
        (title: 'Customer Billing (Sales)', icon: Icons.receipt_long_rounded, index: 0, tint: const Color(0xFFD93025)),
        (title: 'Packing & Loading Slip', icon: Icons.local_shipping_rounded, index: 3, tint: const Color(0xFFF29900)),
        (title: 'Invoice History Log', icon: Icons.description_rounded, index: 4, tint: const Color(0xFF188038)),
      ],
      'REPORTS': [
        (title: 'Sales & Business Reports', icon: Icons.bar_chart_rounded, index: 5, tint: const Color(0xFFD93025)),
      ],
      'UTILITIES': [
        (title: 'Google Sheet Sync', icon: Icons.storage_rounded, index: -2, tint: const Color(0xFF1A73E8)),
        (title: 'Settings & Theme Preferences', icon: Icons.tune_rounded, index: 6, tint: const Color(0xFF12B5CB)),
      ],
    };

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            // Google M3 Profile Banner
            Card(
              color: scheme.surfaceContainerHighest.withOpacity(0.35),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: scheme.primaryContainer,
                      child: Text(
                        'AC',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: scheme.onPrimaryContainer),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            CompanyConfig.name,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${CompanyConfig.tradeSubtitle} • MULTIBILL ERP",
                            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _m3FullDate(DateTime.now()),
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.primary),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Setup'),
                      onPressed: _openCompanyProfileDialog,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Quick Shortcut Buttons
            Row(
              children: [
                Expanded(
                  child: _quickActionButton(
                    context,
                    title: 'New Bill (Sales)',
                    icon: Icons.receipt_long_rounded,
                    color: const Color(0xFFD93025),
                    onTap: () => setState(() => _navIndex = 0),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _quickActionButton(
                    context,
                    title: 'Price List',
                    icon: Icons.inventory_2_rounded,
                    color: const Color(0xFF188038),
                    onTap: () => setState(() => _navIndex = 1),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _quickActionButton(
                    context,
                    title: 'Parties',
                    icon: Icons.people_alt_rounded,
                    color: const Color(0xFF1A73E8),
                    onTap: () => setState(() => _navIndex = 2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _quickActionButton(
                    context,
                    title: 'Reports',
                    icon: Icons.bar_chart_rounded,
                    color: const Color(0xFFF29900),
                    onTap: () => setState(() => _navIndex = 5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Collapsible M3 Categories
            ...categories.entries.map((cat) {
              final isTransactions = cat.key == 'TRANSACTIONS';
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 5),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: isTransactions,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    leading: Icon(
                      isTransactions
                          ? Icons.swap_horiz_rounded
                          : cat.key == 'MASTERS'
                              ? Icons.folder_open_rounded
                              : cat.key == 'REPORTS'
                                  ? Icons.analytics_rounded
                                  : Icons.tune_rounded,
                      color: scheme.primary,
                      size: 22,
                    ),
                    title: Text(
                      cat.key,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                        color: scheme.primary,
                        fontSize: 13,
                      ),
                    ),
                    children: cat.value.map((item) {
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                        leading: Icon(item.icon, color: item.tint, size: 22),
                        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                        onTap: () {
                          if (item.index == -2) {
                            _fetchData(silent: true);
                          } else {
                            setState(() => _navIndex = item.index);
                          }
                        },
                      );
                    }).toList(),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _quickActionButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: color.withOpacity(0.14),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedScreen() {
    final screens = <Widget>[
      TallyBillingScreen(
        items: _items,
        customers: _customers,
        nextBillNo: _estimates.length + 1,
        invoiceToEdit: _invoiceToEdit,
        onClearEditInvoice: () => setState(() => _invoiceToEdit = null),
        onSaved: () => _fetchData(silent: true),
        onSetSyncing: (val) => setState(() => _isBackgroundSyncing = val),
      ),
      PriceListDesktopView(
        items: _items,
        onRefreshRequired: () => _fetchData(silent: true),
      ),
      CustomerDesktopView(
        customers: _customers,
        onRefreshRequired: () => _fetchData(silent: true),
      ),
      LoadingSlipView(loadingSlip: _loadingSlip, items: _items, customers: _customers),
      InvoiceHistoryView(
        estimates: _estimates,
        items: _items,
        customers: _customers,
        onEditInvoice: _onLoadInvoiceToEdit,
        onRefreshRequired: () => _fetchData(silent: true),
      ),
      EnterpriseReportsView(
        estimates: _estimates,
        items: _items,
        customers: _customers,
        onEditInvoice: _onLoadInvoiceToEdit,
        onRefreshRequired: () => _fetchData(silent: true),
      ),
      SettingsDesktopView(
        onReloadSheet: () => _fetchData(silent: true),
        onOpenProfile: _openCompanyProfileDialog,
      ),
    ];

    return Column(
      children: [
        AppBar(
          leading: IconButton(
            tooltip: 'Back to Home',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => setState(() => _navIndex = -1),
          ),
          title: Text(CompanyConfig.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        Expanded(child: screens[_navIndex]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (_isBackgroundSyncing)
              const LinearProgressIndicator(minHeight: 2.5),
            if (_navIndex < 0)
              _buildTopSearchBar(context),
            Expanded(
              child: _navIndex < 0
                  ? _buildGoogleHomeDashboard(context)
                  : _buildSelectedScreen(),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- 1. BILLING SCREEN ----------------

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
        row.textCtrl.text = itemName;
        _rows.add(row);
      }
    }

    if (_rows.isEmpty) _addRow();
    setState(() {});
  }

  void _addRow() {
    setState(() {
      _rows.add(InvoiceRowItem(item: null, rate: 0.0, qty: 1.0, unit: 'KG', bags: 1));
    });
  }

  void _removeRow(int idx) {
    _hideItemOverlay();
    if (_rows.length > 1) {
      setState(() {
        _rows.removeAt(idx);
      });
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

  double get _grossItemsTotal => _rows.fold(0.0, (sum, r) => sum + r.amount);

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
  int get _totalBags => _rows.fold(0, (sum, r) => sum + r.bags);

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

  void _showItemOverlay(int rowIdx) {
    _hideItemOverlay();
    if (_filteredItems.isEmpty) return;

    final renderBox = _rows[rowIdx].itemSearchFocus.context?.findRenderObject() as RenderBox?;
    double offsetY = 48.0;
    const double popupHeight = 200.0;

    if (renderBox != null) {
      final position = renderBox.localToGlobal(Offset.zero);
      final screenHeight = MediaQuery.of(context).size.height;
      final spaceBelow = screenHeight - position.dy - renderBox.size.height;
      if (spaceBelow < 230) {
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
                      return InkWell(
                        onTap: () => _selectItem(rowIdx, item),
                        child: Container(
                          color: isSelected ? const Color(0xFF1A73E8).withOpacity(0.3) : null,
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
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected ? const Color(0xFF8AB4F8) : Colors.white,
                                    ),
                                  ),
                                ],
                              ),
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
    setState(() {
      _rows[rowIdx].item = itm;
      _rows[rowIdx].textCtrl.text = itm.name;
      _rows[rowIdx].rate = double.tryParse(itm.rate) ?? 0.0;
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

    return FocusScope(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final isCtrl = HardwareKeyboard.instance.isControlPressed;
          if ((isCtrl && event.logicalKey == LogicalKeyboardKey.keyS) ||
              event.logicalKey == LogicalKeyboardKey.f8) {
            _saveInvoice();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(isEditing ? 'Edit Customer Bill' : 'Customer Bill',
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
                  label: Text(isEditing ? 'Update & Print' : 'Save & Print'),
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
                                        hintText: 'Search item...',
                                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      ),
                                      onChanged: (val) {
                                        setState(() {
                                          _itemSelectedIndex = 0;
                                          _filteredItems = widget.items.where((i) {
                                            return i.name.toLowerCase().contains(val.toLowerCase()) ||
                                                i.tallyName.toLowerCase().contains(val.toLowerCase());
                                          }).toList();
                                        });
                                        _showItemOverlay(idx);
                                      },
                                      onTap: () {
                                        setState(() {
                                          _filteredItems = widget.items;
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
                                child: TextFormField(
                                  key: ValueKey('rate_${row.item?.name}_$idx'),
                                  initialValue: row.rate.toStringAsFixed(2),
                                  focusNode: row.rateFocus,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                  onChanged: (val) {
                                    setState(() {
                                      row.rate = double.tryParse(val) ?? 0.0;
                                    });
                                  },
                                  onFieldSubmitted: (_) => row.qtyFocus.requestFocus(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 90,
                                child: TextFormField(
                                  initialValue: row.qty.toStringAsFixed(0),
                                  focusNode: row.qtyFocus,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                  onChanged: (val) {
                                    setState(() {
                                      row.qty = double.tryParse(val) ?? 1.0;
                                    });
                                  },
                                  onFieldSubmitted: (_) => row.unitFocus.requestFocus(),
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
                                              Text(row.unit, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                                child: TextFormField(
                                  initialValue: row.bags.toString(),
                                  focusNode: row.bagsFocus,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                  onChanged: (val) {
                                    setState(() {
                                      row.bags = int.tryParse(val) ?? 1;
                                    });
                                  },
                                  onFieldSubmitted: (_) {
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
                            child: TextField(
                              controller: _coolieCtrl,
                              focusNode: _coolieFocus,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Coolie (₹)'),
                              onChanged: (_) => setState(() {}),
                              onSubmitted: (_) => _saveInvoice(),
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

// ---------------- 2. PRICE LIST VIEW ----------------

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

  void _openEditItemDialog({DCItem? item}) {
    final isNew = item == null;
    final nameCtrl = TextEditingController(text: isNew ? '' : item.name);
    final rateCtrl = TextEditingController(text: isNew ? '' : item.rate);
    final rateTypeCtrl = TextEditingController(text: isNew ? 'RATE PER KG' : item.rateType);
    final qtyCtrl = TextEditingController(text: isNew ? '50' : '${item.qty}');
    final tallyCtrl = TextEditingController(text: isNew ? '' : item.tallyName);
    final billedCtrl = TextEditingController(text: isNew ? 'KILOGRAM' : item.billedIn);
    bool isTaxable = isNew ? false : item.isTaxable;

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
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Item Name')),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: rateCtrl, decoration: const InputDecoration(labelText: 'Rate (₹)'))),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: rateTypeCtrl, decoration: const InputDecoration(labelText: 'Rate Type'))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: 'Qty'))),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: billedCtrl, decoration: const InputDecoration(labelText: 'Billed In'))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: tallyCtrl, decoration: const InputDecoration(labelText: 'Tally Name')),
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

  @override
  Widget build(BuildContext context) {
    final filtered = widget.items
        .where((i) => i.name.toLowerCase().contains(_query.toLowerCase()) || i.tallyName.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Search items...',
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
              physics: const BouncingScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 8),
              itemBuilder: (ctx, idx) {
                final item = filtered[idx];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Text('${item.no}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    subtitle: Text('${item.qty} ${item.billedIn} • Tally: ${item.tallyName}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('₹${item.rate}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A73E8))),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () => _openEditItemDialog(item: item),
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

// ---------------- 3. CUSTOMERS VIEW ----------------

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

  void _openEditCustomerDialog({DCCustomer? customer}) {
    final isNew = customer == null;
    final nameCtrl = TextEditingController(text: isNew ? '' : customer.name);
    final contactCtrl = TextEditingController(text: isNew ? '' : customer.contact);
    final addressCtrl = TextEditingController(text: isNew ? '' : customer.address);
    final b2bCtrl = TextEditingController(text: isNew ? '' : customer.b2b);
    final b2cCtrl = TextEditingController(text: isNew ? '' : customer.b2c);
    final remarksCtrl = TextEditingController(text: isNew ? '' : customer.remarks);

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
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Party Name')),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextField(controller: contactCtrl, decoration: const InputDecoration(labelText: 'Contact'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address'))),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(controller: b2bCtrl, decoration: const InputDecoration(labelText: 'Trade Name (B2B)')),
                const SizedBox(height: 10),
                TextField(controller: b2cCtrl, decoration: const InputDecoration(labelText: 'B2C Ref')),
                const SizedBox(height: 10),
                TextField(controller: remarksCtrl, decoration: const InputDecoration(labelText: 'Delivery Rules / Remarks')),
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

  @override
  Widget build(BuildContext context) {
    final filtered = widget.customers.where((c) {
      return c.name.toLowerCase().contains(_query.toLowerCase()) ||
          c.b2b.toLowerCase().contains(_query.toLowerCase()) ||
          c.contact.contains(_query);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Search parties...',
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
              physics: const BouncingScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final c = filtered[i];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Text('${c.slNo}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    title: Row(
                      children: [
                        Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(c.billingTag, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    subtitle: Text('📞 ${c.contact.isNotEmpty ? c.contact : "-"} • 📍 ${c.address.isNotEmpty ? c.address : "-"}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => _openEditCustomerDialog(customer: c),
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

// ---------------- 4. INVOICE HISTORY VIEW ----------------

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
                    onTap: () => widget.onEditInvoice(est),
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

// ---------------- 5. PACKING SLIP VIEW ----------------

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

// ---------------- 6. ENTERPRISE REPORTS VIEW ----------------

class EnterpriseReportsView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final active = estimates.where((e) => e.status != 'CANCELLED').toList();
    final double totalRevenue = active.fold(0.0, (sum, e) => sum + (double.tryParse(e.grandTotal) ?? 0.0));
    final double totalCoolie = active.fold(0.0, (sum, e) => sum + (double.tryParse(e.coolie) ?? 0.0));

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
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
        const SizedBox(height: 16),
        const Text('Recent Invoices (Click to View/Edit)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        ...active.take(15).map((est) => Card(
              child: ListTile(
                title: Text(est.customer, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(formatDisplayDateTime(est.date), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                trailing: Text('₹${est.grandTotal}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF188038))),
                onTap: () => onEditInvoice(est),
              ),
            )),
      ],
    );
  }
}

// ---------------- 7. SETTINGS VIEW ----------------

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
