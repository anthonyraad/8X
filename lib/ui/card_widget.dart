import 'package:flutter/material.dart';

class CardWidget extends StatelessWidget {
  final String value; // e.g., '2', '10', 'j', 'q', 'k', 'a'
  final bool isJoker; // true if this is a joker card
  final bool isCardBack; // true if this is the card back
  final bool isPrize; // true if this is a prize card

  const CardWidget({
    super.key,
    this.value = '',
    this.isJoker = false,
    this.isCardBack = false,
    this.isPrize = false,
  });

  @override
  Widget build(BuildContext context) {
    String assetName;

    if (isCardBack) {
      assetName = 'assets/images/cardback.png';
    } else if (isPrize) {
      assetName = 'assets/images/prize.png';
    } else if (isJoker) {
      assetName = 'assets/images/jkr.png';
    } else {
      assetName = 'assets/images/${value.toLowerCase()}.png';
    }

    return Image.asset(
      assetName,
      width: 100,
      height: 150,
      fit: BoxFit.contain,
    );
  }
}

