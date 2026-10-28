import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const DCPrimeApp());
}

const String sheetApiUrl = "https://script.google.com/macros/s/AKfycbzFDW5eeT4abGSRNLHlKs43JJ81YiKt0UrNEbbK2_cQIylsU_zGylqE8IMBqtpmXsjOEg/exec";

class DCItem {
  dynamic no;
  String name;
  String rateType;
  String rate;
  dynamic qty;
  String tallyName;
  String billedIn;
  bool isTaxable;

  DCItem({
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
  dynamic slNo;
  String name;
  String b2c;
  String b2b;
  String remarks;

  DCCustomer({
    required this.slNo,
    required this.name,
    required this.b2c,
    required this.b2b,
    required this.remarks,
  });

  factory DCCustomer.fromJson(Map<String, dynamic> json) {
    return DCCustomer(
      slNo: json['slNo'] ?? '',
      name: json['name'] ?? '',
      b2c: json['b2c'] ?? '',
      b2b: json['b2b'] ?? '',
      remarks: json['remarks'] ?? '',
    );
  }
}

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

        setState(() {
          _items = itemList.map((i) => DCItem.fromJson(i)).toList();
          _customers = custList.map((c) => DCCustomer.fromJson(c)).toList();
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
            backgroundColor: const Color(0xFF161B22),
            selectedIndex: _navIndex,
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
                child: const Text('DC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.grey),
              tooltip: 'Reload from Google Sheet',
              onPressed: _fetchData,
            ),
            destinations: const [
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
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1, color: Colors.white10),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _navIndex == 0
                    ? PriceListDesktopView(
                        items: _items,
                        onUpdate: () => setState(() {}),
                      )
                    : CustomerDesktopView(
                        customers: _customers,
                        onUpdate: () => setState(() {}),
                      ),
          ),
        ],
      ),
    );
  }
}

// ---------------- PRICE LIST SECTION ----------------

class PriceListDesktopView extends StatefulWidget {
  final List<DCItem> items;
  final VoidCallback onUpdate;
  const PriceListDesktopView({super.key, required this.items, required this.onUpdate});

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
              child: Text(
                item.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blueAccent),
              onPressed: () {
                Navigator.pop(ctx);
                _openItemEditDialog(item: item);
              },
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(color: Colors.white12),
              _buildModalRow('Current Rate:', '₹${item.rate}', isColor: true),
              _buildModalRow('Rate Unit:', item.rateType),
              _buildModalRow('Quantity / Pack:', '${item.qty}'),
              _buildModalRow('Item Name on Tally:', item.tallyName),
              _buildModalRow('Billed In:', item.billedIn),
              _buildModalRow('Tax Status:', item.isTaxable ? 'TAXABLE' : 'NON-TAXABLE'),
            ],
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

  void _openItemEditDialog({DCItem? item}) {
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
          backgroundColor: const Color(0xFF1C2128),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isNew ? 'Add New Item' : 'Edit Item Details'),
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF238636)),
              onPressed: () {
                if (isNew) {
                  widget.items.insert(
                    0,
                    DCItem(
                      no: widget.items.length + 1,
                      name: nameCtrl.text.trim(),
                      rateType: rateTypeCtrl.text.trim(),
                      rate: rateCtrl.text.trim(),
                      qty: qtyCtrl.text.trim(),
                      tallyName: tallyCtrl.text.trim(),
                      billedIn: billedCtrl.text.trim(),
                      isTaxable: isTaxable,
                    ),
                  );
                } else {
                  item.name = nameCtrl.text.trim();
                  item.rate = rateCtrl.text.trim();
                  item.rateType = rateTypeCtrl.text.trim();
                  item.qty = qtyCtrl.text.trim();
                  item.tallyName = tallyCtrl.text.trim();
                  item.billedIn = billedCtrl.text.trim();
                  item.isTaxable = isTaxable;
                }
                widget.onUpdate();
                Navigator.pop(ctx);
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Flexible(
            child: Text(
              val,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
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
        .where((i) => i.name.toLowerCase().contains(_query.toLowerCase()) || i.tallyName.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('DAVIS & COMPANY', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('PRICE LIST (${widget.items.length} ITEMS)', style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF238636),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                label: const Text('Add Item', style: TextStyle(color: Colors.white)),
                onPressed: () => _openItemEditDialog(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Enlarged Card View with Rate under Title
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
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.blueGrey.shade900,
                          child: Text('${item.no}', style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 20),
                        // Expanded text area for full stretch reading
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, letterSpacing: 0.3),
                              ),
                              const SizedBox(height: 6),
                              // Rate prominently placed under the name
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
                                    style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(width: 14),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: item.isTaxable ? Colors.orange.withOpacity(0.2) : Colors.blueGrey.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      item.isTaxable ? 'TAXABLE' : 'NON-TAXABLE',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: item.isTaxable ? Colors.orangeAccent : Colors.grey),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tally: ${item.tallyName}  |  Pack: ${item.qty}  |  Unit: ${item.billedIn}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_note, color: Colors.white60, size: 24),
                          tooltip: 'Edit Item',
                          onPressed: () => _openItemEditDialog(item: item),
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

// ---------------- CUSTOMERS SECTION ----------------

class CustomerDesktopView extends StatefulWidget {
  final List<DCCustomer> customers;
  final VoidCallback onUpdate;
  const CustomerDesktopView({super.key, required this.customers, required this.onUpdate});

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
              child: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blueAccent),
              onPressed: () {
                Navigator.pop(ctx);
                _openCustomerEditDialog(customer: customer);
              },
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(color: Colors.white12),
              _buildModalRow('Customer Name:', customer.name),
              _buildModalRow('B2B Firm Name:', customer.b2b.isEmpty ? '-' : customer.b2b),
              _buildModalRow('B2C Reference:', customer.b2c.isEmpty ? '-' : customer.b2c),
              if (customer.remarks.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text('Special Remarks:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                  child: Text(customer.remarks, style: const TextStyle(color: Colors.amberAccent, fontSize: 13)),
                ),
              ],
            ],
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

  void _openCustomerEditDialog({DCCustomer? customer}) {
    final isNew = customer == null;
    final nameCtrl = TextEditingController(text: isNew ? '' : customer.name);
    final b2bCtrl = TextEditingController(text: isNew ? '' : customer.b2b);
    final b2cCtrl = TextEditingController(text: isNew ? '' : customer.b2c);
    final remarksCtrl = TextEditingController(text: isNew ? '' : customer.remarks);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isNew ? 'Add New Customer' : 'Edit Customer'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Customer / Party Name')),
                const SizedBox(height: 10),
                TextField(controller: b2bCtrl, decoration: const InputDecoration(labelText: 'B2B Trade Name')),
                const SizedBox(height: 10),
                TextField(controller: b2cCtrl, decoration: const InputDecoration(labelText: 'B2C Reference Names')),
                const SizedBox(height: 10),
                TextField(controller: remarksCtrl, decoration: const InputDecoration(labelText: 'Delivery Remarks / Rules')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF238636)),
            onPressed: () {
              if (isNew) {
                widget.customers.insert(
                  0,
                  DCCustomer(
                    slNo: widget.customers.length + 1,
                    name: nameCtrl.text.trim(),
                    b2b: b2bCtrl.text.trim(),
                    b2c: b2cCtrl.text.trim(),
                    remarks: remarksCtrl.text.trim(),
                  ),
                );
              } else {
                customer.name = nameCtrl.text.trim();
                customer.b2b = b2bCtrl.text.trim();
                customer.b2c = b2cCtrl.text.trim();
                customer.remarks = remarksCtrl.text.trim();
              }
              widget.onUpdate();
              Navigator.pop(ctx);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildModalRow(String title, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Flexible(
            child: Text(
              val,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
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
          c.b2c.toLowerCase().contains(_query.toLowerCase());
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
                  Text('TOTAL ${widget.customers.length} PARTIES', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: 300,
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 20),
                    hintText: 'Search customer name, B2B...',
                    filled: true,
                    fillColor: const Color(0xFF161B22),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF238636),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                icon: const Icon(Icons.person_add, color: Colors.white, size: 18),
                label: const Text('Add Customer', style: TextStyle(color: Colors.white)),
                onPressed: () => _openCustomerEditDialog(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Enlarged Customer Cards for One-Stretch Readability
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
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.teal.shade900,
                          child: Text('${c.slNo}', style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                              const SizedBox(height: 6),
                              if (c.b2b.isNotEmpty)
                                Text('B2B: ${c.b2b}', style: const TextStyle(fontSize: 14, color: Colors.lightBlueAccent, fontWeight: FontWeight.w500)),
                              if (c.b2c.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text('B2C: ${c.b2c}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                                ),
                              if (c.remarks.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text('Note: ${c.remarks}', style: const TextStyle(fontSize: 12, color: Colors.amberAccent)),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_note, color: Colors.white60, size: 24),
                          tooltip: 'Edit Customer',
                          onPressed: () => _openCustomerEditDialog(customer: c),
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
