import 'package:flutter/material.dart';

class CardWidget extends StatelessWidget {
  final String value; // e.g., '2', '10', 'j', 'q', 'k', 'a'
  final bool isJoker; // true if this is a joker card
  final bool isCardBack; // true if this is the card back
  final bool isPrize; // true if this is a prize card
  final String? cardBackAsset; // optional per-instance card back asset

  // Default asset used for card backs; can be changed at runtime.
  static String defaultCardBackAsset = 'assets/images/cardback.png';

  const CardWidget({
    super.key,
    this.value = '',
    this.isJoker = false,
    this.isCardBack = false,
    this.isPrize = false,
    this.cardBackAsset,
  });

  @override
  Widget build(BuildContext context) {
    String assetName;

    if (isCardBack) {
      assetName = cardBackAsset ?? CardWidget.defaultCardBackAsset;
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

