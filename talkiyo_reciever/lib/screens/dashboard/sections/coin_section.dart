import 'package:flutter/material.dart';

class CoinSection extends StatelessWidget {
  CoinSection({super.key});

  final List<Map<String, String>> coins = [
    {'name': 'Today', 'value': '₹0', 'assets': 'assets/coin1.png'},
    {'name': 'This Week', 'value': '₹0', 'assets': 'assets/coin2.png'},
    {'name': 'This Month', 'value': '₹0', 'assets': 'assets/coin3.png'},
    {'name': 'Answered', 'value': '0 calls', 'assets': 'assets/coin4.png'},
    {'name': 'Rate', 'value': '2/sec', 'assets': 'assets/coin5.png'},
    {'name': 'Payout', 'value': 'Ready', 'assets': 'assets/coin6.png'},
  ];

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
          onTap: () {
            debugPrint('Clicked ${coin['name']}');
          },
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
                  fontSize: 13,
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
