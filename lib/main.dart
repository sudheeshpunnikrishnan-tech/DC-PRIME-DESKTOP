import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() {
  runApp(const DCPrimeApp());
}

const String sheetApiUrl =
    "https://script.google.com/macros/s/AKfycbzFDW5eeT4abGSRNLHlKs43JJ81YiKt0UrNEbbK2_cQIylsU_zGylqE8IMBqtpmXsjOEg/exec";

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
  final dynamic slNo;
  final String date;
  final String customer;
  final String itemSummary;
  final String coolie;
  final String sgst;
  final String cgst;
  final String roundOff;
  final String grandTotal;

  DCEstimate({
    required this.slNo,
    required this.date,
    required this.customer,
    required this.itemSummary,
    required this.coolie,
    required this.sgst,
    required this.cgst,
    required this.roundOff,
    required this.grandTotal,
  });

  factory DCEstimate.fromJson(Map<String, dynamic> json) {
    return DCEstimate(
      slNo: json['slNo'] ?? '',
      date: json['date'] ?? '',
      customer: json['customer'] ?? '',
      itemSummary: json['itemSummary'] ?? '',
      coolie: json['coolie']?.toString() ?? '0',
      sgst: json['sgst']?.toString() ?? '0',
      cgst: json['cgst']?.toString() ?? '0',
      roundOff: json['roundOff']?.toString() ?? '0',
      grandTotal: json['grandTotal']?.toString() ?? '0',
    );
  }
}

class InvoiceRowItem {
  DCItem? item;
  double qty;
  double rate;

  InvoiceRowItem({this.item, this.qty = 1.0, this.rate = 0.0});

  double get amount => qty * rate;
}

// ---------------- APP ROOT ----------------

class DCPrimeApp extends StatelessWidget {
  const DCPrimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Davis & Company - Tally Billing',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF111418),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3B82F6),
          surface: Color(0xFF1A1F26),
          onSurface: Color(0xFFE2E8F0),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF1E242C),
          border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF333D4B))),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF2C3540))),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF64748B))),
          labelStyle: TextStyle(color: Color(0xFF94A3B8)),
        ),
      ),
      home: const MainDashboard(),
    );
  }
}

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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(Uri.parse(sheetApiUrl));
      if (res.statusCode == 200 || res.statusCode == 302) {
        final data = jsonDecode(res.body);
        final List itemList = data['items'] ?? [];
        final List custList = data['customers'] ?? [];
        final List estList = data['estimates'] ?? [];

        setState(() {
          _items = itemList.map((i) => DCItem.fromJson(i)).toList();
          _customers = custList.map((c) => DCCustomer.fromJson(c)).toList();
          _estimates = estList.map((e) => DCEstimate.fromJson(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _navigateTo(int index) {
    setState(() => _navIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: const Color(0xFF14181F),
            selectedIndex: _navIndex > 2 ? 0 : _navIndex,
            onDestinationSelected: (val) => setState(() => _navIndex = val),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('DC',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF64748B)),
              tooltip: 'Reload from Google Sheet',
              onPressed: _fetchData,
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.receipt_outlined),
                selectedIcon: Icon(Icons.receipt),
                label: Text('Tally Invoice'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: Text('History'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: Text('Directory'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1, color: Color(0xFF242C37)),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : IndexedStack(
                    index: _navIndex,
                    children: [
                      TallyBillingScreen(
                        items: _items,
                        customers: _customers,
                        onSaved: _fetchData,
                      ),
                      InvoiceHistoryView(estimates: _estimates),
                      HomeDirectoryView(
                        itemCount: _items.length,
                        customerCount: _customers.length,
                        onOpenPriceList: () => _navigateTo(3),
                        onOpenCustomers: () => _navigateTo(4),
                      ),
                      PriceListDesktopView(
                        items: _items,
                        onBack: () => _navigateTo(2),
                        onRefreshRequired: _fetchData,
                      ),
                      CustomerDesktopView(
                        customers: _customers,
                        onBack: () => _navigateTo(2),
                        onRefreshRequired: _fetchData,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------- 1. TALLY PRIME BILLING SCREEN ----------------

class TallyBillingScreen extends StatefulWidget {
  final List<DCItem> items;
  final List<DCCustomer> customers;
  final VoidCallback onSaved;

  const TallyBillingScreen({
    super.key,
    required this.items,
    required this.customers,
    required this.onSaved,
  });

  @override
  State<TallyBillingScreen> createState() => _TallyBillingScreenState();
}

class _TallyBillingScreenState extends State<TallyBillingScreen> {
  final _billNoCtrl = TextEditingController(text: '51942');
  final _refCtrl = TextEditingController(text: '75');
  final _coolieCtrl = TextEditingController(text: '0.00');
  String _invoiceType = 'Regular B2C';
  DCCustomer? _selectedParty;

  final List<InvoiceRowItem> _rows = [];

  @override
  void initState() {
    super.initState();
    _addRow();
  }

  void _addRow() {
    setState(() {
      _rows.add(InvoiceRowItem(item: null, qty: 1.0, rate: 0.0));
    });
  }

  void _removeRow(int idx) {
    if (_rows.length > 1) {
      setState(() {
        _rows.removeAt(idx);
      });
    }
  }

  double get _subTotal => _rows.fold(0.0, (sum, r) => sum + r.amount);

  double get _taxableAmount {
    double sum = 0.0;
    for (var r in _rows) {
      if (r.item != null && r.item!.isTaxable) {
        sum += r.amount;
      }
    }
    return sum;
  }

  double get _sgst => _taxableAmount * 0.025;
  double get _cgst => _taxableAmount * 0.025;
  double get _coolie => double.tryParse(_coolieCtrl.text.trim()) ?? 0.0;

  double get _exactTotal => _subTotal + _sgst + _cgst + _coolie;
  double get _grandTotal => _exactTotal.roundToDouble();
  double get _roundOff => _grandTotal - _exactTotal;

  Future<void> _saveInvoice() async {
    if (_selectedParty == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Party / Customer')),
      );
      return;
    }

    final now = DateTime.now();
    final dateStr = "${now.day}/${now.month}/${now.year}";
    final summary = _rows
        .where((r) => r.item != null)
        .map((r) => "${r.item!.name} (${r.qty}x${r.rate})")
        .join(", ");

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saving invoice to Google Sheets...')),
    );

    await http.post(
      Uri.parse(sheetApiUrl),
      body: jsonEncode({
        "action": "ADD_ESTIMATE",
        "date": dateStr,
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
    _showPrintDialog(dateStr);
  }

  void _showPrintDialog(String dateStr) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E242C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Invoice Saved Successfully'),
        content: const Text('Would you like to print or save the PDF Invoice now?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
            ),
            icon: const Icon(Icons.print, size: 18),
            label: const Text('Print / Export PDF'),
            onPressed: () {
              Navigator.pop(ctx);
              _generateAndPrintPdf(dateStr);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _generateAndPrintPdf(String dateStr) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text("DAVIS & COMPANY",
                      style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Center(
                  child: pw.Text("WHOLESALE RICE MERCHANTS - ALUVA",
                      style: const pw.TextStyle(fontSize: 11)),
                ),
                pw.SizedBox(height: 16),
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Bill No: ${_billNoCtrl.text}"),
                    pw.Text("Date: $dateStr"),
                  ],
                ),
                pw.Text("Party Name: ${_selectedParty?.name ?? ''}"),
                if (_selectedParty?.b2b.isNotEmpty ?? false)
                  pw.Text("B2B Firm: ${_selectedParty?.b2b ?? ''}"),
                pw.SizedBox(height: 12),
                pw.TableHelper.fromTextArray(
                  headers: ['No', 'Item Name', 'Rate', 'Qty', 'Amount'],
                  data: _rows.where((r) => r.item != null).map((r) {
                    final idx = _rows.indexOf(r) + 1;
                    return [
                      '$idx',
                      r.item!.name,
                      r.rate.toStringAsFixed(2),
                      r.qty.toStringAsFixed(0),
                      r.amount.toStringAsFixed(2),
                    ];
                  }).toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellAlignment: pw.Alignment.centerLeft,
                ),
                pw.Divider(),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("Sub Total: Rs ${_subTotal.toStringAsFixed(2)}"),
                      pw.Text("Coolie: Rs ${_coolie.toStringAsFixed(2)}"),
                      if (_sgst > 0) pw.Text("SGST (2.5%): Rs ${_sgst.toStringAsFixed(2)}"),
                      if (_cgst > 0) pw.Text("CGST (2.5%): Rs ${_cgst.toStringAsFixed(2)}"),
                      pw.Text("Round Off: Rs ${_roundOff.toStringAsFixed(2)}"),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        "Grand Total: Rs ${_grandTotal.toStringAsFixed(2)}",
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
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

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            children: [
              const Text('Customer Bill',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE2E8F0))),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.save, color: Colors.white, size: 18),
                label: const Text('Save & Print',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: _saveInvoice,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tally Meta Fields Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF242C37)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: _billNoCtrl,
                    decoration: const InputDecoration(labelText: 'Bill No'),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<DCCustomer>(
                    value: _selectedParty,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Party Name'),
                    items: widget.customers
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(
                                c.name + (c.b2b.isNotEmpty ? ' (${c.b2b})' : ''),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedParty = v),
                  ),
                ),
                const SizedBox(width: 14),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _refCtrl,
                    decoration: const InputDecoration(labelText: 'Ref'),
                  ),
                ),
                const SizedBox(width: 14),
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
          const SizedBox(height: 16),

          // Tally Grid Table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF242C37)),
              ),
              child: Column(
                children: [
                  // Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E242C),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(width: 40, child: Text('No', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                        SizedBox(width: 16),
                        Expanded(flex: 4, child: Text('Name of Item', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                        SizedBox(width: 16),
                        Expanded(flex: 2, child: Text('Rate (₹)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                        SizedBox(width: 16),
                        Expanded(flex: 2, child: Text('Qty (Bags)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                        SizedBox(width: 16),
                        Expanded(flex: 2, child: Text('Net Amount (₹)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                        SizedBox(width: 40),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFF242C37)),

                  // Rows List
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _rows.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 12, color: Color(0xFF242C37)),
                      itemBuilder: (ctx, idx) {
                        final row = _rows[idx];
                        return Row(
                          children: [
                            SizedBox(width: 40, child: Text('${idx + 1}', style: const TextStyle(color: Color(0xFF94A3B8)))),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 4,
                              child: DropdownButtonFormField<DCItem>(
                                value: row.item,
                                isExpanded: true,
                                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                hint: const Text('Select item...'),
                                items: widget.items
                                    .map((item) => DropdownMenuItem(
                                          value: item,
                                          child: Text(item.name, overflow: TextOverflow.ellipsis),
                                        ))
                                    .toList(),
                                onChanged: (v) {
                                  setState(() {
                                    row.item = v;
                                    row.rate = double.tryParse(v?.rate ?? '0') ?? 0.0;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                key: ValueKey('rate_${row.item?.name}_$idx'),
                                initialValue: row.rate.toStringAsFixed(2),
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                onChanged: (val) {
                                  setState(() {
                                    row.rate = double.tryParse(val) ?? 0.0;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                initialValue: row.qty.toStringAsFixed(0),
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                onChanged: (val) {
                                  setState(() {
                                    row.qty = double.tryParse(val) ?? 1.0;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '₹${row.amount.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                            SizedBox(
                              width: 40,
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
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('+ Add Item Row'),
                        onPressed: _addRow,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Tally Summary & Auto-Calculation Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF242C37)),
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
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Coolie (₹)'),
                          onChanged: (v) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Text(
                        'Taxable Subtotal: ₹${_taxableAmount.toStringAsFixed(2)}',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _summaryLine('Sub Total:', '₹${_subTotal.toStringAsFixed(2)}'),
                      if (_coolie > 0) _summaryLine('Coolie:', '₹${_coolie.toStringAsFixed(2)}'),
                      if (_sgst > 0) _summaryLine('SGST @ 2.5%:', '₹${_sgst.toStringAsFixed(2)}'),
                      if (_cgst > 0) _summaryLine('CGST @ 2.5%:', '₹${_cgst.toStringAsFixed(2)}'),
                      _summaryLine('Round Off:', '₹${_roundOff.toStringAsFixed(2)}'),
                      const Divider(height: 12, color: Color(0xFF242C37)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Text('Grand Total: ',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                          Text('₹${_grandTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF38BDF8))),
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

// ---------------- 2. DIRECTORY & ACTION CARDS ----------------

class HomeDirectoryView extends StatelessWidget {
  final int itemCount;
  final int customerCount;
  final VoidCallback onOpenPriceList;
  final VoidCallback onOpenCustomers;

  const HomeDirectoryView({
    super.key,
    required this.itemCount,
    required this.customerCount,
    required this.onOpenPriceList,
    required this.onOpenCustomers,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('MASTER DIRECTORY',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFE2E8F0))),
          const Text('Davis & Company - Rates and Party Management',
              style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8))),
          const SizedBox(height: 28),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: 1.8,
              children: [
                _buildCard(
                  title: 'Price List',
                  subtitle: '$itemCount Items Catalogued',
                  icon: Icons.inventory_2_outlined,
                  onTap: onOpenPriceList,
                ),
                _buildCard(
                  title: 'Customers Directory',
                  subtitle: '$customerCount Parties & Billing Rules',
                  icon: Icons.people_outline,
                  onTap: onOpenCustomers,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF242C37)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF38BDF8), size: 30),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }
}

// ---------------- 3. INVOICE HISTORY VIEW ----------------

class InvoiceHistoryView extends StatelessWidget {
  final List<DCEstimate> estimates;
  const InvoiceHistoryView({super.key, required this.estimates});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('INVOICE HISTORY',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text('${estimates.length} INVOICES RECORDED',
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          const SizedBox(height: 20),
          Expanded(
            child: estimates.isEmpty
                ? const Center(
                    child: Text('No invoice history logged yet.',
                        style: TextStyle(color: Color(0xFF94A3B8))),
                  )
                : ListView.separated(
                    itemCount: estimates.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                    itemBuilder: (ctx, idx) {
                      final est = estimates[idx];
                      return Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161B22),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF242C37)),
                        ),
                        child: Row(
                          children: [
                            Text('#${est.slNo}',
                                style: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(est.customer,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text(est.itemSummary,
                                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                                ],
                              ),
                            ),
                            Text('₹${est.grandTotal}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF38BDF8))),
                          ],
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

// ---------------- 4. PRICE LIST VIEW ----------------

class PriceListDesktopView extends StatefulWidget {
  final List<DCItem> items;
  final VoidCallback onBack;
  final VoidCallback onRefreshRequired;
  const PriceListDesktopView({
    super.key,
    required this.items,
    required this.onBack,
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
          backgroundColor: const Color(0xFF1E242C),
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
                  TextField(controller: tallyCtrl, decoration: const InputDecoration(labelText: 'Tally Ledger')),
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
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              onPressed: () async {
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
              },
              child: const Text('Save to Sheet'),
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
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack),
              const SizedBox(width: 10),
              const Text('PRICE LIST', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const Spacer(),
              SizedBox(
                width: 300,
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(hintText: 'Search items...'),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Item'),
                onPressed: () => _openEditItemDialog(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 10),
              itemBuilder: (ctx, idx) {
                final item = filtered[idx];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF242C37)),
                  ),
                  child: Row(
                    children: [
                      Text('${item.no}', style: const TextStyle(color: Color(0xFF94A3B8))),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text('₹${item.rate} (${item.rateType})  •  Tally: ${item.tallyName}',
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18, color: Color(0xFF94A3B8)),
                        onPressed: () => _openEditItemDialog(item: item),
                      ),
                    ],
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

// ---------------- 5. CUSTOMERS VIEW ----------------

class CustomerDesktopView extends StatefulWidget {
  final List<DCCustomer> customers;
  final VoidCallback onBack;
  final VoidCallback onRefreshRequired;
  const CustomerDesktopView({
    super.key,
    required this.customers,
    required this.onBack,
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
        backgroundColor: const Color(0xFF1E242C),
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
                TextField(controller: b2bCtrl, decoration: const InputDecoration(labelText: 'B2B Firm Name')),
                const SizedBox(height: 10),
                TextField(controller: b2cCtrl, decoration: const InputDecoration(labelText: 'B2C Reference Names')),
                const SizedBox(height: 10),
                TextField(controller: remarksCtrl, decoration: const InputDecoration(labelText: 'Remarks / Billing Notes')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            onPressed: () async {
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
            },
            child: const Text('Save to Sheet'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.customers
        .where((c) =>
            c.name.toLowerCase().contains(_query.toLowerCase()) ||
            c.b2b.toLowerCase().contains(_query.toLowerCase()) ||
            c.contact.contains(_query))
        .toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack),
              const SizedBox(width: 10),
              const Text('CUSTOMERS DIRECTORY', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const Spacer(),
              SizedBox(
                width: 300,
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(hintText: 'Search customer name...'),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('Add Customer'),
                onPressed: () => _openEditCustomerDialog(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 10),
              itemBuilder: (ctx, idx) {
                final c = filtered[idx];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF242C37)),
                  ),
                  child: Row(
                    children: [
                      Text('${c.slNo}', style: const TextStyle(color: Color(0xFF94A3B8))),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text('B2B: ${c.b2b.isEmpty ? '-' : c.b2b}  •  📞 ${c.contact.isEmpty ? '-' : c.contact}',
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                            if (c.remarks.isNotEmpty)
                              Text('Note: ${c.remarks}',
                                  style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18, color: Color(0xFF94A3B8)),
                        onPressed: () => _openEditCustomerDialog(customer: c),
                      ),
                    ],
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
