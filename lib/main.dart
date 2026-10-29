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
  runApp(const SPMultiBillApp());
}

String sheetApiUrl =
    "https://script.google.com/macros/s/AKfycbzFDW5eeT4abGSRNLHlKs43JJ81YiKt0UrNEbbK2_cQIylsU_zGylqE8IMBqtpmXsjOEg/exec";

// ---------------- 90+ FPS SMOOTH SCROLL BEHAVIOR ----------------

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

// ---------------- CONFIG & COMPANY PROFILE ----------------

class CompanyConfig {
  static String name = "DAVIS & COMPANY";
  static String tradeSubtitle = "Wholesale Rice Merchants";
  static String address = "Market Road, Aluva, Ernakulam, Kerala - 683101";
  static String phone = "+91 98470 12345";
  static String email = "davisandcompanyaluva@gmail.com";
  static String gstin = "32AABCD1234E1Z5";
  static String regType = "Regular";
  static String stateCode = "Kerala (32)";
  static String logoUrl = "";
  static double defaultGstRate = 5.0; // 5% Inclusive Tax
}

// ---------------- MODELS ----------------

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

// ---------------- TOP-LEVEL TALLY PRIME PDF GENERATOR ----------------

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
    } catch (e) {}
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
                          pw.Text("GSTIN/UIN: ${CompanyConfig.gstin}  |  State: ${CompanyConfig.stateCode}  |  Ph: ${CompanyConfig.phone}", style: const pw.TextStyle(fontSize: 9)),
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
                            pw.Text("Powered by SP MultiBill ERP • SP Tech Solutions", style: const pw.TextStyle(fontSize: 5, color: PdfColors.grey600)),
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

// ---------------- APP ROOT (SPMultiBillApp) ----------------

class SPMultiBillApp extends StatelessWidget {
  const SPMultiBillApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SP MultiBill ERP • SP Tech Solutions',
      scrollBehavior: UltraSmoothScrollBehavior(),
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B1015),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3B82F6),
          secondary: Color(0xFF10B981),
          tertiary: Color(0xFF8B5CF6),
          surface: Color(0xFF131922),
          onSurface: Color(0xFFF8FAFC),
        ),
        navigationRailTheme: const NavigationRailThemeData(
          backgroundColor: Color(0xFF0E141B),
          indicatorColor: Color(0xFF1E88E5),
          selectedIconTheme: IconThemeData(color: Colors.white, size: 22),
          unselectedIconTheme: IconThemeData(color: Color(0xFF94A3B8), size: 22),
          selectedLabelTextStyle: TextStyle(color: Color(0xFF6FB1FC), fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelTextStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF18202B),
          border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF263342))),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF263342))),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF3B82F6), width: 1.5)),
          labelStyle: TextStyle(color: Color(0xFF94A3B8)),
        ),
      ),
      home: const MainDashboard(),
    );
  }
}

// ---------------- MAIN DASHBOARD ----------------

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _navIndex = 0;
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
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isBackgroundSyncing = false;
      });
    }
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
          backgroundColor: const Color(0xFF131922),
          title: const Row(
            children: [
              Icon(Icons.business, color: Color(0xFF3B82F6)),
              SizedBox(width: 10),
              Text('Company Profile & Header (Saved to Sheet)', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E141B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF263342)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: const Color(0xFF18202B),
                          backgroundImage: logoPathLocal.isNotEmpty
                              ? FileImage(File(logoPathLocal))
                              : (CompanyConfig.logoUrl.isNotEmpty ? NetworkImage(CompanyConfig.logoUrl) as ImageProvider : null),
                          child: (logoPathLocal.isEmpty && CompanyConfig.logoUrl.isEmpty)
                              ? const Icon(Icons.image, color: Color(0xFF94A3B8))
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(logoPathLocal.isNotEmpty
                                  ? 'Selected: ${logoPathLocal.split(Platform.pathSeparator).last}'
                                  : (CompanyConfig.logoUrl.isNotEmpty ? 'Cloud Logo Synced' : 'No Logo Uploaded')),
                              const SizedBox(height: 4),
                              const Text('Select PNG/JPG (Auto-uploads to Google Drive)', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF3B82F6)),
                            foregroundColor: const Color(0xFF6FB1FC),
                          ),
                          icon: const Icon(Icons.file_upload, size: 16),
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
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
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
                } catch (e) {}

                CompanyConfig.name = nameCtrl.text.trim();
                CompanyConfig.tradeSubtitle = subCtrl.text.trim();
                CompanyConfig.address = addrCtrl.text.trim();
                CompanyConfig.phone = phoneCtrl.text.trim();
                CompanyConfig.email = emailCtrl.text.trim();
                CompanyConfig.gstin = gstinCtrl.text.trim();
                CompanyConfig.regType = regTypeCtrl.text.trim();

                setState(() => _isBackgroundSyncing = false);
              },
              child: const Text('Save to Sheet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _onLoadInvoiceToEdit(DCEstimate est) {
    setState(() {
      _invoiceToEdit = est;
      _navIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B1015),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [Color(0xFF0052D4), Color(0xFF4364F7), Color(0xFF6FB1FC)]),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF1E88E5).withOpacity(0.35), blurRadius: 28, spreadRadius: 4),
                  ],
                ),
                child: const Text('SP', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(height: 24),
              const Text('SP MULTIBILL ERP',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Color(0xFFF8FAFC))),
              const SizedBox(height: 6),
              const Text('POWERED BY SP TECH SOLUTIONS',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.5, color: Color(0xFF3B82F6))),
              const SizedBox(height: 4),
              const Text('Wholesale, Retail & Distribution ERP Suite • v3.5.0',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              const SizedBox(height: 32),
              const SizedBox(
                width: 150,
                child: LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: Color(0xFF131922),
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E88E5)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          if (_isBackgroundSyncing)
            const LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: Color(0xFF131922),
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E88E5)),
            ),
          Expanded(
            child: Row(
              children: [
                NavigationRail(
                  selectedIndex: _navIndex,
                  onDestinationSelected: (val) => setState(() => _navIndex = val),
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Tooltip(
                      message: 'Click to edit Company Header & Logo',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: _openCompanyProfileDialog,
                        child: CompanyConfig.logoUrl.isNotEmpty
                            ? CircleAvatar(
                                radius: 20,
                                backgroundColor: const Color(0xFF18202B),
                                backgroundImage: NetworkImage(CompanyConfig.logoUrl),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [Color(0xFF0052D4), Color(0xFF4364F7)]),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text('SP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white)),
                              ),
                      ),
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh, color: Color(0xFF94A3B8)),
                    tooltip: 'Sync from Google Sheet',
                    onPressed: () => _fetchData(silent: true),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.receipt_long_outlined),
                      selectedIcon: Icon(Icons.receipt_long),
                      label: Text('Billing'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      selectedIcon: Icon(Icons.inventory_2),
                      label: Text('Price List'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.people_outline),
                      selectedIcon: Icon(Icons.people),
                      label: Text('Customers'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.local_shipping_outlined),
                      selectedIcon: Icon(Icons.local_shipping),
                      label: Text('Packing Slip'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.history_outlined),
                      selectedIcon: Icon(Icons.history),
                      label: Text('Invoices'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: Text('Settings'),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1, color: Color(0xFF1E2833)),
                Expanded(
                  child: IndexedStack(
                    index: _navIndex,
                    children: [
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
                        estimates: _estimates,
                        onRefreshRequired: () => _fetchData(silent: true),
                      ),
                      CustomerDesktopView(
                        customers: _customers,
                        estimates: _estimates,
                        onRefreshRequired: () => _fetchData(silent: true),
                      ),
                      LoadingSlipView(
                        loadingSlip: _loadingSlip,
                        items: _items,
                        customers: _customers,
                      ),
                      InvoiceHistoryView(
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
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- 1. SP MULTIBILL BILLING SCREEN ----------------

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
  int? _activeItemRowIndex;
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
        } catch (e) {}

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
                color: const Color(0xFF18202B),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 220),
                  decoration: BoxDecoration(
                    color: const Color(0xFF18202B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF1E88E5), width: 1.2),
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
                          color: isSelected ? const Color(0xFF1E88E5).withOpacity(0.3) : null,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              if (isSelected)
                                const Text('> ', style: TextStyle(color: Color(0xFF6FB1FC), fontWeight: FontWeight.bold)),
                              Expanded(
                                child: Text(
                                  "${p.name} ${p.b2b.isNotEmpty ? '(${p.b2b})' : ''}",
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? const Color(0xFF6FB1FC) : Colors.white,
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
      final isAlt = HardwareKeyboard.instance.isAltPressed;
      if (isAlt && event.logicalKey == LogicalKeyboardKey.keyC) {
        _hidePartyOverlay();
        _openInstantAddCustomerDialog(_partyTextCtrl.text.trim());
        return KeyEventResult.handled;
      }

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
                color: const Color(0xFF18202B),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: popupHeight,
                  decoration: BoxDecoration(
                    color: const Color(0xFF18202B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF1E88E5), width: 1.2),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
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
                          color: isSelected ? const Color(0xFF1E88E5).withOpacity(0.35) : null,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  if (isSelected)
                                    const Text('> ', style: TextStyle(color: Color(0xFF6FB1FC), fontWeight: FontWeight.bold)),
                                  Text(
                                    item.name,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected ? const Color(0xFF6FB1FC) : Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              Text('₹${item.rate}', style: const TextStyle(color: Color(0xFF6FB1FC), fontWeight: FontWeight.bold, fontSize: 13)),
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
      final isAlt = HardwareKeyboard.instance.isAltPressed;
      if (isAlt && event.logicalKey == LogicalKeyboardKey.keyC) {
        _hideItemOverlay();
        _openInstantAddItemDialog(rowIdx, _rows[rowIdx].textCtrl.text.trim());
        return KeyEventResult.handled;
      }

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

  void _openInstantAddCustomerDialog(String presetName) {
    final nameCtrl = TextEditingController(text: presetName);
    final contactCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final b2bCtrl = TextEditingController();
    final b2cCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131922),
        title: const Text('Instant Add Customer (Alt + C)'),
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
                TextField(controller: b2bCtrl, decoration: const InputDecoration(labelText: 'B2B Trade Name')),
                const SizedBox(height: 10),
                TextField(controller: b2cCtrl, decoration: const InputDecoration(labelText: 'B2C Reference')),
                const SizedBox(height: 10),
                TextField(controller: remarksCtrl, decoration: const InputDecoration(labelText: 'Remarks / Delivery Rules')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0052D4)),
            onPressed: () async {
              if (nameCtrl.text.trim().isNotEmpty) {
                Navigator.pop(ctx);
                final newCust = DCCustomer(
                  rowIndex: widget.customers.length + 2,
                  slNo: widget.customers.length + 1,
                  name: nameCtrl.text.trim(),
                  contact: contactCtrl.text.trim(),
                  address: addressCtrl.text.trim(),
                  b2c: b2cCtrl.text.trim(),
                  b2b: b2bCtrl.text.trim(),
                  remarks: remarksCtrl.text.trim(),
                );
                setState(() {
                  widget.customers.insert(0, newCust);
                  _selectedParty = newCust;
                  _partyTextCtrl.text = newCust.name;
                });
                widget.onSetSyncing(true);
                await http.post(
                  Uri.parse(sheetApiUrl),
                  body: jsonEncode({
                    "action": "ADD_CUSTOMER",
                    "name": newCust.name,
                    "contact": newCust.contact,
                    "address": newCust.address,
                    "b2c": newCust.b2c,
                    "b2b": newCust.b2b,
                    "remarks": newCust.remarks,
                  }),
                );
                widget.onSaved();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_rows.isNotEmpty) {
                    _rows[0].itemSearchFocus.requestFocus();
                  }
                });
              }
            },
            child: const Text('Save & Select', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _openInstantAddItemDialog(int rowIndex, String presetName) {
    final nameCtrl = TextEditingController(text: presetName);
    final rateCtrl = TextEditingController();
    final rateTypeCtrl = TextEditingController(text: 'RATE PER KG');
    final qtyCtrl = TextEditingController(text: '50');
    final tallyCtrl = TextEditingController();
    final billedCtrl = TextEditingController(text: 'KILOGRAM');
    bool isTaxable = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF131922),
          title: const Text('Instant Add Item (Alt + C)'),
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
                  TextField(controller: tallyCtrl, decoration: const InputDecoration(labelText: 'Item Name on Tally')),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: const Text('Taxable'),
                    value: isTaxable,
                    onChanged: (v) => setDialogState(() => isTaxable = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0052D4)),
              onPressed: () async {
                if (nameCtrl.text.trim().isNotEmpty) {
                  Navigator.pop(ctx);
                  final newItem = DCItem(
                    rowIndex: widget.items.length + 2,
                    no: widget.items.length + 1,
                    name: nameCtrl.text.trim(),
                    rateType: rateTypeCtrl.text.trim(),
                    rate: rateCtrl.text.trim(),
                    qty: qtyCtrl.text.trim(),
                    tallyName: tallyCtrl.text.trim(),
                    billedIn: billedCtrl.text.trim(),
                    isTaxable: isTaxable,
                  );
                  setState(() {
                    widget.items.insert(0, newItem);
                    _rows[rowIndex].item = newItem;
                    _rows[rowIndex].textCtrl.text = newItem.name;
                    _rows[rowIndex].rate = double.tryParse(newItem.rate) ?? 0.0;
                  });
                  widget.onSetSyncing(true);
                  await http.post(
                    Uri.parse(sheetApiUrl),
                    body: jsonEncode({
                      "action": "ADD_ITEM",
                      "name": newItem.name,
                      "rateType": newItem.rateType,
                      "rate": newItem.rate,
                      "qty": newItem.qty,
                      "tallyName": newItem.tallyName,
                      "billedIn": newItem.billedIn,
                      "isTaxable": newItem.isTaxable,
                    }),
                  );
                  widget.onSaved();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _rows[rowIndex].rateFocus.requestFocus();
                  });
                }
              },
              child: const Text('Save & Select', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
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
    final now = DateTime.now();
    final dateStr = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
    final summary = validRows.map((r) => "${r.item!.name} (${r.qty} ${r.unit} x ${r.rate}) [${r.bags}B]").join(", ");

    widget.onSetSyncing(true);

    final billNoToUse = isUpdating ? widget.invoiceToEdit!.slNo : widget.nextBillNo;

    await http.post(
      Uri.parse(sheetApiUrl),
      body: jsonEncode({
        "action": isUpdating ? "UPDATE_ESTIMATE" : "ADD_ESTIMATE",
        if (isUpdating) "rowIndex": widget.invoiceToEdit!.rowIndex,
        "slNo": billNoToUse,
        "date": isUpdating ? widget.invoiceToEdit!.date : dateStr,
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
      dateStr: isUpdating ? widget.invoiceToEdit!.date : dateStr,
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
        backgroundColor: const Color(0xFF131922),
        insetPadding: const EdgeInsets.all(20),
        child: SizedBox(
          width: 920,
          height: 720,
          child: Column(
            children: [
              AppBar(
                backgroundColor: const Color(0xFF0E141B),
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
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(isEditing ? 'Edit Customer Bill' : 'Customer Bill',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFF8FAFC))),
                const SizedBox(width: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isEditing ? Colors.orange.withOpacity(0.2) : const Color(0xFF18202B),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isEditing ? Colors.orangeAccent : const Color(0xFF263342)),
                  ),
                  child: Text(isEditing ? 'Editing Bill #${widget.invoiceToEdit!.slNo}' : 'Bill #${widget.nextBillNo}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isEditing ? Colors.orangeAccent : const Color(0xFF6FB1FC))),
                ),
                const SizedBox(width: 14),
                const Text('Ctrl + S / F8: Any-field Save  |  Alt + C: Instant Add',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                const Spacer(),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: Text(isEditing ? 'Cancel Edit' : 'Cancel Bill'),
                  onPressed: _clearBilling,
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0052D4),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.print, color: Colors.white, size: 18),
                  label: Text(isEditing ? 'Update & Print (Ctrl+S / F8)' : 'Save & Print (Ctrl+S / F8)',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: _saveInvoice,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Party Input
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF131922),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF263342)),
              ),
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
                          decoration: InputDecoration(
                            labelText: 'Party / Customer Name (Type & Arrow Navigate)',
                            hintText: 'Search customer...',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.person_add, size: 18),
                              tooltip: 'Instant Add Customer (Alt + C)',
                              onPressed: () {
                                _hidePartyOverlay();
                                _openInstantAddCustomerDialog(_partyTextCtrl.text.trim());
                              },
                            ),
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
                  const SizedBox(width: 14),
                  SizedBox(
                    width: 180,
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
            const SizedBox(height: 16),

            // Table Area
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF131922),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF263342)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        color: Color(0xFF18202B),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(width: 40, child: Text('No', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                          SizedBox(width: 12),
                          Expanded(flex: 5, child: Text('Name of Item', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                          SizedBox(width: 12),
                          SizedBox(width: 110, child: Text('Rate (₹)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                          SizedBox(width: 12),
                          SizedBox(width: 100, child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                          SizedBox(width: 12),
                          SizedBox(width: 90, child: Text('Unit (KG/NOS)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                          SizedBox(width: 12),
                          SizedBox(width: 80, child: Text('Bags', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                          SizedBox(width: 12),
                          SizedBox(width: 110, child: Text('Net Amount (₹)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                          SizedBox(width: 36),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFF263342)),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _rows.length,
                        separatorBuilder: (ctx, i) => const Divider(height: 12, color: Color(0xFF263342)),
                        itemBuilder: (ctx, idx) {
                          final row = _rows[idx];

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: SizedBox(width: 40, child: Text('${idx + 1}', style: const TextStyle(color: Color(0xFF94A3B8)))),
                              ),
                              const SizedBox(width: 12),
                              // Name of Item
                              Expanded(
                                flex: 5,
                                child: CompositedTransformTarget(
                                  link: row.layerLink,
                                  child: Focus(
                                    onKeyEvent: (node, event) => _handleItemKeyEvent(idx, node, event),
                                    child: TextField(
                                      controller: row.textCtrl,
                                      focusNode: row.itemSearchFocus,
                                      decoration: InputDecoration(
                                        hintText: 'Search item...',
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        suffixIcon: IconButton(
                                          icon: const Icon(Icons.add, size: 16),
                                          tooltip: 'Instant Add Item (Alt + C)',
                                          onPressed: () {
                                            _hideItemOverlay();
                                            _openInstantAddItemDialog(idx, row.textCtrl.text.trim());
                                          },
                                        ),
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
                              const SizedBox(width: 12),
                              // Rate
                              SizedBox(
                                width: 110,
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
                              const SizedBox(width: 12),
                              // Qty
                              SizedBox(
                                width: 100,
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
                              const SizedBox(width: 12),
                              // Unit Field
                              SizedBox(
                                width: 90,
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
                                          height: 48,
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF18202B),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: hasFocus ? const Color(0xFF1E88E5) : const Color(0xFF263342),
                                              width: hasFocus ? 1.5 : 1.0,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                row.unit,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: hasFocus ? const Color(0xFF6FB1FC) : Colors.white,
                                                ),
                                              ),
                                              const Icon(Icons.swap_vert, size: 16, color: Color(0xFF94A3B8)),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Bags
                              SizedBox(
                                width: 80,
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
                              const SizedBox(width: 12),
                              // Net Amount
                              Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: SizedBox(
                                  width: 110,
                                  child: Text(
                                    '₹${row.amount.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 36,
                                child: IconButton(
                                  icon: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
                                  onPressed: () => _removeRow(idx),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.add, size: 18, color: Color(0xFF1E88E5)),
                            label: const Text('+ Add Item Row (Enter on Bags)', style: TextStyle(color: Color(0xFF6FB1FC))),
                            onPressed: _addRow,
                          ),
                          const Spacer(),
                          Text('Total Bags in Bill: $_totalBags Bags',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6FB1FC))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Calculation Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF131922),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF263342)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 140,
                          child: TextField(
                            controller: _coolieCtrl,
                            focusNode: _coolieFocus,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Coolie (₹)'),
                            onChanged: (v) => setState(() {}),
                            onSubmitted: (_) => _saveInvoice(),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Inclusive Tax: ₹${_totalGst.toStringAsFixed(2)}',
                              style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Taxable Base: ₹${_taxableBaseAmount.toStringAsFixed(2)}',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _summaryLine('Total Item Value (Inc. Tax):', '₹${_grossItemsTotal.toStringAsFixed(2)}'),
                        if (_coolie > 0) _summaryLine('Coolie:', '₹${_coolie.toStringAsFixed(2)}'),
                        if (_sgst > 0) _summaryLine('Incl. SGST (2.5%):', '₹${_sgst.toStringAsFixed(2)}'),
                        if (_cgst > 0) _summaryLine('Incl. CGST (2.5%):', '₹${_cgst.toStringAsFixed(2)}'),
                        _summaryLine('Round Off:', '₹${_roundOff.toStringAsFixed(2)}'),
                        const Divider(height: 12, color: Color(0xFF263342)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Text('Grand Total: ',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                            Text('₹${_grandTotal.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF6FB1FC))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
          const SizedBox(width: 14),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}

// ---------------- 2. PRICE LIST VIEW ----------------

class PriceListDesktopView extends StatefulWidget {
  final List<DCItem> items;
  final List<DCEstimate> estimates;
  final VoidCallback onRefreshRequired;
  const PriceListDesktopView({
    super.key,
    required this.items,
    required this.estimates,
    required this.onRefreshRequired,
  });

  @override
  State<PriceListDesktopView> createState() => _PriceListDesktopViewState();
}

class _PriceListDesktopViewState extends State<PriceListDesktopView> {
  String _query = '';

  List<Map<String, dynamic>> _getItemBillHistory(String itemName) {
    List<Map<String, dynamic>> history = [];
    for (var est in widget.estimates) {
      if (est.status != 'CANCELLED' && est.itemSummary.toLowerCase().contains(itemName.toLowerCase())) {
        history.add({
          "billNo": est.slNo,
          "date": est.date,
          "customer": est.customer,
          "summary": est.itemSummary,
        });
      }
    }
    return history;
  }

  void _showItemPreviewModal(DCItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131922),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.analytics_outlined, color: Color(0xFF1E88E5)),
                  tooltip: 'Item Sales & Distribution Report',
                  onPressed: () => _openItemSalesReportModal(item),
                ),
                const SizedBox(width: 8),
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
          ],
        ),
        content: SizedBox(
          width: 580,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(color: Color(0xFF263342)),
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
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0052D4)),
            icon: const Icon(Icons.edit, size: 16, color: Colors.white),
            label: const Text('Edit Item Details', style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.pop(ctx);
              _openEditItemDialog(item: item);
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
        ],
      ),
    );
  }

  void _openItemSalesReportModal(DCItem item) {
    final history = _getItemBillHistory(item.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131922),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.assessment, color: Color(0xFF1E88E5)),
            const SizedBox(width: 10),
            Text('Sales Report • ${item.name}'),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Invoices Billed: ${history.length}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E88E5))),
              const SizedBox(height: 12),
              if (history.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No billed records found for this item.')))
              else
                Container(
                  constraints: const BoxConstraints(maxHeight: 260),
                  decoration: BoxDecoration(color: const Color(0xFF0E141B), borderRadius: BorderRadius.circular(8)),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: history.length,
                    separatorBuilder: (c, i) => const Divider(height: 1, color: Color(0xFF1E2833)),
                    itemBuilder: (c, i) {
                      final h = history[i];
                      return ListTile(
                        dense: true,
                        title: Text("${h['customer']} • Bill #${h['billNo']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("${h['date'].split('GMT')[0]} | ${h['summary']}", style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
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

  void _confirmDeleteItem(DCItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131922),
        title: const Text('Confirm Delete Item'),
        content: Text('Are you sure you want to permanently remove "${item.name}" from Google Sheet?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
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

    final fn1 = FocusNode();
    final fn2 = FocusNode();
    final fn3 = FocusNode();
    final fn4 = FocusNode();
    final fn5 = FocusNode();
    final fn6 = FocusNode();

    Future<void> submit() async {
      if (nameCtrl.text.trim().isNotEmpty) {
        Navigator.pop(context);
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
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF131922),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isNew ? 'Add New Item (Enter Jump Enabled)' : 'Edit Item (Enter Jump Enabled)'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    focusNode: fn1,
                    decoration: const InputDecoration(labelText: 'Item Name'),
                    onSubmitted: (_) => fn2.requestFocus(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: rateCtrl,
                          focusNode: fn2,
                          decoration: const InputDecoration(labelText: 'Rate (₹)'),
                          onSubmitted: (_) => fn3.requestFocus(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: rateTypeCtrl,
                          focusNode: fn3,
                          decoration: const InputDecoration(labelText: 'Rate Type'),
                          onSubmitted: (_) => fn4.requestFocus(),
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
                          focusNode: fn4,
                          decoration: const InputDecoration(labelText: 'Quantity'),
                          onSubmitted: (_) => fn5.requestFocus(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: billedCtrl,
                          focusNode: fn5,
                          decoration: const InputDecoration(labelText: 'Billed In'),
                          onSubmitted: (_) => fn6.requestFocus(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: tallyCtrl,
                    focusNode: fn6,
                    decoration: const InputDecoration(labelText: 'Item Name on Tally'),
                    onSubmitted: (_) => submit(),
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
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0052D4)),
              onPressed: submit,
              child: Text(isNew ? 'Save to Sheet (Enter)' : 'Update Sheet (Enter)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
          SizedBox(width: 160, child: Text(title, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14))),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              val,
              softWrap: true,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isColor ? const Color(0xFF6FB1FC) : Colors.white,
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

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(CompanyConfig.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('PRICE LIST (${widget.items.length} ITEMS)', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: 300,
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search, size: 20), hintText: 'Search items...'),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0052D4), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                label: const Text('Add Item', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () => _openEditItemDialog(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 12),
              itemBuilder: (ctx, idx) {
                final item = filtered[idx];
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _showItemPreviewModal(item),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131922),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF263342)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFF18202B),
                          child: Text('${item.no}', style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, letterSpacing: 0.3)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text('₹${item.rate}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF6FB1FC))),
                                  const SizedBox(width: 8),
                                  Text('(${item.rateType})', style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                                  const SizedBox(width: 14),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF18202B),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF263342)),
                                    ),
                                    child: Text(
                                      item.isTaxable ? 'TAXABLE (5%)' : 'NON-TAXABLE',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: item.isTaxable ? Colors.orangeAccent : const Color(0xFF94A3B8)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('Tally: ${item.tallyName}  |  Pack: ${item.qty}  |  Unit: ${item.billedIn}', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_note, color: Color(0xFF1E88E5), size: 24),
                          tooltip: 'Edit Item',
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
  final List<DCEstimate> estimates;
  final VoidCallback onRefreshRequired;
  const CustomerDesktopView({
    super.key,
    required this.customers,
    required this.estimates,
    required this.onRefreshRequired,
  });

  @override
  State<CustomerDesktopView> createState() => _CustomerDesktopViewState();
}

class _CustomerDesktopViewState extends State<CustomerDesktopView> {
  String _query = '';

  List<DCEstimate> _getCustomerPurchaseHistory(String custName) {
    return widget.estimates.where((e) {
      return e.status != 'CANCELLED' && e.customer.toLowerCase().trim() == custName.toLowerCase().trim();
    }).toList();
  }

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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 1.0),
      ),
      child: Text(
        tag,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: text, letterSpacing: 0.5),
      ),
    );
  }

  void _showCustomerPreviewModal(DCCustomer customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131922),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20))),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.analytics_outlined, color: Color(0xFF1E88E5)),
                  tooltip: 'Customer Ledger & Purchase Report',
                  onPressed: () => _openCustomerLedgerReportModal(customer),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                  icon: const Icon(Icons.person_remove, size: 18),
                  label: const Text('Delete Customer'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _confirmDeleteCustomer(customer);
                  },
                ),
              ],
            ),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(color: Color(0xFF263342)),
              _buildCustomerModalRow('Customer Name:', customer.name),
              _buildCustomerModalRow('Contact Number:', customer.contact.isEmpty ? '-' : customer.contact),
              _buildCustomerModalRow('Address:', customer.address.isEmpty ? '-' : customer.address),
              _buildCustomerModalRow('B2B Firm Name:', customer.b2b.isEmpty ? '-' : customer.b2b, isHighlight: true),
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
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0052D4)),
            icon: const Icon(Icons.edit, size: 16, color: Colors.white),
            label: const Text('Edit Customer Details', style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.pop(ctx);
              _openEditCustomerDialog(customer: customer);
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
        ],
      ),
    );
  }

  void _openCustomerLedgerReportModal(DCCustomer customer) {
    final history = _getCustomerPurchaseHistory(customer.name);
    double totalSpent = history.fold(0.0, (sum, e) => sum + (double.tryParse(e.grandTotal) ?? 0.0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131922),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.assessment, color: Color(0xFF1E88E5)),
            const SizedBox(width: 10),
            Text('Purchase Ledger • ${customer.name}'),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Invoices: ${history.length}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E88E5))),
                  Text('Cumulative Value: ₹${totalSpent.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))),
                ],
              ),
              const SizedBox(height: 12),
              if (history.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No purchase records found for this customer.')))
              else
                Container(
                  constraints: const BoxConstraints(maxHeight: 280),
                  decoration: BoxDecoration(color: const Color(0xFF0E141B), borderRadius: BorderRadius.circular(8)),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: history.length,
                    separatorBuilder: (c, i) => const Divider(height: 1, color: Color(0xFF1E2833)),
                    itemBuilder: (c, i) {
                      final h = history[i];
                      return ListTile(
                        dense: true,
                        title: Text("Bill #${h.slNo} • ₹${h.grandTotal}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6FB1FC))),
                        subtitle: Text("${h.date.split('GMT')[0]} | ${h.itemSummary}", style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
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

  void _confirmDeleteCustomer(DCCustomer customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131922),
        title: const Text('Confirm Delete Customer'),
        content: Text('Are you sure you want to permanently delete party "${customer.name}" from Google Sheet?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
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

    final fn1 = FocusNode();
    final fn2 = FocusNode();
    final fn3 = FocusNode();
    final fn4 = FocusNode();
    final fn5 = FocusNode();
    final fn6 = FocusNode();

    Future<void> submit() async {
      if (nameCtrl.text.trim().isNotEmpty) {
        Navigator.pop(context);
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
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131922),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isNew ? 'Add Customer (Enter Jump Enabled)' : 'Edit Customer (Enter Jump Enabled)'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  focusNode: fn1,
                  decoration: const InputDecoration(labelText: 'Party Name'),
                  onSubmitted: (_) => fn2.requestFocus(),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: contactCtrl,
                        focusNode: fn2,
                        decoration: const InputDecoration(labelText: 'Contact'),
                        onSubmitted: (_) => fn3.requestFocus(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: addressCtrl,
                        focusNode: fn3,
                        decoration: const InputDecoration(labelText: 'Address'),
                        onSubmitted: (_) => fn4.requestFocus(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: b2bCtrl,
                  focusNode: fn4,
                  decoration: const InputDecoration(labelText: 'B2B Trade Name'),
                  onSubmitted: (_) => fn5.requestFocus(),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: b2cCtrl,
                  focusNode: fn5,
                  decoration: const InputDecoration(labelText: 'B2C Reference'),
                  onSubmitted: (_) => fn6.requestFocus(),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: remarksCtrl,
                  focusNode: fn6,
                  decoration: const InputDecoration(labelText: 'Remarks / Delivery Rules'),
                  onSubmitted: (_) => submit(),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0052D4)),
            onPressed: submit,
            child: Text(isNew ? 'Save to Sheet (Enter)' : 'Update Sheet (Enter)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerModalRow(String title, String val, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 150, child: Text(title, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14))),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              val,
              softWrap: true,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: isHighlight ? const Color(0xFF6FB1FC) : Colors.white,
                height: 1.3,
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
          c.b2c.toLowerCase().contains(_query.toLowerCase()) ||
          c.contact.contains(_query);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CUSTOMERS DIRECTORY', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('TOTAL ${widget.customers.length} PARTIES', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: 300,
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search, size: 20), hintText: 'Search customer name...'),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0052D4), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                icon: const Icon(Icons.person_add, color: Colors.white, size: 18),
                label: const Text('Add Customer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () => _openEditCustomerDialog(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final c = filtered[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _showCustomerPreviewModal(c),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131922),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF263342)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFF18202B),
                          child: Text('${c.slNo}', style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    c.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, letterSpacing: 0.3),
                                  ),
                                  const SizedBox(width: 12),
                                  _buildTagChip(c.billingTag),
                                ],
                              ),
                              const SizedBox(height: 6),
                              if (c.b2b.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text('B2B: ${c.b2b}', style: const TextStyle(fontSize: 13, color: Color(0xFF60A5FA), fontWeight: FontWeight.w500)),
                                ),
                              if (c.b2c.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    'B2C: ${c.b2c}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF38BDF8),
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              if (c.contact.isNotEmpty || c.address.isNotEmpty)
                                Text('📞 ${c.contact.isNotEmpty ? c.contact : "-"}  |  📍 ${c.address.isNotEmpty ? c.address : "-"}',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_note, color: Color(0xFF1E88E5), size: 24),
                          tooltip: 'Edit Customer',
                          onPressed: () => _openEditCustomerDialog(customer: c),
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

  DateTime? _parseSheetDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    try {
      if (dateStr.contains('/')) {
        final p = dateStr.split('/');
        if (p.length >= 3) {
          return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
        }
      }
      return DateTime.tryParse(dateStr);
    } catch (e) {
      return null;
    }
  }

  List<Map<String, dynamic>> _parseSummaryTable(String summary) {
    List<Map<String, dynamic>> rows = [];
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
        } catch (e) {}

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
        backgroundColor: const Color(0xFF131922),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      color: isCancelled ? Colors.redAccent : const Color(0xFF6FB1FC),
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
                    Text('Party: ${est.customer}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                    Text('Date: ${est.date.split("GMT")[0]}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E141B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF263342)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: const BoxDecoration(
                          color: Color(0xFF18202B),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                        ),
                        child: const Row(
                          children: [
                            SizedBox(width: 35, child: Text('No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF94A3B8)))),
                            Expanded(flex: 5, child: Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF94A3B8)))),
                            SizedBox(width: 80, child: Text('Rate (₹)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF94A3B8)))),
                            SizedBox(width: 60, child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF94A3B8)))),
                            SizedBox(width: 60, child: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF94A3B8)))),
                            SizedBox(width: 60, child: Text('Bags', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF94A3B8)))),
                            SizedBox(width: 90, child: Text('Amount (₹)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF94A3B8)))),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFF263342)),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(12),
                        itemCount: parsedRows.length,
                        separatorBuilder: (c, i) => const Divider(height: 10, color: Color(0xFF1E2833)),
                        itemBuilder: (c, i) {
                          final r = parsedRows[i];
                          return Row(
                            children: [
                              SizedBox(width: 35, child: Text('${i + 1}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13))),
                              Expanded(flex: 5, child: Text(r['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                              SizedBox(width: 80, child: Text('₹${r['rate']}', style: const TextStyle(fontSize: 13))),
                              SizedBox(width: 60, child: Text(r['qty'], style: const TextStyle(fontSize: 13))),
                              SizedBox(width: 60, child: Text(r['unit'], style: const TextStyle(fontSize: 13, color: Color(0xFF6FB1FC)))),
                              SizedBox(width: 60, child: Text(r['bags'], style: const TextStyle(fontSize: 13))),
                              SizedBox(width: 90, child: Text('₹${r['amount']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF38BDF8)))),
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
                    Text('Coolie Charges: ₹${est.coolie}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                    Text('SGST (2.5%): ₹${est.sgst}  |  CGST (2.5%): ₹${est.cgst}', style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 13)),
                    Text('Round Off: ₹${est.roundOff}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('Grand Total: ₹${est.grandTotal}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF6FB1FC))),
                ),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0052D4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            icon: const Icon(Icons.print, size: 16, color: Colors.white),
            label: const Text('Print / View PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              _printHistoryInvoice(context, est);
            },
          ),
          if (!isCancelled)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1E88E5),
                side: const BorderSide(color: Color(0xFF1E88E5)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              icon: const Icon(Icons.edit_document, size: 16),
              label: const Text('Edit Invoice'),
              onPressed: () {
                Navigator.pop(ctx);
                widget.onEditInvoice(est);
              },
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
        ],
      ),
    );
  }

  void _confirmCancelDialog(BuildContext context, DCEstimate est) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131922),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Text('Cancel Confirmation'),
          ],
        ),
        content: Text('Are you sure you want to CANCEL Invoice #${est.slNo} (${est.customer})?\n\nYES: Cancel Bill\nNO: Back to Details'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('NO (Back)', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
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
            child: const Text('YES (Cancel Bill)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
        parsedItems.add(
          InvoiceRowItem(
            item: DCItem(
              rowIndex: 0,
              no: 1,
              name: part.trim(),
              rateType: 'KG',
              rate: '0',
              qty: 1,
              tallyName: '',
              billedIn: '',
              isTaxable: false,
            ),
            rate: double.tryParse(est.grandTotal) ?? 0,
            qty: 1,
            unit: 'KG',
            bags: 1,
          ),
        );
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF131922),
        insetPadding: const EdgeInsets.all(20),
        child: SizedBox(
          width: 920,
          height: 720,
          child: Column(
            children: [
              AppBar(
                backgroundColor: const Color(0xFF0E141B),
                title: Text('Invoice #${est.slNo} - Tally Print View'),
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
                    dateStr: est.date.split("GMT")[0].trim(),
                    customer: matchedCustomer,
                    items: parsedItems,
                    subTotal: double.tryParse(est.grandTotal) ?? 0,
                    coolie: double.tryParse(est.coolie) ?? 0,
                    sgst: double.tryParse(est.sgst) ?? 0,
                    cgst: double.tryParse(est.cgst) ?? 0,
                    roundOff: double.tryParse(est.roundOff) ?? 0,
                    grandTotal: double.tryParse(est.grandTotal) ?? 0,
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

    final sortedEstimates = List<DCEstimate>.from(widget.estimates.reversed);

    final filtered = sortedEstimates.where((e) {
      final eDate = _parseSheetDate(e.date);
      if (eDate == null) {
        final nowStr = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
        if (_selectedFilter == 'TODAY') return e.date.contains(nowStr);
        return true;
      }

      final checkDay = DateTime(eDate.year, eDate.month, eDate.day);

      if (_selectedFilter == 'TODAY') {
        return checkDay.isAtSameMomentAs(today);
      } else if (_selectedFilter == 'YESTERDAY') {
        return checkDay.isAtSameMomentAs(yesterday);
      } else if (_selectedFilter == 'CUSTOM' && _customDateRange != null) {
        return (checkDay.isAfter(_customDateRange!.start.subtract(const Duration(days: 1))) &&
            checkDay.isBefore(_customDateRange!.end.add(const Duration(days: 1))));
      }
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('INVOICE HISTORY', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('${filtered.length} INVOICES (NEWEST FIRST)', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                ],
              ),
              const Spacer(),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'ALL', label: Text('All')),
                  ButtonSegment(value: 'TODAY', label: Text('Today')),
                  ButtonSegment(value: 'YESTERDAY', label: Text('Yesterday')),
                  ButtonSegment(value: 'CUSTOM', label: Text('Custom Date')),
                ],
                selected: {_selectedFilter},
                onSelectionChanged: (val) async {
                  final chosen = val.first;
                  if (chosen == 'CUSTOM') {
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
                    setState(() {
                      _selectedFilter = chosen;
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No invoice history logged for this period.', style: TextStyle(color: Color(0xFF94A3B8))))
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                    itemBuilder: (ctx, idx) {
                      final est = filtered[idx];
                      final isCancelled = est.status == 'CANCELLED';

                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _showInvoiceDetails(context, est),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFF131922),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: isCancelled ? Colors.redAccent.withOpacity(0.4) : const Color(0xFF263342)),
                          ),
                          child: Row(
                            children: [
                              Text('#${est.slNo}',
                                  style: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(est.customer,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              decoration: isCancelled ? TextDecoration.lineThrough : null,
                                            )),
                                        const SizedBox(width: 10),
                                        Text('(${est.date.split("GMT")[0].trim()})',
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                                        if (isCancelled) ...[
                                          const SizedBox(width: 10),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text('CANCELLED',
                                                style: TextStyle(
                                                    color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(est.itemSummary,
                                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                                  ],
                                ),
                              ),
                              Text('₹${est.grandTotal}',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: isCancelled ? Colors.grey : const Color(0xFF6FB1FC))),
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
          backgroundColor: const Color(0xFF131922),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add to Packing Slip'),
          content: SizedBox(
            width: 500,
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
                  const SizedBox(height: 12),
                  TextField(controller: placeCtrl, decoration: const InputDecoration(labelText: 'Place (സ്ഥലം)')),
                  const SizedBox(height: 12),
                  TextField(
                    controller: summaryCtrl,
                    decoration: const InputDecoration(labelText: 'Item Summary (ഉദാ: Sadhya Vadi 5, Priyam 5)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bagsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Total Nos of Bags (ചാക്ക്)'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0052D4)),
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
              child: const Text('Save to Sheet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _copySlipToClipboard() {
    final buffer = StringBuffer();
    buffer.writeln("--- SP MULTIBILL PACKING SLIP ---");
    int total = 0;
    for (int i = 0; i < widget.loadingSlip.length; i++) {
      final e = widget.loadingSlip[i];
      total += e.bags;
      buffer.writeln("${i + 1}. ${e.customerName} (${e.place}) : ${e.summary} - ${e.bags} Bags");
    }
    buffer.writeln("TOTAL BAGS: $total");

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Packing slip copied to clipboard!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalBags = widget.loadingSlip.fold(0, (sum, entry) => sum + entry.bags);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('PACKING / LOADING SLIP', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('LINKED DIRECTLY TO GOOGLE SHEET', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF18202B), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy Slip'),
                onPressed: widget.loadingSlip.isEmpty ? null : _copySlipToClipboard,
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0052D4), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                label: const Text('Add Entry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: _openAddPackingSlipDialog,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: widget.loadingSlip.isEmpty
                ? const Center(child: Text('No entries added yet. Tap "Add Entry" to create a slip.', style: TextStyle(color: Color(0xFF94A3B8))))
                : ListView.separated(
                    itemCount: widget.loadingSlip.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                    itemBuilder: (ctx, idx) {
                      final entry = widget.loadingSlip[idx];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131922),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF263342)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(0xFF18202B),
                              child: Text('${idx + 1}', style: const TextStyle(color: Color(0xFF94A3B8))),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(entry.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      if (entry.place.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: const Color(0xFF18202B), borderRadius: BorderRadius.circular(4)),
                                          child: Text(entry.place, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(entry.summary, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                                ],
                              ),
                            ),
                            Text('${entry.bags} Bags', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF6FB1FC))),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Color(0xFF64748B)),
                              onPressed: () {
                                setState(() {
                                  widget.loadingSlip.removeAt(idx);
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF131922),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF263342)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL DISPATCH LOAD:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('$totalBags BAGS', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF6FB1FC))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- 6. SETTINGS VIEW ----------------

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
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SYSTEM SETTINGS & SUPPORT', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const Text('Configure SP MultiBill ERP & Technical Support', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: [
                _buildSectionHeader('Company & Header Setup (Google Sheets Linked)'),
                _buildCard(
                  title: 'Firm Details & GST Settings',
                  subtitle: '${CompanyConfig.name} • ${CompanyConfig.gstin}',
                  icon: Icons.storefront,
                  actionText: 'Configure Header',
                  onTap: onOpenProfile,
                ),
                const SizedBox(height: 20),
                _buildSectionHeader('Backend & Sheet Sync'),
                _buildCard(
                  title: 'Google Apps Script Webhook',
                  subtitle: sheetApiUrl,
                  icon: Icons.sync_alt,
                  actionText: 'Force Reload',
                  onTap: () {
                    onReloadSheet();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Syncing data with Google Sheets...')),
                    );
                  },
                ),
                const SizedBox(height: 20),
                _buildSectionHeader('Developer & Technical Support'),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131922),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF263342)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: Color(0xFF0052D4),
                            child: Icon(Icons.support_agent, color: Colors.white, size: 24),
                          ),
                          SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('SP Tech Solutions', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                              Text('Enterprise Software Systems & Custom ERP Solutions', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Color(0xFF263342)),
                      const SizedBox(height: 10),
                      _supportRow('Developer Email', 'sudheeshpunnikrishnan@gmail.com'),
                      _supportRow('Application Suite', 'SP MultiBill ERP (Desktop 64-bit Engine)'),
                      _supportRow('Release Version', 'v3.5.0 (Windows Native Build)'),
                      _supportRow('Target Framework', 'Flutter 3.x (Runner x64)'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF6FB1FC))),
    );
  }

  Widget _buildCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String actionText,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF131922),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF263342)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1E88E5), size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF18202B),
              side: const BorderSide(color: Color(0xFF263342)),
            ),
            onPressed: onTap,
            child: Text(actionText, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _supportRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 160, child: Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFF8FAFC)))),
        ],
      ),
    );
  }
}
