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
  runApp(const DCPrimeApp());
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

// ---------------- TOP-LEVEL PDF GENERATOR ----------------

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

// ---------------- APP ROOT ----------------

class DCPrimeApp extends StatelessWidget {
  const DCPrimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Davis & Company - DC Prime Desktop',
      scrollBehavior: UltraSmoothScrollBehavior(),
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B1015),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF10B981),
          secondary: Color(0xFF3B82F6),
          tertiary: Color(0xFF8B5CF6),
          surface: Color(0xFF131922),
          onSurface: Color(0xFFF8FAFC),
        ),
        navigationRailTheme: const NavigationRailThemeData(
          backgroundColor: Color(0xFF0E141B),
          indicatorColor: Color(0xFF10B981),
          selectedIconTheme: IconThemeData(color: Colors.white, size: 22),
          unselectedIconTheme: IconThemeData(color: Color(0xFF94A3B8), size: 22),
          selectedLabelTextStyle: TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelTextStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF18202B),
          border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF263342))),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF263342))),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF34D399), width: 1.5)),
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
              Icon(Icons.business, color: Color(0xFF10B981)),
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
                            side: const BorderSide(color: Color(0xFF10B981)),
                            foregroundColor: const Color(0xFF34D399),
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
                backgroundColor: const Color(0xFF059669),
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
                  gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFF3B82F6)]),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF10B981).withOpacity(0.35), blurRadius: 28, spreadRadius: 4),
                  ],
                ),
                child: const Text('DC', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(height: 24),
              const Text('DC PRIME DESKTOP',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Color(0xFFF8FAFC))),
              const SizedBox(height: 6),
              const Text('DEVELOPED BY SUDHEESH',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.5, color: Color(0xFF34D399))),
              const SizedBox(height: 4),
              const Text('Wholesale Rice Merchants Suite • v3.0.0',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              const SizedBox(height: 32),
              const SizedBox(
                width: 150,
                child: LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: Color(0xFF131922),
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
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
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
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
                                  gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFF3B82F6)]),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text('DC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white)),
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

// ---------------- CUSTOMERS VIEW (CLEAN TAGS & HIGHLIGHTED B2C) ----------------

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

  // Tag styling helper based on tag type
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
                  icon: const Icon(Icons.analytics_outlined, color: Color(0xFF3B82F6)),
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
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
            const Icon(Icons.assessment, color: Color(0xFF38BDF8)),
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
                  Text('Total Invoices: ${history.length}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF34D399))),
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
                        title: Text("Bill #${h.slNo} • ₹${h.grandTotal}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF34D399))),
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
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
                color: isHighlight ? const Color(0xFF34D399) : Colors.white,
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
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
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
                                  // Clean Color Coded Tag Chip
                                  _buildTagChip(c.billingTag),
                                ],
                              ),
                              const SizedBox(height: 6),
                              if (c.b2b.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text('B2B: ${c.b2b}', style: const TextStyle(fontSize: 13, color: Color(0xFF60A5FA), fontWeight: FontWeight.w500)),
                                ),
                              // Prominent High-Contrast B2C Name
                              if (c.b2c.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    'B2C: ${c.b2c}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF38BDF8), // Bright Sky Blue Glow
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
                          icon: const Icon(Icons.edit_note, color: Color(0xFF34D399), size: 24),
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

// ---------------- PACKING SLIP VIEW ----------------

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
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
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
    buffer.writeln("--- DAVIS & COMPANY PACKING SLIP ---");
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
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
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
                            Text('${entry.bags} Bags', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF34D399))),
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
                Text('$totalBags BAGS', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF34D399))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- SETTINGS VIEW ----------------

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
          const Text('Configure DC Prime Billing & Developer Support', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
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
                            backgroundColor: Color(0xFF059669),
                            child: Icon(Icons.support_agent, color: Colors.white, size: 24),
                          ),
                          SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Sudheesh P Unnikrishnan', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                              Text('Software Architect & Desktop Systems Engineer', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Color(0xFF263342)),
                      const SizedBox(height: 10),
                      _supportRow('Developer Email', 'sudheeshpunnikrishnan@gmail.com'),
                      _supportRow('Application Suite', 'DC Prime Desktop (TallyPrime Workflow Edition)'),
                      _supportRow('Release Version', 'v3.0.0 (Desktop 64-bit Build)'),
                      _supportRow('Target Framework', 'Flutter 3.x (Windows Runner)'),
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
      child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF34D399))),
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
          Icon(icon, color: const Color(0xFF34D399), size: 28),
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
