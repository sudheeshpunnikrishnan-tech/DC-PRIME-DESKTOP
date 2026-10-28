import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

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
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF238636),
          surface: Color(0xFF161B22),
          onSurface: Colors.white,
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

  void _navigateTo(int index) {
    setState(() => _navIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: const Color(0xFF161B22),
            selectedIndex: _navIndex > 3 ? 0 : _navIndex,
            onDestinationSelected: (val) => setState(() => _navIndex = val),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('DC',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.grey),
              tooltip: 'Reload from Google Sheet',
              onPressed: _fetchData,
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: Text('Home'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: Text('Invoices'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.local_shipping_outlined),
                selectedIcon: Icon(Icons.local_shipping),
                label: Text('Packing Slip'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.calculate_outlined),
                selectedIcon: Icon(Icons.calculate),
                label: Text('Calculator'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1, color: Colors.white10),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : IndexedStack(
                    index: _navIndex,
                    children: [
                      HomeDashboardView(
                        itemCount: _items.length,
                        customerCount: _customers.length,
                        invoiceCount: _estimates.length,
                        onOpenPriceList: () => _navigateTo(4),
                        onOpenCustomers: () => _navigateTo(5),
                        onOpenPackingSlip: () => _navigateTo(2),
                        onOpenInvoices: () => _navigateTo(1),
                      ),
                      InvoiceHistoryView(
                        estimates: _estimates,
                        customers: _customers,
                        items: _items,
                        onRefreshRequired: _fetchData,
                      ),
                      LoadingSlipView(
                        loadingSlip: _loadingSlip,
                        items: _items,
                        customers: _customers,
                      ),
                      PackSizeCalculatorView(items: _items),
                      PriceListDesktopView(
                        items: _items,
                        onBack: () => _navigateTo(0),
                        onRefreshRequired: _fetchData,
                      ),
                      CustomerDesktopView(
                        customers: _customers,
                        onBack: () => _navigateTo(0),
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

// ---------------- 1. HOME VIEW ----------------

class HomeDashboardView extends StatelessWidget {
  final int itemCount;
  final int customerCount;
  final int invoiceCount;
  final VoidCallback onOpenPriceList;
  final VoidCallback onOpenCustomers;
  final VoidCallback onOpenPackingSlip;
  final VoidCallback onOpenInvoices;

  const HomeDashboardView({
    super.key,
    required this.itemCount,
    required this.customerCount,
    required this.invoiceCount,
    required this.onOpenPriceList,
    required this.onOpenCustomers,
    required this.onOpenPackingSlip,
    required this.onOpenInvoices,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DAVIS & COMPANY, ALUVA',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const Text('Operations, Billing & Wholesale Manager',
              style: TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 30),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: 1.6,
              children: [
                _buildActionCard(
                  title: 'Price List',
                  subtitle: '$itemCount Items Catalogued',
                  icon: Icons.inventory_2,
                  color: Colors.blueAccent,
                  onTap: onOpenPriceList,
                ),
                _buildActionCard(
                  title: 'Customers Directory',
                  subtitle: '$customerCount Registered Parties',
                  icon: Icons.people,
                  color: Colors.tealAccent,
                  onTap: onOpenCustomers,
                ),
                _buildActionCard(
                  title: 'Invoice History',
                  subtitle: '$invoiceCount Recorded Estimates',
                  icon: Icons.receipt_long,
                  color: Colors.amberAccent,
                  onTap: onOpenInvoices,
                ),
                _buildActionCard(
                  title: 'Vehicle Packing Slip',
                  subtitle: 'Dispatch & Bag Allocation',
                  icon: Icons.local_shipping,
                  color: Colors.purpleAccent,
                  onTap: onOpenPackingSlip,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 16),
            Text(title,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// ---------------- 2. INVOICE HISTORY VIEW ----------------

class InvoiceHistoryView extends StatefulWidget {
  final List<DCEstimate> estimates;
  final List<DCCustomer> customers;
  final List<DCItem> items;
  final VoidCallback onRefreshRequired;

  const InvoiceHistoryView({
    super.key,
    required this.estimates,
    required this.customers,
    required this.items,
    required this.onRefreshRequired,
  });

  @override
  State<InvoiceHistoryView> createState() => _InvoiceHistoryViewState();
}

class _InvoiceHistoryViewState extends State<InvoiceHistoryView> {
  String _query = '';

  void _openAddInvoiceDialog() {
    String? selectedCust =
        widget.customers.isNotEmpty ? widget.customers.first.name : null;
    final summaryCtrl = TextEditingController();
    final coolieCtrl = TextEditingController(text: '0');
    final sgstCtrl = TextEditingController(text: '0');
    final cgstCtrl = TextEditingController(text: '0');
    final totalCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1C2128),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Record New Invoice / Estimate'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedCust,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Customer'),
                    items: widget.customers
                        .map((c) =>
                            DropdownMenuItem(value: c.name, child: Text(c.name)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedCust = v),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: summaryCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Item Summary (Items, Rates, Bags)'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                          child: TextField(
                              controller: coolieCtrl,
                              decoration:
                                  const InputDecoration(labelText: 'Coolie (₹)'))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: TextField(
                              controller: sgstCtrl,
                              decoration:
                                  const InputDecoration(labelText: 'SGST (₹)'))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: TextField(
                              controller: cgstCtrl,
                              decoration:
                                  const InputDecoration(labelText: 'CGST (₹)'))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: totalCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Grand Total (₹)'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF238636)),
              onPressed: () async {
                if (selectedCust != null && totalCtrl.text.trim().isNotEmpty) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Saving Estimate to Sheet...')),
                  );
                  final now = DateTime.now();
                  final dateStr = "${now.day}/${now.month}/${now.year}";

                  await http.post(
                    Uri.parse(sheetApiUrl),
                    body: jsonEncode({
                      "action": "ADD_ESTIMATE",
                      "date": dateStr,
                      "customer": selectedCust,
                      "itemSummary": summaryCtrl.text.trim(),
                      "coolie": coolieCtrl.text.trim(),
                      "sgst": sgstCtrl.text.trim(),
                      "cgst": cgstCtrl.text.trim(),
                      "roundOff": "0",
                      "grandTotal": totalCtrl.text.trim(),
                    }),
                  );
                  widget.onRefreshRequired();
                }
              },
              child: const Text('Save Estimate',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.estimates
        .where((e) =>
            e.customer.toLowerCase().contains(_query.toLowerCase()) ||
            e.itemSummary.toLowerCase().contains(_query.toLowerCase()))
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
                  const Text('INVOICE & ESTIMATES HISTORY',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('${widget.estimates.length} BILLS LOGGED',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: 300,
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 20),
                    hintText: 'Search customer, items...',
                    filled: true,
                    fillColor: const Color(0xFF161B22),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF238636),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                label: const Text('Record Invoice',
                    style: TextStyle(color: Colors.white)),
                onPressed: _openAddInvoiceDialog,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text('No invoice history found in Sheet.',
                        style: TextStyle(color: Colors.grey)),
                  )
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                    itemBuilder: (ctx, idx) {
                      final est = filtered[idx];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161B22),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.amber.shade900,
                              child: Text('${est.slNo}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(est.customer,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 17)),
                                      const SizedBox(width: 10),
                                      Text('(${est.date})',
                                          style: const TextStyle(
                                              fontSize: 12, color: Colors.grey)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(est.itemSummary,
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 14)),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Coolie: ₹${est.coolie}  |  SGST: ₹${est.sgst}  |  CGST: ₹${est.cgst}',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            Text('₹${est.grandTotal}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                    color: Colors.greenAccent)),
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

// ---------------- 3. PRICE LIST (WITH EDIT & ADD) ----------------

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

  void _showItemPreviewModal(DCItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Expanded(
              child: Text(item.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 19)),
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blueAccent),
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
                const Divider(color: Colors.white12),
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
            child: const Text('Close', style: TextStyle(color: Colors.white70)),
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
          backgroundColor: const Color(0xFF1C2128),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isNew ? 'Add New Item to Sheet' : 'Edit Item Details'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Item Name')),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                          child: TextField(
                              controller: rateCtrl,
                              decoration:
                                  const InputDecoration(labelText: 'Rate (₹)'))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: TextField(
                              controller: rateTypeCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Rate Type'))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                          child: TextField(
                              controller: qtyCtrl,
                              decoration:
                                  const InputDecoration(labelText: 'Quantity'))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: TextField(
                              controller: billedCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Billed In'))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                      controller: tallyCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Item Name on Tally')),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Taxable'),
                    value: isTaxable,
                    onChanged: (v) => setDialogState(() => isTaxable = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF238636)),
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
            child: Text(title,
                style: const TextStyle(color: Colors.grey, fontSize: 14)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              val,
              softWrap: true,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isColor ? Colors.greenAccent : Colors.white,
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
              IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back to Home',
                onPressed: widget.onBack,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('DAVIS & COMPANY',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('PRICE LIST (${widget.items.length} ITEMS)',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: 300,
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 20),
                    hintText: 'Search items...',
                    filled: true,
                    fillColor: const Color(0xFF161B22),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF238636),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                label: const Text('Add Item',
                    style: TextStyle(color: Colors.white)),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.blueGrey.shade900,
                          child: Text('${item.no}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
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
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                    letterSpacing: 0.3),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    '₹${item.rate}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                      color: Color(0xFF39D353),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '(${item.rateType})',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(width: 14),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: item.isTaxable
                                          ? Colors.orange.withOpacity(0.2)
                                          : Colors.blueGrey.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      item.isTaxable ? 'TAXABLE' : 'NON-TAXABLE',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: item.isTaxable
                                              ? Colors.orangeAccent
                                              : Colors.grey),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tally: ${item.tallyName}  |  Pack: ${item.qty}  |  Unit: ${item.billedIn}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_note,
                              color: Colors.white60, size: 24),
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

// ---------------- 4. CUSTOMERS DIRECTORY (WITH EDIT & ADD) ----------------

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

  void _showCustomerPreviewModal(DCCustomer customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Expanded(
              child: Text(customer.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 20)),
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blueAccent),
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
                const Divider(color: Colors.white12),
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
                          color: Colors.grey,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      customer.remarks,
                      softWrap: true,
                      style: const TextStyle(
                          color: Colors.amberAccent, fontSize: 14, height: 1.4),
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
            child: const Text('Close',
                style: TextStyle(color: Colors.white70, fontSize: 15)),
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
        backgroundColor: const Color(0xFF1C2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isNew ? 'Add New Customer to Sheet' : 'Edit Customer Details'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Customer / Party Name')),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                          controller: contactCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Contact Number')),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                          controller: addressCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Address')),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                    controller: b2bCtrl,
                    decoration:
                        const InputDecoration(labelText: 'B2B Trade Name')),
                const SizedBox(height: 10),
                TextField(
                    controller: b2cCtrl,
                    decoration: const InputDecoration(
                        labelText: 'B2C Reference Names')),
                const SizedBox(height: 10),
                TextField(
                    controller: remarksCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Delivery Remarks / Rules')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF238636)),
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

  Widget _buildCustomerModalRow(String title, String val,
      {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(title,
                style: const TextStyle(color: Colors.grey, fontSize: 14)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              val,
              softWrap: true,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: isHighlight ? Colors.lightBlueAccent : Colors.white,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getTagColor(String tag) {
    switch (tag) {
      case 'CREDIT':
        return Colors.redAccent;
      case 'VAZHI BILL':
        return Colors.amberAccent;
      case 'NO COOLI':
        return Colors.purpleAccent;
      default:
        return Colors.tealAccent;
    }
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
              IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back to Home',
                onPressed: widget.onBack,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CUSTOMERS DIRECTORY',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('TOTAL ${widget.customers.length} PARTIES',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: 300,
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 20),
                    hintText: 'Search customer name, contact...',
                    filled: true,
                    fillColor: const Color(0xFF161B22),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF238636),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                icon: const Icon(Icons.person_add, color: Colors.white, size: 18),
                label: const Text('Add Customer',
                    style: TextStyle(color: Colors.white)),
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
                final tagColor = _getTagColor(c.billingTag);
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _showCustomerPreviewModal(c),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.teal.shade900,
                          child: Text('${c.slNo}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white,
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
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 17)),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: tagColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: tagColor.withOpacity(0.5)),
                                    ),
                                    child: Text(
                                      c.billingTag,
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: tagColor),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              if (c.contact.isNotEmpty || c.address.isNotEmpty)
                                Text(
                                  '📞 ${c.contact.isNotEmpty ? c.contact : "-"}  |  📍 ${c.address.isNotEmpty ? c.address : "-"}',
                                  style: const TextStyle(
                                      fontSize: 13, color: Colors.white70),
                                ),
                              if (c.b2b.isNotEmpty)
                                Text('B2B: ${c.b2b}',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.lightBlueAccent,
                                        fontWeight: FontWeight.w500)),
                              if (c.b2c.isNotEmpty)
                                Text('B2C: ${c.b2c}',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                              if (c.remarks.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('Note: ${c.remarks}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.amberAccent)),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_note,
                              color: Colors.white60, size: 24),
                          tooltip: 'Edit Customer',
                          onPressed: () =>
                              _openEditCustomerDialog(customer: c),
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
    String? selectedCust =
        widget.customers.isNotEmpty ? widget.customers.first.name : null;
    final placeCtrl = TextEditingController();
    final summaryCtrl = TextEditingController();
    final bagsCtrl = TextEditingController(text: '10');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1C2128),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    decoration:
                        const InputDecoration(labelText: 'Party / Customer Name'),
                    items: widget.customers
                        .map((c) =>
                            DropdownMenuItem(value: c.name, child: Text(c.name)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedCust = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: placeCtrl,
                    decoration: const InputDecoration(labelText: 'Place (സ്ഥലം)'),
                  ),
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
                    decoration: const InputDecoration(
                        labelText: 'Total Nos of Bags (ചാക്ക്)'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF238636)),
              onPressed: () async {
                if (selectedCust != null && bagsCtrl.text.trim().isNotEmpty) {
                  final party = selectedCust!;
                  final place = placeCtrl.text.trim();
                  final summary = summaryCtrl.text.trim();
                  final bags = int.tryParse(bagsCtrl.text.trim()) ?? 0;

                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Saving to Google Sheet Packing Slip...')),
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
              child: const Text('Save to Sheet',
                  style: TextStyle(color: Colors.white)),
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
    int totalBags =
        widget.loadingSlip.fold(0, (sum, entry) => sum + entry.bags);

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
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('LINKED DIRECTLY TO GOOGLE SHEET',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey.shade800,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy Slip'),
                onPressed:
                    widget.loadingSlip.isEmpty ? null : _copySlipToClipboard,
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF238636),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                label: const Text('Add Entry',
                    style: TextStyle(color: Colors.white)),
                onPressed: _openAddPackingSlipDialog,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: widget.loadingSlip.isEmpty
                ? const Center(
                    child: Text(
                        'No entries added yet. Tap "Add Entry" to create a slip.',
                        style: TextStyle(color: Colors.grey)),
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
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.indigo.shade900,
                              child: Text('${idx + 1}',
                                  style: const TextStyle(color: Colors.white)),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(entry.customerName,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16)),
                                      if (entry.place.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blueGrey
                                                .withOpacity(0.3),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(entry.place,
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.white70)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(entry.summary,
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 13)),
                                ],
                              ),
                            ),
                            Text('${entry.bags} Bags',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.greenAccent)),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.redAccent),
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
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL DISPATCH LOAD:',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('$totalBags BAGS',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.greenAccent)),
              ],
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
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
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
                            child:
                                Text('${i.name} — ₹${i.rate} (${i.rateType})'),
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
                          labelText: _selectedItem != null &&
                                  _selectedItem!.rateType.contains('BAG')
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
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Estimated Amount:',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 13)),
                            Text(
                              '₹${_totalCalculated.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.greenAccent),
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
