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
      title: 'Call Earning',
      subtitle: 'Recent answered call',
      amount: 300,
      icon: Icons.call_received_rounded,
    ),
  ];

  Future<void> _simulatePaymentReceived() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _PaymentReceivingDialog(),
    );

    if (!mounted) return;

    setState(() {
      _balance += 42;
      _transactions.insert(
        0,
        const _WalletTransaction(
          title: 'Payment Received',
          subtitle: 'Demo call payout credited',
          amount: 42,
          icon: Icons.payments_rounded,
        ),
      );
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Demo payment received: +42.00'),
        backgroundColor: Color(0xFF19A463),
      ),
    );
  }

  Future<void> _openWithdraw() async {
    final result = await showModalBottomSheet<_WithdrawResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WithdrawSheet(maxAmount: _balance),
    );

    if (!mounted || result == null) return;

    setState(() {
      _balance -= result.amount;
      _transactions.insert(
        0,
        _WalletTransaction(
          title: 'Payout Requested',
          subtitle: '${result.destination} transfer processing',
          amount: -result.amount,
          icon: Icons.account_balance_rounded,
        ),
      );
    });

    showDialog<void>(
      context: context,
      builder: (_) => _WalletNoticeDialog(
        title: 'Payout Started',
        message:
            '${result.amount.toStringAsFixed(2)} will be sent to ${result.destination}.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 28),
          _BalanceSection(
            balance: _balance,
            onReceiveDemoPayment: _simulatePaymentReceived,
            onWithdraw: _openWithdraw,
          ),
          const SizedBox(height: 26),
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
                      'Earning Activity',
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

class _WithdrawResult {
  final double amount;
  final String destination;

  const _WithdrawResult({required this.amount, required this.destination});
}

class _BalanceSection extends StatelessWidget {
  final double balance;
  final VoidCallback onReceiveDemoPayment;
  final VoidCallback onWithdraw;

  const _BalanceSection({
    required this.balance,
    required this.onReceiveDemoPayment,
    required this.onWithdraw,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const Text(
            'Earnings Balance',
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
              Flexible(
                child: Text(
                  balance.toStringAsFixed(2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 60,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _PillActionButton(
                  label: 'Receive Demo',
                  icon: Icons.call_received_rounded,
                  color: const Color(0xFF19A463),
                  onTap: onReceiveDemoPayment,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PillActionButton(
                  label: 'Withdraw',
                  icon: Icons.account_balance_wallet_rounded,
                  color: const Color(0xFF6E1BDB),
                  onTap: onWithdraw,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PillActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _PillActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.26),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 21),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WithdrawSheet extends StatefulWidget {
  final double maxAmount;

  const _WithdrawSheet({required this.maxAmount});

  @override
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<_WithdrawSheet> {
  final destinations = const ['UPI', 'Bank'];
  String _destination = 'UPI';
  double _amount = 100;
  bool _isProcessing = false;

  Future<void> _withdraw() async {
    if (_isProcessing) return;

    final amount = _amount.clamp(1, widget.maxAmount).toDouble();
    setState(() => _isProcessing = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;
    Navigator.of(
      context,
    ).pop(_WithdrawResult(amount: amount, destination: _destination));
  }

  @override
  Widget build(BuildContext context) {
    final maxAmount = widget.maxAmount <= 0 ? 1.0 : widget.maxAmount;
    final selectedAmount = _amount.clamp(1, maxAmount).toDouble();

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
              'Withdraw Earnings',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Demo payout request',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              selectedAmount.toStringAsFixed(0),
              style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w800),
            ),
            Slider(
              value: selectedAmount,
              min: 1,
              max: maxAmount,
              divisions: maxAmount.round().clamp(1, 20),
              activeColor: const Color(0xFF6E1BDB),
              onChanged: (value) => setState(() => _amount = value),
            ),
            Wrap(
              spacing: 10,
              children: destinations.map((destination) {
                final selected = destination == _destination;
                return ChoiceChip(
                  label: Text(destination),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _destination = destination);
                  },
                  selectedColor: const Color(0xFFEDE3FF),
                  labelStyle: TextStyle(
                    color: selected ? const Color(0xFF6E1BDB) : Colors.black87,
                    fontWeight: FontWeight.w700,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _withdraw,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _isProcessing ? 'Sending...' : 'Request Demo Payout',
                ),
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

class _PaymentReceivingDialog extends StatefulWidget {
  const _PaymentReceivingDialog();

  @override
  State<_PaymentReceivingDialog> createState() =>
      _PaymentReceivingDialogState();
}

class _PaymentReceivingDialogState extends State<_PaymentReceivingDialog> {
  bool _complete = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 850), () {
      if (mounted) setState(() => _complete = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: CircleAvatar(
        radius: 30,
        backgroundColor: _complete
            ? const Color(0xFFE7F8ED)
            : const Color(0xFFF1EAFF),
        child: _complete
            ? const Icon(
                Icons.check_rounded,
                color: Color(0xFF19A463),
                size: 36,
              )
            : const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
      ),
      title: Text(
        _complete ? 'Payment Received' : 'Receiving Payment',
        textAlign: TextAlign.center,
      ),
      content: Text(
        _complete
            ? 'A demo call earning was credited to your wallet.'
            : 'Matching completed call and wallet credit...',
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: _complete ? () => Navigator.of(context).pop() : null,
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

class _WalletNoticeDialog extends StatelessWidget {
  final String title;
  final String message;

  const _WalletNoticeDialog({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: const CircleAvatar(
        radius: 28,
        backgroundColor: Color(0xFFF1EAFF),
        child: Icon(Icons.schedule_rounded, color: Color(0xFF6E1BDB), size: 32),
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
