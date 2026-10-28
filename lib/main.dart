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
  double qty;
  double rate;
  final FocusNode rateFocus = FocusNode();
  final FocusNode qtyFocus = FocusNode();

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
      title: 'Davis & Company - DC Prime',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF111418),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3B82F6),
          surface: Color(0xFF181E26),
          onSurface: Color(0xFFE2E8F0),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF1E242C),
          border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF2C3540))),
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
  final List<LoadingEntry> _loadingSlip = [];
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: const Color(0xFF14181F),
            selectedIndex: _navIndex,
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
                icon: Icon(Icons.calculate_outlined),
                selectedIcon: Icon(Icons.calculate),
                label: Text('Calculator'),
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
                      PriceListDesktopView(
                        items: _items,
                        onRefreshRequired: _fetchData,
                      ),
                      CustomerDesktopView(
                        customers: _customers,
                        onRefreshRequired: _fetchData,
                      ),
                      LoadingSlipView(
                        loadingSlip: _loadingSlip,
                        items: _items,
                        customers: _customers,
                      ),
                      InvoiceHistoryView(estimates: _estimates),
                      PackSizeCalculatorView(items: _items),
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

  final FocusNode _billNoFocus = FocusNode();
  final FocusNode _refFocus = FocusNode();
  final FocusNode _coolieFocus = FocusNode();

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
        backgroundColor: const Color(0xFF1E242C),
        title: const Text('Instant Add Customer to Sheet'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Customer / Party Name')),
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
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
                });
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
              }
            },
            child: const Text('Save & Select'),
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
          backgroundColor: const Color(0xFF1E242C),
          title: const Text('Instant Add Item to Sheet'),
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
                      Expanded(child: TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: 'Qty (e.g. 50)'))),
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
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
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
                    _rows[rowIndex].rate = double.tryParse(newItem.rate) ?? 0.0;
                  });
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
                }
              },
              child: const Text('Save & Select'),
            ),
          ],
        ),
      ),
    );
  }

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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
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
                label: const Text('Save & Print (Enter)',
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
                    focusNode: _billNoFocus,
                    decoration: const InputDecoration(labelText: 'Bill No'),
                    onSubmitted: (_) => _refFocus.requestFocus(),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 3,
                  child: Autocomplete<DCCustomer>(
                    displayStringForOption: (c) =>
                        "${c.name} ${c.b2b.isNotEmpty ? '(${c.b2b})' : ''}",
                    optionsBuilder: (TextEditingValue textVal) {
                      if (textVal.text.isEmpty) {
                        return widget.customers;
                      }
                      return widget.customers.where((c) =>
                          c.name.toLowerCase().contains(textVal.text.toLowerCase()) ||
                          c.b2b.toLowerCase().contains(textVal.text.toLowerCase()));
                    },
                    onSelected: (c) {
                      setState(() => _selectedParty = c);
                      _billNoFocus.requestFocus();
                    },
                    fieldViewBuilder: (ctx, textCtrl, fNode, onSubmitted) {
                      return TextField(
                        controller: textCtrl,
                        focusNode: fNode,
                        decoration: InputDecoration(
                          labelText: 'Party Name (Search)',
                          hintText: 'Type customer name...',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.person_add, size: 18),
                            tooltip: 'Instant Add Customer',
                            onPressed: () => _openInstantAddCustomerDialog(textCtrl.text.trim()),
                          ),
                        ),
                        onSubmitted: (val) {
                          if (_selectedParty == null && val.trim().isNotEmpty) {
                            _openInstantAddCustomerDialog(val.trim());
                          } else {
                            _billNoFocus.requestFocus();
                          }
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 14),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _refCtrl,
                    focusNode: _refFocus,
                    decoration: const InputDecoration(labelText: 'Ref'),
                    onSubmitted: (_) {
                      if (_rows.isNotEmpty) {
                        _rows[0].rateFocus.requestFocus();
                      }
                    },
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
                        Expanded(flex: 4, child: Text('Name of Item (Search)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
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
                              child: Autocomplete<DCItem>(
                                initialValue: TextEditingValue(text: row.item?.name ?? ''),
                                displayStringForOption: (i) => i.name,
                                optionsBuilder: (TextEditingValue tVal) {
                                  if (tVal.text.isEmpty) {
                                    return widget.items;
                                  }
                                  return widget.items.where((i) =>
                                      i.name.toLowerCase().contains(tVal.text.toLowerCase()) ||
                                      i.tallyName.toLowerCase().contains(tVal.text.toLowerCase()));
                                },
                                onSelected: (item) {
                                  setState(() {
                                    row.item = item;
                                    row.rate = double.tryParse(item.rate) ?? 0.0;
                                  });
                                  row.rateFocus.requestFocus();
                                },
                                fieldViewBuilder: (ctx, itemTextCtrl, iFocus, onSub) {
                                  return TextField(
                                    controller: itemTextCtrl,
                                    focusNode: iFocus,
                                    decoration: InputDecoration(
                                      hintText: 'Search or type item...',
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      suffixIcon: IconButton(
                                        icon: const Icon(Icons.add, size: 16),
                                        tooltip: 'Instant Add Item',
                                        onPressed: () => _openInstantAddItemDialog(idx, itemTextCtrl.text.trim()),
                                      ),
                                    ),
                                    onSubmitted: (val) {
                                      if (row.item == null && val.trim().isNotEmpty) {
                                        _openInstantAddItemDialog(idx, val.trim());
                                      } else {
                                        row.rateFocus.requestFocus();
                                      }
                                    },
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
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
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
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
                                onFieldSubmitted: (_) {
                                  if (idx == _rows.length - 1) {
                                    _addRow();
                                  } else {
                                    _rows[idx + 1].rateFocus.requestFocus();
                                  }
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
                        label: const Text('+ Add Item Row (Enter on Qty)'),
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
                          focusNode: _coolieFocus,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Coolie (₹)'),
                          onChanged: (v) => setState(() {}),
                          onSubmitted: (_) => _saveInvoice(),
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

// ---------------- 2. PRICE LIST (VIEW MODAL & EDIT/ADD) ----------------

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

  void _showItemPreviewModal(DCItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E242C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Expanded(
              child: Text(item.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: Color(0xFF38BDF8)),
              onPressed: () {
                Navigator.pop(ctx);
                _openEditItemDialog(item: item);
              },
            ),
          ],
        ),
        content: SizedBox(
          width: 580,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(color: Color(0xFF242C37)),
                _buildModalRow('Current Rate:', '₹${item.rate}', isColor: true),
                _buildModalRow('Rate Unit:', item.rateType),
                _buildModalRow('Quantity / Pack Size:', '${item.qty} KG/Bag'),
                _buildModalRow('Item Name on Tally:', item.tallyName),
                _buildModalRow('Billed Unit:', item.billedIn),
                _buildModalRow('Tax Status:',
                    item.isTaxable ? 'TAXABLE (5%)' : 'NON-TAXABLE'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
        ],
      ),
    );
  }

  void _openEditItemDialog({DCItem? item}) {
    final isNew = item == null;
    final nameCtrl = TextEditingController(text: isNew ? '' : item.name);
    final rateCtrl = TextEditingController(text: isNew ? '' : item.rate);
    final rateTypeCtrl =
        TextEditingController(text: isNew ? 'RATE PER KG' : item.rateType);
    final qtyCtrl = TextEditingController(text: isNew ? '50' : '${item.qty}');
    final tallyCtrl =
        TextEditingController(text: isNew ? '' : item.tallyName);
    final billedCtrl =
        TextEditingController(text: isNew ? 'KILOGRAM' : item.billedIn);
    bool isTaxable = isNew ? false : item.isTaxable;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E242C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isNew ? 'Add New Item to Sheet' : 'Edit Item Details'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Item Name')),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                          child: TextField(
                              controller: rateCtrl,
                              decoration: const InputDecoration(labelText: 'Rate (₹)'))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: TextField(
                              controller: rateTypeCtrl,
                              decoration: const InputDecoration(labelText: 'Rate Type'))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                          child: TextField(
                              controller: qtyCtrl,
                              decoration: const InputDecoration(labelText: 'Quantity'))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: TextField(
                              controller: billedCtrl,
                              decoration: const InputDecoration(labelText: 'Billed In'))),
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
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              onPressed: () async {
                if (nameCtrl.text.trim().isNotEmpty) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Updating Google Sheet...')),
                  );

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
              child: Text(isNew ? 'Save to Sheet' : 'Update Sheet',
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalRow(String title, String val, {bool isColor = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(title, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              val,
              softWrap: true,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isColor ? const Color(0xFF38BDF8) : Colors.white,
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
        .where((i) =>
            i.name.toLowerCase().contains(_query.toLowerCase()) ||
            i.tallyName.toLowerCase().contains(_query.toLowerCase()))
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
                  const Text('DAVIS & COMPANY',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('PRICE LIST (${widget.items.length} ITEMS)',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: 300,
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, size: 20),
                    hintText: 'Search items...',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                label: const Text('Add Item', style: TextStyle(color: Colors.white)),
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
                      color: const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF242C37)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFF1E242C),
                          child: Text('${item.no}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 17, letterSpacing: 0.3),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    '₹${item.rate}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                      color: Color(0xFF38BDF8),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '(${item.rateType})',
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                  ),
                                  const SizedBox(width: 14),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E242C),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF2C3540)),
                                    ),
                                    child: Text(
                                      item.isTaxable ? 'TAXABLE' : 'NON-TAXABLE',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: item.isTaxable
                                              ? Colors.orangeAccent
                                              : const Color(0xFF94A3B8)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tally: ${item.tallyName}  |  Pack: ${item.qty}  |  Unit: ${item.billedIn}',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_note, color: Color(0xFF94A3B8), size: 24),
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

// ---------------- 3. CUSTOMERS (VIEW MODAL & EDIT/ADD) ----------------

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

  void _showCustomerPreviewModal(DCCustomer customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E242C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Expanded(
              child: Text(customer.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: Color(0xFF38BDF8)),
              onPressed: () {
                Navigator.pop(ctx);
                _openEditCustomerDialog(customer: customer);
              },
            ),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(color: Color(0xFF242C37)),
                _buildCustomerModalRow('Customer Name:', customer.name),
                _buildCustomerModalRow('Contact Number:',
                    customer.contact.isEmpty ? '-' : customer.contact),
                _buildCustomerModalRow(
                    'Address:', customer.address.isEmpty ? '-' : customer.address),
                _buildCustomerModalRow(
                    'B2B Firm Name:', customer.b2b.isEmpty ? '-' : customer.b2b,
                    isHighlight: true),
                _buildCustomerModalRow(
                    'B2C Reference:', customer.b2c.isEmpty ? '-' : customer.b2c),
                _buildCustomerModalRow('Billing Category:', customer.billingTag),
                if (customer.remarks.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Special Delivery & Billing Remarks:',
                      style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: const Color(0xFF161B22),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF242C37))),
                    child: Text(
                      customer.remarks,
                      softWrap: true,
                      style: const TextStyle(
                          color: Color(0xFFE2E8F0), fontSize: 14, height: 1.4),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15)),
          ),
        ],
      ),
    );
  }

  void _openEditCustomerDialog({DCCustomer? customer}) {
    final isNew = customer == null;
    final nameCtrl = TextEditingController(text: isNew ? '' : customer.name);
    final contactCtrl =
        TextEditingController(text: isNew ? '' : customer.contact);
    final addressCtrl =
        TextEditingController(text: isNew ? '' : customer.address);
    final b2bCtrl = TextEditingController(text: isNew ? '' : customer.b2b);
    final b2cCtrl = TextEditingController(text: isNew ? '' : customer.b2c);
    final remarksCtrl =
        TextEditingController(text: isNew ? '' : customer.remarks);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E242C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isNew ? 'Add New Customer to Sheet' : 'Edit Customer Details'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Party Name')),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(controller: contactCtrl, decoration: const InputDecoration(labelText: 'Contact')),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address')),
                    ),
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            onPressed: () async {
              if (nameCtrl.text.trim().isNotEmpty) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Updating Customer to Sheet...')),
                );
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
            child: Text(isNew ? 'Save to Sheet' : 'Update Sheet',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerModalRow(String title, String val, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(title, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              val,
              softWrap: true,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: isHighlight ? const Color(0xFF38BDF8) : Colors.white,
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
                  const Text('CUSTOMERS DIRECTORY',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('TOTAL ${widget.customers.length} PARTIES',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: 300,
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, size: 20),
                    hintText: 'Search customer name...',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                icon: const Icon(Icons.person_add, color: Colors.white, size: 18),
                label: const Text('Add Customer', style: TextStyle(color: Colors.white)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF242C37)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFF1E242C),
                          child: Text('${c.slNo}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(c.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E242C),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF2C3540)),
                                    ),
                                    child: Text(
                                      c.billingTag,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF94A3B8)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              if (c.contact.isNotEmpty || c.address.isNotEmpty)
                                Text(
                                  '📞 ${c.contact.isNotEmpty ? c.contact : "-"}  |  📍 ${c.address.isNotEmpty ? c.address : "-"}',
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                ),
                              if (c.b2b.isNotEmpty)
                                Text('B2B: ${c.b2b}',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF38BDF8),
                                        fontWeight: FontWeight.w500)),
                              if (c.b2c.isNotEmpty)
                                Text('B2C: ${c.b2c}',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                              if (c.remarks.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('Note: ${c.remarks}',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1))),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_note, color: Color(0xFF94A3B8), size: 24),
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

// ---------------- 4. PACKING SLIP VIEW ----------------

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
    String? selectedCust =
        widget.customers.isNotEmpty ? widget.customers.first.name : null;
    final placeCtrl = TextEditingController();
    final summaryCtrl = TextEditingController();
    final bagsCtrl = TextEditingController(text: '10');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E242C),
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
                    items: widget.customers
                        .map((c) => DropdownMenuItem(value: c.name, child: Text(c.name)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedCust = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: placeCtrl, decoration: const InputDecoration(labelText: 'Place (സ്ഥലം)')),
                  const SizedBox(height: 12),
                  TextField(
                    controller: summaryCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Item Summary (ഉദാ: Sadhya Vadi 5, Priyam 5)',
                    ),
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
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              onPressed: () async {
                if (selectedCust != null && bagsCtrl.text.trim().isNotEmpty) {
                  final party = selectedCust!;
                  final place = placeCtrl.text.trim();
                  final summary = summaryCtrl.text.trim();
                  final bags = int.tryParse(bagsCtrl.text.trim()) ?? 0;

                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Saving to Google Sheet Packing Slip...')),
                  );

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
              child: const Text('Save to Sheet', style: TextStyle(color: Colors.white)),
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
      buffer.writeln(
          "${i + 1}. ${e.customerName} (${e.place}) : ${e.summary} - ${e.bags} Bags");
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
                  const Text('PACKING / LOADING SLIP',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('LINKED DIRECTLY TO GOOGLE SHEET',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E242C),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy Slip'),
                onPressed: widget.loadingSlip.isEmpty ? null : _copySlipToClipboard,
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                label: const Text('Add Entry', style: TextStyle(color: Colors.white)),
                onPressed: _openAddPackingSlipDialog,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: widget.loadingSlip.isEmpty
                ? const Center(
                    child: Text('No entries added yet. Tap "Add Entry" to create a slip.',
                        style: TextStyle(color: Color(0xFF94A3B8))),
                  )
                : ListView.separated(
                    itemCount: widget.loadingSlip.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                    itemBuilder: (ctx, idx) {
                      final entry = widget.loadingSlip[idx];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161B22),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF242C37)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(0xFF1E242C),
                              child: Text('${idx + 1}',
                                  style: const TextStyle(color: Color(0xFF94A3B8))),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(entry.customerName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      if (entry.place.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1E242C),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(entry.place,
                                              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(entry.summary,
                                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                                ],
                              ),
                            ),
                            Text('${entry.bags} Bags',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF38BDF8))),
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
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF242C37)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL DISPATCH LOAD:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('$totalBags BAGS',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- 5. INVOICE HISTORY VIEW ----------------

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
          Text('${estimates.length} INVOICES LOGGED IN SHEET',
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
                                  Row(
                                    children: [
                                      Text(est.customer,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      const SizedBox(width: 10),
                                      Text('(${est.date})',
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
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

// ---------------- 6. CALCULATOR VIEW ----------------

class PackSizeCalculatorView extends StatefulWidget {
  final List<DCItem> items;
  const PackSizeCalculatorView({super.key, required this.items});

  @override
  State<PackSizeCalculatorView> createState() => _PackSizeCalculatorViewState();
}

class _PackSizeCalculatorViewState extends State<PackSizeCalculatorView> {
  DCItem? _selectedItem;
  final _qtyCtrl = TextEditingController(text: '1');
  double _totalCalculated = 0.0;

  void _calculate() {
    if (_selectedItem == null) return;
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0.0;
    final rate = double.tryParse(_selectedItem!.rate) ?? 0.0;
    setState(() {
      _totalCalculated = qty * rate;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PACK SIZE & RATE CALCULATOR',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const Text('QUICK ESTIMATE PER BAG / KG',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF242C37)),
            ),
            child: Column(
              children: [
                DropdownButtonFormField<DCItem>(
                  value: _selectedItem,
                  hint: const Text('Select an Item from Price List'),
                  isExpanded: true,
                  items: widget.items
                      .map((i) => DropdownMenuItem(
                            value: i,
                            child: Text('${i.name} — ₹${i.rate} (${i.rateType})'),
                          ))
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      _selectedItem = v;
                    });
                    _calculate();
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _qtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: _selectedItem != null && _selectedItem!.rateType.contains('BAG')
                              ? 'Number of Bags'
                              : 'Quantity in KGs',
                        ),
                        onChanged: (v) => _calculate(),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E242C),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Estimated Amount:',
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                            Text(
                              '₹${_totalCalculated.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF38BDF8)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
