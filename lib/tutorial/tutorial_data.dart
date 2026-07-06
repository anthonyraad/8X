// Tutorial data definitions for the scripted first-time user tutorial

/// Regions that can be highlighted during tutorial
enum HighlightRegion {
  none,
  cardInHand,           // Specific card in hand (use cardValue parameter)
  playerPrizeCards,     // Player's prize card area
  handCards,            // Entire player hand
  handCardsAndOperator, // Hand plus the operator between cards
}

/// Actions required to progress from each step
enum RequiredAction {
  tapAnywhere,
  swipeUpCard4,
  swipeUpCard10,
  tap5And2ThenPlay,
  tap12And4ChangeToMinusThenPlay,
  triggerVictory,
}

/// Data class representing a single tutorial step
class TutorialStep {
  final int stepNumber;
  final String instructionText;
  final List<String> playerHandOverride;
  final List<String> fieldStateOverride;
  final HighlightRegion highlightRegion;
  final String? highlightCardValue; // For cardInHand highlight
  final RequiredAction requiredAction;
  final String? opponentPlaysCard; // Card opponent plays after this step completes
  final bool shouldShowPrizeHighlight;
  final int expectedPrizeCount; // Expected player prize cards remaining

  const TutorialStep({
    required this.stepNumber,
    required this.instructionText,
    required this.playerHandOverride,
    required this.fieldStateOverride,
    required this.highlightRegion,
    this.highlightCardValue,
    required this.requiredAction,
    this.opponentPlaysCard,
    this.shouldShowPrizeHighlight = false,
    this.expectedPrizeCount = 3,
  });
}

/// All tutorial steps in sequence
final List<TutorialStep> tutorialSteps = [
  // Step 1: Welcome
  const TutorialStep(
    stepNumber: 1,
    instructionText: "This is 8X.\n\nThe objective is to double or halve the last card.\n\n(tap to continue)",
    playerHandOverride: ['4', '5'],
    fieldStateOverride: [],
    highlightRegion: HighlightRegion.none,
    requiredAction: RequiredAction.tapAnywhere,
    expectedPrizeCount: 3,
  ),

  // Step 2: Play First Card
  const TutorialStep(
    stepNumber: 2,
    instructionText: "Start by playing a card.\n\nTry swiping up on the 4!",
    playerHandOverride: ['4', '5'],
    fieldStateOverride: [],
    highlightRegion: HighlightRegion.cardInHand,
    highlightCardValue: '4',
    requiredAction: RequiredAction.swipeUpCard4,
    opponentPlaysCard: '5', // Opponent plays 5 after player plays
    expectedPrizeCount: 3,
  ),

  // Step 3: Opponent Turn
  const TutorialStep(
    stepNumber: 3,
    instructionText: "Your opponent played a 5.",
    playerHandOverride: ['5', '10'],
    fieldStateOverride: ['4', '5'],
    highlightRegion: HighlightRegion.none,
    requiredAction: RequiredAction.tapAnywhere,
    expectedPrizeCount: 3,
  ),

  // Step 4: Doubling
  const TutorialStep(
    stepNumber: 4,
    instructionText: "You can double their 5 with a 10.\n\nSwipe up on the 10.",
    playerHandOverride: ['5', '10'],
    fieldStateOverride: ['4', '5'],
    highlightRegion: HighlightRegion.cardInHand,
    highlightCardValue: '10',
    requiredAction: RequiredAction.swipeUpCard10,
    expectedPrizeCount: 3,
  ),

  // Step 5: Scoring
  const TutorialStep(
    stepNumber: 5,
    instructionText: "Score! \nWhen you double or halve, you get a point.",
    playerHandOverride: ['5', '2'],
    fieldStateOverride: ['4', '5', '10'],
    highlightRegion: HighlightRegion.cardInHand,
    requiredAction: RequiredAction.tapAnywhere,
    shouldShowPrizeHighlight: true,
    expectedPrizeCount: 2, // Player won 1 prize
  ),

  // Step 6: Win Condition
  const TutorialStep(
    stepNumber: 6,
    instructionText: "Get 3 points to win!",
    playerHandOverride: ['5', '2'],
    fieldStateOverride: ['4', '5', '10'],
    highlightRegion: HighlightRegion.cardInHand,
    requiredAction: RequiredAction.tapAnywhere,
    opponentPlaysCard: 'a', // Opponent plays ace (14) after this step
    shouldShowPrizeHighlight: true,
    expectedPrizeCount: 2,
  ),

  // Step 7: Opponent Plays Ace
  const TutorialStep(
    stepNumber: 7,
    instructionText: "Your opponent played a 14. \nLet's add cards together to halve it.",
    playerHandOverride: ['5', '2'],
    fieldStateOverride: ['4', '5', '10', 'a'],
    highlightRegion: HighlightRegion.none,
    requiredAction: RequiredAction.tapAnywhere,
    expectedPrizeCount: 2,
  ),

  // Step 8: Adding Cards
  const TutorialStep(
    stepNumber: 8,
    instructionText: "Tap both 5 and 2, then hit =.\n\nThe lower number must always be last!",
    playerHandOverride: ['5', '2'],
    fieldStateOverride: ['4', '5', '10', 'a'],
    highlightRegion: HighlightRegion.cardInHand,
    requiredAction: RequiredAction.tap5And2ThenPlay,
    expectedPrizeCount: 2, // No prize yet - will be awarded when opponent plays 4
  ),

  // Step 9: Opponent Plays Small Card
  const TutorialStep(
    stepNumber: 9,
    instructionText: "Your opponent played a 4. \nLet's use our cards to double it.",
    playerHandOverride: ['q', '4'],
    fieldStateOverride: ['4', '5', '10', 'a', '2', '4'],
    highlightRegion: HighlightRegion.none,
    requiredAction: RequiredAction.tapAnywhere,
    expectedPrizeCount: 1, // Player won prize because opponent's 4 doubled their 2
  ),

  // Step 10: Subtraction
  const TutorialStep(
    stepNumber: 10,
    instructionText: "We need to get to 8.\n\nTap both 12 and 4.\nThen tap the + to change it to -",
    playerHandOverride: ['q', '4'],
    fieldStateOverride: ['4', '5', '10', 'a', '2', '4'],
    highlightRegion: HighlightRegion.cardInHand,
    requiredAction: RequiredAction.tap12And4ChangeToMinusThenPlay,
    expectedPrizeCount: 1,
  ),

  // Step 11: Victory
  const TutorialStep(
    stepNumber: 11,
    instructionText: "Victory! You're ready to play.",
    playerHandOverride: [],
    fieldStateOverride: ['4', '5', '10', 'a', '2', '4', '4'],
    highlightRegion: HighlightRegion.none,
    requiredAction: RequiredAction.triggerVictory,
    expectedPrizeCount: 0, // Won all prizes
  ),
];

/// Tutorial modifiers (visible but disabled)
const List<String> tutorialModifiers = ['2x', '+3', '-1'];

/// Validates if the given action matches what's required for the current step
bool validateTutorialAction({
  required TutorialStep step,
  required String actionType,
  String? cardValue,
  List<int>? selectedIndices,
  List<String>? selectedOps,
  List<String>? playerHand,
}) {
  switch (step.requiredAction) {
    case RequiredAction.tapAnywhere:
      return actionType == 'tap';
      
    case RequiredAction.swipeUpCard4:
      return actionType == 'swipeUp' && cardValue == '4';
      
    case RequiredAction.swipeUpCard10:
      return actionType == 'swipeUp' && cardValue == '10';
      
    case RequiredAction.tap5And2ThenPlay:
      if (actionType == 'play' && 
          selectedIndices != null && 
          playerHand != null &&
          selectedIndices.length == 2) {
        // Must select 5 first, then 2 (in that order in hand)
        final firstCard = playerHand[selectedIndices[0]];
        final secondCard = playerHand[selectedIndices[1]];
        return firstCard == '5' && secondCard == '2';
      }
      return false;
      
    case RequiredAction.tap12And4ChangeToMinusThenPlay:
      if (actionType == 'play' && 
          selectedIndices != null && 
          selectedOps != null &&
          playerHand != null &&
          selectedIndices.length == 2 &&
          selectedOps.isNotEmpty) {
        // Must select q (12) first, then 4, with minus operator
        final firstCard = playerHand[selectedIndices[0]];
        final secondCard = playerHand[selectedIndices[1]];
        return firstCard == 'q' && secondCard == '4' && selectedOps[0] == '-';
      }
      return false;
      
    case RequiredAction.triggerVictory:
      return actionType == 'victory';
  }
}

/// Get the card value to highlight for the current step
String? getHighlightCardValue(TutorialStep step) {
  if (step.highlightRegion == HighlightRegion.cardInHand) {
    return step.highlightCardValue;
  }
  return null;
}

/// Check if a specific card tap/swipe is allowed at current step
bool isCardInteractionAllowed({
  required TutorialStep step,
  required String cardValue,
  required String interactionType, // 'tap' or 'swipe'
}) {
  switch (step.requiredAction) {
    case RequiredAction.swipeUpCard4:
      return interactionType == 'swipe' && cardValue == '4';
      
    case RequiredAction.swipeUpCard10:
      return interactionType == 'swipe' && cardValue == '10';
      
    case RequiredAction.tap5And2ThenPlay:
      return interactionType == 'tap' && (cardValue == '5' || cardValue == '2');
      
    case RequiredAction.tap12And4ChangeToMinusThenPlay:
      return interactionType == 'tap' && (cardValue == 'q' || cardValue == '4');
      
    default:
      return false;
  }
}

/// Check if operator interaction is allowed at current step
bool isOperatorInteractionAllowed(TutorialStep step) {
  return step.requiredAction == RequiredAction.tap12And4ChangeToMinusThenPlay;
}

/// Check if play button interaction is allowed at current step
bool isPlayButtonAllowed({
  required TutorialStep step,
  required List<int> selectedIndices,
  required List<String> selectedOps,
  required List<String> playerHand,
}) {
  switch (step.requiredAction) {
    case RequiredAction.tap5And2ThenPlay:
      if (selectedIndices.length == 2) {
        final firstCard = playerHand[selectedIndices[0]];
        final secondCard = playerHand[selectedIndices[1]];
        return firstCard == '5' && secondCard == '2';
      }
      return false;
      
    case RequiredAction.tap12And4ChangeToMinusThenPlay:
      if (selectedIndices.length == 2 && selectedOps.isNotEmpty) {
        final firstCard = playerHand[selectedIndices[0]];
        final secondCard = playerHand[selectedIndices[1]];
        return firstCard == 'q' && secondCard == '4' && selectedOps[0] == '-';
      }
      return false;
      
    default:
      return false;
  }
}
