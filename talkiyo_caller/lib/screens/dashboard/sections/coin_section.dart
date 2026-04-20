import 'package:flutter/material.dart';

class CoinSection extends StatelessWidget {
  CoinSection({super.key});

  final List<Map<String, String>> coins = [
    {'name': '100 Coins', 'value': '₹50', 'assets': 'assets/coin1.png'},
    {'name': '200 Coins', 'value': '₹100', 'assets': 'assets/coin2.png'},
    {'name': '300 Coins', 'value': '₹150', 'assets': 'assets/coin3.png'},
    {'name': '400 Coins', 'value': '₹200', 'assets': 'assets/coin4.png'},
    {'name': '500 Coins', 'value': '₹250', 'assets': 'assets/coin5.png'},
    {'name': '600 Coins', 'value': '₹300', 'assets': 'assets/coin6.png'},
    {'name': '700 Coins', 'value': '₹350', 'assets': 'assets/coin7.png'},
    {'name': '800 Coins', 'value': '₹400', 'assets': 'assets/coin8.png'},
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
                color: Colors.black.withOpacity(_pressed ? 0.05 : 0.10),
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
            ],
          ),
        ),
      ),
    );
  }
}
