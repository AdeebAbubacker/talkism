import 'package:flutter/material.dart';

class CoinSection extends StatefulWidget {
  const CoinSection({super.key});

  @override
  State<CoinSection> createState() => _CoinSectionState();
}

class _CoinSectionState extends State<CoinSection> {
  final List<Map<String, String>> coins = const [
    {'name': '100 Coins', 'value': '₹50', 'assets': 'assets/coin1.png'},
    {'name': '200 Coins', 'value': '₹100', 'assets': 'assets/coin2.png'},
    {'name': '300 Coins', 'value': '₹150', 'assets': 'assets/coin3.png'},
    {'name': '400 Coins', 'value': '₹200', 'assets': 'assets/coin4.png'},
    {'name': '500 Coins', 'value': '₹250', 'assets': 'assets/coin5.png'},
    {'name': '600 Coins', 'value': '₹300', 'assets': 'assets/coin6.png'},
    {'name': '700 Coins', 'value': '₹350', 'assets': 'assets/coin7.png'},
    {'name': '800 Coins', 'value': '₹400', 'assets': 'assets/coin8.png'},
  ];

  Future<void> _openPaymentSheet(Map<String, String> coin) async {
    final purchased = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _DummyPaymentSheet(coinName: coin['name']!, price: coin['value']!),
    );

    if (!mounted || purchased != true) return;

    showDialog<void>(
      context: context,
      builder: (_) => _PaymentSuccessDialog(
        title: 'Coins Added',
        message: '${coin['name']} added to your demo wallet.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: coins.length,
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.9,
      ),
      itemBuilder: (context, index) {
        final coin = coins[index];
        return _CoinTile(
          name: coin['name']!,
          value: coin['value']!,
          asset: coin['assets']!,
          onTap: () => _openPaymentSheet(coin),
        );
      },
    );
  }
}

class _CoinTile extends StatefulWidget {
  final String name;
  final String value;
  final String asset;
  final VoidCallback onTap;

  const _CoinTile({
    required this.name,
    required this.value,
    required this.asset,
    required this.onTap,
  });

  @override
  State<_CoinTile> createState() => _CoinTileState();
}

class _CoinTileState extends State<_CoinTile> {
  bool _pressed = false;

  void _handleTapDown(TapDownDetails details) {
    setState(() {
      _pressed = true;
    });
  }

  void _handleTapCancel() {
    setState(() {
      _pressed = false;
    });
  }

  Future<void> _handleTapUp(TapUpDetails details) async {
    setState(() {
      _pressed = false;
    });
    widget.onTap();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.93 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _pressed ? 0.05 : 0.10),
                blurRadius: _pressed ? 4 : 8,
                offset: Offset(0, _pressed ? 2 : 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(child: Image.asset(widget.asset, fit: BoxFit.contain)),
              const SizedBox(height: 6),
              Text(
                widget.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF7E3DFF),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DummyPaymentSheet extends StatefulWidget {
  final String coinName;
  final String price;

  const _DummyPaymentSheet({required this.coinName, required this.price});

  @override
  State<_DummyPaymentSheet> createState() => _DummyPaymentSheetState();
}

class _DummyPaymentSheetState extends State<_DummyPaymentSheet> {
  final methods = const ['UPI', 'Card', 'Wallet'];
  String _method = 'UPI';
  bool _isPaying = false;

  Future<void> _pay() async {
    if (_isPaying) return;

    setState(() => _isPaying = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;
    Navigator.of(context).pop(true);
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
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4C5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.monetization_on,
                    color: Color(0xFFF1A000),
                    size: 30,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.coinName,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Checkout - ${widget.price}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              children: methods.map((method) {
                final selected = method == _method;
                return ChoiceChip(
                  label: Text(method),
                  selected: selected,
                  onSelected: (_) => setState(() => _method = method),
                  selectedColor: const Color(0xFFEDE3FF),
                  labelStyle: TextStyle(
                    color: selected ? const Color(0xFF6E1BDB) : Colors.black87,
                    fontWeight: FontWeight.w700,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            _SummaryRow(label: 'Pack', value: widget.coinName),
            _SummaryRow(label: 'Payment', value: _method),
            _SummaryRow(label: 'Total', value: widget.price),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isPaying ? null : _pay,
                icon: _isPaying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_rounded),
                label: Text(_isPaying ? 'Processing...' : 'Pay Securely'),
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

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _PaymentSuccessDialog extends StatelessWidget {
  final String title;
  final String message;

  const _PaymentSuccessDialog({required this.title, required this.message});

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
