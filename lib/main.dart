import 'package:flutter/material.dart';

void main() {
  runApp(const DCPrimeApp());
}

class DCItem {
  final int no;
  final String name;
  final String rateType;
  final double rate;
  final int qty;
  final String tallyName;
  final String billedIn;
  final bool isTaxable;

  const DCItem({
    required this.no,
    required this.name,
    required this.rateType,
    required this.rate,
    required this.qty,
    required this.tallyName,
    required this.billedIn,
    required this.isTaxable,
  });
}

class DCCustomer {
  final int slNo;
  final String name;
  final String b2bName;
  final String remarks;

  const DCCustomer({
    required this.slNo,
    required this.name,
    required this.b2bName,
    required this.remarks,
  });
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
        scaffoldBackgroundColor: const Color(0xFF0F1318),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF388E3C),
          surface: Color(0xFF181E26),
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

  final List<DCItem> _items = const [
    DCItem(no: 1, name: 'SADHYA VADI 50', rateType: 'RATE PER KG', rate: 61.0, qty: 50, tallyName: 'RICE - VADI', billedIn: 'KILOGRAM', isTaxable: false),
    DCItem(no: 2, name: 'PRIYAM VADI 50', rateType: 'RATE PER KG', rate: 59.5, qty: 50, tallyName: 'RICE - VADI', billedIn: 'KILOGRAM', isTaxable: false),
    DCItem(no: 3, name: 'MATTANAD VADI 50', rateType: 'RATE PER KG', rate: 59.5, qty: 50, tallyName: 'RICE - VADI', billedIn: 'KILOGRAM', isTaxable: false),
    DCItem(no: 4, name: 'MAYIL VADI 50', rateType: 'RATE PER KG', rate: 58.0, qty: 50, tallyName: 'RICE - VADI', billedIn: 'KILOGRAM', isTaxable: false),
    DCItem(no: 5, name: 'PAVIZHAM VADI 50', rateType: 'RATE PER KG', rate: 59.0, qty: 50, tallyName: 'RICE - VADI', billedIn: 'KILOGRAM', isTaxable: false),
    DCItem(no: 6, name: 'MOTHER VADI 50', rateType: 'RATE PER KG', rate: 57.5, qty: 50, tallyName: 'RICE - VADI', billedIn: 'KILOGRAM', isTaxable: false),
    DCItem(no: 7, name: 'NIRMAL VADI 50', rateType: 'RATE PER KG', rate: 57.0, qty: 50, tallyName: 'RICE - VADI', billedIn: 'KILOGRAM', isTaxable: false),
    DCItem(no: 8, name: 'PETER VADI 50', rateType: 'RATE PER KG', rate: 57.0, qty: 50, tallyName: 'RICE - VADI', billedIn: 'KILOGRAM', isTaxable: false),
    DCItem(no: 9, name: '2 STAR VADI 50', rateType: 'RATE PER KG', rate: 56.0, qty: 50, tallyName: 'RICE - VADI', billedIn: 'KILOGRAM', isTaxable: false),
    DCItem(no: 10, name: 'PAVAN VADI 50', rateType: 'RATE PER KG', rate: 54.5, qty: 50, tallyName: 'RICE - VADI', billedIn: 'KILOGRAM', isTaxable: false),
    DCItem(no: 11, name: 'RABBIT VADI 50', rateType: 'RATE PER KG', rate: 54.5, qty: 50, tallyName: 'RICE - VADI', billedIn: 'KILOGRAM', isTaxable: false),
    DCItem(no: 12, name: 'MALABAR VADI 50', rateType: 'RATE PER KG', rate: 54.5, qty: 50, tallyName: 'RICE - VADI', billedIn: 'KILOGRAM', isTaxable: false),
    DCItem(no: 13, name: 'GAYATHRI VADI 50', rateType: 'RATE PER KG', rate: 54.0, qty: 50, tallyName: 'RICE - VADI', billedIn: 'KILOGRAM', isTaxable: false),
    DCItem(no: 14, name: 'KAVITHA VADI 50', rateType: 'RATE PER KG', rate: 49.0, qty: 50, tallyName: 'RICE - VADI', billedIn: 'KILOGRAM', isTaxable: false),
    DCItem(no: 15, name: 'PAVIZHAM UNDA 50', rateType: 'RATE PER KG', rate: 47.0, qty: 50, tallyName: 'RICE - UNDA', billedIn: 'KILOGRAM', isTaxable: false),
    DCItem(no: 16, name: 'SADHYA UNDA 50', rateType: 'RATE PER KG', rate: 46.0, qty: 50, tallyName: 'RICE - UNDA', billedIn: 'KILOGRAM', isTaxable: false),
    DCItem(no: 22, name: 'NEY KICHADI 30', rateType: 'RATE PER KG', rate: 72.5, qty: 30, tallyName: 'RICE - PONNI', billedIn: 'KILOGRAM', isTaxable: false),
    DCItem(no: 26, name: '999 PONNI 30', rateType: 'RATE PER BAG', rate: 1740.0, qty: 30, tallyName: 'RICE - PONNI', billedIn: 'KILOGRAM', isTaxable: false),
    DCItem(no: 44, name: 'SADHYA VADI 10', rateType: 'RATE PER BAG', rate: 656.0, qty: 10, tallyName: 'RICE 10 KG', billedIn: 'KILOGRAM', isTaxable: true),
    DCItem(no: 46, name: 'PRIYAM VADI 5', rateType: 'RATE PER BAG', rate: 308.0, qty: 5, tallyName: 'RICE 05 KG', billedIn: 'KILOGRAM', isTaxable: true),
  ];

  final List<DCCustomer> _customers = const [
    DCCustomer(slNo: 1, name: 'ALANCE', b2bName: 'ALAN TRADERS', remarks: 'NON TAXABLE IN B2B, TAXABLE IN B2C (VAZHI BILL)'),
    DCCustomer(slNo: 2, name: 'HOMELY FOODS', b2bName: 'YUSAF EDAPPALLY', remarks: ''),
    DCCustomer(slNo: 3, name: 'DILEEP KUNDOOR', b2bName: 'J MART', remarks: ''),
    DCCustomer(slNo: 4, name: 'SHAHIDAMOL', b2bName: 'PLAPILLI TRADERS', remarks: ''),
    DCCustomer(slNo: 5, name: 'AISWARYA PATTIMATTOM', b2bName: 'AISWARYA TRADERS', remarks: ''),
    DCCustomer(slNo: 8, name: 'ARUN STORES', b2bName: 'ARUN STORES', remarks: 'CORRECT AMOUNT + COOLI'),
    DCCustomer(slNo: 9, name: 'MK STORE', b2bName: 'MK TRADING COMPANY', remarks: 'KAREEM , MANAF'),
    DCCustomer(slNo: 14, name: 'THANNIKODAN', b2bName: 'STAR AGENCIES', remarks: ''),
    DCCustomer(slNo: 22, name: 'MKB', b2bName: 'S AND S TRADES', remarks: 'MEETHEEKUNJU, RAJU CHUNANGAMVELY'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: const Color(0xFF141920),
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
            child: _navIndex == 0
                ? PriceListDesktopView(items: _items)
                : CustomerDesktopView(customers: _customers),
          ),
        ],
      ),
    );
  }
}

class PriceListDesktopView extends StatefulWidget {
  final List<DCItem> items;
  const PriceListDesktopView({super.key, required this.items});

  @override
  State<PriceListDesktopView> createState() => _PriceListDesktopViewState();
}

class _PriceListDesktopViewState extends State<PriceListDesktopView> {
  String _query = '';

  void _showItemModal(DCItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F2631),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(color: Colors.white12),
              _buildModalRow('Rate:', '₹${item.rate} (${item.rateType})', isColor: true),
              _buildModalRow('Packing Qty:', '${item.qty} KG/Bag'),
              _buildModalRow('Tally Ledger:', item.tallyName),
              _buildModalRow('Billed Unit:', item.billedIn),
              _buildModalRow('Tax Status:', item.isTaxable ? 'TAXABLE (5%)' : 'NON-TAXABLE'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
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
          Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DAVIS & COMPANY', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('PRICE LIST DIRECTORY (ALUVA)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: 320,
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 20),
                    hintText: 'Search items, tally names...',
                    filled: true,
                    fillColor: const Color(0xFF181E26),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 10),
              itemBuilder: (ctx, idx) {
                final item = filtered[idx];
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _showItemModal(item),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF181E26),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.blueGrey.shade900,
                          child: Text('${item.no}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text('${item.rateType}  •  ${item.tallyName}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('₹${item.rate}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.lightGreenAccent)),
                            Text(item.isTaxable ? 'Taxable (5%)' : 'Non Taxable', style: TextStyle(fontSize: 11, color: item.isTaxable ? Colors.orangeAccent : Colors.grey)),
                          ],
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

class CustomerDesktopView extends StatelessWidget {
  final List<DCCustomer> customers;
  const CustomerDesktopView({super.key, required this.customers});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CUSTOMERS DIRECTORY', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const Text('B2B, B2C and Special billing rules', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: customers.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final c = customers[i];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF181E26),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.teal.shade900,
                        child: Text('${c.slNo}', style: const TextStyle(fontSize: 12, color: Colors.white)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            if (c.b2bName.isNotEmpty) Text('B2B: ${c.b2bName}', style: const TextStyle(fontSize: 13, color: Colors.blueAccent)),
                            if (c.remarks.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(c.remarks, style: const TextStyle(fontSize: 11, color: Colors.amberAccent)),
                              ),
                          ],
                        ),
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
