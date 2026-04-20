import 'package:flutter/material.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  double _balance = 300;
  final List<_WalletTransaction> _transactions = [
    const _WalletTransaction(
      title: 'Bonus',
      subtitle: 'April 16 2026, 9:55 AM',
      amount: 300,
      icon: Icons.card_giftcard_rounded,
    ),
  ];

  Future<void> _openRecharge() async {
    final result = await showModalBottomSheet<_RechargeResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _RechargeSheet(),
    );

    if (!mounted || result == null) return;

    setState(() {
      _balance += result.coins;
      _transactions.insert(
        0,
        _WalletTransaction(
          title: 'Wallet Recharge',
          subtitle: '${result.method} payment completed',
          amount: result.coins,
          icon: Icons.account_balance_wallet_rounded,
        ),
      );
    });

    showDialog<void>(
      context: context,
      builder: (_) => _WalletSuccessDialog(
        title: 'Recharge Complete',
        message: '+${result.coins.toStringAsFixed(0)} coins added to wallet.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 28),
          _BalanceSection(balance: _balance, onRecharge: _openRecharge),
          const SizedBox(height: 30),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFF2F2F2),
                borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
              ),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 30, 20, 34),
                itemCount: _transactions.length + 1,
                separatorBuilder: (_, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return const Text(
                      'Wallet Activity',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    );
                  }

                  return _TransactionTile(
                    transaction: _transactions[index - 1],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletTransaction {
  final String title;
  final String subtitle;
  final double amount;
  final IconData icon;

  const _WalletTransaction({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.icon,
  });
}

class _RechargeResult {
  final double coins;
  final String method;

  const _RechargeResult({required this.coins, required this.method});
}

class _BalanceSection extends StatelessWidget {
  final double balance;
  final VoidCallback onRecharge;

  const _BalanceSection({required this.balance, required this.onRecharge});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Coin Balance',
          style: TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _CoinBadge(size: 52),
            const SizedBox(width: 12),
            Text(
              balance.toStringAsFixed(2),
              style: const TextStyle(
                color: Colors.black,
                fontSize: 60,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        InkWell(
          onTap: onRecharge,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFB964FF), Color(0xFF6E1BDB)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.24),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_card_rounded, color: Colors.white, size: 22),
                SizedBox(width: 8),
                Text(
                  'Recharge Wallet',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RechargeSheet extends StatefulWidget {
  const _RechargeSheet();

  @override
  State<_RechargeSheet> createState() => _RechargeSheetState();
}

class _RechargeSheetState extends State<_RechargeSheet> {
  final amounts = const [100.0, 300.0, 600.0];
  final methods = const ['UPI', 'Card', 'Netbanking'];
  double _selectedAmount = 300;
  String _method = 'UPI';
  bool _isProcessing = false;

  Future<void> _completePayment() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);
    await Future<void>.delayed(const Duration(milliseconds: 950));

    if (!mounted) return;
    Navigator.of(
      context,
    ).pop(_RechargeResult(coins: _selectedAmount, method: _method));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recharge Wallet',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Dummy payment for app preview',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: amounts.map((amount) {
                final selected = amount == _selectedAmount;
                return ChoiceChip(
                  label: Text('${amount.toStringAsFixed(0)} coins'),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedAmount = amount),
                  selectedColor: const Color(0xFFEDE3FF),
                  labelStyle: TextStyle(
                    color: selected ? const Color(0xFF6E1BDB) : Colors.black87,
                    fontWeight: FontWeight.w700,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              children: methods.map((method) {
                final selected = method == _method;
                return ChoiceChip(
                  label: Text(method),
                  selected: selected,
                  onSelected: (_) => setState(() => _method = method),
                  selectedColor: const Color(0xFFE7F8ED),
                  labelStyle: TextStyle(
                    color: selected ? const Color(0xFF19A463) : Colors.black87,
                    fontWeight: FontWeight.w700,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F4FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.receipt_long_rounded,
                    color: Color(0xFF6E1BDB),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pay ₹${(_selectedAmount / 2).toStringAsFixed(0)} with $_method',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _completePayment,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.payment_rounded),
                label: Text(_isProcessing ? 'Processing...' : 'Pay Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6E1BDB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final _WalletTransaction transaction;

  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.amount >= 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            height: 74,
            width: 74,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              transaction.icon,
              size: 36,
              color: const Color(0xFF232323),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  transaction.subtitle,
                  style: const TextStyle(
                    color: Color(0xFF808080),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isCredit ? '+' : '-'}${transaction.amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              color: isCredit ? const Color(0xFF27B332) : Colors.red,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletSuccessDialog extends StatelessWidget {
  final String title;
  final String message;

  const _WalletSuccessDialog({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: const CircleAvatar(
        radius: 28,
        backgroundColor: Color(0xFFE7F8ED),
        child: Icon(Icons.check_rounded, color: Color(0xFF19A463), size: 34),
      ),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(message, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _CoinBadge extends StatelessWidget {
  final double size;

  const _CoinBadge({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF1A5), Color(0xFFF9A602)],
        ),
      ),
      child: Center(
        child: Container(
          height: size * 0.72,
          width: size * 0.72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFFFD45D), width: 2),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFD35A), Color(0xFFF18A00)],
            ),
          ),
          child: Center(
            child: Text(
              '₹',
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.34,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
