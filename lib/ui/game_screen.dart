import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:async';
import 'card_widget.dart';
import 'package:audioplayers/audioplayers.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late List<String> fullDeck;
  late List<String> playerDeck;
  late List<String> opponentDeck;
  late List<String> playerHand;
  late List<String> opponentHand;
  late List<String> playerPrizeCards;
  late List<String> opponentPrizeCards;
  late List<String> playerDrawPile;
  late List<String> opponentDrawPile;
  List<String> field = [];
  List<String> activityLog = [];

  int aiDifficulty = 1; // 1 = Easy, 2 = Medium, 3 = Hard
  int winStreak = 0;

  bool isPlayerTurn = true;
  bool gameOver = false;
  bool showInitialOverlay = true; // NEW: Track initial overlay state
  bool showRules = false;
  String message = '';
  List<int> selectedIndices = [];
  List<String> selectedOps = [];
  int playerMaxHandSize = 2;
  Timer? turnTimer;
  int timerSeconds = 8;

  String? winner; // 'player', 'opponent', or null

  final AudioPlayer _audioPlayer = AudioPlayer();

  // --- NEW: Track the value of the Ace on the field ---
  int? fieldAceValue; // null if not an Ace, 1 or 14 if Ace

  // --- Defensive Helper Methods ---

  /// Safely removes cards from hand using indices in reverse order
  void safeRemoveFromHand(
    List<String> hand,
    List<int> indices,
    String handName,
  ) {
    // Validate all indices first
    for (int i = 0; i < indices.length; i++) {
      if (indices[i] < 0 || indices[i] >= hand.length) {
        print(
          'ERROR: Index ${indices[i]} out of bounds for $handName (length: ${hand.length})',
        );
        return; // Don't proceed if any index is invalid
      }
    }

    // Sort indices in descending order to maintain validity during removal
    List<int> sortedIndices = List.from(indices)
      ..sort((a, b) => b.compareTo(a));

    // Remove cards
    for (int index in sortedIndices) {
      hand.removeAt(index);
    }
  }

  /// Safely accesses list elements with bounds checking
  T? safeListAccess<T>(List<T> list, int index, [String? listName]) {
    if (index < 0 || index >= list.length) {
      if (listName != null) {
        print(
          'WARNING: Index $index out of bounds for $listName (length: ${list.length})',
        );
      }
      return null;
    }
    return list[index];
  }

  /// Validates that selectedIndices and selectedOps are in sync
  bool validateSelections() {
    // Check bounds
    for (int i = 0; i < selectedIndices.length; i++) {
      if (selectedIndices[i] < 0 || selectedIndices[i] >= playerHand.length) {
        print(
          'Invalid selectedIndices[$i]: ${selectedIndices[i]} (hand length: ${playerHand.length})',
        );
        return false;
      }
    }

    // Check operation count
    int expectedOpsCount = selectedIndices.length > 1
        ? selectedIndices.length - 1
        : 0;
    if (selectedOps.length != expectedOpsCount) {
      print(
        'selectedOps length mismatch: ${selectedOps.length} vs expected $expectedOpsCount',
      );
      return false;
    }

    return true;
  }

  /// Safe card drawing that handles empty piles
  void safeDrawCards(List<String> hand, List<String> drawPile, int targetSize) {
    while (hand.length < targetSize && drawPile.isNotEmpty) {
      try {
        hand.add(drawPile.removeAt(0));
      } catch (e) {
        print('Error drawing card: $e');
        break;
      }
    }
  }

  void clearSelections() {
    selectedIndices.clear();
    selectedOps.clear();
  }

  bool isSelectionValidForPlay() {
    if (selectedIndices.isEmpty) return false;
    if (!selectedIndices.every((i) => i >= 0 && i < playerHand.length)) {
      return false;
    }
    if (selectedOps.length != selectedIndices.length - 1 &&
        selectedIndices.length > 1) {
      return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    // Make fullscreen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _setupGame();
  }

  @override
  void dispose() {
    turnTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Widget buildDifficultySelector({required bool isMobile}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 6 : 8,
        vertical: isMobile ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 3,
            offset: const Offset(1, 1),
          ),
        ],
        border: Border.all(
          color: const Color.fromARGB(153, 255, 214, 64).withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.tune, color: Colors.amberAccent, size: 15),
          SizedBox(width: isMobile ? 3 : 5),
          Text(
            'Skill:',
            style: TextStyle(
              color: const Color.fromARGB(192, 255, 214, 64),
              fontWeight: FontWeight.w500,
              fontSize: isMobile ? 9 : 11,
              letterSpacing: 0.7,
            ),
          ),
          SizedBox(width: isMobile ? 5 : 7),
          DropdownButton<int>(
            value: aiDifficulty,
            dropdownColor: Colors.black87,
            style: const TextStyle(
              color: Color.fromARGB(202, 255, 214, 64),
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
            underline: SizedBox.shrink(),
            icon: const Icon(
              Icons.arrow_drop_down,
              color: Colors.amberAccent,
              size: 15,
            ),
            items: const [
              DropdownMenuItem(value: 1, child: Text('Dull')),
              DropdownMenuItem(value: 2, child: Text('Keen')),
              DropdownMenuItem(value: 3, child: Text('Sharp')),
            ],
            onChanged: (value) {
              setState(() {
                aiDifficulty = value!;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget buildWinStreak({required bool isMobile}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.content_cut_sharp,
          color: Color.fromARGB(255, 0, 255, 149),
          size: 18,
        ),
        SizedBox(width: isMobile ? 4 : 6),
        Text(
          'Streak: $winStreak',
          style: TextStyle(
            color: const Color.fromARGB(255, 58, 255, 196),
            fontWeight: FontWeight.bold,
            fontSize: isMobile ? 12 : 15,
          ),
        ),
      ],
    );
  }

  void _setupGame() {
    fullDeck = [];
    for (var value in [
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      '10',
      'j',
      'q',
      'k',
      'a',
    ]) {
      for (int i = 0; i < 4; i++) {
        fullDeck.add(value);
      }
    }
    fullDeck.add('jkr');
    fullDeck.add('jkr');

    fullDeck.shuffle(Random());
    playerDeck = fullDeck.sublist(0, 27);
    opponentDeck = fullDeck.sublist(27, 54);

    playerPrizeCards = playerDeck.sublist(0, 3);
    opponentPrizeCards = opponentDeck.sublist(0, 3);

    playerHand = playerDeck.sublist(3, 5);
    opponentHand = opponentDeck.sublist(3, 5);

    playerDrawPile = playerDeck.sublist(5);
    opponentDrawPile = opponentDeck.sublist(5);

    field = [];
    activityLog.clear(); // Add this line
    fieldAceValue = null;
    isPlayerTurn = true;
    gameOver = false;
    message = "Your turn!";
    clearSelections();
    setState(() {});
    playerMaxHandSize = 2;

    // Don't start timer if showing initial overlay
    if (!showInitialOverlay) {
      turnTimer?.cancel();
      startTimer();
    }
  }

  double cardValue(String card, {int? aceOverride}) {
    if (card == 'jkr') return 0.5;
    if (card == 'j') return 11;
    if (card == 'q') return 12;
    if (card == 'k') return 13;
    if (card == 'a') return aceOverride?.toDouble() ?? 14;
    return double.tryParse(card) ?? 0;
  }

  String buildPlayDescription(List<String> cards, List<String> ops) {
    if (cards.isEmpty) return '';
    String result = cardValue(cards[0]).toString().replaceAll('.0', '');
    for (int i = 1; i < cards.length; i++) {
      if (i - 1 < ops.length) {
        result +=
            ' ${ops[i - 1]} ${cardValue(cards[i]).toString().replaceAll('.0', '')}';
      } else {
        result += ' ${cardValue(cards[i]).toString().replaceAll('.0', '')}';
      }
    }
    return result;
  }

  // --- UPDATED: Add fieldAceValue as an optional named parameter ---
  bool isValidPlay(
    List<String> playedCards,
    List<String> ops,
    String lastFieldCard,
    List<int>? aceOverrides, {
    int? fieldAceValue,
  }) {
    aceOverrides = aceOverrides ?? [];

    if (playedCards.isEmpty || playedCards.length > 3) return false;
    if (playedCards.length > 1 && ops.length != playedCards.length - 1) {
      return false;
    }

    List<double> values = [];
    int aceIdx = 0;
    for (int i = 0; i < playedCards.length; i++) {
      if (playedCards[i] == 'a') {
        int aceValue = 14;
        if (aceIdx < aceOverrides.length) {
          aceValue = aceOverrides[aceIdx];
        }
        values.add(cardValue('a', aceOverride: aceValue));
        aceIdx++;
      } else {
        values.add(cardValue(playedCards[i]));
      }
    }

    // Ensure the smallest value card is last (top of field stack)
    double minValue = values.reduce(min);
    int minIdx = values.indexOf(minValue);
    if (minIdx != values.length - 1) {
      // Move the smallest value card to the end
      String tempCard = playedCards[minIdx];
      playedCards.removeAt(minIdx);
      playedCards.add(tempCard);

      // Also reorder aceOverrides if needed
      if (playedCards[playedCards.length - 1] == 'a' &&
          aceOverrides.isNotEmpty &&
          minIdx < aceOverrides.length) {
        int tempAce = aceOverrides[minIdx];
        aceOverrides.removeAt(minIdx);
        aceOverrides.add(tempAce);
      }
      // Rebuild values to match new order
      values = [];
      aceIdx = 0;
      for (int i = 0; i < playedCards.length; i++) {
        if (playedCards[i] == 'a') {
          int aceValue = 14;
          if (aceIdx < aceOverrides.length) {
            aceValue = aceOverrides[aceIdx];
          }
          values.add(cardValue('a', aceOverride: aceValue));
          aceIdx++;
        } else {
          values.add(cardValue(playedCards[i]));
        }
      }
    }

    double result = values[0];
    for (int i = 1; i < values.length; i++) {
      if (i - 1 < ops.length && ops[i - 1] == '+') {
        result += values[i];
      } else if (i - 1 < ops.length) {
        result -= values[i];
      }
      // If ops doesn't have enough elements, skip the operation
    }

    // --- UPDATED: Use fieldAceValue if the field card is an Ace ---
    double lastVal;
    if (lastFieldCard == 'a' && fieldAceValue != null) {
      lastVal = cardValue('a', aceOverride: fieldAceValue);
    } else {
      lastVal = cardValue(lastFieldCard);
    }

    return (result == lastVal * 2) || (result == lastVal / 2);
  }

  void checkForWin() {
    if (playerPrizeCards.isEmpty) {
      setState(() {
        message = "You win!";
        isPlayerTurn = false;
        gameOver = true;
        winner = 'player';
        if (aiDifficulty == 3) {
          winStreak += 1;
        }
        clearSelections();
      });
      turnTimer?.cancel();
      // Add a small delay before playing sound
      Future.delayed(const Duration(milliseconds: 100), () {
        playGameWinSound();
      });
    } else if (opponentPrizeCards.isEmpty) {
      setState(() {
        message = "Opponent wins!";
        isPlayerTurn = false;
        gameOver = true;
        winner = 'opponent';
        winStreak = 0;
        clearSelections();
      });
      turnTimer?.cancel();
      Future.delayed(const Duration(milliseconds: 100), () {
        playGameLossSound();
      });
    }
  }

  Future<void> playCardSound() async {
    try {
      await _audioPlayer.stop(); // Stop any current sound
      await _audioPlayer.play(AssetSource('sounds/cardplay.mp3'));
      print('Card sound played');
    } catch (e) {
      print('Error playing card sound: $e');
    }
  }

  Future<void> playPrizeCardSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/winplay.mp3'));
      print('Prize card sound played');
    } catch (e) {
      print('Error playing prize card sound: $e');
    }
  }

  Future<void> playGameWinSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/gamewin.mp3'));
      print('Game win sound played');
    } catch (e) {
      print('Error playing game win sound: $e');
    }
  }

  Future<void> playGameLossSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/gameloss.mp3'));
      print('Game loss sound played');
    } catch (e) {
      print('Error playing game loss sound: $e');
    }
  }

  void startTimer() {
    turnTimer?.cancel();

    // Set timerSeconds based on difficulty
    if (aiDifficulty == 1) {
      timerSeconds = 10; // Dull
    } else if (aiDifficulty == 2) {
      timerSeconds = 8; // Keen
    } else {
      timerSeconds = 6; // Sharp
    }

    setState(() {}); // Update UI if needed

    turnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        timerSeconds--;
      });
      if (timerSeconds <= 0) {
        turnTimer?.cancel();
        if (isPlayerTurn && !gameOver) {
          handlePlayerTimeout();
        } else if (!isPlayerTurn && !gameOver) {
          handleOpponentTimeout();
        }
      }
    });
  }

  void handlePlayerTimeout() {
    setState(() {
      message = "Time's up!";
      if (opponentPrizeCards.isNotEmpty) {
        opponentPrizeCards.removeLast();
        print('Opponent wins a prize card due to timeout!');
        playPrizeCardSound(); // Add sound for timeout penalty
        checkForWin();
      }
      isPlayerTurn = false;
      clearSelections();
    });
    if (!gameOver) {
      Future.delayed(const Duration(seconds: 1), opponentTurn);
    }
  }

  void handleOpponentTimeout() {
    setState(() {
      message = "Opponent timed out! You draw a prize card.";
      if (playerPrizeCards.length < 3) {
        playerPrizeCards.add('prize');
        playPrizeCardSound(); // Add sound when player gets penalty prize
      }
      isPlayerTurn = true;
    });
    startTimer();
  }

  Future<List<int>> promptForAceValues(List<String> playedCards) async {
    List<int> aceOverrides = [];
    for (var card in playedCards) {
      if (card == 'a') {
        int? aceValue = await showDialog<int>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.black.withOpacity(0.9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Colors.amberAccent, width: 1.5),
            ),
            title: const Text(
              'Choose Value',
              textAlign: TextAlign.center, // Center the title
              style: TextStyle(
                color: Colors.amberAccent,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 1.1,
              ),
            ),
            content: const Text(
              '1 or 14?',
              textAlign: TextAlign.center, // Center the content
              style: TextStyle(color: Colors.white70, fontSize: 15),
            ),
            actionsAlignment: MainAxisAlignment.spaceEvenly,
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.grey[900],
                  foregroundColor: Colors.amberAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(1),
                child: const Text(
                  '1',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.grey[900],
                  foregroundColor: Colors.amberAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(14),
                child: const Text(
                  '14',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        );
        aceOverrides.add(aceValue ?? 14);
      }
    }
    int aceCount = playedCards.where((c) => c == 'a').length;
    while (aceOverrides.length < aceCount) {
      aceOverrides.add(14);
    }
    return aceOverrides;
  }

  Future<void> playSelectedCards() async {
    if (!isPlayerTurn || gameOver || selectedIndices.isEmpty) return;

    turnTimer?.cancel();

    // Defensive: Remove any invalid indices before playing
    selectedIndices.removeWhere((i) => i < 0 || i >= playerHand.length);

    // If after sanitizing, the selection is not valid, bail out
    if (!isSelectionValidForPlay()) {
      print(
        'Invalid selection: $selectedIndices for playerHand of length ${playerHand.length}',
      );
      clearSelections();
      return;
    }

    List<String> playedCards = selectedIndices
        .map((i) => playerHand[i])
        .toList();
    List<int> aceOverrides = await promptForAceValues(playedCards);

    // CRITICAL: Re-validate after async dialog - hand may have changed!
    if (!isPlayerTurn || gameOver) {
      print('Game state changed during ace selection, canceling play');
      clearSelections();
      return;
    }

    // Re-validate indices after the async operation
    List<int> originalIndices = List.from(selectedIndices);
    selectedIndices.removeWhere((i) => i < 0 || i >= playerHand.length);

    if (selectedIndices.isEmpty) {
      print(
        'All selections became invalid during ace selection (hand length: ${playerHand.length}, original indices: $originalIndices)',
      );
      clearSelections();
      return;
    }

    if (selectedIndices.length != originalIndices.length) {
      print(
        'Some selections became invalid during ace selection, clearing all selections for safety',
      );
      clearSelections();
      return;
    }

    // Final validation before proceeding
    for (int i = 0; i < selectedIndices.length; i++) {
      if (selectedIndices[i] < 0 || selectedIndices[i] >= playerHand.length) {
        print(
          'FINAL VALIDATION FAILED: selectedIndices[$i]=${selectedIndices[i]} out of bounds for hand length ${playerHand.length}',
        );
        clearSelections();
        return;
      }
    }

    // Rebuild playedCards with current valid indices
    playedCards = selectedIndices.map((i) => playerHand[i]).toList();

    // Ensure selectedOps has the correct number of operations for the number of cards selected
    while (selectedOps.length < selectedIndices.length - 1) {
      selectedOps.add('+');
    }
    while (selectedOps.length > selectedIndices.length - 1) {
      selectedOps.removeLast();
    }

    print('DEBUG: playedCards: $playedCards');
    print('DEBUG: selectedOps: $selectedOps');
    print('DEBUG: selectedIndices: $selectedIndices');
    print('DEBUG: playerHand.length: ${playerHand.length}');

    // SAVE the selectedOps BEFORE clearing selections
    List<String> savedSelectedOps = List.from(selectedOps);

    setState(() {
      if (field.isEmpty) {
        // Final safety check inside setState with detailed logging
        for (int i = 0; i < selectedIndices.length; i++) {
          if (selectedIndices[i] < 0 ||
              selectedIndices[i] >= playerHand.length) {
            print(
              'SETSTATE VALIDATION FAILED: selectedIndices[$i]=${selectedIndices[i]}, playerHand.length=${playerHand.length}',
            );
            clearSelections();
            return;
          }
        }

        // Store the actual cards to remove before any modifications
        List<String> cardsToRemove = [];
        List<int> validatedIndices = [];

        // Double-validation: build list of cards to remove with bounds checking
        for (int index in selectedIndices) {
          if (index >= 0 && index < playerHand.length) {
            cardsToRemove.add(playerHand[index]);
            validatedIndices.add(index);
          } else {
            print(
              'ERROR: Index $index is invalid for playerHand length ${playerHand.length}',
            );
            clearSelections();
            return;
          }
        }

        // Remove cards in descending order to maintain index validity
        validatedIndices.sort((a, b) => b.compareTo(a));
        for (int index in validatedIndices) {
          if (index >= 0 && index < playerHand.length) {
            playerHand.removeAt(index);
          } else {
            print(
              'CRITICAL ERROR: Index became invalid during removal: $index',
            );
            break;
          }
        }

        // Clear selections AFTER removing cards
        clearSelections();

        // Add cards to field in order (playedCards reordered by isValidPlay)
        for (var card in playedCards) {
          field.add(card);
        }
        // --- NEW: Track Ace value if last card is Ace ---
        if (field.isNotEmpty && field.last == 'a') {
          if (playedCards.isNotEmpty &&
              playedCards.last == 'a' &&
              aceOverrides.isNotEmpty) {
            fieldAceValue = aceOverrides.last;
          } else {
            fieldAceValue = 14;
          }
        } else {
          fieldAceValue = null;
        }

        // Add to activity log
        List<String> localSelectedOps = List.from(savedSelectedOps);
        String playDescription =
            'You played ${playedCards.asMap().entries.map((entry) {
              int i = entry.key;
              String card = entry.value;
              String cardNum = cardValue(card).toString().replaceAll('.0', '');
              if (i == 0) return cardNum;
              if (localSelectedOps.isEmpty || (i - 1) >= localSelectedOps.length || (i - 1) < 0) return ' $cardNum';
              return ' ${localSelectedOps[i - 1]} $cardNum';
            }).join('')}';

        activityLog.add(playDescription);

        playCardSound();
        message = "Opponent's turn!";
        isPlayerTurn = false;
        safeDrawCards(playerHand, playerDrawPile, 2);
        playerMaxHandSize = 2;
        Future.delayed(const Duration(seconds: 1), opponentTurn);
      } else {
        // Final safety check inside setState for non-empty field case
        for (int i = 0; i < selectedIndices.length; i++) {
          if (selectedIndices[i] < 0 ||
              selectedIndices[i] >= playerHand.length) {
            print(
              'SETSTATE VALIDATION FAILED (non-empty field): selectedIndices[$i]=${selectedIndices[i]}, playerHand.length=${playerHand.length}',
            );
            clearSelections();
            return;
          }
        }

        String prevFieldCard;
        if (field.isNotEmpty) {
          prevFieldCard = field.last;
        } else if (playedCards.isNotEmpty) {
          prevFieldCard = playedCards.first;
        } else {
          prevFieldCard = '2'; // fallback to a valid card value
        }
        // --- NEW: Use fieldAceValue when calling isValidPlay ---
        if (isValidPlay(
          playedCards,
          selectedOps,
          prevFieldCard,
          aceOverrides,
          fieldAceValue: fieldAceValue,
        )) {
          // Store the actual cards to remove before any modifications
          List<String> cardsToRemove = [];
          List<int> validatedIndices = [];

          // Double-validation: build list of cards to remove with bounds checking
          for (int index in selectedIndices) {
            if (index >= 0 && index < playerHand.length) {
              cardsToRemove.add(playerHand[index]);
              validatedIndices.add(index);
            } else {
              print(
                'ERROR: Index $index is invalid for playerHand length ${playerHand.length} during valid play',
              );
              clearSelections();
              return;
            }
          }

          // Remove cards in descending order to maintain index validity
          validatedIndices.sort((a, b) => b.compareTo(a));
          for (int index in validatedIndices) {
            if (index >= 0 && index < playerHand.length) {
              playerHand.removeAt(index);
            } else {
              print(
                'CRITICAL ERROR: Index became invalid during valid play removal: $index',
              );
              break;
            }
          }

          // Clear selections AFTER removing cards
          clearSelections();

          // Add removed cards to field in reordered sequence (playedCards reordered by isValidPlay)
          for (var card in playedCards) {
            field.add(card);
          }
          // --- NEW: Track Ace value if last card is Ace ---
          if (field.isNotEmpty && field.last == 'a') {
            if (playedCards.isNotEmpty &&
                playedCards.last == 'a' &&
                aceOverrides.isNotEmpty) {
              fieldAceValue = aceOverrides.last;
            } else {
              fieldAceValue = 14;
            }
          } else {
            fieldAceValue = null;
          }
          // Add to activity log
          List<String> localSelectedOps = List.from(savedSelectedOps);
          int aceOverrideIdx = 0;
          String playDescription =
              'You played ${playedCards.asMap().entries.map((entry) {
                print('DEBUG START: i: ${entry.key}, localSelectedOps: $localSelectedOps');
                int i = entry.key;
                String card = entry.value;
                String cardNum;
                if (card == 'a' && aceOverrides.isNotEmpty && aceOverrideIdx < aceOverrides.length) {
                  cardNum = aceOverrides[aceOverrideIdx].toString();
                  aceOverrideIdx++;
                } else {
                  cardNum = cardValue(card).toString().replaceAll('.0', '');
                }
                if (i == 0) return cardNum;
                if (localSelectedOps.isEmpty || (i - 1) >= localSelectedOps.length || (i - 1) < 0) return ' $cardNum';
                print('DEBUG: i: $i, localSelectedOps.length: ${localSelectedOps.length}, trying to access index: ${i - 1}');
                print('DEBUG: localSelectedOps contents: $localSelectedOps');
                return ' ${localSelectedOps[i - 1]} $cardNum';
              }).join('')}';

          activityLog.add(playDescription);

          playCardSound();
          if (playerPrizeCards.isNotEmpty) {
            playerPrizeCards.removeLast();
            print('Prize card won! Remaining: ${playerPrizeCards.length}');
            message = "Great play!";
            playPrizeCardSound(); // Add prize card sound here
            checkForWin();
            if (gameOver) return;
          } else {
            message = "Success! But no prize cards left.";
          }
          if (playedCards.length == 1) {
            playerMaxHandSize = 3;
          } else {
            playerMaxHandSize = 2;
          }
        } else {
          // Store the actual cards to remove before any modifications
          List<String> cardsToRemove = [];
          List<int> validatedIndices = [];

          // Double-validation: build list of cards to remove with bounds checking
          for (int index in selectedIndices) {
            if (index >= 0 && index < playerHand.length) {
              cardsToRemove.add(playerHand[index]);
              validatedIndices.add(index);
            } else {
              print(
                'ERROR: Index $index is invalid for playerHand length ${playerHand.length} during invalid play',
              );
              clearSelections();
              return;
            }
          }

          // Remove cards in descending order to maintain index validity
          validatedIndices.sort((a, b) => b.compareTo(a));
          for (int index in validatedIndices) {
            if (index >= 0 && index < playerHand.length) {
              playerHand.removeAt(index);
            } else {
              print(
                'CRITICAL ERROR: Index became invalid during invalid play removal: $index',
              );
              break;
            }
          }

          // Clear selections AFTER removing cards
          clearSelections();

          // Add removed cards to field in original order
          for (var card in cardsToRemove) {
            field.add(card);
          }
          // --- NEW: Track Ace value if last card is Ace ---
          if (field.isNotEmpty && field.last == 'a') {
            if (playedCards.isNotEmpty &&
                playedCards.last == 'a' &&
                aceOverrides.isNotEmpty) {
              fieldAceValue = aceOverrides.last;
            } else {
              fieldAceValue = 14;
            }
          } else {
            fieldAceValue = null;
          }
          // Add to activity log
          List<String> localSelectedOps = List.from(savedSelectedOps);
          String playDescription =
              'You played ${playedCards.asMap().entries.map((entry) {
                int i = entry.key;
                String card = entry.value;
                String cardNum = cardValue(card).toString().replaceAll('.0', '');
                if (i == 0) return cardNum;
                if (localSelectedOps.isEmpty || (i - 1) >= localSelectedOps.length || (i - 1) < 0) return ' $cardNum';
                return ' ${localSelectedOps[i - 1]} $cardNum';
              }).join('')}';

          activityLog.add(playDescription);

          playCardSound();
          message = "No contest";
          playerMaxHandSize = 2;
        }
        isPlayerTurn = false;
        safeDrawCards(playerHand, playerDrawPile, 2);
        if (!gameOver) {
          Future.delayed(const Duration(seconds: 1), opponentTurn);
        }
      }
    });
  }

  void opponentTurn() async {
    if (gameOver) return;
    turnTimer?.cancel();
    setState(() {});

    await Future.delayed(const Duration(seconds: 1));
    if (!mounted || gameOver) return;

    // Enhanced AI: Always plays optimal moves and chooses the best one strategically
    double winChance;
    if (aiDifficulty == 1) {
      winChance = 0.7; // Easy
    } else if (aiDifficulty == 2) {
      winChance = 0.9; // Medium
    } else {
      winChance = 1.0; // Hard
    }
    bool tryToWin = Random().nextDouble() < winChance;

    // Strategic AI: Find ALL valid plays and choose the best one
    List<Map<String, dynamic>> allValidPlays = [];

    // Helper to generate all possible combinations
    List<List<int>> getCombinations(int n, int k) {
      List<List<int>> result = [];
      void combine(List<int> curr, int start) {
        if (curr.length == k) {
          result.add(List.from(curr));
          return;
        }
        for (int i = start; i < n; i++) {
          curr.add(i);
          combine(curr, i + 1);
          curr.removeLast();
        }
      }

      combine([], 0);
      return result;
    }

    // Try all single-card plays
    if (field.isNotEmpty) {
      for (int i = 0; i < opponentHand.length; i++) {
        String card = opponentHand[i];
        List<int> aceOverrides = [];
        String prevFieldCard = field.isNotEmpty ? field.last : card;
        if (card == 'a') {
          // Try both ace values
          for (int aceVal in [1, 14]) {
            aceOverrides = [aceVal];
            if (isValidPlay(
              [card],
              [],
              prevFieldCard,
              aceOverrides,
              fieldAceValue: fieldAceValue,
            )) {
              allValidPlays.add({
                'cards': [card],
                'ops': [],
                'aceOverrides': [aceVal],
                'score': 3, // Single card plays get priority
              });
            }
          }
        } else {
          if (isValidPlay(
            [card],
            [],
            prevFieldCard,
            [],
            fieldAceValue: fieldAceValue,
          )) {
            allValidPlays.add({
              'cards': [card],
              'ops': [],
              'aceOverrides': [],
              'score': 3, // Single card plays get priority
            });
          }
        }
      }
    }

    // Try all double-card plays
    if (field.isNotEmpty && opponentHand.length >= 2) {
      for (var combo in getCombinations(opponentHand.length, 2)) {
        // --- Range check to prevent out-of-bounds errors ---
        if (combo[0] >= opponentHand.length ||
            combo[1] >= opponentHand.length) {
          continue;
        }
        List<String> cards = [opponentHand[combo[0]], opponentHand[combo[1]]];
        for (var op in ['+', '-']) {
          List<List<int>> aceValueCombos = [[]];
          if (cards[0] == 'a' && cards[1] == 'a') {
            aceValueCombos = [
              [1, 1],
              [1, 14],
              [14, 1],
              [14, 14],
            ];
          } else if (cards[0] == 'a') {
            aceValueCombos = [
              [1],
              [14],
            ];
          } else if (cards[1] == 'a') {
            aceValueCombos = [
              [1],
              [14],
            ];
          }
          for (var aceOverrides in aceValueCombos) {
            String prevFieldCard = field.isNotEmpty ? field.last : cards.first;
            if (isValidPlay(
              cards,
              [op],
              prevFieldCard,
              aceOverrides,
              fieldAceValue: fieldAceValue,
            )) {
              allValidPlays.add({
                'cards': List.from(cards),
                'ops': [op],
                'aceOverrides': List.from(aceOverrides),
                'score':
                    2, // Double plays are good but less priority than singles
              });
            }
          }
        }
      }
    }

    // Try all triple-card plays
    if (field.isNotEmpty && opponentHand.length >= 3) {
      for (var combo in getCombinations(opponentHand.length, 3)) {
        if (combo[0] >= opponentHand.length ||
            combo[1] >= opponentHand.length ||
            combo[2] >= opponentHand.length) {
          continue;
        }
        List<String> cards = [
          opponentHand[combo[0]],
          opponentHand[combo[1]],
          opponentHand[combo[2]],
        ];
        for (var op1 in ['+', '-']) {
          for (var op2 in ['+', '-']) {
            List<List<int>> aceValueCombos = [[]];
            int aceCount = cards.where((c) => c == 'a').length;
            if (aceCount == 3) {
              aceValueCombos = [
                [1, 1, 1],
                [1, 1, 14],
                [1, 14, 1],
                [1, 14, 14],
                [14, 1, 1],
                [14, 1, 14],
                [14, 14, 1],
                [14, 14, 14],
              ];
            } else if (aceCount == 2) {
              aceValueCombos = [
                [1, 1],
                [1, 14],
                [14, 1],
                [14, 14],
              ];
            } else if (aceCount == 1) {
              aceValueCombos = [
                [1],
                [14],
              ];
            }
            for (var aceOverrides in aceValueCombos) {
              String prevFieldCard = field.isNotEmpty
                  ? field.last
                  : cards.first;
              if (isValidPlay(
                cards,
                [op1, op2],
                prevFieldCard,
                aceOverrides,
                fieldAceValue: fieldAceValue,
              )) {
                allValidPlays.add({
                  'cards': List.from(cards),
                  'ops': [op1, op2],
                  'aceOverrides': List.from(aceOverrides),
                  'score': 1, // Triple plays are least priority
                });
              }
            }
          }
        }
      }
    }

    // Choose the best play (highest score = single card preferred)
    List<String> bestPlay = [];
    List<String> bestOps = [];
    List<int> bestAceOverrides = [];

    if (allValidPlays.isNotEmpty) {
      // Sort by score (descending) to prioritize single-card plays
      allValidPlays.sort((a, b) => b['score'].compareTo(a['score']));
      var chosenPlay = allValidPlays.first;
      bestPlay = List<String>.from(chosenPlay['cards']);
      bestOps = List<String>.from(chosenPlay['ops']);
      bestAceOverrides = List<int>.from(chosenPlay['aceOverrides']);
    }

    // Decide whether to play a valid move or random
    bool playValid = bestPlay.isNotEmpty && tryToWin;

    setState(() {
      if (opponentHand.isEmpty) {
        message = "Opponent has no cards left!";
        isPlayerTurn = true;
        startTimer();
        return;
      }

      List<int> indicesToPlay = [];
      List<String> opsToPlay = [];
      List<int> aceOverrides = [];

      if (playValid) {
        // Find indices in hand for bestPlay (in order)
        List<String> handCopy = List.from(opponentHand);
        for (var card in bestPlay) {
          int idx = handCopy.indexOf(card);
          if (idx != -1) {
            indicesToPlay.add(idx);
            handCopy[idx] = ''; // Mark as used
          }
        }
        opsToPlay = bestOps;
        aceOverrides = bestAceOverrides;
      } else {
        // Play a random card - but validate the hand first
        if (opponentHand.isNotEmpty) {
          indicesToPlay = [0];
        } else {
          message = "Opponent has no cards to play!";
          isPlayerTurn = true;
          startTimer();
          return;
        }
        opsToPlay = [];
        aceOverrides = [];
      }

      // CRITICAL FIX: Validate indices BEFORE attempting to remove cards
      bool indicesValid = indicesToPlay.every(
        (i) => i >= 0 && i < opponentHand.length,
      );

      if (!indicesValid) {
        print(
          'Invalid opponent indices detected: $indicesToPlay for hand length ${opponentHand.length}',
        );
        // Fallback to playing the first available card safely
        if (opponentHand.isNotEmpty) {
          indicesToPlay = [0];
          opsToPlay = [];
          aceOverrides = [];
        } else {
          message = "Opponent has no valid cards to play!";
          isPlayerTurn = true;
          startTimer();
          return;
        }
      }

      // Remove and play cards in reverse order so indices remain valid
      List<String> playedCards = [];
      indicesToPlay.sort();
      for (int i = indicesToPlay.length - 1; i >= 0; i--) {
        if (indicesToPlay[i] >= 0 && indicesToPlay[i] < opponentHand.length) {
          playedCards.insert(0, opponentHand.removeAt(indicesToPlay[i]));
        } else {
          print(
            'ERROR: Attempted to remove invalid index ${indicesToPlay[i]} from opponent hand of length ${opponentHand.length}',
          );
          // Skip this invalid index
          continue;
        }
      }

      // If no cards were successfully removed, fallback
      if (playedCards.isEmpty && opponentHand.isNotEmpty) {
        print('No cards removed successfully, playing first card as fallback');
        playedCards = [opponentHand.removeAt(0)];
        opsToPlay = [];
        aceOverrides = [];
      }

      // Store the previous field card before adding new cards
      String prevFieldCard = field.isNotEmpty
          ? field.last
          : (playedCards.isNotEmpty ? playedCards.first : '2'); // fallback

      // Add to field in order, lowest value last
      if (playedCards.isNotEmpty) {
        List<double> values = [];
        int aceIdx = 0;
        for (int i = 0; i < playedCards.length; i++) {
          if (playedCards[i] == 'a') {
            if (aceIdx < aceOverrides.length) {
              values.add(cardValue('a', aceOverride: aceOverrides[aceIdx]));
            } else {
              values.add(14);
            }
            aceIdx++;
          } else {
            values.add(cardValue(playedCards[i]));
          }
        }
        // Find index of lowest value
        int minIdx = values.indexOf(values.reduce(min));
        // Move lowest value card to last position
        if (minIdx != values.length - 1) {
          String tempCard = playedCards[minIdx];
          playedCards.removeAt(minIdx);
          playedCards.add(tempCard);
        }
        for (var card in playedCards) {
          field.add(card);
        }
        // --- NEW: Track Ace value if last card is Ace ---
        if (field.isNotEmpty && field.last == 'a') {
          if (playedCards.isNotEmpty &&
              playedCards.last == 'a' &&
              aceOverrides.isNotEmpty) {
            fieldAceValue = aceOverrides.last;
          } else {
            fieldAceValue = 14;
          }
        } else {
          fieldAceValue = null;
        }
        playCardSound();

        // Use opsToPlay instead of selectedOps for opponent
        List<String> localSelectedOps = List.from(opsToPlay);
        int aceOverrideIdx = 0;
        String playDescription =
            'Opponent played ${playedCards.asMap().entries.map((entry) {
              int i = entry.key;
              String card = entry.value;
              String cardNum;
              if (card == 'a' && aceOverrides.isNotEmpty && aceOverrideIdx < aceOverrides.length) {
                cardNum = aceOverrides[aceOverrideIdx].toString();
                aceOverrideIdx++;
              } else {
                cardNum = cardValue(card).toString().replaceAll('.0', '');
              }
              if (i == 0) return cardNum;
              if (localSelectedOps.isEmpty || (i - 1) >= localSelectedOps.length || (i - 1) < 0) return ' $cardNum';
              return ' ${localSelectedOps[i - 1]} $cardNum';
            }).join('')}';
        activityLog.add(playDescription);

        int prevIndex = field.length - playedCards.length - 1;
        if (prevIndex >= 0 && prevIndex < field.length) {
          prevFieldCard = field[prevIndex];
        } else if (field.isNotEmpty) {
          prevFieldCard = field.last;
        } else if (playedCards.isNotEmpty) {
          prevFieldCard = playedCards.first;
        } else {
          prevFieldCard = '2'; // fallback
        }
        // Use prevFieldCard for the valid play check
        if (playValid &&
            isValidPlay(
              playedCards,
              opsToPlay,
              prevFieldCard,
              aceOverrides,
              fieldAceValue: fieldAceValue,
            )) {
          if (opponentPrizeCards.isNotEmpty) {
            opponentPrizeCards.removeLast();
            message = "Yikes!";
            playPrizeCardSound(); // Add prize card sound here too
            checkForWin();
            if (gameOver) return;
          } else {
            message = "Opponent succeeded, but no prize cards left.";
          }
        } else {
          message = "Opponent played, your turn!";
        }
      } else {
        message = "Opponent couldn't play, your turn!";
      }

      isPlayerTurn = true;
      safeDrawCards(opponentHand, opponentDrawPile, 2);
      startTimer();
    });
  }

  void toggleCardSelection(int index) {
    if (index < 0 || index >= playerHand.length) {
      print(
        'Invalid card selection index: $index (hand length: ${playerHand.length})',
      );
      return;
    }

    setState(() {
      if (selectedIndices.contains(index)) {
        // Remove card
        selectedIndices.remove(index);

        // Rebuild selectedOps to match new length exactly
        selectedOps.clear();
        for (int i = 0; i < selectedIndices.length - 1; i++) {
          selectedOps.add('+');
        }
      } else {
        // Add card if under limit
        if (selectedIndices.length < 3) {
          selectedIndices.add(index);

          // Rebuild selectedOps to match new length exactly
          selectedOps.clear();
          for (int i = 0; i < selectedIndices.length - 1; i++) {
            selectedOps.add('+');
          }
        }
      }

      if (selectedOps.length != (selectedIndices.length - 1).clamp(0, 2)) {
        print('Emergency fix: ops length mismatch');
        selectedOps.clear();
        for (int i = 0; i < selectedIndices.length - 1; i++) {
          selectedOps.add('+');
        }
      }
    });
  }

  void toggleOperation(int opIndex) {
    if (opIndex < 0 || opIndex >= selectedOps.length) {
      print(
        'Invalid operation index: $opIndex (selectedOps length: ${selectedOps.length})',
      );
      return;
    }

    setState(() {
      selectedOps[opIndex] = selectedOps[opIndex] == '+' ? '-' : '+';
    });
  }

  Widget buildTimer({required bool isMobile, required bool isTablet}) {
    final timerSize = isMobile ? 60.0 : (isTablet ? 75.0 : 90.0);
    return Padding(
      padding: EdgeInsets.only(left: isMobile ? 12 : 24),
      child: SizedBox(
        width: timerSize,
        height: timerSize,
        child: AnalogPaperTimer(secondsLeft: timerSeconds, totalSeconds: 10),
      ),
    );
  }

  Widget buildCardSelectionRow({
    required bool isMobile,
    required bool isTablet,
  }) {
    if (selectedIndices.isEmpty) return const SizedBox.shrink();

    // Emergency validation - if anything is wrong, clear and return empty
    for (int index in selectedIndices) {
      if (index < 0 || index >= playerHand.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() => clearSelections());
        });
        return const SizedBox.shrink();
      }
    }

    // Ensure selectedOps has exactly the right length
    int expectedOpsLength = (selectedIndices.length - 1).clamp(0, 2);
    if (selectedOps.length != expectedOpsLength) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          selectedOps.clear();
          for (int i = 0; i < expectedOpsLength; i++) {
            selectedOps.add('+');
          }
        });
      });
      return const SizedBox.shrink();
    }

    List<Widget> widgets = [];

    for (int i = 0; i < selectedIndices.length; i++) {
      // Add card widget
      widgets.add(
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.yellow, width: 4),
            borderRadius: BorderRadius.circular(8),
          ),
          margin: EdgeInsets.symmetric(horizontal: isMobile ? 2.0 : 4.0),
          child: SizedBox(
            width: isMobile ? 35 : (isTablet ? 50 : 60),
            height: isMobile ? 49 : (isTablet ? 70 : 84),
            child: CardWidget(
              value: playerHand[selectedIndices[i]],
              isJoker: playerHand[selectedIndices[i]] == 'jkr',
            ),
          ),
        ),
      );

      // Add operation selector only if we need one AND it exists
      if (i < selectedIndices.length - 1 && i < selectedOps.length) {
        widgets.add(
          GestureDetector(
            onTap: () => toggleOperation(i),
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: isMobile ? 1.0 : 2.0),
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 4 : 8,
                vertical: isMobile ? 4 : 8,
              ),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.greenAccent, width: 2),
              ),
              child: Text(
                selectedOps[i],
                style: TextStyle(
                  fontFamily: 'Courier',
                  fontSize: isMobile ? 24 : (isTablet ? 28 : 32),
                  color: const Color.fromARGB(255, 104, 255, 210),
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      blurRadius: 4,
                      color: Color.fromARGB(255, 218, 251, 255),
                      offset: Offset(0, 0),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }

    // Add equals button
    if (isPlayerTurn && !gameOver) {
      widgets.add(
        Padding(
          padding: EdgeInsets.only(left: isMobile ? 8.0 : 16.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(5, 194, 194, 194),
              shape: const CircleBorder(),
              padding: EdgeInsets.all(isMobile ? 12 : 18), // Remove const here
              elevation: 8,
              shadowColor: const Color.fromARGB(255, 123, 207, 255),
            ),
            onPressed: isSelectionValidForPlay()
                ? () => playSelectedCards()
                : null,
            child: Text(
              // Remove const here
              '=',
              style: TextStyle(
                // Remove const here
                fontFamily: 'Courier',
                fontSize: isMobile ? 28 : (isTablet ? 32 : 36),
                color: const Color.fromARGB(255, 237, 227, 240),
                fontWeight: FontWeight.bold,
                shadows: const [
                  Shadow(
                    blurRadius: 8,
                    color: Color.fromARGB(255, 219, 242, 255),
                    offset: Offset(0, 0),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(mainAxisAlignment: MainAxisAlignment.center, children: widgets);
  }

  @override
  Widget build(BuildContext context) {
    // Add MediaQuery breakpoints here
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;
    final isShortScreen = screenHeight < 900;
    final verticalSpacing = isShortScreen ? 8.0 : (isMobile ? 16 : 32);

    return Scaffold(
      appBar: null, // Removes any app bar
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: SafeArea(
        child: Stack(
          children: [
            // Background layer (static)
            Positioned.fill(
              child: Image.asset(
                'assets/images/playmat.png',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
            // Content layer
            Padding(
              padding: EdgeInsets.all(
                isMobile ? 16.0 : (isTablet ? 20.0 : 24.0),
              ),
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: isMobile ? screenHeight * 0.9 : screenHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      mainAxisAlignment: isMobile
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,
                      children: [
                        // Opponent's prize cards (face-down)
                        Row(
                          mainAxisAlignment: MainAxisAlignment
                              .center, // Leave this one unchanged
                          children: List.generate(
                            opponentPrizeCards.length,
                            (_) => Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 2.0 : 4.0,
                              ),
                              child: SizedBox(
                                width: isMobile ? 40 : (isTablet ? 55 : 70),
                                height: isMobile
                                    ? 56
                                    : (isTablet
                                          ? 77
                                          : 98), // Maintain card aspect ratio (1.4)
                                child: CardWidget(isCardBack: true),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: isMobile ? 8 : 16),
                        // Opponent's hand (hidden)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            opponentHand.length,
                            (_) => Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 2.0 : 4.0,
                              ),
                              child: SizedBox(
                                width: isMobile ? 40 : (isTablet ? 55 : 70),
                                height: isMobile ? 56 : (isTablet ? 77 : 98),
                                child: CardWidget(isCardBack: true),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: isMobile ? 16 : 32),
                        // Field area (last played card, if any) + Timer to the far right
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Left spacer - smaller on mobile
                            Expanded(
                              flex: isMobile ? 1 : 2,
                              child: Container(),
                            ),
                            // Centered field card
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 330),
                              transitionBuilder:
                                  (Widget child, Animation<double> animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: ScaleTransition(
                                        scale: Tween<double>(
                                          begin: 0.95,
                                          end: 1.0,
                                        ).animate(animation),
                                        child: child,
                                      ),
                                    );
                                  },
                              child: field.isNotEmpty
                                  ? SizedBox(
                                      key: ValueKey(field.last),
                                      width: isMobile
                                          ? 50
                                          : (isTablet ? 65 : 80),
                                      height: isMobile
                                          ? 70
                                          : (isTablet ? 91 : 112),
                                      child: CardWidget(
                                        value: field.last,
                                        isJoker: field.last == 'jkr',
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            // Right spacer with activity log and timer
                            Expanded(
                              flex: isMobile ? 1 : 2,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Activity log - hide on very small screens
                                  if (screenWidth > 350)
                                    Flexible(
                                      child: Container(
                                        constraints: BoxConstraints(
                                          maxWidth: isMobile
                                              ? 80
                                              : (isTablet ? 140 : 180),
                                          minHeight: isMobile ? 25 : 35,
                                          maxHeight: isMobile ? 40 : 50,
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isMobile ? 6 : 10,
                                          vertical: isMobile ? 4 : 6,
                                        ),
                                        margin: EdgeInsets.only(
                                          right: isMobile ? 6 : 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color.fromARGB(
                                            6,
                                            159,
                                            154,
                                            230,
                                          ).withOpacity(0.5),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        alignment: Alignment.centerRight,
                                        child: activityLog.isNotEmpty
                                            ? Text(
                                                activityLog.last,
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 2,
                                                textAlign: TextAlign.right,
                                                style: TextStyle(
                                                  color: const Color.fromARGB(
                                                    242,
                                                    246,
                                                    252,
                                                    255,
                                                  ),
                                                  fontSize: isMobile
                                                      ? 8
                                                      : (isTablet ? 10 : 12),
                                                  height: 1.2,
                                                ),
                                              )
                                            : const SizedBox.shrink(),
                                      ),
                                    ),
                                  // Timer
                                  buildTimer(
                                    isMobile: isMobile,
                                    isTablet: isTablet,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isMobile ? 16 : 32),
                        // Card selection row (shows selected cards and operation selectors, with = button)
                        buildCardSelectionRow(
                          isMobile: isMobile,
                          isTablet: isTablet,
                        ),
                        // Player's hand (visible and selectable if it's player's turn)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          decoration: isPlayerTurn && !gameOver
                              ? BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color.fromARGB(
                                        148,
                                        104,
                                        228,
                                        201,
                                      ).withOpacity(0.25),
                                      blurRadius: 24,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                )
                              : null,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(playerHand.length, (index) {
                              String cardValue = playerHand[index];
                              bool isSelected = selectedIndices.contains(index);
                              return GestureDetector(
                                onTap: isPlayerTurn && !gameOver
                                    ? () => toggleCardSelection(index)
                                    : null,
                                child: Opacity(
                                  opacity: isPlayerTurn && !gameOver
                                      ? 1.0
                                      : 0.5,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: isSelected
                                          ? Border.all(
                                              color: const Color.fromARGB(
                                                88,
                                                134,
                                                110,
                                                141,
                                              ),
                                              width: 4,
                                            )
                                          : null,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    margin: EdgeInsets.symmetric(
                                      horizontal: isMobile ? 4.0 : 8.0,
                                    ),
                                    child: SizedBox(
                                      width: isMobile
                                          ? 45
                                          : (isTablet ? 60 : 75),
                                      height: isMobile
                                          ? 63
                                          : (isTablet ? 84 : 105),
                                      child: CardWidget(
                                        value: cardValue,
                                        isJoker: cardValue == 'jkr',
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        SizedBox(height: isMobile ? 8 : 16),
                        // Player's prize cards (face-down)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            playerPrizeCards.length,
                            (_) => Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 2.0 : 4.0,
                              ),
                              child: SizedBox(
                                width: isMobile ? 40 : (isTablet ? 55 : 70),
                                height: isMobile ? 56 : (isTablet ? 77 : 98),
                                child: CardWidget(isCardBack: true),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: isMobile ? 16 : 24),
                        // Message
                        Text(
                          message,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 14 : (isTablet ? 16 : 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Win/Lose Overlay
            if (gameOver)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.7),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          winner == 'player' ? '=1' : 'D=',
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 100,
                            color: winner == 'player'
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                blurRadius: 12,
                                color: winner == 'player'
                                    ? Colors.greenAccent
                                    : Colors.redAccent,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          winner == 'player' ? 'You Win!' : 'You Lose!',
                          style: TextStyle(
                            color: winner == 'player'
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                blurRadius: 12,
                                color: winner == 'player'
                                    ? Colors.greenAccent
                                    : Colors.redAccent,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: isMobile ? 16 : 32),
                        ElevatedButton(
                          onPressed: () => setState(() => _setupGame()),
                          child: const Text('Next Game'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // NEW: Initial Overlay
            if (showInitialOverlay)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.7),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.content_cut_sharp,
                          size: 100,
                          color: Color.fromARGB(255, 77, 104, 255),
                          shadows: [
                            Shadow(blurRadius: 12, color: Colors.indigo),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Start Game',
                          style: TextStyle(
                            color: Color.fromARGB(255, 77, 104, 255),
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(blurRadius: 12, color: Colors.indigo),
                            ],
                          ),
                        ),
                        SizedBox(height: isMobile ? 16 : 32),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color.fromARGB(255, 77, 104, 255),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              showInitialOverlay = false;
                            });
                            startTimer(); // Start the timer when game begins
                          },
                          child: const Text(
                            'Play',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Learn to Play Section
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              showRules = !showRules;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Invisible spacer to balance the caret
                                SizedBox(
                                  width: 28,
                                ), // 20 (icon size) + 8 (spacing)
                                Text(
                                  'Learn to Play',
                                  style: TextStyle(
                                    color: const Color.fromARGB(
                                      192,
                                      242,
                                      244,
                                      255,
                                    ),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    decoration: TextDecoration.underline,
                                    decorationColor: const Color.fromARGB(
                                      180,
                                      175,
                                      182,
                                      223,
                                    ).withOpacity(0.8),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  showRules
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  color: Color.fromARGB(182, 77, 104, 255),
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Expandable Rules
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          height: showRules ? null : 0,
                          child: showRules
                              ? Container(
                                  constraints: BoxConstraints(
                                    maxWidth: isMobile ? 300 : 400,
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color.fromARGB(
                                        255,
                                        87,
                                        111,
                                        251,
                                      ).withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildRuleItem(
                                        'Take turns playing cards against your opponent',
                                      ),
                                      const SizedBox(height: 8),
                                      _buildRuleItem(
                                        'Double or halve the last played card to win a point',
                                      ),
                                      const SizedBox(height: 8),
                                      _buildRuleItem(
                                        'Add or subtract your cards for strategic plays',
                                      ),
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // Difficulty selector in the top-right corner (wrapped in Material for pointer events)
            Positioned(
              top: isMobile ? 20 : 30,
              right: isMobile ? 15 : 30,
              child: Material(
                color: Colors.transparent,
                child: buildDifficultySelector(isMobile: isMobile),
              ),
            ),
            // Winstreak in the bottom-right corner (wrapped in Material for pointer events)
            Positioned(
              bottom: isMobile ? 20 : 30,
              right: isMobile ? 15 : 30,
              child: Material(
                color: Colors.transparent,
                child: buildWinStreak(isMobile: isMobile),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 4,
          margin: const EdgeInsets.only(top: 8, right: 12),
          decoration: BoxDecoration(
            color: Colors.indigo.withOpacity(0.8),
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class AnalogPaperTimer extends StatelessWidget {
  final int secondsLeft;
  final int totalSeconds;

  const AnalogPaperTimer({
    super.key,
    required this.secondsLeft,
    required this.totalSeconds,
    this.size = 90.0, // Add size parameter
  });

  final double size; // Add this field

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: const Size(90, 90),
        painter: _PaperTimerPainter(
          secondsLeft: secondsLeft,
          totalSeconds: totalSeconds,
        ),
        child: Center(
          child: Text(
            '$secondsLeft',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: size * 0.4, // Scale with timer size
              color: Color.fromARGB(220, 60, 60, 63),
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  blurRadius: 2,
                  color: Color.fromARGB(61, 90, 90, 90),
                  offset: Offset(1, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaperTimerPainter extends CustomPainter {
  final int secondsLeft;
  final int totalSeconds;

  _PaperTimerPainter({required this.secondsLeft, required this.totalSeconds});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color.fromARGB(57, 67, 67, 71)
      ..strokeWidth =
          4 // thinner arc
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    double progress = (totalSeconds - secondsLeft) / totalSeconds;
    double sweepAngle = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(
        center: size.center(Offset.zero),
        radius: size.width / 2 - 18,
      ), // further from center
      -pi / 2,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
