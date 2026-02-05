import 'package:flutter/material.dart';
// import removed: http
import '../services/api_client.dart';
import 'dart:convert';
import '../services/rider_orders_db.dart';
// RiderOrdersService is defined in rider_orders_db.dart
import 'payment_webview_page.dart';
import '../services/user_session_db.dart';
import '../services/api_config.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // Constants
  static const String _dashboardApi = '/api/shop/getriderdashboard';
  static String get _paymentUrl => ApiConfig.paymentStartLoadPurchase;

  // State variables
  bool _loading = true;
  String? _error;
  double _balance = 0.0;
  int _ongoing = 0;
  double _earnings = 0.0;
  int _completed = 0;

  // Pending loads state
  List<dynamic> _pendingLoads = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
    _fetchPendingLoads();
  }

  Future<void> _fetchDashboard() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await UserSessionDB.getSession();
      final userId = session?['user_id'] ?? '';
      final url = ApiConfig.absolute(_dashboardApi);
      final body = {'UserId': userId};
      final response = await ApiClient.post(url,
          body: jsonEncode(body),
          headers: {'Content-Type': 'application/json'});
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (!mounted) return;
        setState(() {
          _balance = (data['LoadBalance'] is num)
              ? data['LoadBalance'].toDouble()
              : double.tryParse(data['LoadBalance']?.toString() ?? '0') ?? 0.0;
          _ongoing = (data['OnGoing'] is int)
              ? data['OnGoing']
              : int.tryParse(data['OnGoing']?.toString() ?? '0') ?? 0;
          _earnings = (data['Earnings'] is num)
              ? data['Earnings'].toDouble()
              : double.tryParse(data['Earnings']?.toString() ?? '0') ?? 0.0;
          _completed = (data['Completed'] is int)
              ? data['Completed']
              : int.tryParse(data['Completed']?.toString() ?? '0') ?? 0;
          _loading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _error = 'Failed to load dashboard: ${response.body}';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error: $e';
        _loading = false;
      });
    }
  }

  Future<void> _fetchPendingLoads() async {
    try {
      final session = await UserSessionDB.getSession();
      final userId = session?['user_id'] ?? '';
      final loads = await RiderOrdersService.getRiderLoadTrans(userId: userId);
      setState(() {
        _pendingLoads = loads.where((e) => e['IsConfirmed'] == false).toList();
      });
    } catch (e) {
      // Handle error silently for now
    }
  }

  bool _isBalanceLow() {
    return _balance < 100;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isSmall = constraints.maxWidth < 400;
                final double horizontalPadding = isSmall ? 8.0 : 24.0;
                final double cardFontSize = isSmall ? 13 : 16;
                final double cardValueFontSize = isSmall ? 15 : 18;

                if (_loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (_error != null) {
                  return Center(
                      child: Text(_error!,
                          style: const TextStyle(color: Colors.red)));
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await _fetchDashboard();
                    await _fetchPendingLoads();
                  },
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: 24.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: isSmall ? 20 : 40),
                          SizedBox(height: isSmall ? 18 : 32),
                          GestureDetector(
                            onTap: () => _handleLoadBalanceCardTap(context),
                            child: _buildDashboardCard(
                              icon: Icons.account_balance_wallet,
                              label: 'Load Balance',
                              value: '₱${_balance.toStringAsFixed(2)}',
                              color: const Color(0xFF5D8AA8).withOpacity(0.1),
                              labelFontSize: cardFontSize,
                              valueFontSize: cardValueFontSize,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF5D8AA8),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      minimumSize: Size(0, 36),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    icon: const Icon(Icons.add_circle_outline,
                                        size: 18),
                                    label: const Text('Top Up',
                                        style: TextStyle(fontSize: 14)),
                                    onPressed: () => _showTopUpModal(context),
                                  ),
                                  if (_pendingLoads.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.orange,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${_pendingLoads.length} Pending',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          // Removed Top Up button from outside the card
                          SizedBox(height: isSmall ? 10 : 16),
                          _buildDashboardCard(
                            icon: Icons.timelapse,
                            label: 'On Going',
                            value: '$_ongoing Orders',
                            color: const Color(0xFF5D8AA8).withOpacity(0.1),
                            labelFontSize: cardFontSize,
                            valueFontSize: cardValueFontSize,
                          ),
                          SizedBox(height: isSmall ? 10 : 16),
                          _buildDashboardCard(
                            icon: Icons.attach_money,
                            label: 'Earnings',
                            value: '₱${_earnings.toStringAsFixed(2)}',
                            color: const Color(0xFF5D8AA8).withOpacity(0.1),
                            labelFontSize: cardFontSize,
                            valueFontSize: cardValueFontSize,
                          ),
                          SizedBox(height: isSmall ? 10 : 16),
                          _buildDashboardCard(
                            icon: Icons.check_circle,
                            label: 'Completed',
                            value: '$_completed Orders',
                            color: const Color(0xFF5D8AA8).withOpacity(0.1),
                            labelFontSize: cardFontSize,
                            valueFontSize: cardValueFontSize,
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
    );
  }

  Widget _buildDashboardCard({
    required IconData icon,
    required String label,
    required String value,
    Color? color,
    double labelFontSize = 16,
    double valueFontSize = 18,
    Widget? trailing, // Add trailing widget parameter
  }) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: color ?? const Color(0xFF5D8AA8),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(icon, color: const Color(0xFF5D8AA8)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: const Color(0xFF5D8AA8),
                      fontWeight: FontWeight.bold,
                      fontSize: labelFontSize,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: const Color(0xFF5D8AA8),
                      fontWeight: FontWeight.w800,
                      fontSize: valueFontSize + 2,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTopUpModal(BuildContext context) async {
    final amount = await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return _TopUpSheet();
      },
    );
    if (amount != null) {
      try {
        final session = await UserSessionDB.getSession();
        final riderId = session?['rider_id'] ?? '';
        final mobileNo = session?['mobile_no'] ?? '';
        final email = session?['email'] ?? '';

        if (riderId.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User session not found')),
          );
          return;
        }

        final result = await RiderOrdersService.postLoadRiderWallet(
            riderId: riderId, amount: amount);
        final orderno = result['message'] ?? '';
        if (orderno.isEmpty) throw Exception('No order number returned');
        final url =
            '${_paymentUrl}?Id=16&PROC_ID=GCSH&amount=$amount&PhoneNumber=$mobileNo&email=$email&LoadRefNo=$orderno';
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentWebViewPage(paymentUrl: url),
          ),
        );
        _fetchPendingLoads();
        _fetchDashboard();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Top up failed: $e')),
        );
      }
    }
  }

  Future<void> _handleLoadBalanceCardTap(BuildContext context) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      );

      // Get user session
      final session = await UserSessionDB.getSession();
      final userId = session?['user_id'] ?? '';

      if (userId.isEmpty) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User session not found')),
        );
        return;
      }

      // Use the new refresh method
      await RiderOrdersDB.refreshTransactionsFromAPI(userId);

      // Close loading dialog
      Navigator.pop(context);

      // Navigate to transaction history page
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const TransactionHistoryPage()),
        );
      }
    } catch (e) {
      // Close loading dialog
      Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load transaction history: $e')),
        );
      }
    }
  }
}

class _TopUpSheet extends StatefulWidget {
  const _TopUpSheet();

  @override
  State<_TopUpSheet> createState() => _TopUpSheetState();
}

class _TopUpSheetState extends State<_TopUpSheet> {
  final List<int> presets = [100, 200, 300, 400, 500, 1000];
  int? selectedAmount;
  final TextEditingController customController = TextEditingController();
  String? errorText;

  @override
  void dispose() {
    customController.dispose();
    super.dispose();
  }

  void _selectPreset(int amount) {
    setState(() {
      selectedAmount = amount;
      customController.text = amount.toString();
      errorText = null;
    });
  }

  void _onCustomChanged(String value) {
    final int? val = int.tryParse(value);
    setState(() {
      selectedAmount = val;
      if (val == null) {
        errorText = 'Enter a valid number';
      } else if (val < 100) {
        errorText = 'Minimum is ₱100';
      } else if (val > 1000) {
        errorText = 'Maximum is ₱1000';
      } else {
        errorText = null;
      }
    });
  }

  void _confirm() {
    if (selectedAmount == null) {
      setState(() => errorText = 'Please select or enter an amount');
      return;
    }
    if (selectedAmount! < 100 || selectedAmount! > 1000) {
      setState(() => errorText = 'Amount must be between ₱100 and ₱1000');
      return;
    }
    Navigator.pop(context, selectedAmount!);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Center(
            child: Text(
              'Top Up Load Balance',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5D8AA8),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: presets.map((amount) {
              final bool selected = selectedAmount == amount;
              return ChoiceChip(
                label: Text('₱$amount'),
                selected: selected,
                onSelected: (_) => _selectPreset(amount),
                selectedColor: const Color(0xFF5D8AA8),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF5D8AA8),
                  fontWeight: FontWeight.bold,
                ),
                backgroundColor: Colors.grey[100],
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: customController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Custom Amount',
              prefixText: '₱',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              errorText: errorText,
            ),
            onChanged: _onCustomChanged,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5D8AA8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _confirm,
              child: const Text('Confirm'),
            ),
          ),
        ],
      ),
    );
  }
}

class TransactionHistoryPage extends StatefulWidget {
  const TransactionHistoryPage({Key? key}) : super(key: key);

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _transactions = [];
  bool _isRefreshing = false;
  int _transactionCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchTransactions({bool showLoading = true}) async {
    if (_isRefreshing) return; // Prevent multiple simultaneous refreshes

    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    _isRefreshing = true;

    try {
      // Fetch transactions from local database
      final txs = await RiderOrdersDB.getLoadTransactions();
      final count = await RiderOrdersDB.getLoadTransactionsCount();

      if (mounted) {
        setState(() {
          _transactions = txs;
          _transactionCount = count;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load data: $e';
          _loading = false;
        });
      }
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _handleRefresh() async {
    try {
      // Show loading indicator
      setState(() {
        _loading = true;
        _error = null;
      });

      // Get user session
      final session = await UserSessionDB.getSession();
      final userId = session?['user_id'] ?? '';

      if (userId.isEmpty) {
        setState(() {
          _error = 'User session not found';
          _loading = false;
        });
        return;
      }

      // Use the new refresh method
      await RiderOrdersDB.refreshTransactionsFromAPI(userId);

      // Fetch from database to update UI
      await _fetchTransactions(showLoading: false);
    } catch (e) {
      setState(() {
        _error = 'Failed to refresh: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Transaction History'),
            if (_transactionCount > 0)
              Text(
                '$_transactionCount transaction${_transactionCount == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        backgroundColor: const Color(0xFF5D8AA8),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_error!,
                              style: const TextStyle(color: Colors.red)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _handleRefresh,
                            child: const Text('Try Again'),
                          ),
                        ],
                      ),
                    )
                  : _transactions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.receipt_long,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No transactions found',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Pull down to refresh or tap the button below',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: _handleRefresh,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Refresh from API'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF5D8AA8),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Column(
                            children: _transactions
                                .map((tx) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 16.0),
                                      child: _buildTransactionCard(tx),
                                    ))
                                .toList(),
                          ),
                        ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _handleRefresh,
        backgroundColor: const Color(0xFF5D8AA8),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh'),
        tooltip: 'Refresh from API',
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> tx) {
    // Format the date
    String formattedDate = 'N/A';
    try {
      if (tx['dateLoaded'] != null && tx['dateLoaded'].toString().isNotEmpty) {
        final date = DateTime.parse(tx['dateLoaded'].toString());
        formattedDate =
            '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      formattedDate = tx['dateLoaded']?.toString() ?? 'N/A';
    }

    // Format the amount
    String formattedAmount = '₱0.00';
    try {
      if (tx['amount'] != null) {
        final amount = double.tryParse(tx['amount'].toString()) ?? 0.0;
        formattedAmount = '₱${amount.toStringAsFixed(2)}';
      }
    } catch (e) {
      formattedAmount = '₱0.00';
    }

    // Get confirmation status
    final isConfirmed = tx['isConfirmed'] == 1 || tx['isConfirmed'] == true;
    final confirmationText = isConfirmed ? 'Confirmed' : 'Pending';
    final confirmationColor = isConfirmed ? Colors.green : Colors.orange;
    final isPending = !isConfirmed;

    return GestureDetector(
      onTap: isPending ? () => _handlePendingTransactionTap(tx) : null,
      child: Card(
        elevation: isPending ? 4 : 3,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: confirmationColor.withOpacity(0.2),
              width: isPending ? 2 : 1,
            ),
            // Add subtle gradient for pending transactions
            gradient: isPending
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      confirmationColor.withOpacity(0.05),
                      confirmationColor.withOpacity(0.02),
                    ],
                  )
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Reference Number and Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        tx['referenceNo']?.toString() ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isPending) ...[
                          const Icon(
                            Icons.touch_app,
                            size: 16,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: confirmationColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: confirmationColor.withOpacity(0.3)),
                          ),
                          child: Text(
                            confirmationText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: confirmationColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Amount (Highlighted)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5D8AA8).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF5D8AA8).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Amount:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        formattedAmount,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5D8AA8),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Date and Remarks in a grid layout
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildInfoRow('Date', formattedDate),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildInfoRow(
                          'Remarks', tx['remarks']?.toString() ?? 'N/A'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Handles tap on pending transaction to resume payment
  Future<void> _handlePendingTransactionTap(Map<String, dynamic> tx) async {
    try {
      // Show confirmation dialog
      final shouldResume = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Resume Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Resume payment for:'),
              const SizedBox(height: 8),
              Text(
                'Amount: ₱${(double.tryParse(tx['amount'].toString()) ?? 0.0).toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Reference: ${tx['referenceNo'] ?? 'N/A'}'),
              const SizedBox(height: 16),
              const Text(
                'This will open the payment page where you left off.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5D8AA8),
                foregroundColor: Colors.white,
              ),
              child: const Text('Resume Payment'),
            ),
          ],
        ),
      );

      if (shouldResume != true) return;

      // Get user session
      final session = await UserSessionDB.getSession();
      final riderId = session?['rider_id'] ?? '';
      final mobileNo = session?['mobile_no'] ?? '';
      final email = session?['email'] ?? '';

      if (riderId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User session not found')),
        );
        return;
      }

      // Get transaction details
      final referenceNo = tx['referenceNo']?.toString() ?? '';
      final amount = tx['amount']?.toString() ?? '0';

      if (referenceNo.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid transaction reference')),
        );
        return;
      }

      // Check if transaction is still valid
      final statusResp = await RiderOrdersService.postCheckRiderLoadStatus(
          loadRefNo: referenceNo, riderId: riderId);
      final status = statusResp['status']?.toString();

      if (status == '411' || status == 'cancelled') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This transaction is already paid or cancelled.'),
            backgroundColor: Colors.orange,
          ),
        );
        // Refresh transactions to update UI
        await _fetchTransactions(showLoading: false);
        return;
      }

      // Build payment URL
      final url =
          '${ApiConfig.paymentStartLoadPurchase}?Id=16&PROC_ID=GCSH&amount=$amount&PhoneNumber=$mobileNo&email=$email&LoadRefNo=$referenceNo';

      // Navigate to payment page with callback to refresh data
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentWebViewPage(
            paymentUrl: url,
            onPaymentComplete: () async {
              // Refresh data when payment is completed
              await _fetchTransactions(showLoading: false);
            },
          ),
        ),
      );

      // Refresh data after returning from payment page
      await _fetchTransactions(showLoading: false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to resume payment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _BalanceWarningBanner extends StatelessWidget {
  final double balance;
  final VoidCallback? onTap;

  const _BalanceWarningBanner({
    required this.balance,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border(
          bottom: BorderSide(
            color: Colors.orange.shade200,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange.shade700,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Low balance: ₱${balance.toStringAsFixed(2)}. Please top up to continue.',
              style: TextStyle(
                color: Colors.orange.shade900,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Top Up',
                style: TextStyle(
                  color: Colors.orange.shade900,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
