import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:async';
import 'card_widget.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';


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
  late List<String> opponentActualHand; // Store real opponent cards locally
  late List<String> playerPrizeCards;
  late List<String> opponentPrizeCards;
  late List<String> playerDrawPile;
  late List<String> opponentDrawPile;
  late List<String>
      opponentActualDrawPile; // Store real opponent draw pile locally
  List<String> field = [];
  List<String> activityLog = [];
  Set<String> processedTimeoutPenalties = <String>{};

String selectedCardback = 'cardback'; // Current cardback asset name
List<String> availableCardbacks = ['cardback']; // List of unlocked cardbacks
  String cardbackChoice = 'Diamond'; // UI choice for dropdown (Diamond|Opal)

// Firebase multiplayer variables
  String gameMode = 'ai'; // 'ai' or 'human'
  bool showRoomSelection = false;
  bool showCreateRoom = false;
  bool showJoinRoom = false;
  bool isSearchingForGame = false; // Quick match state
  String? roomCode;
  String? playerId;
  String? opponentId;
  List<String> playedCards = [];
  bool isHost = false;
  bool waitingForOpponent = false;
  bool _isUpdatingFirebase = false;
  String connectionStatus = '';
  StreamSubscription<DatabaseEvent>? gameSubscription;
  StreamSubscription<DatabaseEvent>? quickMatchSubscription; // For monitoring quick match
  final TextEditingController roomCodeController = TextEditingController();
  int? lastKnownOpponentHandSize;
  int? lastKnownOpponentDrawPileSize;
  List<String> backgrounds = [
    'assets/images/playmat1.png',
    'assets/images/playmat2.png',
    'assets/images/playmat3.png',
    'assets/images/playmat4.png',
    'assets/images/playmat5.png',
    'assets/images/playmat6.png',
  ];
  int currentBackgroundIndex = 0;
  bool isTransitioning = false;

  int aiDifficulty = 1; // 1 = Easy, 2 = Medium, 3 = Hard
  int defaultAiDifficulty = 1; // Default difficulty preference (1 = Dull, 2 = Keen, 3 = Sharp)
  int winStreak = 0;
  int highScore = 0;
  int totalWins = 0;
  bool unlockedOpal = false;
  bool unlockedOnyx = false;
  bool unlockedAmber = false;
  bool unlockedAmethyst = false;

  // Map of playerId -> cardback asset (for multiplayer to show opponent's selection)
  Map<String, String> playerCardbackAssets = {};
  String aiOpponentCardbackAsset = CardWidget.defaultCardBackAsset;


  bool isPlayerTurn = true;
  bool gameOver = false;
  bool showInitialOverlay = true;
  int _gameSessionId = 0; // Increments when a new game starts, used for prize card animations
  bool _showPrizeWinShine = false; // Triggers shine animation when player wins prize
  bool _showOpponentWinShine = false; // Triggers dark shine when opponent wins prize
  bool _showCardSplash = false;
  bool showRules = false;
  bool _waitingForRematch = false;
  bool _aceDialogOpen = false;
  bool _isOpponentTurnRunning = false;
  bool showSettings = false;
  bool volumeEnabled = true;
  bool _hasEverConnected = false; // True once game has started with 2 players
  bool _isIntentionallyLeaving = false; // True when user deliberately cancels/leaves
  bool _isInitializingRematch = false; // True while host is initializing rematch to prevent double-processing
  
  // Multiplayer win streaks - tracks consecutive wins per player for timer reduction
  Map<String, int> multiplayerWinStreaks = {};

  String message = '';
  List<int> selectedIndices = [];
  List<String> selectedOps = [];
  int playerMaxHandSize = 2;
  Timer? turnTimer;
  int timerSeconds = 8;
  int currentHandSize = 2;
  Map<String, int> playedCardCounts = {}; // Track all cards played
  List<String> gameHistory = []; // Complete sequence of plays
  Map<String, int> playerPlayPatterns =
      {}; // Track player's card usage patterns
  int totalCardsPlayed = 0;
  List<int?> fieldAceValueHistory = []; // Track ace values as cards are played

  String? winner; // 'player', 'opponent', or null

  Map<String, bool> playerModifiers = {
    'mulligan': false,
    '2x': false,
    '+3': false,
    '-3': false,
    '-1': false,
    '+1': false,
    '+11': false,
    'draw1': false,
    '-0.5': false,
    'rewind': false,
  };

  Map<String, bool> opponentModifiers = {
    'mulligan': false,
    '2x': false,
    '+3': false,
    '-3': false,
    '-1': false,
    '+1': false,
    '+11': false,
    'draw1': false,
    '-0.5': false,
    'rewind': false,
  };

  String? activePlayerModifier; // Currently selected modifier for this turn
  bool showModifierSelection = false;

  List<String> playerAvailableModifiers = [];
  List<String> opponentAvailableModifiers = [];

// All possible modifiers
  static const List<String> allModifiers = [
    'mulligan',
    '2x',
    '+3',
    '-3',
    '-1',
    '+1',
    '+11',
    'draw1',
    '-0.5',
    'rewind'
  ];

  String? appliedModifier;

  // Sanitize modifier keys for Firebase
  Map<String, String> _sanitizeModifierKey(String modifier) {
    final keyMapping = {
      '2x': 'twoTimes',
      '+3': 'plusThree',
      '-3': 'minusThree',
      '+1': 'plusOne',
      '-1': 'minusOne',
      '+11': 'plusEleven',
      '-0.5': 'minusHalf', // CRITICAL: Must sanitize - Firebase doesn't allow '.' in keys
      'draw1': 'drawOne',
      'rewind': 'rewind',
      'mulligan': 'mulligan',
    };

    return keyMapping;
  }

  String _sanitizeModifierForFirebase(String modifier) {
    final mapping = _sanitizeModifierKey(modifier);
    return mapping[modifier] ?? modifier;
  }

  String _unsanitizeModifierFromFirebase(String sanitizedModifier) {
    final mapping = _sanitizeModifierKey('');
    for (String key in mapping.keys) {
      if (mapping[key] == sanitizedModifier) {
        return key;
      }
    }
    return sanitizedModifier;
  }

  late final AudioPlayer _audioPlayer;
  late final AudioPlayer _tapAudioPlayer;
  late final AudioPlayer _gameOverAudioPlayer;
  late final AudioPlayer _oppWinAudioPlayer;

  // Initialize audio context and players so they inherit the configured audio context
  Future<void> _initAudioPlayers() async {
    await _configureAudioSession();

    // Create players after audio context is set so they don't request audio focus
    _audioPlayer = AudioPlayer();
    _tapAudioPlayer = AudioPlayer();
    _gameOverAudioPlayer = AudioPlayer();
    _oppWinAudioPlayer = AudioPlayer();

    try {
      // Prefer low-latency for tap sounds
      await _tapAudioPlayer.setPlayerMode(PlayerMode.lowLatency);
    } catch (e) {}

    try {
      // Avoid forcing a specific player mode for the main players to keep
      // compatibility with the installed audioplayers version.
      // The tap player uses low-latency mode above.
    } catch (e) {}

    // Apply current volume setting to newly created players
    _applyVolumeSetting();

    // Preload tap sound
    await _preloadTapSound();
  }

  void _applyVolumeSetting() {
    try {
      final vol = volumeEnabled ? 1.0 : 0.0;
      _audioPlayer.setVolume(vol);
      _tapAudioPlayer.setVolume(vol);
      _gameOverAudioPlayer.setVolume(vol);
      _oppWinAudioPlayer.setVolume(vol);
    } catch (e) {}
  }

  Future<void> _loadVolumeSetting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool('volumeEnabled');
      if (saved != null) {
        setState(() {
          volumeEnabled = saved;
        });
        _applyVolumeSetting();
      }
    } catch (e) {}
  }

  Future<void> _saveVolumeSetting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('volumeEnabled', volumeEnabled);
    } catch (e) {}
  }

  Future<void> _loadDefaultDifficulty() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt('defaultAiDifficulty');
      if (saved != null) {
        setState(() {
          defaultAiDifficulty = saved;
        });
      }
    } catch (e) {}
  }

  Future<void> _saveDefaultDifficulty() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('defaultAiDifficulty', defaultAiDifficulty);
    } catch (e) {}
  }

  

  int? fieldAceValue;

  Color activityLogColor = const Color.fromARGB(245, 255, 255, 255);

Future<void> _loadHighScore() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      highScore = prefs.getInt('winStreakHighScore') ?? 0;
    });
  } catch (e) {
    highScore = 0;
  }
}

// Save high score to persistent storage
Future<void> _saveHighScore(int score) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('winStreakHighScore', score);
  } catch (e) {
  }
}

// Load total wins from persistent storage
Future<void> _loadTotalWins() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      totalWins = prefs.getInt('totalWinsSharp') ?? 0;
    });
  } catch (e) {
    totalWins = 0;
  }
}

// Save total wins to persistent storage
Future<void> _saveTotalWins(int wins) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('totalWinsSharp', wins);
  } catch (e) {
  }
}

// Load saved cardback choice from persistent storage
Future<void> _loadCardbackChoice() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final choice = prefs.getString('cardbackChoice') ?? 'Diamond';
    // Prefer a directly saved asset name if present so the exact asset is applied
    final savedAsset = prefs.getString('selectedCardbackAsset');
    setState(() {
      cardbackChoice = choice;
      if (savedAsset != null && savedAsset.isNotEmpty) {
        CardWidget.defaultCardBackAsset = savedAsset;
        // Derive selectedCardback token from asset filename
        if (savedAsset.contains('cardback5')) {
          selectedCardback = 'cardback5';
          cardbackChoice = 'Opal';
        } else if (savedAsset.contains('cardback4')) {
          selectedCardback = 'cardback4';
          cardbackChoice = 'Amethyst';
        } else if (savedAsset.contains('cardback3')) {
          selectedCardback = 'cardback3';
          cardbackChoice = 'Amber';
        } else if (savedAsset.contains('cardback2')) {
          selectedCardback = 'cardback2';
          cardbackChoice = 'Onyx';
        } else {
          selectedCardback = 'cardback';
          cardbackChoice = 'Diamond';
        }
      } else {
        if (choice == 'Opal') {
          selectedCardback = 'cardback5';
          CardWidget.defaultCardBackAsset = 'assets/images/cardback5.png';
        } else if (choice == 'Amethyst') {
          selectedCardback = 'cardback4';
          CardWidget.defaultCardBackAsset = 'assets/images/cardback4.png';
        } else if (choice == 'Amber') {
          selectedCardback = 'cardback3';
          CardWidget.defaultCardBackAsset = 'assets/images/cardback3.png';
        } else if (choice == 'Onyx') {
          selectedCardback = 'cardback2';
          CardWidget.defaultCardBackAsset = 'assets/images/cardback2.png';
        } else {
          selectedCardback = 'cardback';
          CardWidget.defaultCardBackAsset = 'assets/images/cardback.png';
        }
      }
    });
  } catch (e) {
    // default stays as Diamond
    cardbackChoice = 'Diamond';
  }
}

// Ensure loaded cardback is allowed; fallback to Diamond if locked
void _ensureCardbackUnlocked() async {
  if ((cardbackChoice == 'Opal' && !unlockedOpal) || (cardbackChoice == 'Amethyst' && !unlockedAmethyst) || (cardbackChoice == 'Amber' && !unlockedAmber) || (cardbackChoice == 'Onyx' && !unlockedOnyx)) {
    setState(() {
      cardbackChoice = 'Diamond';
      selectedCardback = 'cardback';
      CardWidget.defaultCardBackAsset = 'assets/images/cardback.png';
    });
    await _saveCardbackChoice();
  }
}

// Load unlocked cardbacks flags
Future<void> _loadUnlockedCardbacks() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      unlockedOpal = prefs.getBool('unlockedOpal') ?? false;
      unlockedOnyx = prefs.getBool('unlockedOnyx') ?? false;
      unlockedAmber = prefs.getBool('unlockedAmber') ?? false;
      unlockedAmethyst = prefs.getBool('unlockedAmethyst') ?? false;
    });
  } catch (e) {
    unlockedOpal = false;
    unlockedOnyx = false;
    unlockedAmber = false;
    unlockedAmethyst = false;
  }
}

// Save unlocked cardbacks flags
Future<void> _saveUnlockedCardbacks() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('unlockedOpal', unlockedOpal);
    await prefs.setBool('unlockedOnyx', unlockedOnyx);
    await prefs.setBool('unlockedAmber', unlockedAmber);
    await prefs.setBool('unlockedAmethyst', unlockedAmethyst);
  } catch (e) {}
}

// Check and unlock cardbacks based on high score thresholds
void _unlockCardbacksIfNeeded() {
  // Remember previous unlock state so we can detect newly unlocked items
  final wasOpal = unlockedOpal;
  final wasAmethyst = unlockedAmethyst;
  final wasAmber = unlockedAmber;
  final wasOnyx = unlockedOnyx;

  bool changed = false;
  // Update flags inside setState so the UI reflects unlocks immediately
  setState(() {
    if (!unlockedAmethyst && highScore >= 7) {
      unlockedAmethyst = true;
      changed = true;
    }
    if (!unlockedAmber && highScore >= 5) {
      unlockedAmber = true;
      changed = true;
    }
    if (!unlockedOnyx && highScore >= 3) {
      unlockedOnyx = true;
      changed = true;
    }
    if (!unlockedOpal && highScore >= 10) {
      unlockedOpal = true;
      changed = true;
    }
  });

  if (changed) {
    _saveUnlockedCardbacks();
    if (mounted) {
      // Show only the highest-priority newly unlocked cardback's snackbar.
      // Priority: Opal (10) > Amethyst (7) > Amber (5) > Onyx (3)
      if (!wasOpal && unlockedOpal) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unlocked Opal cardback!', style: const TextStyle(fontFamily: 'Balatro')),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.black87,
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            elevation: 6,
            duration: const Duration(seconds: 2),
          ),
        );
      } else if (!wasAmethyst && unlockedAmethyst) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unlocked Amethyst cardback!', style: const TextStyle(fontFamily: 'Balatro')),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.black87,
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            elevation: 6,
            duration: const Duration(seconds: 2),
          ),
        );
      } else if (!wasAmber && unlockedAmber) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unlocked Amber cardback!', style: const TextStyle(fontFamily: 'Balatro')),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.black87,
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            elevation: 6,
            duration: const Duration(seconds: 2),
          ),
        );
      } else if (!wasOnyx && unlockedOnyx) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unlocked Onyx cardback!', style: const TextStyle(fontFamily: 'Balatro')),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.black87,
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            elevation: 6,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

// Save cardback choice to persistent storage
Future<void> _saveCardbackChoice() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cardbackChoice', cardbackChoice);
    // Also persist the selected asset so the exact cardback is applied on load
    await prefs.setString('selectedCardbackAsset', CardWidget.defaultCardBackAsset);
    // If in human multiplayer, publish our selected cardback asset so opponents can see it
    if (gameMode == 'human' && roomCode != null && playerId != null) {
      try {
        final ref = FirebaseDatabase.instance.ref('rooms/$roomCode/playerSettings/$playerId');
        print('DEBUG: Writing cardback to Firebase -> room: $roomCode player: $playerId asset: ${CardWidget.defaultCardBackAsset} choice: $cardbackChoice');
        await ref.update({
          'cardbackAsset': CardWidget.defaultCardBackAsset,
          'choice': cardbackChoice,
        });
      } catch (e) {
        print('DEBUG: Failed writing cardback to Firebase: $e');
      }
    }

    // Immediately update local AI/opponent visuals so overlays reflect the
    // newly selected cardback without requiring a restart or game reset.
    try {
      if (mounted) {
        setState(() {
          if (gameMode == 'ai' && aiDifficulty == 3) {
            // For Sharp AI, match the player's cardback until 2 consecutive wins.
            if (winStreak < 2) {
              aiOpponentCardbackAsset = CardWidget.defaultCardBackAsset;
            } else {
              final projected = winStreak + 1;
              if (projected >= 10) {
                aiOpponentCardbackAsset = 'assets/images/cardback5.png';
              } else if (projected >= 7) {
                aiOpponentCardbackAsset = 'assets/images/cardback4.png';
              } else if (projected >= 5) {
                aiOpponentCardbackAsset = 'assets/images/cardback3.png';
              } else if (projected >= 3) {
                aiOpponentCardbackAsset = 'assets/images/cardback2.png';
              } else {
                aiOpponentCardbackAsset = CardWidget.defaultCardBackAsset;
              }
            }
          } else {
            // In other modes, reflect the player's current selection locally.
            aiOpponentCardbackAsset = CardWidget.defaultCardBackAsset;
          }
        });
      }
    } catch (e) {
      print('DEBUG: Failed to update local opponent cardback: $e');
    }
  } catch (e) {
    print('DEBUG: _saveCardbackChoice error: $e');
  }
}

// Check and update high score if current streak is higher
void _checkAndUpdateHighScore() {
  if (winStreak > highScore) {
    setState(() {
      highScore = winStreak;
    });
    _saveHighScore(highScore);
    _unlockCardbacksIfNeeded();
  }
}

// Firebase methods
  void _generatePlayerId() {
    playerId =
        'player_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
  }

  String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return String.fromCharCodes(Iterable.generate(
        3, (_) => chars.codeUnitAt(Random().nextInt(chars.length))));
  }

  void _prepareForMultiplayer() {

    // Cancel any active AI timers
    turnTimer?.cancel();

    // Cancel any existing Firebase subscriptions
    gameSubscription?.cancel();
    gameSubscription = null;
    quickMatchSubscription?.cancel();
    quickMatchSubscription = null;

    // Reset all game state
    _resetGameState();
    _resetMultiplayerState();

    // Clear any pending AI operations
    // (In case opponentTurn was scheduled)

    setState(() {
      // Ensure we're in a clean state
      gameOver = false;
      isPlayerTurn = false;
      showInitialOverlay = true;
      waitingForOpponent = false;
      message = '';
      _waitingForRematch = false;
      _hasEverConnected = false;
      _isIntentionallyLeaving = false;

      // Clear selections
      clearSelections();
    });

  }

// Quick Match - Search for an open game or create one
  Future<void> _searchForGame() async {
    
    // Light preparation - don't use _prepareForMultiplayer() as it resets too much
    turnTimer?.cancel();
    gameSubscription?.cancel();
    gameSubscription = null;
    quickMatchSubscription?.cancel();
    quickMatchSubscription = null;
    
    setState(() {
      // Set up for quick match
      isSearchingForGame = true;
      waitingForOpponent = false;
      showRoomSelection = false;
      showInitialOverlay = false; // Hide the Play button overlay
      showCreateRoom = false;
      showJoinRoom = false;
      gameMode = 'human'; // Set to human mode immediately
      connectionStatus = 'Searching for opponent...';
      gameOver = false;
      _hasEverConnected = false;
      _isIntentionallyLeaving = false;
    });

    try {
      _generatePlayerId();
      print('DEBUG: Starting quick match search with playerId: $playerId');
      
      // Query specifically for quick match rooms (not room-code rooms)
      final DatabaseReference roomsRef = FirebaseDatabase.instance.ref('rooms');
      
      final snapshot = await roomsRef
          .orderByChild('isQuickMatch')
          .equalTo(true)
          .limitToFirst(20)
          .get();
      
      print('DEBUG: Query completed. snapshot.exists=${snapshot.exists}, value type=${snapshot.value?.runtimeType}');


      String? foundRoomCode;
      
      if (snapshot.exists) {
        final rooms = snapshot.value as Map<dynamic, dynamic>;
        final now = DateTime.now().millisecondsSinceEpoch;
        
        print('DEBUG: Found ${rooms.length} quick match rooms to check');
        
        // Find a suitable quick match room that's waiting for opponent
        for (var entry in rooms.entries) {
          final roomData = entry.value as Map<dynamic, dynamic>;
          final gameState = roomData['gameState'] as String?;
          // Handle ServerValue.timestamp - it might be a map or an int
          final createdAtRaw = roomData['createdAt'];
          final createdAt = (createdAtRaw is int) ? createdAtRaw : 0;
          final host = roomData['host'] as String?;
          final players = roomData['players'] as Map<dynamic, dynamic>? ?? {};
          
          // Room must be: waiting state, less than 2 minutes old, has 1 player, not ours
          final isWaiting = gameState == 'waiting';
          final isRecent = createdAt == 0 || (now - createdAt) < 120000; // 2 minutes (or if createdAt not set)
          final hasOnePlayer = players.length == 1;
          final isNotOurs = host != playerId;
          
          print('DEBUG: Room ${entry.key}: gameState=$gameState, createdAt=$createdAtRaw, host=$host, players=${players.length}, isWaiting=$isWaiting, isRecent=$isRecent, hasOnePlayer=$hasOnePlayer, isNotOurs=$isNotOurs');
          
          if (isWaiting && isRecent && hasOnePlayer && isNotOurs) {
            foundRoomCode = entry.key as String;
            print('DEBUG: Found suitable room: $foundRoomCode');
            break;
          }
        }
      } else {
        print('DEBUG: No quick match rooms found in query');
      }

      if (foundRoomCode != null) {
        // Found an open room - join it
        print('DEBUG: Joining existing quick match room: $foundRoomCode');
        await _joinQuickMatchRoom(foundRoomCode);
      } else {
        // No room found - create one and wait
        print('DEBUG: No suitable room found, creating new quick match room');
        await _createQuickMatchRoom();
      }
    } catch (e) {
      // Show error in the Versus Mode modal so user can try again
      _resetToAIMode(showError: true, errorMessage: 'Connection error. Please try again.');
    }
  }

  Future<void> _createQuickMatchRoom() async {
    try {
      roomCode = _generateRoomCode();
      isHost = true;
      gameMode = 'human';

      final DatabaseReference roomRef =
          FirebaseDatabase.instance.ref('rooms/$roomCode');

      await roomRef.set({
        'host': playerId,
        'players': {playerId!: true},
        'gameState': 'waiting',
        'isQuickMatch': true, // Mark as quick match room
        'createdAt': ServerValue.timestamp, // For stale room cleanup
        'turn': playerId,
        'field': [],
        'activityLog': [],
        'fieldAceValue': null,
        'gameData': {'playerDecks': {}},
        'playerHands': {},
        'playerPrizeCards': {},
        'playerDrawPiles': {},
        'handSizes': {},
        'prizeCardCounts': {},
        'drawPileSizes': {},
        'modifierAssignments': {},
      });

      
      setState(() {
        waitingForOpponent = true;
        isSearchingForGame = true; // Keep this true while waiting
        showInitialOverlay = false; // Ensure Play button overlay is hidden
        connectionStatus = 'Waiting for opponent...';
      });

      _listenToRoom();

      // Publish local player's selected cardback to Firebase so opponent can see it
      try {
        final ref = FirebaseDatabase.instance.ref('rooms/$roomCode/playerSettings/$playerId');
        await ref.update({
          'cardbackAsset': CardWidget.defaultCardBackAsset,
          'choice': cardbackChoice,
        });
        print('DEBUG: Published cardback to Firebase on quick match room creation -> $playerId: ${CardWidget.defaultCardBackAsset}');
      } catch (e) {
        print('DEBUG: Failed to publish cardback on quick match room creation: $e');
      }
    } catch (e) {
      // Show error in the Versus Mode modal so user can try again
      _resetToAIMode(showError: true, errorMessage: 'Error creating game. Please try again.');
    }
  }

  Future<void> _joinQuickMatchRoom(String code) async {
    try {
      roomCode = code;
      isHost = false;
      gameMode = 'human';

      final DatabaseReference roomRef =
          FirebaseDatabase.instance.ref('rooms/$roomCode');

      // Use transaction to prevent race condition
      final result = await roomRef.runTransaction((data) {
        if (data == null) return Transaction.abort();
        
        final roomData = data as Map<dynamic, dynamic>;
        final players = roomData['players'] as Map<dynamic, dynamic>? ?? {};
        
        // Check room is still valid
        if (players.length >= 2 || roomData['gameState'] != 'waiting') {
          return Transaction.abort();
        }
        
        // Add ourselves to the room
        players[playerId!] = true;
        roomData['players'] = players;
        
        return Transaction.success(roomData);
      });

      if (!result.committed) {
        // Room was taken, search again
        await _searchForGame();
        return;
      }

      // Get host's player ID for opponent tracking
      final snapshot = await roomRef.get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final hostId = data['host'] as String?;
        if (hostId != null && hostId != playerId) {
          opponentId = hostId;
        }
      }

      setState(() {
        waitingForOpponent = true;
        showInitialOverlay = false; // Ensure Play button overlay is hidden
        connectionStatus = 'Joining game...';
      });

      _listenToRoom();

      // Publish local player's selected cardback to Firebase so opponent can see it
      try {
        final ref = FirebaseDatabase.instance.ref('rooms/$roomCode/playerSettings/$playerId');
        await ref.update({
          'cardbackAsset': CardWidget.defaultCardBackAsset,
          'choice': cardbackChoice,
        });
        print('DEBUG: Published cardback to Firebase on quick match room join -> $playerId: ${CardWidget.defaultCardBackAsset}');
      } catch (e) {
        print('DEBUG: Failed to publish cardback on quick match room join: $e');
      }
    } catch (e) {
      // Try searching again
      await _searchForGame();
    }
  }

  void _cancelQuickMatch() {
    // Set flag to prevent listener from firing disconnect events
    _isIntentionallyLeaving = true;
    
    quickMatchSubscription?.cancel();
    quickMatchSubscription = null;
    gameSubscription?.cancel();
    gameSubscription = null;
    
    // If we created a room, delete it
    final roomToDelete = roomCode;
    if (isHost && roomToDelete != null) {
      FirebaseDatabase.instance.ref('rooms/$roomToDelete').remove();
    }
    
    setState(() {
      isSearchingForGame = false;
      waitingForOpponent = false;
      connectionStatus = '';
      roomCode = null;
      opponentId = null;
      _hasEverConnected = false;
      _isIntentionallyLeaving = false; // Reset for next time
      // Go back to Versus Mode modal
      showRoomSelection = true;
      gameMode = 'ai';
    });
  }

// Update your _createRoom method
  Future<void> _createRoom() async {
    _prepareForMultiplayer();

    try {
      _generatePlayerId();
      roomCode = _generateRoomCode();
      isHost = true;
      gameMode = 'human';

      final DatabaseReference roomRef =
          FirebaseDatabase.instance.ref('rooms/$roomCode');

      // Initialize basic room structure (modifiers will be assigned when game starts)
      await roomRef.set({
        'host': playerId,
        'players': {playerId!: true},
        'gameState': 'waiting',
        'turn': playerId,
        'field': [],
        'activityLog': [],
        'fieldAceValue': null,
        'gameData': {'playerDecks': {}},
        'playerHands': {},
        'playerPrizeCards': {},
        'playerDrawPiles': {},
        'handSizes': {},
        'prizeCardCounts': {},
        'drawPileSizes': {},
        'modifierAssignments':
            {}, // Initialize empty - will be set when game starts
      });

      setState(() {
        waitingForOpponent = true;
        connectionStatus = 'Room created: $roomCode';
        showCreateRoom = true;
        showRoomSelection = false;
        gameMode = 'human';
      });

      _listenToRoom();

      // Publish local player's selected cardback to Firebase so opponent can see it
      try {
        final ref = FirebaseDatabase.instance.ref('rooms/$roomCode/playerSettings/$playerId');
        await ref.update({
          'cardbackAsset': CardWidget.defaultCardBackAsset,
          'choice': cardbackChoice,
        });
        print('DEBUG: Published cardback to Firebase on room creation -> $playerId: ${CardWidget.defaultCardBackAsset}');
      } catch (e) {
        print('DEBUG: Failed to publish cardback on room creation: $e');
      }
    } catch (e) {
      setState(() {
        connectionStatus = 'Error creating room: $e';
        // Stay in create room modal so user can try again
        showCreateRoom = true;
      });
    }
  }

// Update your _joinRoom method
  Future<void> _joinRoom(String code) async {
    // Clean up any existing game state first
    _prepareForMultiplayer();

    try {
      _generatePlayerId();
      roomCode = code.toUpperCase();
      isHost = false;
      gameMode = 'human';

      final DatabaseReference roomRef =
          FirebaseDatabase.instance.ref('rooms/$roomCode');

      final snapshot = await roomRef.get();
      if (!snapshot.exists) {
        setState(() {
          connectionStatus = 'Room not found';
          // Stay in join room modal so user can try again
          showJoinRoom = true;
          showRoomSelection = false;
        });
        return;
      }

      final data = snapshot.value as Map<dynamic, dynamic>;
      final players = data['players'] as Map<dynamic, dynamic>? ?? {};

      if (players.length >= 2) {
        setState(() {
          connectionStatus = 'Room is full';
          // Stay in join room modal so user can try again
          showJoinRoom = true;
          showRoomSelection = false;
        });
        return;
      }

      // Add the new player
      await roomRef.child('players').child(playerId!).set(true);

      // Get host's player ID for opponent tracking
      final hostId = data['host'] as String?;
      if (hostId != null && hostId != playerId) {
        opponentId = hostId;
      }

      setState(() {
        waitingForOpponent = true;
        connectionStatus = 'Joined room: $roomCode';
        showJoinRoom = false;
        showRoomSelection = false;
      });

      _listenToRoom();

      // Publish local player's selected cardback to Firebase so opponent can see it
      try {
        final ref = FirebaseDatabase.instance.ref('rooms/$roomCode/playerSettings/$playerId');
        await ref.update({
          'cardbackAsset': CardWidget.defaultCardBackAsset,
          'choice': cardbackChoice,
        });
        print('DEBUG: Published cardback to Firebase on room join -> $playerId: ${CardWidget.defaultCardBackAsset}');
      } catch (e) {
        print('DEBUG: Failed to publish cardback on room join: $e');
      }
    } catch (e) {
      setState(() {
        connectionStatus = 'Error joining room: $e';
        // Stay in join room modal so user can try again
        showJoinRoom = true;
        showRoomSelection = false;
      });
    }
  }

// Add this helper method to safely return to AI mode on errors
  void _resetToAIMode({bool showError = false, String errorMessage = ''}) {
    setState(() {
      gameMode = 'ai';
      isSearchingForGame = false;
      waitingForOpponent = false;
      showCreateRoom = false;
      showJoinRoom = false;
      
      if (showError && errorMessage.isNotEmpty) {
        // Show the Versus Mode modal with error message
        showRoomSelection = true;
        showInitialOverlay = false;
        connectionStatus = errorMessage;
      } else {
        // Return to initial state
        showRoomSelection = false;
        showInitialOverlay = true;
        connectionStatus = '';
      }
    });
  }
  
  // Helper to reset back to search/selection when room disappears before connection
  void _resetToSearchState() {
    gameSubscription?.cancel();
    gameSubscription = null;
    quickMatchSubscription?.cancel();
    quickMatchSubscription = null;
    
    setState(() {
      isSearchingForGame = false;
      waitingForOpponent = false;
      roomCode = null;
      opponentId = null;
      _hasEverConnected = false;
      // Go back to Versus Mode modal so they can try again
      showRoomSelection = true;
      showInitialOverlay = false;
      connectionStatus = 'Room closed. Please try again.';
    });
  }

  void _listenToRoom() {
    if (roomCode == null) return;

    final DatabaseReference roomRef =
        FirebaseDatabase.instance.ref('rooms/$roomCode');

    gameSubscription = roomRef.onValue.listen((DatabaseEvent event) {
      if (!mounted) return;
      
      // If we're intentionally leaving, ignore all events
      if (_isIntentionallyLeaving) return;

      try {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        if (data == null) {
          // Room was deleted - only handle as disconnect if we were actually connected
          if (_hasEverConnected) {
            _handleOpponentDisconnect();
          } else {
            // Room deleted before we ever connected - just reset to search/selection
            _resetToSearchState();
          }
          return;
        }

        final gameState = data['gameState'] as String?;
        final players = data['players'] as Map<dynamic, dynamic>? ?? {};

        // Check for opponent disconnect - only if we were actually connected
        if (players.length < 2 && _hasEverConnected && !waitingForOpponent) {
          _handleOpponentDisconnect();
          return;
        }

        // Set opponent ID if we don't have it
        if (opponentId == null && players.length == 2) {
          for (String pid in players.keys.cast<String>()) {
            if (pid != playerId) {
              opponentId = pid;
              break;
            }
          }
        }

        // FIXED: If we're the host and a second player joined, start the game
        if (isHost && players.length == 2 && gameState == 'waiting') {
          _initializeCompleteGameState();
        }

        if (gameState == 'playing' && players.length == 2) {
          // Mark that we've successfully connected
          _hasEverConnected = true;
          
          // CRITICAL FIX: Always ensure showInitialOverlay is false during active multiplayer games
          final wasWaitingForOpponent = waitingForOpponent;
          if (waitingForOpponent || showInitialOverlay) {
            setState(() {
              waitingForOpponent = false;
              isSearchingForGame = false;
              showInitialOverlay = false;
              showCreateRoom = false;
              if (wasWaitingForOpponent) {
                _gameSessionId++; // Trigger prize card entrance animation for multiplayer (only on first connect)
              }
            });
          }
          _updateGameFromFirebase(data);
        } else if (gameState == 'gameOver') {
          _handleGameOverFromFirebase(data);
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            connectionStatus = 'Connection error occurred';
          });
        }
      }
    });
  }

  Future<void> _initializeCompleteGameState([String? firstPlayer]) async {
    if (!isHost || roomCode == null || opponentId == null) return;

    try {
      final DatabaseReference roomRef =
          FirebaseDatabase.instance.ref('rooms/$roomCode');

      // Create and distribute decks
      fullDeck = _createFullDeck();
      fullDeck.shuffle(Random());

      final playerDeck = List<String>.from(fullDeck.sublist(0, 34));
      final opponentDeck = List<String>.from(fullDeck.sublist(34, 68));

      // Use provided firstPlayer or default to host
      final gameFirstPlayer = firstPlayer ?? playerId!;

      // CRITICAL FIX: Generate modifier assignments once and store in Firebase
      List<String> shuffledModifiers = List.from(allModifiers)..shuffle();

      // Assign modifiers to specific player IDs (not local variables)
      List<String> hostModifiers = shuffledModifiers.take(3).toList();
      List<String> guestModifiers = shuffledModifiers.skip(3).take(3).toList();

      // Determine which player gets which modifiers based on their IDs
      Map<String, List<String>> playerModifierAssignments = {
        playerId!: hostModifiers, // Host gets first 3
        opponentId!: guestModifiers, // Guest gets next 3
      };

      // Update local modifier assignments
      playerAvailableModifiers = playerModifierAssignments[playerId!]!;
      opponentAvailableModifiers = playerModifierAssignments[opponentId!]!;

      // Reset modifier usage states based on assignments
      playerModifiers = {};
      opponentModifiers = {};

      for (String modifier in playerAvailableModifiers) {
        playerModifiers[modifier] = false;
      }

      for (String modifier in opponentAvailableModifiers) {
        opponentModifiers[modifier] = false;
      }

      // Create sanitized versions for Firebase
      Map<String, bool> myModifiersSanitized = {};
      Map<String, bool> oppModifiersSanitized = {};

      for (String key in playerModifiers.keys) {
        String sanitizedKey = _sanitizeModifierForFirebase(key);
        myModifiersSanitized[sanitizedKey] = playerModifiers[key] ?? false;
      }

      for (String key in opponentModifiers.keys) {
        String sanitizedKey = _sanitizeModifierForFirebase(key);
        oppModifiersSanitized[sanitizedKey] = opponentModifiers[key] ?? false;
      }

      // Store modifier assignments in Firebase so both players can see them
      Map<String, List<String>> sanitizedAssignments = {};
      for (String playerId in playerModifierAssignments.keys) {
        sanitizedAssignments[playerId] = playerModifierAssignments[playerId]!
            .map((modifier) => _sanitizeModifierForFirebase(modifier))
            .toList();
      }

      // Initialize complete game state with modifier assignments
      final updates = {
        'gameState': 'playing',
        'turn': gameFirstPlayer,
        'field': [],
        'activityLog': [],
        'fieldAceValue': null,
        'firstPlayer': gameFirstPlayer,
        'gameData': {
          'playerDecks': {
            playerId!: playerDeck,
            opponentId!: opponentDeck,
          }
        },
        // CRITICAL: Store modifier assignments so both players can see them
        'modifierAssignments': sanitizedAssignments,
        'playerHands/$playerId': playerDeck.sublist(3, 5),
        'playerHands/$opponentId': opponentDeck.sublist(3, 5),
        'playerPrizeCards/$playerId': playerDeck.sublist(0, 3),
        'playerPrizeCards/$opponentId': opponentDeck.sublist(0, 3),
        'playerDrawPiles/$playerId': playerDeck.sublist(5),
        'playerDrawPiles/$opponentId': opponentDeck.sublist(5),
        'handSizes/$playerId': 2,
        'handSizes/$opponentId': 2,
        'maxHandSizes/$playerId': 2,
        'maxHandSizes/$opponentId': 2,
        'prizeCardCounts/$playerId': 3,
        'prizeCardCounts/$opponentId': 3,
        'drawPileSizes/$playerId': playerDeck.sublist(5).length,
        'drawPileSizes/$opponentId': opponentDeck.sublist(5).length,
        'playerModifiers/$playerId': myModifiersSanitized,
        'playerModifiers/$opponentId': oppModifiersSanitized,
        'lastTimeoutPenalty': null,
        'rematchRequests': {},
        // Initialize win streaks if not present (preserve existing values for rematches)
        'winStreaks/$playerId': multiplayerWinStreaks[playerId] ?? 0,
        'winStreaks/$opponentId': multiplayerWinStreaks[opponentId] ?? 0,
      };

      await roomRef.update(updates);
    } catch (e) {
    }
  }

  void _updateGameFromFirebase(Map<dynamic, dynamic> data) {
    try {
      final turn = data['turn'] as String?;
      final gameState = data['gameState'] as String?;
      final fieldData = data['field'] as List<dynamic>? ?? [];
      final activityLogData = data['activityLog'] as List<dynamic>? ?? [];
      final fieldAceValueData = data['fieldAceValue'] as int?;
      final players = data['players'] as Map<dynamic, dynamic>? ?? {};

      // CRITICAL FIX: Read modifier assignments from Firebase
      final modifierAssignments =
          data['modifierAssignments'] as Map<dynamic, dynamic>? ?? {};

      if (modifierAssignments.isNotEmpty && opponentId != null) {
        // Update my available modifiers
        if (modifierAssignments.containsKey(playerId)) {
          final myAssignedModifiers = List<String>.from(
              (modifierAssignments[playerId] as List<dynamic>? ?? [])
                  .cast<String>());

          // Convert back from sanitized keys
          playerAvailableModifiers = myAssignedModifiers
              .map((sanitized) => _unsanitizeModifierFromFirebase(sanitized))
              .toList();

        }

        // Update opponent's available modifiers
        if (modifierAssignments.containsKey(opponentId)) {
          final oppAssignedModifiers = List<String>.from(
              (modifierAssignments[opponentId] as List<dynamic>? ?? [])
                  .cast<String>());

          // Convert back from sanitized keys
          opponentAvailableModifiers = oppAssignedModifiers
              .map((sanitized) => _unsanitizeModifierFromFirebase(sanitized))
              .toList();

        }
      }

      final playerModifiersData =
          data['playerModifiers'] as Map<dynamic, dynamic>? ?? {};

      if (playerModifiersData.containsKey(playerId)) {
        final myModifiers =
            playerModifiersData[playerId] as Map<dynamic, dynamic>? ?? {};

        // Clear current modifiers
        for (String key in playerModifiers.keys) {
          playerModifiers[key] = false;
        }

        // Only update modifiers that are in our assignment
        for (String modifier in playerAvailableModifiers) {
          String sanitizedKey = _sanitizeModifierForFirebase(modifier);
          if (myModifiers.containsKey(sanitizedKey)) {
            playerModifiers[modifier] =
                myModifiers[sanitizedKey] as bool? ?? false;
          }
        }
      }

      if (opponentId != null && playerModifiersData.containsKey(opponentId)) {
        final oppModifiers =
            playerModifiersData[opponentId] as Map<dynamic, dynamic>? ?? {};

        // Clear current opponent modifiers
        for (String key in opponentModifiers.keys) {
          opponentModifiers[key] = false;
        }

        // Only update modifiers that are in opponent's assignment
        for (String modifier in opponentAvailableModifiers) {
          String sanitizedKey = _sanitizeModifierForFirebase(modifier);
          if (oppModifiers.containsKey(sanitizedKey)) {
            opponentModifiers[modifier] =
                oppModifiers[sanitizedKey] as bool? ?? false;
          }
        }
      }

      // Handle rematch transitions and early returns
      if (gameState == 'playing' && players.length == 2) {
        // Check if this is a rematch transition
        // Use multiple conditions to detect rematch:
        // 1. Standard: waiting flag AND (game was over OR field is empty)
        // 2. Fallback: game is still in gameOver state but Firebase says 'playing' with empty field
        //    This handles the case where non-host receives 'playing' before processing rematch request
        final rematchRequests = data['rematchRequests'] as Map<dynamic, dynamic>? ?? {};
        final isStandardTransition = _waitingForRematch && 
            (gameOver || (fieldData.isEmpty && rematchRequests.isEmpty));
        final isFallbackTransition = !isHost && gameOver && fieldData.isEmpty && rematchRequests.isEmpty;
        final isRematchTransition = isStandardTransition || isFallbackTransition;
        
        print('DEBUG REMATCH: gameState=$gameState, _waitingForRematch=$_waitingForRematch, gameOver=$gameOver, fieldData.isEmpty=${fieldData.isEmpty}, rematchRequests=$rematchRequests, isStandardTransition=$isStandardTransition, isFallbackTransition=$isFallbackTransition, isRematchTransition=$isRematchTransition, isHost=$isHost');
        
        if (isRematchTransition) {
          final firstPlayer = data['firstPlayer'] as String?;
          print('DEBUG REMATCH: Transition detected! firstPlayer=$firstPlayer');
          if (firstPlayer != null) {
            // Only non-host should use _handleRematchStart
            // Host handles transition in _initializeCompleteGameState().then()
            if (!isHost) {
              print('DEBUG REMATCH: Non-host calling _handleRematchStart');
              _handleRematchStart(firstPlayer);
              print('DEBUG REMATCH: Non-host _handleRematchStart complete, continuing to process Firebase data');
            } else {
              // Host: just clear waiting flag, let .then() handle the rest
              print('DEBUG REMATCH: Host clearing waiting flag');
              _waitingForRematch = false;
            }
          }
        }
        
        // SAFEGUARD: If still in waiting state but game is playing, clear it
        // This prevents getting stuck in waiting forever
        if (_waitingForRematch && !gameOver) {
          print('DEBUG REMATCH: Safeguard triggered - clearing stuck waiting state');
          setState(() {
            _waitingForRematch = false;
          });
        }

        // CRITICAL FIX: Always ensure showInitialOverlay is false during active multiplayer games
        if (waitingForOpponent || showInitialOverlay) {
          setState(() {
            waitingForOpponent = false;
            isSearchingForGame = false;
            showInitialOverlay = false;
            showCreateRoom = false;
          });
        }
        // Continue with normal game state processing below
      } else if (gameState == 'gameOver') {
        _handleGameOverFromFirebase(data);
        return; // Exit early for game over state
      }

      // ENHANCED DEBUG LOGGING

      // Get game data
      final gameData = data['gameData'] as Map<dynamic, dynamic>? ?? {};
      final playerDecks =
          gameData['playerDecks'] as Map<dynamic, dynamic>? ?? {};
      final playerHandsData =
          data['playerHands'] as Map<dynamic, dynamic>? ?? {};
      final playerPrizeCardsData =
          data['playerPrizeCards'] as Map<dynamic, dynamic>? ?? {};
      final playerDrawPilesData =
          data['playerDrawPiles'] as Map<dynamic, dynamic>? ?? {};
      final handSizes = data['handSizes'] as Map<dynamic, dynamic>? ?? {};
      final prizeCardCounts =
          data['prizeCardCounts'] as Map<dynamic, dynamic>? ?? {};
      final drawPileSizes =
          data['drawPileSizes'] as Map<dynamic, dynamic>? ?? {};
      final maxHandSizes = data['maxHandSizes'] as Map<dynamic, dynamic>? ?? {};
      
      // Read win streaks for dynamic timer calculation
      final winStreaksData = data['winStreaks'] as Map<dynamic, dynamic>? ?? {};
      for (var entry in winStreaksData.entries) {
        multiplayerWinStreaks[entry.key as String] = entry.value as int? ?? 0;
      }

      setState(() {
        // FIXED: Store previous turn state to detect changes and add debug logging
        final wasMyTurn = isPlayerTurn;
        final newTurnState = (turn == playerId);


        // CRITICAL: Add validation that we have proper opponent ID
        if (opponentId == null) {
          // Try to find opponent from players in the room data
          if (players.length == 2) {
            for (String pid in players.keys.cast<String>()) {
              if (pid != playerId) {
                opponentId = pid;
                break;
              }
            }
          }
        }

        // CRITICAL FIX: Only trust Firebase for turn state
        isPlayerTurn = newTurnState;

        // Read player-specific settings (like selected cardback) from Firebase
        final playerSettings = data['playerSettings'] as Map<dynamic, dynamic>? ?? {};
        print('DEBUG: playerSettings payload from Firebase: $playerSettings');
        if (playerSettings.isNotEmpty) {
          for (var entry in playerSettings.entries) {
            final pid = entry.key as String;
            final settingsMap = entry.value as Map<dynamic, dynamic>? ?? {};
            String? asset;
            if (settingsMap.containsKey('cardbackAsset')) {
              asset = settingsMap['cardbackAsset'] as String?;
            } else if (settingsMap.containsKey('choice')) {
              final choice = settingsMap['choice'] as String?;
              if (choice == 'Opal') {
                asset = 'assets/images/cardback5.png';
              } else if (choice == 'Amethyst') {
                asset = 'assets/images/cardback4.png';
              } else if (choice == 'Amber') {
                asset = 'assets/images/cardback3.png';
              } else if (choice == 'Onyx') {
                asset = 'assets/images/cardback2.png';
              } else {
                asset = 'assets/images/cardback.png';
              }
            }

            if (asset != null) {
              playerCardbackAssets[pid] = asset;
            }
          }
          print('DEBUG: populated playerCardbackAssets: $playerCardbackAssets');
        }

        // Track previous field length to detect opponent card plays
        final previousFieldLength = field.length;
        field = List<String>.from(fieldData.cast<String>());

// Play card sound when opponent plays (field grows and it wasn't my turn)
        if (!wasMyTurn && field.length > previousFieldLength) {
          Future.delayed(const Duration(milliseconds: 100), () {
            playCardSound();
          });
        }

        // FIXED: Process activity log with proper "you" vs "opponent" labeling
        final rawActivityLog =
            List<String>.from(activityLogData.cast<String>());
        activityLog = rawActivityLog.map((message) {
          String processedMessage = message;

          if (message.startsWith('$playerId played:')) {
            processedMessage =
                message.replaceFirst('$playerId played:', 'You played:');
          } else if (opponentId != null &&
              message.startsWith('$opponentId played:')) {
            processedMessage =
                message.replaceFirst('$opponentId played:', 'Opp played:');
          } else if (message.contains('timed out')) {
            // Handle timeout messages
            if (message.startsWith('$playerId timed out')) {
              processedMessage = message.replaceFirst(
                  '$playerId timed out - $opponentId gets prize card!',
                  'You timed out!');
            } else if (opponentId != null &&
                message.startsWith('$opponentId timed out')) {
              processedMessage = message.replaceFirst(
                  '$opponentId timed out - $playerId gets prize card!',
                  'Opponent timed out!');
            }
          } else if (message.contains('used') &&
              (message.contains('modifier') || message.contains('mod'))) {
            // Handle modifier usage messages
            if (message.startsWith('$playerId used')) {
              processedMessage =
                  message.replaceFirst('$playerId used', 'You used');
            } else if (opponentId != null &&
                message.startsWith('$opponentId used')) {
              processedMessage =
                  message.replaceFirst('$opponentId used', 'Opp used');
            }
          }

          // Remove the result indicators from the visible message
          processedMessage =
              processedMessage.replaceAll(RegExp(r' \((winning|normal)\)'), '');

          return processedMessage;
        }).toList();

// NEW: Set activity log color based on the latest message (before cleaning)
        if (activityLogData.isNotEmpty) {
          final lastRawMessage = activityLogData.last as String;
          if (lastRawMessage.startsWith('$playerId played:')) {
            // Check if this was a winning play
            if (lastRawMessage.contains('(winning)')) {
              activityLogColor = Colors.greenAccent; // Player won a prize
            } else {
              activityLogColor = Colors.white; // Regular play
            }
          } else if (opponentId != null &&
              lastRawMessage.startsWith('$opponentId played:')) {
            // Check if opponent won a prize
            if (lastRawMessage.contains('(winning)')) {
              activityLogColor = Colors.redAccent; // Opponent won a prize
            } else {
              activityLogColor = Colors.white; // Regular play
            }
          } else if (lastRawMessage.contains('timed out')) {
            activityLogColor = Colors.white; // Timeout message
          } else {
            activityLogColor = Colors.white; // Default
          }
        }

        fieldAceValue = fieldAceValueData;

        // Initialize local game if we have deck data
        if (playerDecks.containsKey(playerId)) {
          final myDeck = List<String>.from(
              (playerDecks[playerId] as List<dynamic>)
                  .cast<String>()); // FIXED: Create mutable copy
          if (playerHand.isEmpty) {
            // First time setup
            playerDeck = myDeck;
            playerHand = List<String>.from(myDeck.sublist(3, 5));
            playerPrizeCards = List<String>.from(myDeck.sublist(0, 3));
            playerDrawPile = List<String>.from(myDeck.sublist(5));
          }
        }

        // Set up opponent data locally
        if (opponentId != null && playerDecks.containsKey(opponentId)) {
          final opponentDeckData = List<String>.from(
              (playerDecks[opponentId] as List<dynamic>)
                  .cast<String>()); // FIXED: Create mutable copy
          if (opponentActualHand.isEmpty) {
            // First time setup
            opponentDeck = opponentDeckData;
            opponentActualHand =
                List<String>.from(opponentDeckData.sublist(3, 5));
            opponentPrizeCards = List.generate(3, (_) => 'cardback');
            opponentActualDrawPile =
                List<String>.from(opponentDeckData.sublist(5));
          }
        }

        // FIXED: Only update player data if it exists in Firebase
        if (playerHandsData.containsKey(playerId)) {
          final handData = List<String>.from(
              (playerHandsData[playerId] as List<dynamic>)
                  .cast<String>()); // FIXED: Create mutable copy
          // FIXED: Only update if the data is different to prevent unnecessary overwrites
          if (handData.length != playerHand.length ||
              !_listsEqual(handData, playerHand)) {
            playerHand = handData;
          }
        }

        if (playerPrizeCardsData.containsKey(playerId)) {
          final prizeData = List<String>.from(
              (playerPrizeCardsData[playerId] as List<dynamic>).cast<String>());
          if (prizeData.length != playerPrizeCards.length ||
              !_listsEqual(prizeData, playerPrizeCards)) {
            playerPrizeCards = prizeData;
          }
        } else if (prizeCardCounts.containsKey(playerId)) {
          // FIXED: Only sync counts if we don't have explicit prize card data
          // and ONLY if the count is LARGER than current (never regenerate lost cards)
          final expectedPrizeCount = prizeCardCounts[playerId] as int;
          if (expectedPrizeCount > playerPrizeCards.length) {
            while (playerPrizeCards.length < expectedPrizeCount) {
              playerPrizeCards.add('cardback');
            }
          }
          // DO NOT regenerate if count is smaller - that means cards were legitimately lost
        }

        if (playerDrawPilesData.containsKey(playerId)) {
          final drawData = List<String>.from(
              (playerDrawPilesData[playerId] as List<dynamic>)
                  .cast<String>()); // FIXED: Create mutable copy
          if (drawData.length != playerDrawPile.length ||
              !_listsEqual(drawData, playerDrawPile)) {
            playerDrawPile = drawData;
          }
        }

        if (maxHandSizes.containsKey(playerId)) {
          final maxHandSizeData = maxHandSizes[playerId] as int? ?? 2;
          if (maxHandSizeData != playerMaxHandSize) {
            playerMaxHandSize = maxHandSizeData;
          }
        }

        // FIXED: Sync modifier states from Firebase
        final playerModifiersData =
            data['playerModifiers'] as Map<dynamic, dynamic>? ?? {};

        if (playerModifiersData.containsKey(playerId)) {
          final myModifiers =
              playerModifiersData[playerId] as Map<dynamic, dynamic>? ?? {};
          for (String key in playerModifiers.keys) {
            // FIX: Use sanitized key to look up in Firebase data
            String sanitizedKey = _sanitizeModifierForFirebase(key);
            if (myModifiers.containsKey(sanitizedKey)) {
              playerModifiers[key] = myModifiers[sanitizedKey] as bool? ?? false;
            }
          }
        }

        if (opponentId != null && playerModifiersData.containsKey(opponentId)) {
          final oppModifiers =
              playerModifiersData[opponentId] as Map<dynamic, dynamic>? ?? {};
          for (String key in opponentModifiers.keys) {
            // FIX: Use sanitized key to look up in Firebase data
            String sanitizedKey = _sanitizeModifierForFirebase(key);
            if (oppModifiers.containsKey(sanitizedKey)) {
              opponentModifiers[key] = oppModifiers[sanitizedKey] as bool? ?? false;
            }
          }
        }

        // Check for timeout penalty first to determine if opponent prize decrease is due to penalty
        final lastTimeoutPenalty =
            data['lastTimeoutPenalty'] as Map<dynamic, dynamic>?;
        final isOpponentTimeoutPenalty = lastTimeoutPenalty != null &&
            lastTimeoutPenalty['timeoutPlayer'] == opponentId;

        // Update OPPONENT display based on sizes
        if (opponentId != null) {
          final opponentHandSize =
              handSizes[opponentId] as int? ?? opponentHand.length;
          final opponentPrizeCount =
              prizeCardCounts[opponentId] as int? ?? opponentPrizeCards.length;
          final opponentDrawSize =
              drawPileSizes[opponentId] as int? ?? opponentDrawPile.length;
          // Check if opponent won a prize card (their count decreased) before updating
          final previousOpponentPrizeCount = opponentPrizeCards.length;
          final opponentCountDecreased =
              opponentPrizeCount < previousOpponentPrizeCount;

          // Only treat as "opponent won prize" if count decreased AND it's NOT a timeout penalty
          final opponentWonPrize =
              opponentCountDecreased && !isOpponentTimeoutPenalty;

          // FIXED: Only update if sizes changed to prevent unnecessary rebuilds
          if (opponentHand.length != opponentHandSize) {
            opponentHand = List.generate(opponentHandSize, (_) => 'cardback');
          }

          // CRITICAL: Handle player benefiting from opponent timeout BEFORE updating prize counts
          // This ensures animation/sound triggers even if prize count hasn't updated yet
          if (isOpponentTimeoutPenalty) {
            final String penaltyId = (lastTimeoutPenalty != null && lastTimeoutPenalty['id'] != null)
                ? lastTimeoutPenalty['id'].toString()
                : lastTimeoutPenalty.toString();

            if (!processedTimeoutPenalties.contains(penaltyId)) {
              processedTimeoutPenalties.add(penaltyId);
              print('DEBUG: Opponent timeout detected! Triggering win animation and sound.');

              // Trigger player win shine animation and play win sound
              setState(() {
                _showPrizeWinShine = true;
              });

              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) {
                  playPrizeCardSound(); // Use player's win sound
                }
              });

              Future.delayed(const Duration(milliseconds: 800), () {
                if (mounted) {
                  setState(() {
                    _showPrizeWinShine = false;
                  });
                }
              });
            }
          }

          if (opponentPrizeCards.length != opponentPrizeCount) {
            // Handle normal opponent wins (non-timeout)
            if (opponentWonPrize) {
              // Only play sound if opponent still has prize cards left (not the final one)
              if (opponentPrizeCount > 0) {
                Future.delayed(const Duration(milliseconds: 100), () {
                  playOpponentPrizeCardSound();
                });
              }
              // Trigger opponent win shine animation for multiplayer
              _showOpponentWinShine = true;
              Future.delayed(const Duration(milliseconds: 800), () {
                if (mounted) {
                  setState(() {
                    _showOpponentWinShine = false;
                  });
                }
              });
            }

            opponentPrizeCards =
                List.generate(opponentPrizeCount, (_) => 'cardback');
          }
  if (opponentDrawPile.length != opponentDrawSize) {
    opponentDrawPile =
        List.generate(opponentDrawSize, (_) => 'cardback');
  }
}

        // FIXED: Critical turn management - only act on actual turn changes
        if (!gameOver) {
          if (isPlayerTurn && !wasMyTurn) {
            // Turn switched TO me
            message = "Your turn!";
            turnTimer?.cancel();
            startTimer();
            clearSelections();
          } else if (!isPlayerTurn && wasMyTurn) {
            // Turn switched AWAY from me
            message = "Opponent's turn!";
            turnTimer?.cancel();
            clearSelections();
            activePlayerModifier = null; // Clears any selected modifiers
            showModifierSelection = false;

            // NEW: Close ace dialog if it's open
            if (_aceDialogOpen && mounted) {
              Navigator.of(context).pop(); // Close the dialog
              _aceDialogOpen = false;
            }
          } else if (isPlayerTurn &&
              (turnTimer == null || !turnTimer!.isActive)) {
            // I still have turn but timer isn't running
            message = "Your turn!";
            startTimer();
            clearSelections();
          } else if (!isPlayerTurn) {
            message = "Opponent's turn!";
          } else {
          }
        }

        // Check for win conditions
        if (!gameOver) {
          checkForWin();
        }
      });

      // Add debug logging for modifier state
    } catch (e) {
    }
  }

// Helper method to compare lists efficiently
  bool _listsEqual<T>(List<T> list1, List<T> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }

  void _handleGameOverFromFirebase(Map<dynamic, dynamic> data) {
  final winner = data['winner'] as String?;
  final winnerMessage = data['winnerMessage'] as String?;

  // First, ensure game over state is set for both players
  if (!gameOver) {
    setState(() {
      gameOver = true;
      this.winner = winner == playerId ? 'player' : 'opponent';
      message = winnerMessage ??
          (winner == playerId ? "You win!" : "Opponent wins!");
      isPlayerTurn = false;
      clearSelections();
    });
    turnTimer?.cancel();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (winner == playerId) {
        playGameWinSound();
      } else {
        playGameLossSound();
      }
    });
  }

  // FIX: Sync win streaks IMMEDIATELY when game ends, before checking rematch status
  final winStreaksData = data['winStreaks'] as Map<dynamic, dynamic>? ?? {};
      if (winStreaksData.isNotEmpty) {
    setState(() {
      for (var entry in winStreaksData.entries) {
        multiplayerWinStreaks[entry.key as String] = entry.value as int? ?? 0;
      }
      // Update the local winStreak variable that the UI displays
      // but DO NOT treat multiplayer streaks as global progress for
      // high-score or unlocking cardbacks. High score is only updated
      // from single-player (non-human) wins.
      if (playerId != null && multiplayerWinStreaks.containsKey(playerId)) {
        winStreak = multiplayerWinStreaks[playerId]!;
      }
    });
  }

  // Handle rematch requests - but don't change gameOver state until both players are ready
  final rematchRequests =
      data['rematchRequests'] as Map<dynamic, dynamic>? ?? {};

  print('DEBUG GAMEOVER: Processing rematch. rematchRequests=$rematchRequests, playerId=$playerId, gameOver=$gameOver, isHost=$isHost');

  // If this player hasn't requested rematch yet, don't process other player's request
  if (!rematchRequests.containsKey(playerId)) {
    print('DEBUG GAMEOVER: Early return - this player hasnt requested rematch yet');
    return;
  }

  // Only proceed if both players have requested rematch
  if (rematchRequests.length == 2 && gameOver) {
    print('DEBUG GAMEOVER: Both players requested rematch!');
    
    // CRITICAL: Check if we're already initializing a rematch to prevent double-processing
    if (_isInitializingRematch) {
      print('DEBUG GAMEOVER: Already initializing rematch, skipping');
      return;
    }
    
    // Get who went first last game and alternate
    final lastFirstPlayer = data['firstPlayer'] as String?;
    final nextFirstPlayer =
        (lastFirstPlayer == playerId) ? opponentId : playerId;
    print('DEBUG GAMEOVER: lastFirstPlayer=$lastFirstPlayer, nextFirstPlayer=$nextFirstPlayer');

    if (isHost) {
      print('DEBUG GAMEOVER: Host starting rematch initialization');
      // Set flag to prevent double-processing
      _isInitializingRematch = true;
      
      // CRITICAL: Clear waiting flag IMMEDIATELY to prevent race condition
      // The Firebase listener might trigger before .then() runs, causing double-processing
      _waitingForRematch = false;
      
      // Host initializes the new game
      _resetGameState();
      // Clear hands so they get re-populated from Firebase
      playerHand = [];
      playerPrizeCards = [];
      playerDrawPile = [];
      opponentHand = [];
      opponentPrizeCards = [];
      opponentDrawPile = [];
      opponentActualHand = [];
      opponentActualDrawPile = [];
      // Increment game session ID to trigger animations
      _gameSessionId++;
      
      print('DEBUG GAMEOVER: Host calling _initializeCompleteGameState');
      _initializeCompleteGameState(nextFirstPlayer).then((_) {
        print('DEBUG GAMEOVER: _initializeCompleteGameState completed, mounted=$mounted');
        // Clear the initialization flag
        _isInitializingRematch = false;
        
        if (mounted) {
          setState(() {
            // Always ensure these are in correct state for new game
            gameOver = false;
            waitingForOpponent = false;
            _waitingForRematch = false;
            showInitialOverlay = false; // Ensure overlay is hidden for rematch
            
            // Only set turn message if not already set
            if (message.isEmpty || message.contains('Waiting') || message.contains('Starting')) {
              message = (nextFirstPlayer == playerId)
                  ? "Your turn!"
                  : "Opponent's turn!";
            }
            isPlayerTurn = (nextFirstPlayer == playerId);
          });
          print('DEBUG GAMEOVER: Host setState complete, isPlayerTurn=$isPlayerTurn');
          
          // Start timer if it's our turn and timer isn't already running
          if (nextFirstPlayer == playerId && (turnTimer == null || !turnTimer!.isActive)) {
            print('DEBUG GAMEOVER: Host starting timer');
            startTimer();
          }
        }
      }).catchError((error) {
        print('DEBUG GAMEOVER: _initializeCompleteGameState error: $error');
        // Clear the initialization flag on error too
        _isInitializingRematch = false;
        // Reset waiting state on error
        if (mounted) {
          setState(() {
            _waitingForRematch = false;
            gameOver = true; // Restore game over state on error
            message = "Failed to start new game";
          });
        }
      });
    } else {
      // Non-host waits for host to initialize, but doesn't change gameOver yet
      print('DEBUG GAMEOVER: Non-host setting _waitingForRematch = true');
      setState(() {
        _waitingForRematch = true;
        message = "Starting new game...";
      });

      // The actual game state change will come through the normal Firebase listener
      // when the host updates the game state to 'playing'
    }
  }
  print('DEBUG GAMEOVER: Exiting _handleGameOverFromFirebase');
}

// Also add this helper method to handle the transition from waiting to playing
  void _handleRematchStart(String nextFirstPlayer) {
    print('DEBUG _handleRematchStart: Called with nextFirstPlayer=$nextFirstPlayer, mounted=$mounted, _waitingForRematch=$_waitingForRematch, gameOver=$gameOver, field.isEmpty=${field.isEmpty}');
    if (!mounted) {
      print('DEBUG _handleRematchStart: Early return - not mounted');
      return;
    }
    
    // Only proceed if we were waiting for rematch OR if we're stuck in gameOver with stale data
    final shouldTransition = _waitingForRematch || (gameOver && field.isEmpty);
    if (!shouldTransition) {
      print('DEBUG _handleRematchStart: Early return - shouldTransition=$shouldTransition');
      return;
    }
    print('DEBUG _handleRematchStart: Proceeding with transition');
    
    // CRITICAL FIX: Reset local game state for non-host before processing new game
    // This clears old field, cards, modifiers, etc.
    field = [];
    activityLog.clear();
    fieldAceValue = null;
    fieldAceValueHistory.clear();
    clearSelections();
    playerMaxHandSize = 2;
    activePlayerModifier = null;
    showModifierSelection = false;
    
    // Clear hands so they get re-populated from Firebase
    playerHand = [];
    playerPrizeCards = [];
    playerDrawPile = [];
    opponentHand = [];
    opponentPrizeCards = [];
    opponentDrawPile = [];
    opponentActualHand = [];
    opponentActualDrawPile = [];
    
    // Increment game session ID to trigger animations
    _gameSessionId++;
    
    setState(() {
      gameOver = false;
      waitingForOpponent = false;
      _waitingForRematch = false;
      showInitialOverlay = false; // Ensure overlay is hidden for rematch
      message =
          (nextFirstPlayer == playerId) ? "Your turn!" : "Opponent's turn!";
      isPlayerTurn = (nextFirstPlayer == playerId);
    });

    if (nextFirstPlayer == playerId) {
      startTimer();
    }
  }

  Future<void> _updateFirebaseGameState() async {
    if (roomCode == null || playerId == null || _isUpdatingFirebase) return;

    try {
      _isUpdatingFirebase = true;

      // Generate activity message for this move
      String activityMessage;
      List<String> formattedCards = [];

      for (int i = 0; i < playedCards.length; i++) {
        String card = playedCards[i];
        String cardNum;

        if (card == 'a') {
          cardNum = fieldAceValue?.toString() ?? '14';
        } else {
          cardNum = cardValue(card).toString().replaceAll('.0', '');
        }

        if (i == 0) {
          formattedCards.add(cardNum);
        } else if (selectedOps.isNotEmpty && (i - 1) < selectedOps.length) {
          formattedCards.add('${selectedOps[i - 1]} $cardNum');
        } else {
          formattedCards.add('+ $cardNum');
        }
      }

      activityMessage = "$playerId played: ${formattedCards.join(' ')}";

      if (appliedModifier != null) {
        activityMessage += ' ($appliedModifier)';
      }

      activityMessage +=
          ' (${activityLogColor == Colors.greenAccent ? 'winning' : 'normal'})';

      final DatabaseReference roomRef =
          FirebaseDatabase.instance.ref('rooms/$roomCode');

      // ENHANCED: Better retry logic with validation
      int maxRetries = 3;
      int retryDelay = 500;

      for (int attempt = 0; attempt < maxRetries; attempt++) {
        try {
          final result = await roomRef.runTransaction((Object? current) {
            if (current == null) {
              return Transaction.abort();
            }

            final data = current as Map<dynamic, dynamic>;
            final currentTurn = data['turn'] as String?;
            final currentGameState = data['gameState'] as String?;

            // CRITICAL: Enhanced validation
            if (currentTurn != playerId) {
              return Transaction.abort();
            }

            if (currentGameState == 'gameOver') {
              return Transaction.abort();
            }

            // Update all game state atomically
            data['field'] = List.from(field);
            data['activityLog'] = List.from(activityLog)..add(activityMessage);
            data['fieldAceValue'] = fieldAceValue;

            // Initialize nested maps if they don't exist
            data['playerHands'] ??= {};
            data['playerPrizeCards'] ??= {};
            data['playerDrawPiles'] ??= {};
            data['handSizes'] ??= {};
            data['prizeCardCounts'] ??= {};
            data['drawPileSizes'] ??= {};
            data['maxHandSizes'] ??= {};
            data['playerModifiers'] ??= {};

            // Update player-specific data
            (data['playerHands'] as Map)[playerId!] = List.from(playerHand);
            (data['playerPrizeCards'] as Map)[playerId!] =
                List.from(playerPrizeCards);
            (data['playerDrawPiles'] as Map)[playerId!] =
                List.from(playerDrawPile);
            (data['handSizes'] as Map)[playerId!] = playerHand.length;
            (data['maxHandSizes'] as Map)[playerId!] = playerMaxHandSize;
            (data['prizeCardCounts'] as Map)[playerId!] =
                playerPrizeCards.length;
            (data['drawPileSizes'] as Map)[playerId!] = playerDrawPile.length;

            // FIX: Sanitize modifier keys before saving to Firebase
            Map<String, bool> sanitizedModifiers = {};
            for (String key in playerModifiers.keys) {
              String sanitizedKey = _sanitizeModifierForFirebase(key);
              sanitizedModifiers[sanitizedKey] = playerModifiers[key] ?? false;
            }
            (data['playerModifiers'] as Map)[playerId!] = sanitizedModifiers;

            // Switch turn to opponent ONLY if game is still playing
            if (opponentId != null &&
                !gameOver &&
                currentGameState == 'playing') {
              data['turn'] = opponentId;
            }

            return Transaction.success(data);
          });

          if (result.committed) {

            // CRITICAL: Only update local state AFTER successful Firebase commit
            if (mounted) {
              setState(() {
                message = "Move sent - waiting for opponent...";
                isPlayerTurn = false; // This should now be reliable
              });
            }
            return; // Success, exit retry loop
          } else {

            if (attempt == maxRetries - 1) {
              throw Exception(
                  'Transaction failed to commit after $maxRetries attempts');
            }

            await Future.delayed(Duration(milliseconds: retryDelay));
            retryDelay *= 2;
          }
        } catch (e) {

          if (attempt == maxRetries - 1) {
            rethrow;
          }

          await Future.delayed(Duration(milliseconds: retryDelay));
          retryDelay *= 2;
        }
      }
    } catch (e) {

      // IMPROVED: Better error recovery
      if (mounted) {
        setState(() {
          message = "Connection issue - retrying...";
          // DON'T immediately restart turn - wait for recovery
        });

        // Attempt to recover by refreshing game state
        Future.delayed(Duration(seconds: 2), () {
          if (mounted && gameMode == 'human' && !gameOver) {
            _refreshGameStateFromFirebase();
          }
        });
      }
    } finally {
      _isUpdatingFirebase = false;
      appliedModifier = null;
    }
  }

// Add this helper method for recovery
  Future<void> _refreshGameStateFromFirebase() async {
    if (roomCode == null) return;

    try {
      final roomRef = FirebaseDatabase.instance.ref('rooms/$roomCode');
      final snapshot = await roomRef.get();

      if (snapshot.exists && mounted) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        _updateGameFromFirebase(data);
      }
    } catch (e) {
      // If refresh fails, allow player to try again
      if (mounted) {
        setState(() {
          message = "Connection restored - your turn!";
          isPlayerTurn = true;
        });
        startTimer();
      }
    }
  }

  Future<void> _startRematch() async {
    print('DEBUG _startRematch: Called. roomCode=$roomCode, playerId=$playerId, opponentId=$opponentId, isHost=$isHost');
    setState(() {
      currentBackgroundIndex =
          (currentBackgroundIndex + 1) % backgrounds.length;
    });

    if (roomCode == null || playerId == null || opponentId == null) {
      print('DEBUG _startRematch: Early return - missing roomCode/playerId/opponentId');
      return;
    }

    try {
      final DatabaseReference roomRef =
          FirebaseDatabase.instance.ref('rooms/$roomCode');

      // Mark this player as ready for rematch
      print('DEBUG _startRematch: Writing rematchRequest to Firebase for $playerId');
      await roomRef.child('rematchRequests').child(playerId!).set(true);
      print('DEBUG _startRematch: Firebase write complete');

      // Update UI to show waiting state
      setState(() {
        _waitingForRematch = true;
        message = "Waiting for opponent to start next game...";
      });
      print('DEBUG _startRematch: Set _waitingForRematch = true');

      // Note: The actual game state transition will be handled by _handleGameOverFromFirebase
      // when it detects both players have requested a rematch
    } catch (e) {
      setState(() {
        _waitingForRematch = false;
        message = "Failed to start rematch";
      });
    }
  }

  Future<void> _handleOpponentDisconnect() async {
    if (gameMode != 'human') return;
    
    // Don't show disconnect if we're intentionally leaving or never connected
    final shouldShowMessage = _hasEverConnected && !_isIntentionallyLeaving;

    // Cancel any active listeners/timers
    gameSubscription?.cancel();
    gameSubscription = null;
    quickMatchSubscription?.cancel();
    quickMatchSubscription = null;
    turnTimer?.cancel();

    // Attempt to remove the room from Firebase if it exists
    final String? rc = roomCode;
    if (rc != null) {
      try {
        await FirebaseDatabase.instance.ref('rooms/$rc').remove();
      } catch (e) {
        // ignore removal errors
      }
    }

    // Reset connection tracking flags
    _hasEverConnected = false;
    _isIntentionallyLeaving = false;

    // Reset to initial overlay and multiplayer defaults
    _resetMultiplayerState();

    // Show a floating snackbar only if we were actually connected
    if (shouldShowMessage && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('opponent left!', style: const TextStyle(fontFamily: 'Balatro')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.black87,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          elevation: 6,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _setupMultiplayerGame() {
    // This method is now largely handled by Firebase initialization
    // Just reset local state
    try {

      _resetGameState();

      // CRITICAL: Don't set turn state here - let Firebase handle it
      // The turn state should come from Firebase listener
      message = "Waiting for game to start...";

      setState(() {});

    } catch (e) {
      setState(() {
        connectionStatus = 'Failed to setup game: $e';
        showRoomSelection = true;
      });
    }
  }

  // Update your room selection cancel logic
  void _cancelRoomSelection() {
    setState(() {
      showRoomSelection = false;
      connectionStatus = '';
    });

    // Resume AI game if we were in AI mode and the initial overlay is not shown
    if (gameMode == 'ai' && !gameOver && !showInitialOverlay) {
      setState(() {
        message = isPlayerTurn ? "Your turn!" : "Opponent's turn!";
      });

      if (isPlayerTurn) {
        startTimer();
      }
    }
  }

// Update your _leaveRoom method to handle cleanup better
  void _leaveRoom() {
    // Set flag to prevent false disconnect messages
    _isIntentionallyLeaving = true;
    
    try {
      // Cancel timers and listeners
      turnTimer?.cancel();
      gameSubscription?.cancel();
      gameSubscription = null;

      // Remove from Firebase room
      if (roomCode != null && playerId != null) {
        final DatabaseReference roomRef =
            FirebaseDatabase.instance.ref('rooms/$roomCode');
        roomRef.child('players').child(playerId!).remove();
      }
    } catch (e) {
    } finally {
      _resetMultiplayerState();
      _resetToAIMode();
    }
  }

  // Centralized global exit handler used by persistent exit icon
  void _handleGlobalExit() {
    // Set flag to prevent false disconnect messages
    _isIntentionallyLeaving = true;
    
    try {
      turnTimer?.cancel();
      gameSubscription?.cancel();
      gameSubscription = null;
      quickMatchSubscription?.cancel();
      quickMatchSubscription = null;
    } catch (e) {}

    // Stop any audio playback
    try {
      _audioPlayer.stop();
      _tapAudioPlayer.stop();
      _gameOverAudioPlayer.stop();
      _oppWinAudioPlayer.stop();
    } catch (e) {}

    // Close ace dialog if open
    if (_aceDialogOpen && mounted) {
      try {
        Navigator.of(context).pop();
      } catch (e) {}
      _aceDialogOpen = false;
    }

    // Update UI/state to reflect a full reset (like fresh app start)
    setState(() {
      // Prevent AI from continuing
      gameOver = true;
      isPlayerTurn = false;

      // Show initial overlay and clear transient UI state
      showInitialOverlay = true;
      showRoomSelection = false;
      showCreateRoom = false;
      showJoinRoom = false;
      isSearchingForGame = false;
      waitingForOpponent = false;
      message = '';
      clearSelections();
      activePlayerModifier = null;
      showModifierSelection = false;

      // Reset dynamic single-player state
      winStreak = 0;
      timerSeconds = 0;
      _isOpponentTurnRunning = false;
      // Reset playmat rotation to initial
      currentBackgroundIndex = 0;
      _gameSessionId = 0;
    });

    // Ensure multiplayer cleanup and a fresh multiplayer-ready state
    _leaveRoom();
    _prepareForMultiplayer();
    // Reinitialize underlying game state so the initial overlay shows a fresh game
    _setupGame(rotateBackground: false);
  }

  // Update your _showGameModeSelection method
  void _showGameModeSelection() {
    // Pause the current game safely
    turnTimer?.cancel();

    setState(() {
      showRoomSelection = true;
      message = 'Game paused';
    });
  }

// Helper Methods
  List<String> _createFullDeck() {
    List<String> deck = [];
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
      'a'
    ]) {
      for (int i = 0; i < 5; i++) {
        // Changed from 4 to 5
        deck.add(value);
      }
    }
    deck.add('jkr');
    deck.add('jkr');
    deck.add('jkr'); // Added third joker
    return deck;
  }

  void _assignRandomModifiers() {
    List<String> shuffledModifiers = List.from(allModifiers)..shuffle();

    playerAvailableModifiers = shuffledModifiers.take(3).toList();
    opponentAvailableModifiers = shuffledModifiers.skip(3).take(3).toList();

    // Reset modifier usage maps to only include assigned modifiers
    playerModifiers = {};
    opponentModifiers = {};

    for (String modifier in playerAvailableModifiers) {
      playerModifiers[modifier] = false;
    }

    for (String modifier in opponentAvailableModifiers) {
      opponentModifiers[modifier] = false;
    }
  }

  void _resetGameState() {
    field = [];
    activityLog.clear();
    fieldAceValue = null;
    fieldAceValueHistory.clear();
    gameOver = false;
    clearSelections();
    playerMaxHandSize = 2;
    activePlayerModifier = null;
    showModifierSelection = false;

    // Reset modifiers for new game
    playerModifiers = {
      'mulligan': false,
      '2x': false,
      '+3': false,
      '-3': false,
      '-1': false,
      '+1': false,
      '+11': false,
      'draw1': false,
      '-0.5': false,
      'rewind': false,
    };

    opponentModifiers = {
      'mulligan': false,
      '2x': false,
      '+3': false,
      '-3': false,
      '-1': false,
      '+1': false,
      '+11': false,
      'draw1': false,
      '-0.5': false,
      'rewind': false,
    };

    // Assign random modifiers for new game
    _assignRandomModifiers();
  }

  void _resetMultiplayerState() {
    quickMatchSubscription?.cancel();
    quickMatchSubscription = null;
    gameSubscription?.cancel();
    gameSubscription = null;
    
    // Reset rematch initialization flag
    _isInitializingRematch = false;
    
    setState(() {
      roomCode = null;
      playerId = null;
      opponentId = null;
      isHost = false;
      waitingForOpponent = false;
      isSearchingForGame = false;
      connectionStatus = '';
      gameMode = 'ai';
      showRoomSelection = false;
      showInitialOverlay = true;
      _hasEverConnected = false;
      _isIntentionallyLeaving = false;
      _waitingForRematch = false;
      // Reset hand data
      opponentActualHand = [];
      opponentActualDrawPile = [];
      lastKnownOpponentHandSize = null;
      lastKnownOpponentDrawPileSize = null;
      // Reset multiplayer win streaks when leaving a session
      multiplayerWinStreaks = {};
    });
  }

// Defensive Helper Methods
  void safeRemoveFromHand(
      List<String> hand, List<int> indices, String handName) {
// Validate all indices before removing any
    for (int i = 0; i < indices.length; i++) {
      if (indices[i] < 0 || indices[i] >= hand.length) {
        return;
      }
    }

// Sort indices in descending order to avoid index shifting issues
    List<int> sortedIndices = List.from(indices)
      ..sort((a, b) => b.compareTo(a));

// Remove cards from hand
    for (int index in sortedIndices) {
      if (index >= 0 && index < hand.length) {
        hand.removeAt(index);
      } else {
        break;
      }
    }
  }

  T? safeListAccess<T>(List<T> list, int index, [String? listName]) {
    if (index < 0 || index >= list.length) {
      if (listName != null) {
      }
      return null;
    }
    return list[index];
  }

  bool validateSelections() {
    for (int i = 0; i < selectedIndices.length; i++) {
      if (selectedIndices[i] < 0 || selectedIndices[i] >= playerHand.length) {
        return false;
      }
    }

    int expectedOpsCount =
        selectedIndices.length > 1 ? selectedIndices.length - 1 : 0;
    if (selectedOps.length != expectedOpsCount) {
      return false;
    }

    return true;
  }

  void safeDrawCards(List<String> hand, List<String> drawPile, int targetSize) {
    while (hand.length < targetSize && drawPile.isNotEmpty) {
      try {
        hand.add(drawPile.removeAt(0));
      } catch (e) {
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
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // Initialize opponent data structures
    opponentActualHand = [];
    opponentActualDrawPile = [];
    opponentHand = [];
    opponentDrawPile = [];
    opponentPrizeCards = [];
    processedTimeoutPenalties = <String>{};
    // Initialize audio context and players so they inherit the configured audio context
    _initAudioPlayers(); // Allow mixing with other audio (e.g., Spotify)
    _loadHighScore();
    _loadTotalWins();
    // Ensure unlocked flags are loaded before loading choice, then ensure unlocked
    // After loading the saved cardback choice, set the AI opponent cardback
    // to match the player's selected cardback so the initial overlay shows
    // the same visual immediately.
    _loadUnlockedCardbacks().then((_) {
      _loadCardbackChoice().then((_) {
        _ensureCardbackUnlocked();
        setState(() {
          aiOpponentCardbackAsset = CardWidget.defaultCardBackAsset;
        });
      });
    });
    _loadVolumeSetting();
    // Load saved default difficulty and apply it to the selector immediately
    _loadDefaultDifficulty().then((_) {
      setState(() {
        aiDifficulty = defaultAiDifficulty;
      });
    });
    _setupGame(rotateBackground: false);
  }

  Future<void> _preloadTapSound() async {
    try {
      await _tapAudioPlayer.setSource(AssetSource('sounds/tap.mp3'));
      await _tapAudioPlayer.setReleaseMode(ReleaseMode.stop);
    } catch (e) {
    }
  }

  Future<void> _configureLowLatencyAudio() async {
    try {
      await _tapAudioPlayer.setPlayerMode(PlayerMode.lowLatency);
    } catch (e) {
    }
  }

  /// Configure audio to mix with other apps (e.g., Spotify) instead of pausing them
  Future<void> _configureAudioSession() async {
    try {
      // Set global audio context to allow mixing with other audio sources
      final audioContext = AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.ambient, // Mixes with other audio
          options: {
            AVAudioSessionOptions.mixWithOthers,
          },
        ),
        android: AudioContextAndroid(
          isSpeakerphoneOn: false,
          audioMode: AndroidAudioMode.normal,
          stayAwake: false,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.game,
          audioFocus: AndroidAudioFocus.none, // Don't request audio focus
        ),
      );
      await AudioPlayer.global.setAudioContext(audioContext);
    } catch (e) {
      // Silently handle - audio will still work, just might pause other apps
    }
  }

  @override
  void dispose() {
    turnTimer?.cancel();
    gameSubscription?.cancel();
    quickMatchSubscription?.cancel();
    roomCodeController.dispose();
    _audioPlayer.dispose();
    _gameOverAudioPlayer.dispose();
    _tapAudioPlayer.dispose();
    _oppWinAudioPlayer.dispose();
    super.dispose();
  }

  Widget buildDifficultySelector({required bool isMobile}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 6 : 8,
        vertical: isMobile ? 1 : 2, // REDUCED: was 3/4, now 1/2
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
          color: const Color.fromARGB(153, 64, 182, 255).withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.hdr_strong,
            color: Color.fromARGB(255, 64, 182, 255),
            size: 15,
          ),
          SizedBox(width: isMobile ? 3 : 5),
          Text(
            ':',
            style: TextStyle(
              color: const Color.fromARGB(192, 64, 182, 255),
              fontWeight: FontWeight.w500,
              fontSize: isMobile ? 9 : 11,
              letterSpacing: 0.7,
              fontFamily: 'Balatro',
              height: 1.0,
            ),
          ),
          SizedBox(width: isMobile ? 5 : 7),
          DropdownButton<int>(
  value: aiDifficulty,
  dropdownColor: Colors.black87,
  style: const TextStyle(
    color: Color.fromARGB(201, 64, 182, 255),
    fontWeight: FontWeight.w500,
    fontSize: 11,
    fontFamily: 'Balatro',
    height: 1.0,
  ),
  underline: SizedBox.shrink(),
  icon: const Icon(
    Icons.arrow_drop_down,
    color: Color.fromARGB(255, 64, 182, 255),
    size: 15,
  ),
  isDense: true,
  // Remove isExpanded if you added it
  // Remove width: double.infinity from children
  items: const [
    DropdownMenuItem(
      value: 1,
      child: Text(
        'Dull',
        style: TextStyle(fontFamily: 'Balatro'),
      ),
    ),
    DropdownMenuItem(
      value: 2,
      child: Text(
        'Keen',
        style: TextStyle(fontFamily: 'Balatro'),
      ),
    ),
    DropdownMenuItem(
      value: 3,
      child: Text(
        'Sharp',
        style: TextStyle(fontFamily: 'Balatro'),
      ),
    ),
  ],
  onChanged: (value) {
    setState(() {
      aiDifficulty = value!;
    });
  },
)
        ],
      ),
    );
  }

  Widget buildWinStreak({required bool isMobile}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.content_cut_sharp,
          color: Color.fromARGB(255, 0, 255, 183),
          size: 18,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 4,
              offset: Offset(1, 1),
            ),
          ],
        ),
        SizedBox(width: isMobile ? 4 : 6),
        Text(
          ': $winStreak',
          style: TextStyle(
            color: const Color.fromARGB(255, 58, 255, 196),
            fontWeight: FontWeight.bold,
            fontSize: isMobile ? 16 : 18,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 4,
                offset: Offset(1, 1),
              ),
            ],
          ),
        ),
      ],
    );
  }

Widget buildHighScore({required bool isMobile}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(
        Icons.cut_sharp,
        color: Color.fromARGB(255, 0, 195, 255),
        size: 18,
        shadows: [
          Shadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 4,
            offset: Offset(1, 1),
          ),
        ],
      ),
      SizedBox(width: isMobile ? 4 : 6),
      Text(
        ': $highScore',
        style: TextStyle(
          color: Color.fromARGB(255, 0, 195, 255),
          fontWeight: FontWeight.bold,
          fontSize: isMobile ? 16 : 18,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 4,
              offset: Offset(1, 1),
            ),
          ],
        ),
      ),
    ],
  );
}

  void useMulliganModifier() {
    if (!playerModifiers['mulligan']! && isPlayerTurn && !gameOver) {
      HapticFeedback.lightImpact();

      setState(() {
        // Mark mulligan as used
        playerModifiers['mulligan'] = true;

        // Put current hand back into draw pile
        playerDrawPile.addAll(playerHand);
        playerHand.clear();

        // Shuffle draw pile
        playerDrawPile.shuffle(Random());

        // Draw 2 new cards
        safeDrawCards(playerHand, playerDrawPile, 2);

        // Clear any current selections
        clearSelections();

        // Add to activity log
        activityLog.add('You mulliganed');
        activityLogColor = Colors.blueAccent;
      });

      // Update Firebase if in multiplayer - ENHANCE THIS
      if (gameMode == 'human') {
        _updateFirebaseMulliganState();
      }

      playModifierSound();
    }
  }

// Add this new method
  Future<void> _updateFirebaseMulliganState() async {
    if (roomCode == null || playerId == null) return;

    try {
      final DatabaseReference roomRef =
          FirebaseDatabase.instance.ref('rooms/$roomCode');

      await roomRef.update({
        'playerHands/$playerId': List.from(playerHand),
        'playerDrawPiles/$playerId': List.from(playerDrawPile),
        'handSizes/$playerId': playerHand.length,
        'drawPileSizes/$playerId': playerDrawPile.length,
        'activityLog': List.from(activityLog)
          ..add('$playerId used mulligan mod'),
        'playerModifiers/$playerId': Map.from(playerModifiers),
      });
    } catch (e) {
    }
  }

  double applyValueModifiers(double baseValue) {
    double modifiedValue = baseValue;

    if (activePlayerModifier == '2x') {
      modifiedValue *= 2;
    } else if (activePlayerModifier == '+3') {
      modifiedValue += 3;
    }

    return modifiedValue;
  }

  String _createPlayDescription(
      List<String> playedCards, List<String> ops, List<int> aceOverrides) {
    int aceOverrideIdx = 0;
    return 'You played ${playedCards.asMap().entries.map((entry) {
      int i = entry.key;
      String card = entry.value;
      String cardNum;
      if (card == 'a' &&
          aceOverrides.isNotEmpty &&
          aceOverrideIdx < aceOverrides.length) {
        cardNum = aceOverrides[aceOverrideIdx].toString();
        aceOverrideIdx++;
      } else {
        cardNum = cardValue(card).toString().replaceAll('.0', '');
      }
      if (i == 0) return cardNum;
      if (ops.isEmpty || (i - 1) >= ops.length || (i - 1) < 0) {
        return ' $cardNum';
      }
      return ' ${ops[i - 1]} $cardNum';
    }).join('')}';
  }

  void _useDrawModifier() {
    if (!playerModifiers['draw1']! && isPlayerTurn && !gameOver) {
      HapticFeedback.lightImpact();

      setState(() {
        // Mark draw1 as used
        playerModifiers['draw1'] = true;

        // Draw 1 extra card if available
        if (playerDrawPile.isNotEmpty) {
          playerHand.add(playerDrawPile.removeAt(0));
          // Temporarily increase max hand size to accommodate the extra card
          playerMaxHandSize = 3;
        }

        // Add to activity log
        activityLog.add('You drew an extra card');
        activityLogColor = Colors.blueAccent;
      });

      // Update Firebase if in multiplayer - ENHANCE THIS
      if (gameMode == 'human') {
        _updateFirebaseDraw1State();
      }

      playModifierSound();
    }
  }

// Add this new method
  Future<void> _updateFirebaseDraw1State() async {
    if (roomCode == null || playerId == null) return;

    try {
      final DatabaseReference roomRef =
          FirebaseDatabase.instance.ref('rooms/$roomCode');

      await roomRef.update({
        'playerHands/$playerId': List.from(playerHand),
        'playerDrawPiles/$playerId': List.from(playerDrawPile),
        'handSizes/$playerId': playerHand.length,
        'maxHandSizes/$playerId': playerMaxHandSize,
        'drawPileSizes/$playerId': playerDrawPile.length,
        'activityLog': List.from(activityLog)..add('$playerId used draw mod'),
        'playerModifiers/$playerId': Map.from(playerModifiers),
      });
    } catch (e) {
    }
  }

  void _useRewindModifier() {
    if (!playerModifiers['rewind']! &&
        isPlayerTurn &&
        !gameOver &&
        field.length > 1) {
      HapticFeedback.lightImpact();

      setState(() {
        // Mark rewind as used
        playerModifiers['rewind'] = true;

        // Remove the last card from field
        field.removeLast();

        // Remove the corresponding ace value from history
        if (fieldAceValueHistory.isNotEmpty) {
          fieldAceValueHistory.removeLast();
        }

        // Restore proper ace value if the new last card is an ace
        if (field.isNotEmpty && field.last == 'a') {
          // Find the ace value from history for this position
          if (fieldAceValueHistory.isNotEmpty) {
            fieldAceValue = fieldAceValueHistory.last;
          } else {
            fieldAceValue = null; // Fallback
          }
        } else {
          fieldAceValue = null;
        }

        // Add to activity log
        activityLog.add('You rewound the field');
        activityLogColor = Colors.blueAccent;
      });

      // Update Firebase if in multiplayer
      if (gameMode == 'human') {
        _updateFirebaseRewindState();
      }

      playModifierSound();
    }
  }

// Add this new method
  Future<void> _updateFirebaseRewindState() async {
    if (roomCode == null || playerId == null) return;

    try {
      final DatabaseReference roomRef =
          FirebaseDatabase.instance.ref('rooms/$roomCode');

      await roomRef.update({
        'field': List.from(field),
        'fieldAceValue': fieldAceValue,
        'activityLog': List.from(activityLog)..add('$playerId used rewind mod'),
        'playerModifiers/$playerId': Map.from(playerModifiers),
      });
    } catch (e) {
    }
  }

  void _useModifier(String modifierType) {
    if (modifierType == 'mulligan') {
      useMulliganModifier();
    } else if (modifierType == '2x' ||
        modifierType == '+3' ||
        modifierType == '-3' ||
        modifierType == '-1' ||
        modifierType == '+1' ||
        modifierType == '+11' ||
        modifierType == '-0.5') {
      _selectValueModifier(modifierType);
    } else if (modifierType == 'draw1') {
      _useDrawModifier();
    } else if (modifierType == 'rewind') {
      _useRewindModifier();
    }
  }

void _handleSwipeUpModifier(String modifierType) async {
  if (!isPlayerTurn || gameOver || selectedIndices.isEmpty) return;
  
  // Add Firebase turn validation for multiplayer
  if (gameMode == 'human' && roomCode != null) {
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('rooms/$roomCode/turn')
          .get();
      final currentTurn = snapshot.value as String?;
      
      if (currentTurn != playerId) {
        setState(() {
          message = "Not your turn!";
        });
        return;
      }
    } catch (e) {
      return;
    }
  }

  // Handle instant-use modifiers (mulligan, draw1, rewind)
  if (['mulligan', 'draw1', 'rewind'].contains(modifierType)) {
    _useModifier(modifierType);
    return;
  }

  // For calculation modifiers, select it and immediately play
  if (['-0.5', '2x', '+3', '-3', '-1', '+1', '+11'].contains(modifierType)) {
    HapticFeedback.lightImpact();
    
    setState(() {
      activePlayerModifier = modifierType;
      showModifierSelection = true;
    });
    
    // Add to activity log
    activityLog.add('Selected $modifierType mod');
    activityLogColor = Colors.blueAccent;
    
    playModifierSound();
    
    // Small delay for visual feedback, then auto-play
    await Future.delayed(const Duration(milliseconds: 30));
    
    // Auto-play the selected cards with modifier
    await playSelectedCards();
  }
}

  void _selectValueModifier(String modifierType) {
    if (!playerModifiers[modifierType]! && isPlayerTurn && !gameOver) {
      HapticFeedback.lightImpact();

      setState(() {
        // Toggle the modifier selection
        if (activePlayerModifier == modifierType) {
          // Deselect if already selected
          activePlayerModifier = null;
          showModifierSelection = false;
        } else {
          // Select this modifier
          activePlayerModifier = modifierType;
          showModifierSelection = true;
        }
      });

      // Add to activity log
      if (activePlayerModifier == modifierType) {
        activityLog.add('Selected $modifierType mod');
        activityLogColor = Colors.blueAccent;
      } else {
        activityLog.add('Mod deselected');
        activityLogColor = Colors.white;
      }

      // Update Firebase if in multiplayer
      if (gameMode == 'human') {
        _updateFirebaseModifierState();
      }

      playModifierSound();
    }
  }

  Future<void> _updateFirebaseModifierState() async {
    if (roomCode == null || playerId == null) return;

    try {
      final DatabaseReference roomRef =
          FirebaseDatabase.instance.ref('rooms/$roomCode');

      // Prepare updates based on which modifiers are used
      Map<String, dynamic> updates = {
        'playerModifiers/$playerId': Map.from(playerModifiers),
      };

      // Add activity log update
      if (activityLog.isNotEmpty) {
        updates['activityLog'] = List.from(activityLog);
      }

      // Add active modifier state
      if (activePlayerModifier != null) {
        updates['activeModifiers/$playerId'] = activePlayerModifier;
      } else {
        updates['activeModifiers/$playerId'] = null;
      }

      await roomRef.update(updates);
    } catch (e) {
    }
  }

  void _setupGame({bool rotateBackground = true}) {
    // Rotate to next background and increment game session for animations
    if (rotateBackground) {
      setState(() {
        currentBackgroundIndex =
            (currentBackgroundIndex + 1) % backgrounds.length;
        _gameSessionId++; // Trigger prize card entrance animation
      });
    }
    try {
      fullDeck = _createFullDeck();
      fullDeck.shuffle(Random());

      playerDeck = fullDeck.sublist(0, 34);
      opponentDeck = fullDeck.sublist(34, 68);

      playerPrizeCards = playerDeck.sublist(0, 3);
      opponentPrizeCards = opponentDeck.sublist(0, 3);

      playerHand = playerDeck.sublist(3, 5);
      opponentHand = opponentDeck.sublist(3, 5);
      opponentActualHand = gameMode == 'ai' ? List.from(opponentHand) : [];

      playerDrawPile = playerDeck.sublist(5);
      opponentDrawPile = opponentDeck.sublist(5);
      opponentActualDrawPile =
          gameMode == 'ai' ? List.from(opponentDrawPile) : [];

      // Configure AI opponent cardback for Sharp difficulty.
      // Default the AI's cardback to the player's chosen cardback until
      // the player has achieved 2 consecutive wins. After 2 consecutive
      // wins, the next (third) match will show the overridden cardback
      // based on projected streak thresholds.
      if (gameMode == 'ai' && aiDifficulty == 3) {
        if (winStreak < 2) {
          // Keep AI visually matching the player for early/familiar matches
          aiOpponentCardbackAsset = CardWidget.defaultCardBackAsset;
        } else {
          // Player has 2+ consecutive wins — show milestone-based cardback
          final projectedStreak = winStreak + 1; // this game would be the next win
          if (projectedStreak >= 10) {
            aiOpponentCardbackAsset = 'assets/images/cardback5.png'; // Opal
          } else if (projectedStreak >= 7) {
            aiOpponentCardbackAsset = 'assets/images/cardback4.png'; // Amethyst
          } else if (projectedStreak >= 5) {
            aiOpponentCardbackAsset = 'assets/images/cardback3.png'; // Amber
          } else if (projectedStreak >= 3) {
            aiOpponentCardbackAsset = 'assets/images/cardback2.png'; // Onyx
          } else {
            aiOpponentCardbackAsset = CardWidget.defaultCardBackAsset;
          }
        }
      } else {
        aiOpponentCardbackAsset = CardWidget.defaultCardBackAsset;
      }

      // Initialize card counting for new game
      playedCardCounts.clear();
      gameHistory.clear();
      playerPlayPatterns.clear();
      totalCardsPlayed = 0;

      // Initialize all card counts to 0
      for (String cardValue in [
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
        'jkr'
      ]) {
        playedCardCounts[cardValue] = 0;
      }

      // Reset modifiers for new game - UPDATED to use random assignment
      _assignRandomModifiers();

      activePlayerModifier = null;
      showModifierSelection = false;

      _resetGameState();
      isPlayerTurn = true;
      message = "Your turn!";

      setState(() {});

      if (!showInitialOverlay) {
        turnTimer?.cancel();
        startTimer();
      }
    } catch (e) {
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

  bool isValidPlay(List<String> playedCards, List<String> ops,
      String lastFieldCard, List<int>? aceOverrides,
      {int? fieldAceValue, String? appliedModifier}) {
    aceOverrides = aceOverrides ?? [];

    if (playedCards.isEmpty || playedCards.length > 3) return false;
    if (playedCards.length > 1 && ops.length != playedCards.length - 1) {
      return false;
    }

    // NEW: Check that cards are played in descending order (largest to smallest)
    if (playedCards.length > 1) {
      List<double> originalValues = [];
      int aceIdx = 0;
      for (int i = 0; i < playedCards.length; i++) {
        if (playedCards[i] == 'a') {
          int aceValue = 14;
          if (aceIdx < aceOverrides.length) {
            aceValue = aceOverrides[aceIdx];
          }
          originalValues.add(cardValue('a', aceOverride: aceValue));
          aceIdx++;
        } else {
          originalValues.add(cardValue(playedCards[i]));
        }
      }

      // Check if cards are in descending order
      for (int i = 0; i < originalValues.length - 1; i++) {
        if (originalValues[i] < originalValues[i + 1]) {
          return false; // Invalid: smaller number comes before larger
        }
      }
    }

    // Create copies to avoid modifying originals
    List<String> cardsCopy = List.from(playedCards);
    List<int> aceOverridesCopy = List.from(aceOverrides);

    List<double> values = [];
    int aceIdx = 0;
    for (int i = 0; i < cardsCopy.length; i++) {
      if (cardsCopy[i] == 'a') {
        int aceValue = 14;
        if (aceIdx < aceOverridesCopy.length) {
          aceValue = aceOverridesCopy[aceIdx];
        }
        values.add(cardValue('a', aceOverride: aceValue));
        aceIdx++;
      } else {
        values.add(cardValue(cardsCopy[i]));
      }
    }

    double minValue = values.reduce(min);
    int minIdx = values.indexOf(minValue);
    if (minIdx != values.length - 1) {
      String tempCard = cardsCopy[minIdx];
      cardsCopy.removeAt(minIdx);
      cardsCopy.add(tempCard);

      if (cardsCopy[cardsCopy.length - 1] == 'a' &&
          aceOverridesCopy.isNotEmpty &&
          minIdx < aceOverridesCopy.length) {
        int tempAce = aceOverridesCopy[minIdx];
        aceOverridesCopy.removeAt(minIdx);
        aceOverridesCopy.add(tempAce);
      }

      values = [];
      int aceIdx2 = 0;
      for (int i = 0; i < cardsCopy.length; i++) {
        if (cardsCopy[i] == 'a') {
          int aceValue = 14;
          if (aceIdx2 < aceOverridesCopy.length) {
            aceValue = aceOverridesCopy[aceIdx2];
          }
          values.add(cardValue('a', aceOverride: aceValue));
          aceIdx2++;
        } else {
          values.add(cardValue(cardsCopy[i]));
        }
      }
    }

    // Use original values and order for calculation
    List<double> originalValues = [];
    int aceIdx3 = 0;
    for (int i = 0; i < playedCards.length; i++) {
      if (playedCards[i] == 'a') {
        int aceValue = 14;
        if (aceIdx3 < aceOverrides.length) {
          aceValue = aceOverrides[aceIdx3];
        }
        originalValues.add(cardValue('a', aceOverride: aceValue));
        aceIdx3++;
      } else {
        originalValues.add(cardValue(playedCards[i]));
      }
    }

    double result = originalValues[0];
    for (int i = 1; i < originalValues.length; i++) {
      if (i - 1 < ops.length && ops[i - 1] == '+') {
        result += originalValues[i];
      } else if (i - 1 < ops.length) {
        result -= originalValues[i];
      }
    }

    if (appliedModifier == '2x') {
      result *= 2;
    } else if (appliedModifier == '+3') {
      result += 3;
    } else if (appliedModifier == '-3') {
      result -= 3;
    } else if (appliedModifier == '-1') {
      result -= 1;
    } else if (appliedModifier == '+1') {
      result += 1;
    } else if (appliedModifier == '+11') {
      result += 11;
    } else if (appliedModifier == '-0.5') {
      result -= 0.5;
    }
    // Note: draw1 and rewind don't affect the calculation result

    double lastVal;
    if (lastFieldCard == 'a' && fieldAceValue != null) {
      lastVal = cardValue('a', aceOverride: fieldAceValue);
    } else {
      lastVal = cardValue(lastFieldCard);
    }

    return (result == lastVal * 2) || (result == lastVal / 2);
  }

  Map<String, double> _calculateRemainingCardProbabilities() {
    Map<String, double> probabilities = {};

    try {
      final startTime = DateTime.now();
      const maxCalculationTime = Duration(milliseconds: 100);

      for (String cardValue in [
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
        'a'
      ]) {
        // Check timeout
        if (DateTime.now().difference(startTime) > maxCalculationTime) {
          break;
        }

        int totalInDeck = cardValue == 'jkr' ? 3 : 5;
        int played = playedCardCounts[cardValue] ?? 0;

        // Bounds checking to prevent invalid states
        if (played < 0 || played > totalInDeck) {
          played = played.clamp(0, totalInDeck);
        }

        int remaining = totalInDeck - played;

        // Calculate probability this card is in player's hand or draw pile
        int totalUnknownCards = playerHand.length + playerDrawPile.length;
        probabilities[cardValue] =
            totalUnknownCards > 0 ? remaining / totalUnknownCards : 0.0;
      }
    } catch (e) {
      return {}; // Return empty map as fallback
    }

    return probabilities;
  }

  double _evaluatePlayStrategically(Map<String, dynamic> play,
      Map<String, double> cardProbabilities, double playerThreatLevel) {
    try {
      final startTime = DateTime.now();
      const maxEvaluationTime = Duration(milliseconds: 50);

      double baseScore = play['score'].toDouble() * 10; // Base prize card value
      List<String> cards = play['cards'];

      // Bounds checking
      if (cards.isEmpty) return baseScore;

      // Bonus for card efficiency (fewer cards used)
      double efficiencyBonus = (4 - cards.length) * 2;

      // Penalty for playing high-value cards when player likely has counters
      double conservationPenalty = 0;
      for (String card in cards) {
        if (['k', 'q', 'j', '10'].contains(card)) {
          conservationPenalty +=
              playerThreatLevel * 3; // Higher penalty if player is threatening
        }
      }

      // Bonus for creating difficult target values for player
      double targetDifficultyBonus = 0;
      if (cards.isNotEmpty && cardProbabilities.isNotEmpty) {
        String resultCard = cards.last; // Card that will be left on field
        double cardVal = cardValue(resultCard);

        // Check if target values (double/half) are likely hard for player to hit
        List<double> targets = [cardVal * 2, cardVal / 2];
        for (double target in targets) {
          // Check timeout during nested loops
          if (DateTime.now().difference(startTime) > maxEvaluationTime) {
            break;
          }

          bool targetIsHard = true;
          // Limit the search to prevent excessive loops
          int checkedCards = 0;
          for (String possibleCard in cardProbabilities.keys) {
            if (checkedCards++ > 20) break; // Limit iterations

            if (cardValue(possibleCard) == target &&
                (cardProbabilities[possibleCard] ?? 0) > 0.2) {
              targetIsHard = false;
              break;
            }
          }
          if (targetIsHard) targetDifficultyBonus += 2;
        }
      }

      return baseScore +
          efficiencyBonus -
          conservationPenalty +
          targetDifficultyBonus;
    } catch (e) {
      return play['score'].toDouble() * 10; // Fallback to base score
    }
  }

  void checkForWin() {
  if (gameOver) return; // Add this line to prevent duplicate calls

  if (playerPrizeCards.isEmpty) {
    HapticFeedback.mediumImpact();
    // ADDED: Stop any currently playing sounds before game over sound
    _audioPlayer.stop();

    setState(() {
      message = "You win!";
      isPlayerTurn = false;
      gameOver = true;
      winner = 'player';
      // Update win streak only for single-player (AI) mode.
      // Multiplayer win streaks are tracked via Firebase and should NOT
      // affect the global high score or unlocks.
      if (gameMode != 'human') {
        winStreak += 1;
        _checkAndUpdateHighScore();
        // Increment total wins for sharp difficulty (difficulty 3)
        if (aiDifficulty == 3) {
          totalWins += 1;
          _saveTotalWins(totalWins);
        }
      }
      clearSelections();
    });
    turnTimer?.cancel();

    // Sync game over state to Firebase
    if (gameMode == 'human') {
      _updateFirebaseGameOverState('player');
    }

    Future.delayed(const Duration(milliseconds: 100), () {
      playGameWinSound();
    });
  } else if (opponentPrizeCards.isEmpty) {
    HapticFeedback.mediumImpact();
    setState(() {
      message = "Opponent wins!";
      isPlayerTurn = false;
      gameOver = true;
      winner = 'opponent';
      // FIX: In multiplayer, opponent winning should still increment their streak
      // which is tracked in Firebase. Reset local streak since we lost.
      winStreak = 0;
      clearSelections();
    });
    turnTimer?.cancel();

    // Sync game over state to Firebase
    if (gameMode == 'human') {
      _updateFirebaseGameOverState('opponent');
    }

    Future.delayed(const Duration(milliseconds: 100), () {
      playGameLossSound();
    });
  }
}

  Future<void> _updateFirebaseGameOverState(String winner) async {
  if (roomCode == null || playerId == null) return;

  try {
    final DatabaseReference roomRef =
        FirebaseDatabase.instance.ref('rooms/$roomCode');

    // Get current win streaks to update them
    final winnerId = winner == 'player' ? playerId : opponentId;
    final loserId = winner == 'player' ? opponentId : playerId;
    final currentWinnerStreak = multiplayerWinStreaks[winnerId] ?? 0;
    
    // FIX: Update local map immediately so timer calculation works on rematch
    setState(() {
      multiplayerWinStreaks[winnerId!] = currentWinnerStreak + 1;
      multiplayerWinStreaks[loserId!] = 0;
    });
    
    await roomRef.update({
      'gameState': 'gameOver',
      'winner': winnerId,
      'winnerMessage': winner == 'player' ? 'You win!' : 'Opponent wins!',
      'rematchRequests': {}, // Reset rematch requests
      // Winner's streak increases, loser's resets to 0
      'winStreaks/$winnerId': multiplayerWinStreaks[winnerId],
      'winStreaks/$loserId': 0,
    });
  } catch (e) {
  }
}

  Future<void> playCardSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/cardplay.mp3'));
    } catch (e) {
    }
  }

  Future<void> playPrizeCardSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/winplay.mp3'));
    } catch (e) {
    }
  }

Future<void> playOpponentPrizeCardSound() async {
  try {
    await _oppWinAudioPlayer.stop();
    await _oppWinAudioPlayer.play(AssetSource('sounds/oppwinplay.mp3'));
  } catch (e) {
  }
}

  Future<void> playGameWinSound() async {
    try {
      await _gameOverAudioPlayer.play(AssetSource('sounds/gamewin.mp3'));
    } catch (e) {
    }
  }

  Future<void> playGameLossSound() async {
    try {
      await _gameOverAudioPlayer.play(AssetSource('sounds/gameloss.mp3'));
    } catch (e) {
    }
  }

  Future<void> playModifierSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/modplay.mp3'));
    } catch (e) {
    }
  }

  Future<void> playTapSound() async {
    try {
      await _tapAudioPlayer.stop();
      await _tapAudioPlayer.resume();
    } catch (e) {
    }
  }

  void startTimer() {
    // Don't start timer if we're on the initial overlay (user exited to menu)
    if (showInitialOverlay) return;
    
    turnTimer?.cancel();

    int baseTime;
    if (aiDifficulty == 1) {
      baseTime = 10;
    } else if (aiDifficulty == 2) {
      baseTime = 8;
    } else {
      baseTime = 6;
    }

    if (gameMode == 'human') {
      // Dynamic timer based on player's consecutive wins (6 seconds base, -1 per win, min 4)
      final myWinStreak = multiplayerWinStreaks[playerId] ?? 0;
      timerSeconds = (6 - myWinStreak).clamp(4, 6);
    } else if (aiDifficulty == 3) {
      int timeReduction = (winStreak).clamp(0, 3);
      timerSeconds = (baseTime - timeReduction).clamp(4, baseTime);
    } else {
      timerSeconds = baseTime;
    }

    setState(() {});

    turnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        timerSeconds--;
      });
      if (timerSeconds <= 0) {
        turnTimer?.cancel();
        if (isPlayerTurn && !gameOver) {
          handlePlayerTimeout();
        }
      }
    });
  }

  void handlePlayerTimeout() {
    // Don't handle timeout if we're on the initial overlay (user exited to menu)
    if (showInitialOverlay || gameOver) return;
    
    setState(() {
      message = "Time's up!";
      clearSelections();
      activePlayerModifier = null;
      showModifierSelection = false;
    });

    // NEW: Close ace dialog if it's open
    if (_aceDialogOpen && mounted) {
      Navigator.of(context).pop();
      _aceDialogOpen = false;
    }

    // Show grey shine animation on field card when player times out
    if (field.isNotEmpty) {
      setState(() {
        _showOpponentWinShine = true;
      });
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _showOpponentWinShine = false;
          });
        }
      });
    }

    if (gameMode == 'human') {
      // Immediately update local activity log for instant feedback
      setState(() {
        activityLog.add('You timed out!');
        activityLogColor = Colors.redAccent;
      });
      
      _updateTimeoutPenaltyToFirebase().then((_) {
        if (mounted && !gameOver) {
          setState(() {
            isPlayerTurn = false;
            message = "You timed out - opponent gets a prize card!";
          });
        }
      }).catchError((error) {
        if (mounted && !gameOver) {
          setState(() {
            isPlayerTurn = false;
            message = "Time's up - opponent's turn!";
          });
          _updateFirebaseGameState();
        }
      });
    } else if (!gameOver && gameMode == 'ai') {
      // AI mode - opponent (AI) gets a prize card when human times out
      setState(() {
        activityLog.add('You timed out!');
        activityLogColor = Colors.redAccent;
      });
      
      if (opponentPrizeCards.isNotEmpty) {
        opponentPrizeCards.removeLast();
        // Only play sound if opponent still has prize cards left (not the final one)
        if (opponentPrizeCards.isNotEmpty) {
          playOpponentPrizeCardSound();
        }
        checkForWin();
      }
      isPlayerTurn = false;
      Future.delayed(const Duration(seconds: 1), opponentTurn);
    }
  }

 Future<void> _updateTimeoutPenaltyToFirebase() async {
  if (roomCode == null || opponentId == null || playerId == null) return;

  try {
    final DatabaseReference roomRef =
        FirebaseDatabase.instance.ref('rooms/$roomCode');

    final result = await roomRef.runTransaction((Object? current) {
      if (current == null) {
        return Transaction.abort();
      }

      final data = current as Map<dynamic, dynamic>;
      final currentTurn = data['turn'] as String?;
      final currentGameState = data['gameState'] as String?;

      if (currentTurn != playerId || currentGameState == 'gameOver') {
        return Transaction.abort();
      }

      // Initialize nested maps if they don't exist
      data['prizeCardCounts'] ??= {};
      data['playerPrizeCards'] ??= {};
      data['activityLog'] ??= [];

      // Get current OPPONENT prize count (opponent should get a prize card)
      final currentOpponentPrizeCount =
          (data['prizeCardCounts'] as Map)[opponentId] as int? ?? 3;

      // Decrease OPPONENT's prize card count (they draw a prize card - get closer to winning)
      final newOpponentPrizeCount =
          (currentOpponentPrizeCount > 0) ? currentOpponentPrizeCount - 1 : 0;
      (data['prizeCardCounts'] as Map)[opponentId] = newOpponentPrizeCount;

      // Update the OPPONENT's prize cards list
      final currentOpponentPrizeCards =
          (data['playerPrizeCards'] as Map)[opponentId] as List<dynamic>? ??
              List.generate(currentOpponentPrizeCount, (_) => 'cardback');

      // Create a mutable copy to avoid fixed-length list error
      final mutablePrizeCards = List<dynamic>.from(currentOpponentPrizeCards);

      if (mutablePrizeCards.isNotEmpty) {
        mutablePrizeCards.removeLast();
      }
      (data['playerPrizeCards'] as Map)[opponentId] = mutablePrizeCards;

      // Add timeout message to activity log
      final currentActivityLog = List<String>.from(
          (data['activityLog'] as List? ?? []).cast<String>());
      currentActivityLog
          .add('$playerId timed out - $opponentId gets prize card!');
      data['activityLog'] = currentActivityLog;

      // Add timeout penalty marker
      final timeoutId = DateTime.now().millisecondsSinceEpoch.toString();
      data['lastTimeoutPenalty'] = {
        'timeoutPlayer': playerId,
        'benefitPlayer': opponentId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'id': timeoutId,
      };

      // FIX: Check if opponent won due to timeout
      if (newOpponentPrizeCount == 0) {
        // Opponent wins! Set game over state
        data['gameState'] = 'gameOver';
        data['winner'] = opponentId;
        data['winnerMessage'] = 'Opponent wins!';
        data['rematchRequests'] = {};
        
        // Get win streaks and update them
        final winStreaksData = data['winStreaks'] as Map<dynamic, dynamic>? ?? {};
        final opponentCurrentStreak = winStreaksData[opponentId] as int? ?? 0;
        
        // Initialize winStreaks if not present
        data['winStreaks'] ??= {};
        (data['winStreaks'] as Map)[opponentId!] = opponentCurrentStreak + 1;
        (data['winStreaks'] as Map)[playerId!] = 0;
      } else {
        // Game continues - switch turn to opponent
        data['turn'] = opponentId;
      }

      return Transaction.success(data);
    });

    if (result.committed) {
      // FIX: Update local win streaks immediately if game ended
      final snapshot = await roomRef.get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final gameState = data['gameState'] as String?;
        
        if (gameState == 'gameOver') {
          final winStreaksData = data['winStreaks'] as Map<dynamic, dynamic>? ?? {};
          setState(() {
            for (var entry in winStreaksData.entries) {
              multiplayerWinStreaks[entry.key as String] = entry.value as int? ?? 0;
            }
            
            // FIX: Also update the local winStreak variable for UI display
            if (playerId != null && multiplayerWinStreaks.containsKey(playerId)) {
              winStreak = multiplayerWinStreaks[playerId]!;
              _checkAndUpdateHighScore();
            }
          });
        }
      }
    } else {
      throw Exception('Transaction failed to commit');
    }
  } catch (e) {
    rethrow;
  }
}

  void handleOpponentTimeout() {
    // This method should only be called in AI mode
    // In multiplayer, opponent timeout is handled via Firebase sync
    if (gameMode != 'ai') return;

    setState(() {
      message = "Opponent ran out of time!";
      if (playerPrizeCards.length < 3) {
        playerPrizeCards.add('prize');
        playPrizeCardSound();
      }
      isPlayerTurn = true;
    });

    startTimer();
  }

  Future<List<int>> promptForAceValues(List<String> playedCards) async {
    List<int> aceOverrides = [];

    for (var card in playedCards) {
      if (card == 'a') {
        setState(() {
          _aceDialogOpen = true;
        });

        int? aceValue = await showDialog<int>(
          context: context,
          barrierDismissible: false, // Prevent dismissing by tapping outside
          builder: (context) => AlertDialog(
            backgroundColor: Colors.black.withOpacity(0.9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(
                color: Color.fromARGB(255, 64, 182, 255),
                width: 1.5,
              ),
            ),
            title: const Text(
              'Choose Value',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color.fromARGB(255, 64, 182, 255),
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 1.1,
                fontFamily: 'Balatro',
              ),
            ),
            content: const Text(
              '1 or 14?',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 15, fontFamily: 'Balatro'),
            ),
            actionsAlignment: MainAxisAlignment.spaceEvenly,
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.grey[900],
                  foregroundColor: const Color.fromARGB(255, 64, 182, 255),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32, // Increased from 18
                    vertical: 16, // Increased from 8
                  ),
                  minimumSize: const Size(80, 56), // Added minimum size
                ),
                onPressed: () {
                  setState(() {
                    _aceDialogOpen = false;
                  });
                  Navigator.of(context).pop(1);
                },
                child: const Text(
                  '1',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 24, // Increased from 16
                    letterSpacing: 1.2,
                    fontFamily: 'Balatro',
                  ),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.grey[900],
                  foregroundColor: const Color.fromARGB(255, 64, 182, 255),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32, // Increased from 18
                    vertical: 16, // Increased from 8
                  ),
                  minimumSize: const Size(80, 56), // Added minimum size
                ),
                onPressed: () {
                  setState(() {
                    _aceDialogOpen = false;
                  });
                  Navigator.of(context).pop(14);
                },
                child: const Text(
                  '14',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 24, // Increased from 16
                    letterSpacing: 1.2,
                    fontFamily: 'Balatro',
                  ),
                ),
              ),
            ],
          ),
        );

        setState(() {
          _aceDialogOpen = false;
        });

        // Check if turn ended while dialog was open
        if (!isPlayerTurn || gameOver) {
          // Turn ended, return default values for remaining aces
          aceOverrides.add(14); // Default to 14
          int remainingAces =
              playedCards.where((c) => c == 'a').length - aceOverrides.length;
          for (int i = 0; i < remainingAces; i++) {
            aceOverrides.add(14);
          }
          break;
        }

        aceOverrides.add(aceValue ?? 14);
      }
    }

    // Ensure we have values for all aces
    int aceCount = playedCards.where((c) => c == 'a').length;
    while (aceOverrides.length < aceCount) {
      aceOverrides.add(14);
    }

    return aceOverrides;
  }

  void _trackPlayedCards(List<String> cards, bool isPlayer) {
    for (String card in cards) {
      playedCardCounts[card] = (playedCardCounts[card] ?? 0) + 1;
      gameHistory.add(card);
      totalCardsPlayed++;

      // Track player patterns specifically
      if (isPlayer) {
        playerPlayPatterns[card] = (playerPlayPatterns[card] ?? 0) + 1;
      }
    }
  }

  Future<void> playSelectedCards() async {
    if (!isPlayerTurn || gameOver || selectedIndices.isEmpty) return;

    // Add Firebase turn validation for multiplayer
    if (gameMode == 'human' && roomCode != null) {
      try {
        final roomRef = FirebaseDatabase.instance.ref('rooms/$roomCode');
        final snapshot = await roomRef.child('turn').get();
        final currentTurn = snapshot.value as String?;

        if (currentTurn != playerId) {
          setState(() {
            message = "Not your turn!";
            clearSelections();
          });
          return;
        }
      } catch (e) {
        return;
      }
    }

    // Handle rewind modifier
    if (activePlayerModifier == 'rewind') {
      if (field.length > 1) {
        setState(() {
          field.removeLast();

          // Remove the corresponding ace value from history
          if (fieldAceValueHistory.isNotEmpty) {
            fieldAceValueHistory.removeLast();
          }

          // Restore proper ace value if the new last card is an ace
          if (field.isNotEmpty && field.last == 'a') {
            if (fieldAceValueHistory.isNotEmpty) {
              fieldAceValue = fieldAceValueHistory.last;
            } else {
              fieldAceValue = null;
            }
          } else {
            fieldAceValue = null;
          }

          playerModifiers['rewind'] = true;
          activePlayerModifier = null;
          activityLog.add('Field rewound!');
        });
        // Continue with normal play - do NOT return here
      }
    }

    // Handle draw1 modifier
    if (activePlayerModifier == 'draw1') {
      setState(() {
        playerMaxHandSize = 3; // Temporarily increase hand size
        safeDrawCards(playerHand, playerDrawPile, 1);
        playerModifiers['draw1'] = true;
        activePlayerModifier = null;
        activityLog.add('Drew extra card!');
      });
      // Continue with normal play
    }

    HapticFeedback.lightImpact();

    selectedIndices.removeWhere((i) => i < 0 || i >= playerHand.length);

    if (!isSelectionValidForPlay()) {
      clearSelections();
      return;
    }

    List<String> playedCards =
        selectedIndices.map((i) => playerHand[i]).toList();
    List<int> aceOverrides = await promptForAceValues(playedCards);

    turnTimer?.cancel();

    if (!isPlayerTurn || gameOver) {
      clearSelections();
      return;
    }

    // Validate all indices are still valid
    List<int> originalIndices = List.from(selectedIndices);
    selectedIndices.removeWhere((i) => i < 0 || i >= playerHand.length);

    if (selectedIndices.isEmpty ||
        selectedIndices.length != originalIndices.length) {
      clearSelections();
      return;
    }

    playedCards = selectedIndices.map((i) => playerHand[i]).toList();

    while (selectedOps.length < selectedIndices.length - 1) {
      selectedOps.add('+');
    }
    while (selectedOps.length > selectedIndices.length - 1) {
      selectedOps.removeLast();
    }

    if (gameMode == 'ai') {
      _trackPlayedCards(playedCards, true);
    }

    // Handle hand size reset logic for 3-card hands
    if (playerMaxHandSize == 3 && selectedIndices.length == 1) {
      playerMaxHandSize = 2;
    }

    List<String> savedSelectedOps = List.from(selectedOps);
    String? appliedModifier = activePlayerModifier; // FIXED: Store the modifier

    // Validate the move BEFORE updating local state
    bool isFirstPlay = field.isEmpty;
    bool isValidMove = false;

    if (!isFirstPlay) {
      String prevFieldCard = field.isNotEmpty ? field.last : '2';
      // FIXED: Pass the modifier to validation
      isValidMove = isValidPlay(
          playedCards, selectedOps, prevFieldCard, aceOverrides,
          fieldAceValue: fieldAceValue, appliedModifier: appliedModifier);
    }

    // Remove cards from hand
    List<int> validatedIndices = [];
    for (int index in selectedIndices) {
      if (index >= 0 && index < playerHand.length) {
        validatedIndices.add(index);
      } else {
        clearSelections();
        return;
      }
    }

    validatedIndices.sort((a, b) => b.compareTo(a));
    for (int index in validatedIndices) {
      if (index >= 0 && index < playerHand.length) {
        playerHand.removeAt(index);
      }
    }

    clearSelections();

    // Add cards to field with proper reordering
    List<String> cardsToAdd = List.from(playedCards);
    if (cardsToAdd.length > 1) {
      List<double> values = [];
      int aceIdx = 0;
      for (int i = 0; i < cardsToAdd.length; i++) {
        if (cardsToAdd[i] == 'a') {
          int aceValue = 14;
          if (aceIdx < aceOverrides.length) {
            aceValue = aceOverrides[aceIdx];
          }
          values.add(cardValue('a', aceOverride: aceValue));
          aceIdx++;
        } else {
          values.add(cardValue(cardsToAdd[i]));
        }
      }

      double minValue = values.reduce(min);
      int minIdx = values.indexOf(minValue);
      if (minIdx != values.length - 1) {
        String tempCard = cardsToAdd[minIdx];
        cardsToAdd.removeAt(minIdx);
        cardsToAdd.add(tempCard);
      }
    }

    for (var card in cardsToAdd) {
      field.add(card);
    }

    // Track ace values for rewind functionality
    int aceIdx = 0;
    for (int i = 0; i < cardsToAdd.length; i++) {
      String card = cardsToAdd[i];
      if (card == 'a' && i == cardsToAdd.length - 1) {
        // Final ace gets the actual value used
        int aceValue = aceIdx < aceOverrides.length ? aceOverrides[aceIdx] : 14;
        fieldAceValueHistory.add(aceValue);
        aceIdx++;
      } else if (card == 'a') {
        // Non-final ace
        fieldAceValueHistory.add(null);
        aceIdx++;
      } else {
        // Regular card
        fieldAceValueHistory.add(null);
      }
    }

    // Handle Ace value
    if (field.isNotEmpty && field.last == 'a') {
      if (cardsToAdd.isNotEmpty &&
          cardsToAdd.last == 'a' &&
          aceOverrides.isNotEmpty) {
        fieldAceValue = aceOverrides.last;
      } else {
        fieldAceValue = 14;
      }
    } else {
      fieldAceValue = null;
    }

    // Create play description with modifier info
    String playDescription =
        _createPlayDescription(playedCards, savedSelectedOps, aceOverrides);
    if (appliedModifier != null) {
      playDescription += ' ($appliedModifier)';
      // Mark modifier as used
      playerModifiers[appliedModifier] = true;
    }

    activityLog.add(playDescription);
    playCardSound();

// Handle scoring and special cases
    if (isFirstPlay) {
      activityLogColor = Colors.white;
      safeDrawCards(playerHand, playerDrawPile, 2);
    } else if (isValidMove) {
  activityLogColor = Colors.greenAccent;
  if (playerPrizeCards.isNotEmpty) {
    HapticFeedback.mediumImpact();
    playerPrizeCards.removeLast();
    // Only play sound if not the final prize card
    if (playerPrizeCards.isNotEmpty) {
      playPrizeCardSound();
    }
    // Trigger shine animation on winning card
    setState(() {
      _showPrizeWinShine = true;
    });
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            setState(() {
              _showPrizeWinShine = false;
            });
          }
        });
      }
      safeDrawCards(playerHand, playerDrawPile, 2);
      playerMaxHandSize = 2;
    } else {
      activityLogColor = Colors.white;
      safeDrawCards(playerHand, playerDrawPile, 2);
      playerMaxHandSize = 2;
    }

    safeDrawCards(playerHand, playerDrawPile, 2);

    setState(() {
      if (gameMode == 'human') {
        message = "Sending move...";
      } else {
        isPlayerTurn = false;
        message = "Opponent's turn!";
      }
    });

    // Update Firebase with modifier information
    if (gameMode == 'human') {
      this.playedCards = cardsToAdd;
      selectedOps = savedSelectedOps;
      this.appliedModifier = appliedModifier; // FIXED: Store applied modifier
      await _updateFirebaseGameState();
    } else if (!gameOver && gameMode == 'ai') {
      Future.delayed(const Duration(seconds: 1), opponentTurn);
    }

    // Clear active modifier after use
    if (appliedModifier != null) {
      setState(() {
        activePlayerModifier = null;
      });
    }

    checkForWin();
  }

  void opponentTurn() async {
    // FIXED: Only run opponent AI in single-player mode
    if (gameMode != 'ai' || gameOver) return;

    // Don't run if initial overlay is showing (user exited to menu)
    if (showInitialOverlay) return;

    if (gameOver) return;
    turnTimer?.cancel();
    setState(() {});

    await Future.delayed(const Duration(seconds: 1));
    if (!mounted || gameOver || showInitialOverlay) return;

    // CRITICAL FIX: Add recursion prevention using class variable
    if (_isOpponentTurnRunning) {
      return;
    }
    _isOpponentTurnRunning = true;

    try {
      // SAFETY: Validate opponent has cards
      if (opponentActualHand.isEmpty) {
        setState(() {
          message = "Opponent has no cards left!";
          isPlayerTurn = true;
        });
        startTimer();
        return;
      }

      // BULLETPROOF AI LOGIC STARTS HERE

      // Simple difficulty-based win chance
      double winChance;
      if (aiDifficulty == 1) {
        winChance = 0.67; // Easy should still be beatable
      } else if (aiDifficulty == 2) {
        winChance = 0.70; // Medium should be challenging but fair
      } else {
        // Hard difficulty scales with win streak but starts lower
        winChance = (0.82 + (winStreak * 0.02)).clamp(0.82, 1.0);
      }
      bool shouldTryToWin = Random().nextDouble() < winChance;

      // AI MODIFIER LOGIC - Handle special modifiers before card selection
      String? aiModifierToUse;

      // Get available modifiers for AI (but skip if difficulty is 1)
      List<String> availableModifiers = [];
      if (aiDifficulty > 1) {
        // Only use modifiers on Medium (2) and Hard (3) difficulty
        for (String key in opponentModifiers.keys) {
          if (!opponentModifiers[key]!) {
            availableModifiers.add(key);
          }
        }
      }

      if (availableModifiers.isNotEmpty) {
// -0.5 logic - use when AI needs a slight adjustment to hit target
        if (availableModifiers.contains('-0.5') && field.isNotEmpty) {}

        // Rewind logic - use when field target is bad for AI
        if (availableModifiers.contains('rewind') && field.length > 1) {
          double fieldValue = field.last == 'a' && fieldAceValue != null
              ? fieldAceValue!.toDouble()
              : cardValue(field.last);
          // Use rewind if current target is hard to match
          if ([1, 13, 14].contains(fieldValue.toInt()) &&
              Random().nextDouble() < 0.3) {
            setState(() {
              field.removeLast();

              // Remove the corresponding ace value from history
              if (fieldAceValueHistory.isNotEmpty) {
                fieldAceValueHistory.removeLast();
              }

              // Restore proper ace value if the new last card is an ace
              if (field.isNotEmpty && field.last == 'a') {
                if (fieldAceValueHistory.isNotEmpty) {
                  fieldAceValue = fieldAceValueHistory.last;
                } else {
                  fieldAceValue = null;
                }
              } else {
                fieldAceValue = null;
              }

              opponentModifiers['rewind'] = true;
              activityLog.add('Opponent rewound the field!');
              activityLogColor = Colors.orange;
            });
          }
        }

        // Draw1 logic - use when AI has a poor hand
        if (availableModifiers.contains('draw1') &&
            opponentActualHand.length < 3) {
          // Count high-value cards (harder to play strategically)
          int highCards = 0;
          for (String card in opponentActualHand) {
            double val = cardValue(card);
            if (val >= 10) highCards++;
          }
          // Use draw1 if mostly high cards
          if (highCards >= opponentActualHand.length * 0.6 &&
              Random().nextDouble() < 0.4) {
            setState(() {
              if (opponentActualDrawPile.isNotEmpty) {
                opponentActualHand.add(opponentActualDrawPile.removeAt(0));
                opponentHand.add('cardback');
              }
              opponentModifiers['draw1'] = true;
              activityLog.add('Opponent drew an extra card!');
              activityLogColor = Colors.orange;
            });
          }
        }

        // Select calculation modifier for this play
        List<String> calcModifiers = availableModifiers
            .where((m) =>
                ['2x', '+3', '-3', '-1', '+1', '+11', '-0.5'].contains(m))
            .toList();

        if (calcModifiers.isNotEmpty &&
            shouldTryToWin &&
            Random().nextDouble() < 0.3) {
          aiModifierToUse =
              calcModifiers[Random().nextInt(calcModifiers.length)];
        }
      }

      List<Map<String, dynamic>> validPlays = [];

      // STEP 1: Find ALL genuinely valid single-card plays (INCLUDING MODIFIER EFFECTS)
      for (int i = 0; i < opponentActualHand.length; i++) {
        String card = opponentActualHand[i];

        if (field.isEmpty) {
          // First play - any card is valid
          validPlays.add({
            'indices': [i],
            'cards': [card],
            'ops': [],
            'aceOverrides': card == 'a' ? [14] : [],
            'isValid': true,
            'score': 1.0,
            'modifier': null, // No modifiers on first play
          });
        } else {
          // Need to match field card
          String fieldCard = field.last;
          double targetValue = fieldCard == 'a' && fieldAceValue != null
              ? fieldAceValue!.toDouble()
              : cardValue(fieldCard);

          if (card == 'a') {
            // Try ace as both 1 and 14
            for (int aceVal in [1, 14]) {
              double playValue = aceVal.toDouble();

              // Try without modifier first
              if (playValue == targetValue * 2 ||
                  playValue == targetValue / 2) {
                validPlays.add({
                  'indices': [i],
                  'cards': [card],
                  'ops': [],
                  'aceOverrides': [aceVal],
                  'isValid': true,
                  'score': 3.0,
                  'modifier': null,
                });
              }

              // Try with modifier if available
              if (aiModifierToUse != null) {
                double modifiedValue =
                    _applyModifierToValue(playValue, aiModifierToUse);
                if (modifiedValue == targetValue * 2 ||
                    modifiedValue == targetValue / 2) {
                  validPlays.add({
                    'indices': [i],
                    'cards': [card],
                    'ops': [],
                    'aceOverrides': [aceVal],
                    'isValid': true,
                    'score': 4.0, // Higher score for modifier plays
                    'modifier': aiModifierToUse,
                  });
                }
              }
            }
          } else {
            // Regular card
            double playValue = cardValue(card);

            // Try without modifier
            if (playValue == targetValue * 2 || playValue == targetValue / 2) {
              validPlays.add({
                'indices': [i],
                'cards': [card],
                'ops': [],
                'aceOverrides': [],
                'isValid': true,
                'score': 3.0,
                'modifier': null,
              });
            }

            // Try with modifier
            if (aiModifierToUse != null) {
              double modifiedValue =
                  _applyModifierToValue(playValue, aiModifierToUse);
              if (modifiedValue == targetValue * 2 ||
                  modifiedValue == targetValue / 2) {
                validPlays.add({
                  'indices': [i],
                  'cards': [card],
                  'ops': [],
                  'aceOverrides': [],
                  'isValid': true,
                  'score': 4.0,
                  'modifier': aiModifierToUse,
                });
              }
            }
          }
        }
      }

      // STEP 2: Find valid two-card combinations (including modifier effects)
      if (opponentActualHand.length >= 2 && field.isNotEmpty) {
        String fieldCard = field.last;
        double targetValue = fieldCard == 'a' && fieldAceValue != null
            ? fieldAceValue!.toDouble()
            : cardValue(fieldCard);

        for (int i = 0; i < opponentActualHand.length; i++) {
          for (int j = i + 1; j < opponentActualHand.length; j++) {
            String card1 = opponentActualHand[i];
            String card2 = opponentActualHand[j];

            // Try both operations
            for (String op in ['+', '-']) {
              // Handle ace values
              double val1 = cardValue(card1);
              double val2 = cardValue(card2);

              if (card1 == 'a') {
                for (int aceVal in [1, 14]) {
                  val1 = aceVal.toDouble();
                  if (card2 == 'a') {
                    for (int aceVal2 in [1, 14]) {
                      val2 = aceVal2.toDouble();
                      double result = op == '+' ? val1 + val2 : val1 - val2;

                      // Try without modifier
                      if (result == targetValue * 2 ||
                          result == targetValue / 2) {
                        validPlays.add({
                          'indices': [i, j],
                          'cards': [card1, card2],
                          'ops': [op],
                          'aceOverrides': [aceVal, aceVal2],
                          'isValid': true,
                          'score': 2.0,
                          'modifier': null,
                        });
                      }

                      // Try with modifier
                      if (aiModifierToUse != null) {
                        double modifiedResult =
                            _applyModifierToValue(result, aiModifierToUse);
                        if (modifiedResult == targetValue * 2 ||
                            modifiedResult == targetValue / 2) {
                          validPlays.add({
                            'indices': [i, j],
                            'cards': [card1, card2],
                            'ops': [op],
                            'aceOverrides': [aceVal, aceVal2],
                            'isValid': true,
                            'score': 3.0, // Higher score for modifier plays
                            'modifier': aiModifierToUse,
                          });
                        }
                      }
                    }
                  } else {
                    double result = op == '+' ? val1 + val2 : val1 - val2;

                    if (result == targetValue * 2 ||
                        result == targetValue / 2) {
                      validPlays.add({
                        'indices': [i, j],
                        'cards': [card1, card2],
                        'ops': [op],
                        'aceOverrides': [aceVal],
                        'isValid': true,
                        'score': 2.0,
                        'modifier': null,
                      });
                    }

                    if (aiModifierToUse != null) {
                      double modifiedResult =
                          _applyModifierToValue(result, aiModifierToUse);
                      if (modifiedResult == targetValue * 2 ||
                          modifiedResult == targetValue / 2) {
                        validPlays.add({
                          'indices': [i, j],
                          'cards': [card1, card2],
                          'ops': [op],
                          'aceOverrides': [aceVal],
                          'isValid': true,
                          'score': 3.0,
                          'modifier': aiModifierToUse,
                        });
                      }
                    }
                  }
                }
              } else if (card2 == 'a') {
                for (int aceVal in [1, 14]) {
                  val2 = aceVal.toDouble();
                  double result = op == '+' ? val1 + val2 : val1 - val2;

                  if (result == targetValue * 2 || result == targetValue / 2) {
                    validPlays.add({
                      'indices': [i, j],
                      'cards': [card1, card2],
                      'ops': [op],
                      'aceOverrides': [aceVal],
                      'isValid': true,
                      'score': 2.0,
                      'modifier': null,
                    });
                  }

                  if (aiModifierToUse != null) {
                    double modifiedResult =
                        _applyModifierToValue(result, aiModifierToUse);
                    if (modifiedResult == targetValue * 2 ||
                        modifiedResult == targetValue / 2) {
                      validPlays.add({
                        'indices': [i, j],
                        'cards': [card1, card2],
                        'ops': [op],
                        'aceOverrides': [aceVal],
                        'isValid': true,
                        'score': 3.0,
                        'modifier': aiModifierToUse,
                      });
                    }
                  }
                }
              } else {
                // No aces
                double result = op == '+' ? val1 + val2 : val1 - val2;

                if (result == targetValue * 2 || result == targetValue / 2) {
                  validPlays.add({
                    'indices': [i, j],
                    'cards': [card1, card2],
                    'ops': [op],
                    'aceOverrides': [],
                    'isValid': true,
                    'score': 2.0,
                    'modifier': null,
                  });
                }

                if (aiModifierToUse != null) {
                  double modifiedResult =
                      _applyModifierToValue(result, aiModifierToUse);
                  if (modifiedResult == targetValue * 2 ||
                      modifiedResult == targetValue / 2) {
                    validPlays.add({
                      'indices': [i, j],
                      'cards': [card1, card2],
                      'ops': [op],
                      'aceOverrides': [],
                      'isValid': true,
                      'score': 3.0,
                      'modifier': aiModifierToUse,
                    });
                  }
                }
              }
            }
          }
        }
      }


      // STEP 3: Choose the best play
      Map<String, dynamic>? chosenPlay;

      if (validPlays.isNotEmpty && shouldTryToWin) {
        // Sort by score (higher is better)
        validPlays.sort((a, b) => b['score'].compareTo(a['score']));
        chosenPlay = validPlays.first;
      } else if (validPlays.isNotEmpty && !shouldTryToWin) {
        // Sometimes play suboptimally on purpose
        chosenPlay = validPlays[Random().nextInt(validPlays.length)];
      } else {
        // FALLBACK: Play first card (this should rarely happen)
        chosenPlay = {
          'indices': [0],
          'cards': [opponentActualHand[0]],
          'ops': [],
          'aceOverrides': opponentActualHand[0] == 'a' ? [14] : [],
          'isValid': false, // Mark as fallback
          'score': 0.0,
          'modifier': null,
        };
      }

      // STEP 4: Execute the chosen play
      List<int> indicesToPlay = List<int>.from(chosenPlay['indices']);
      List<String> cardsToPlay = List<String>.from(chosenPlay['cards']);
      List<String> opsToPlay = List<String>.from(chosenPlay['ops']);
      List<int> aceOverrides = List<int>.from(chosenPlay['aceOverrides']);
      bool isValidPlay = chosenPlay['isValid'];
      String? usedModifier = chosenPlay['modifier'];

      // Mark modifier as used if AI used one
      if (usedModifier != null) {
        opponentModifiers[usedModifier] = true;
      }

      // Remove cards from AI hand (in reverse order to maintain indices)
      indicesToPlay.sort((a, b) => b.compareTo(a));
      for (int index in indicesToPlay) {
        if (index >= 0 && index < opponentActualHand.length) {
          opponentActualHand.removeAt(index);
        }
      }

      // Update display hand
      for (int i = 0; i < cardsToPlay.length && opponentHand.isNotEmpty; i++) {
        opponentHand.removeAt(0);
      }

      setState(() {
        // Add cards to field (with proper reordering if multi-card)
        if (cardsToPlay.length > 1) {
          // Reorder so largest value goes first (game rule: highest value first)
          List<double> values = [];
          int aceOverrideIdx = 0; // Separate counter for ace overrides
          for (int i = 0; i < cardsToPlay.length; i++) {
            String card = cardsToPlay[i];
            if (card == 'a' && aceOverrideIdx < aceOverrides.length) {
              values.add(aceOverrides[aceOverrideIdx].toDouble());
              aceOverrideIdx++;
            } else {
              values.add(cardValue(card));
            }
          }

          int maxIndex = 0;
          double maxValue = values[0];
          for (int i = 1; i < values.length; i++) {
            if (values[i] > maxValue) {
              maxValue = values[i];
              maxIndex = i;
            }
          }

          // Move largest to front if it's not already there
          if (maxIndex != 0) {
            String tempCard = cardsToPlay[maxIndex];
            cardsToPlay.removeAt(maxIndex);
            cardsToPlay.insert(0, tempCard);

            if (aceOverrides.length > maxIndex) {
              int tempAce = aceOverrides[maxIndex];
              aceOverrides.removeAt(maxIndex);
              aceOverrides.insert(0, tempAce);
            }
          }
        }

        // Add to field
        field.addAll(cardsToPlay);

        // Trigger splash animation for opponent
        //_showCardSplash = true;

        // Set ace value if needed
        if (field.isNotEmpty && field.last == 'a') {
          fieldAceValue = aceOverrides.isNotEmpty ? aceOverrides.last : 14;
        } else {
          fieldAceValue = null;
        }

        // Create activity log message
        String playDescription = 'Opp played ';
        int aceOverrideIdx = 0; // Separate counter for ace overrides
        for (int i = 0; i < cardsToPlay.length; i++) {
          String card = cardsToPlay[i];
          String cardDisplay;

          if (card == 'a' && aceOverrideIdx < aceOverrides.length) {
            cardDisplay = aceOverrides[aceOverrideIdx].toString();
            aceOverrideIdx++;
          } else {
            cardDisplay = cardValue(card).toString().replaceAll('.0', '');
          }

          if (i == 0) {
            playDescription += cardDisplay;
          } else {
            String op = (i - 1) < opsToPlay.length ? opsToPlay[i - 1] : '+';
            playDescription += ' $op $cardDisplay';
          }
        }

        if (usedModifier != null) {
          playDescription += ' ($usedModifier)';
        }

        activityLog.add(playDescription);
        playCardSound();
      });
      
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) {
          setState(() {
            _showCardSplash = false;
          });
        }
      });

      // Handle scoring
      bool isFirstPlay = field.length == cardsToPlay.length;

      if (isFirstPlay) {
        // First play - no prize
        activityLogColor = Colors.white;
      } else if (isValidPlay) {
        // Valid strategic play - AI gets prize card
activityLogColor = Colors.redAccent;
if (opponentPrizeCards.isNotEmpty) {
  opponentPrizeCards.removeLast();
  // Only play sound if opponent still has prize cards left (not the final one)
  if (opponentPrizeCards.isNotEmpty) {
    playOpponentPrizeCardSound();
  }
          // Trigger opponent win shine animation
          _showOpponentWinShine = true;
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) {
              setState(() {
                _showOpponentWinShine = false;
              });
            }
          });
        }
      } else {
        // Invalid play - no prize
        activityLogColor = Colors.white;
      }

      // Replenish AI hand
      while (opponentActualHand.length < 2 &&
          opponentActualDrawPile.isNotEmpty) {
        opponentActualHand.add(opponentActualDrawPile.removeAt(0));
      }
      while (opponentHand.length < 2) {
        opponentHand.add('cardback');
      }

      // Check win condition
      checkForWin();
      if (gameOver) return;

      // End turn
      setState(() {
        isPlayerTurn = true;
        message = "Your turn!";
      });

      startTimer();
    } catch (e) {
      if (mounted) {
        setState(() {
          isPlayerTurn = true;
          message = "Your turn!";
        });
        startTimer();
      }
    } finally {
      _isOpponentTurnRunning = false;
    }
  }

// Helper method to apply modifiers to calculated values
  double _applyModifierToValue(double value, String modifier) {
    switch (modifier) {
      case '2x':
        return value * 2;
      case '+3':
        return value + 3;
      case '-3':
        return value - 3;
      case '-1':
        return value - 1;
      case '+1':
        return value + 1;
      case '+11':
        return value + 11;
      case '-0.5': // ADD THIS CASE
        return value - 0.5;
      default:
        return value;
    }
  }

  void toggleCardSelection(int index) {
    if (index < 0 || index >= playerHand.length) {
      return;
    }

    // Play tap sound for both selection and deselection
    playTapSound();

    HapticFeedback.lightImpact();
    setState(() {
      if (selectedIndices.contains(index)) {
        selectedIndices.remove(index);

        selectedOps.clear();
        for (int i = 0; i < selectedIndices.length - 1; i++) {
          selectedOps.add('+');
        }
      } else {
        if (selectedIndices.length < 3) {
          selectedIndices.add(index);

          selectedOps.clear();
          for (int i = 0; i < selectedIndices.length - 1; i++) {
            selectedOps.add('+');
          }
        }
      }

      if (selectedOps.length != (selectedIndices.length - 1).clamp(0, 2)) {
        selectedOps.clear();
        for (int i = 0; i < selectedIndices.length - 1; i++) {
          selectedOps.add('+');
        }
      }
    });
  }

void handleSwipeUpToPlay(int index) {
  if (!isPlayerTurn || gameOver || index < 0 || index >= playerHand.length) {
    return;
  }

  // Add Firebase turn validation for multiplayer
  if (gameMode == 'human' && roomCode != null) {
    FirebaseDatabase.instance
        .ref('rooms/$roomCode/turn')
        .get()
        .then((snapshot) {
      final currentTurn = snapshot.value as String?;
      if (currentTurn != playerId) {
        setState(() {
          message = "Not your turn!";
        });
        return;
      }

      // Proceed with instant play
      _instantPlayCard(index);
    }).catchError((e) {
      return;
    });
  } else {
    // AI mode - play immediately
    _instantPlayCard(index);
  }
}

void _instantPlayCard(int index) async {
  HapticFeedback.lightImpact();

  // Set the selection internally WITHOUT triggering visual feedback
  selectedIndices = [index];
  selectedOps = [];

  // Play the card immediately without setState (no visual selection)
  await playSelectedCards();
}

  void toggleOperation(int opIndex) {
    if (opIndex < 0 || opIndex >= selectedOps.length) {
      return;
    }

    playTapSound();

    HapticFeedback.selectionClick();
    setState(() {
      selectedOps[opIndex] = selectedOps[opIndex] == '+' ? '-' : '+';
    });
  }

  Widget buildTimer({required bool isMobile, required bool isTablet, bool isSmallPhone = false, bool isShortScreen = false}) {
    final timerSize = isSmallPhone 
        ? 50.0 
        : (isShortScreen ? 55.0 : (isMobile ? 60.0 : (isTablet ? 75.0 : 90.0)));
    return Padding(
      padding: EdgeInsets.only(left: isSmallPhone ? 8 : (isMobile ? 12 : 24)),
      child: SizedBox(
        width: timerSize,
        height: timerSize,
        child: AnalogPaperTimer(secondsLeft: timerSeconds, totalSeconds: 10, size: timerSize),
      ),
    );
  }

  Widget buildModifierCards({required bool isMobile, bool isSmallPhone = false}) {
  // FIX: Don't show modifiers during search or when waiting for opponent
  if (gameOver || showInitialOverlay || isSearchingForGame || waitingForOpponent) {
    return const SizedBox.shrink();
  }

  if (playerAvailableModifiers.isEmpty) {
    return const SizedBox.shrink();
  }

  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (int i = 0; i < playerAvailableModifiers.length && i < 3; i++) ...[
        if (i > 0) SizedBox(width: isSmallPhone ? 6 : (isMobile ? 8 : 12)),
        GestureDetector(
  onVerticalDragEnd: (details) {
    // Check if swipe was upward and fast enough
    if (details.primaryVelocity != null &&
        details.primaryVelocity! < -300 &&
        isPlayerTurn &&
        !gameOver &&
        selectedIndices.isNotEmpty) {
      _handleSwipeUpModifier(playerAvailableModifiers[i]);
    }
  },
        child: AnimatedModifierCard(
          modifierType: playerAvailableModifiers[i],
          tooltip: _getModifierTooltip(playerAvailableModifiers[i]),
          used: playerModifiers[playerAvailableModifiers[i]] ?? false,
          onTap: isPlayerTurn ? () => _useModifier(playerAvailableModifiers[i]) : null,
          isMobile: isMobile,
          isSmallPhone: isSmallPhone,
          isSelected: activePlayerModifier == playerAvailableModifiers[i],
          cardBackAsset: playerCardbackAssets[playerId] ?? CardWidget.defaultCardBackAsset,
        ),
),
      ],
    ],
  );
}

// Add these helper methods to get modifier symbols and tooltips
  String _getModifierSymbol(String modifier) {
    switch (modifier) {
      case 'mulligan':
        return 'M';
      case '2x':
        return '2×';
      case '+3':
        return '+3';
      case '-3':
        return '-3';
      case '+1':
        return '+1';
      case '-1':
        return '-1';
      case '+11':
        return '+11';
      case 'draw1':
        return 'D';
      case '-0.5':
        return '-½';
      case 'rewind':
        return 'R';
      default:
        return '?';
    }
  }

  String _getModifierTooltip(String modifier) {
    switch (modifier) {
      case 'mulligan':
        return 'Mulligan\n(Reshuffle Hand)';
      case '2x':
        return 'Double Result';
      case '+3':
        return 'Add 3 to Result';
      case '-3':
        return 'Subtract 3 from Result';
      case '+1':
        return 'Add 1 to Result';
      case '-1':
        return 'Subtract 1 from Result';
      case '+11':
        return 'Add 11 to Result';
      case 'draw1':
        return 'Draw Extra Card';
      case '-0.5':
        return 'Subtract 0.5 from Result';
      case 'rewind':
        return 'Undo Last Field Card';
      default:
        return 'Unknown Modifier';
    }
  }

  String _getModifierAssetPath(String modifier) {
    switch (modifier) {
      case 'rewind':
        return 'assets/images/rewindmod.png';
      case 'mulligan':
        return 'assets/images/mulliganmod.png';
      case 'draw1':
        return 'assets/images/draw1mod.png';
      case '-1':
        return 'assets/images/-1mod.png';
      case '-3':
        return 'assets/images/-3mod.png';
      case '-0.5':
        return 'assets/images/-halfmod.png';
      case '+1':
        return 'assets/images/+1mod.png';
      case '+3':
        return 'assets/images/+3mod.png';
      case '+11':
        return 'assets/images/+11mod.png';
      case '2x':
        return 'assets/images/2xmod.png';
      default:
        return 'assets/images/rewindmod.png';
    }
  }

  Widget buildOpponentModifierDisplay({required bool isMobile}) {
  // FIX: Don't show modifiers during search or when waiting for opponent
  if (gameOver || showInitialOverlay || isSearchingForGame || waitingForOpponent) {
    return const SizedBox.shrink();
  }

  // Ensure we have opponent available modifiers before displaying
  if (opponentAvailableModifiers.isEmpty) {
    return const SizedBox.shrink();
  }

  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(
      opponentAvailableModifiers.length > 3
          ? 3
          : opponentAvailableModifiers.length,
      (index) {
        if (index >= opponentAvailableModifiers.length) {
          return SizedBox.shrink();
        }

        String modifierKey = opponentAvailableModifiers[index];
        String displaySymbol = _getModifierDisplaySymbol(modifierKey);
        bool isUsed = opponentModifiers[modifierKey] ?? false;

        return Row(
          children: [
            if (index > 0) SizedBox(width: 8),
            _buildOpponentModifierIndicator(displaySymbol, isUsed),
          ],
        );
      },
    ),
  );
}

  Widget _buildModifierCard(String symbol, String tooltip, bool used,
    {VoidCallback? onTap,
    required bool isMobile,
    bool isSelected = false,
    String? modifierType}) {
  bool isDisabled = onTap == null;
  
  // ... existing code ...
  
  return Tooltip(
    message: used ? '$tooltip (Used)' : tooltip,
    child: GestureDetector(
      onTap: onTap,
      onVerticalDragEnd: (details) {
        // Check if swipe was upward and fast enough
        if (details.primaryVelocity != null &&
            details.primaryVelocity! < -300 &&
            modifierType != null &&
            !used &&
            isPlayerTurn &&
            !gameOver &&
            selectedIndices.isNotEmpty) { // Must have cards selected
          _handleSwipeUpModifier(modifierType);
        }
      },
      child: Opacity(
          opacity: used ? 0.3 : (isDisabled ? 0.6 : 0.95),
          child: Container(
            width: isMobile ? 50 : 60,
            height: isMobile ? 70 : 84,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color.fromARGB(255, 134, 158, 255),
                width: isSelected ? 3 : 2, // Thicker border when selected
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(2, 4),
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                  6), // Slightly smaller to account for border
              child: modifierType != null
                  ? ColorFiltered(
                      colorFilter: used
                          ? const ColorFilter.matrix([
                              0.2126, 0.7152, 0.0722, 0, 0, // Red channel
                              0.2126, 0.7152, 0.0722, 0, 0, // Green channel
                              0.2126, 0.7152, 0.0722, 0, 0, // Blue channel
                              0, 0, 0, 1, 0, // Alpha channel
                            ])
                          : (isDisabled
                              ? ColorFilter.mode(
                                  Colors.grey.withOpacity(0.5),
                                  BlendMode.srcATop,
                                )
                              : const ColorFilter.mode(
                                  Colors.transparent,
                                  BlendMode.multiply,
                                )),
                      child: Image.asset(
                        _getModifierAssetPath(modifierType),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    )
                  : Container(
                      color: Colors.grey[800],
                      child: Center(
                        child: Text(
                          '?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 18 : 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOpponentModifierIndicator(String text, bool isUsed) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isUsed
            ? Colors.grey.withOpacity(0.5)
            : Colors.blue.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isUsed ? Colors.grey : Colors.blue,
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Balatro',
            color: isUsed ? Colors.grey : Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget buildCardSelectionRow({
    required bool isMobile,
    required bool isTablet,
    bool isSmallPhone = false,
    double screenScale = 1.0,
  }) {
    if (selectedIndices.isEmpty) return const SizedBox.shrink();

    for (int index in selectedIndices) {
      if (index < 0 || index >= playerHand.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() => clearSelections());
        });
        return const SizedBox.shrink();
      }
    }

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

    // Responsive card sizing for selection row
    final selectionCardWidth = isSmallPhone 
        ? 55.0 
        : (isMobile ? (76.0 * screenScale).clamp(55.0, 80.0) : (isTablet ? 50.0 : 60.0));
    final selectionCardHeight = selectionCardWidth * 1.32;

    // Adjust spacing based on number of cards and screen size
    double cardSpacing = isSmallPhone 
        ? 0.5 
        : (selectedIndices.length >= 3 ? 1.0 : (isMobile ? 2.0 : 4.0));
    double opSpacing = isSmallPhone
        ? 0.25
        : (selectedIndices.length >= 3 ? 0.5 : (isMobile ? 1.0 : 2.0));

    List<Widget> widgets = [];

    for (int i = 0; i < selectedIndices.length; i++) {
      widgets.add(
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: const Color.fromARGB(227, 103, 164, 255),
              width: isSmallPhone ? 3 : 4,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(2, 4),
                spreadRadius: 1,
              ),
            ],
          ),
          margin: EdgeInsets.symmetric(horizontal: cardSpacing),
          child: SizedBox(
            width: selectionCardWidth,
            height: selectionCardHeight,
            child: CardWidget(
              value: playerHand[selectedIndices[i]],
              isJoker: playerHand[selectedIndices[i]] == 'jkr',
            ),
          ),
        ),
      );

      if (i < selectedIndices.length - 1 && i < selectedOps.length) {
  widgets.add(
    GestureDetector(
      onTap: () => toggleOperation(i),
      onVerticalDragEnd: (details) async {
        // Check if it's player's turn and game is active
        if (!isPlayerTurn || gameOver || selectedIndices.isEmpty) return;
        
        // Add Firebase turn validation for multiplayer
        if (gameMode == 'human' && roomCode != null) {
          try {
            final snapshot = await FirebaseDatabase.instance
                .ref('rooms/$roomCode/turn')
                .get();
            final currentTurn = snapshot.value as String?;
            
            if (currentTurn != playerId) {
              setState(() {
                message = "Not your turn!";
              });
              return;
            }
          } catch (e) {
            return;
          }
        }

        // Determine swipe direction
        if (details.primaryVelocity != null && details.primaryVelocity!.abs() > 300) {
          HapticFeedback.lightImpact();
          
          if (details.primaryVelocity! < 0) {
            // Swipe UP - keep current operator and submit
            await playSelectedCards();
          } else {
            // Swipe DOWN - toggle operator first, then submit
            setState(() {
              selectedOps[i] = selectedOps[i] == '+' ? '-' : '+';
            });
            
            // Small delay for visual feedback
            await Future.delayed(const Duration(milliseconds: 100));
            
            // Auto-submit with the new operator
            await playSelectedCards();
          }
        }
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: opSpacing),
        padding: EdgeInsets.symmetric(
          horizontal: 0,
          vertical: isSmallPhone ? 2 : (isMobile ? 4 : 8),
        ),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.greenAccent, width: 2),
        ),
        alignment: Alignment.center,
        constraints: BoxConstraints(
    minWidth: isSmallPhone ? 40 : (isMobile ? 50 : 60),  // Give it a minimum width
  ),
        child: Text(
          selectedOps[i],
          style: TextStyle(
            fontFamily: 'Balatro',
            fontSize: isSmallPhone ? 32 : (isMobile ? 48 : (isTablet ? 48 : 60)),
            color: const Color.fromARGB(255, 104, 255, 210),
            fontWeight: FontWeight.bold,
            shadows: const [
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

    if (isPlayerTurn && !gameOver) {
      final bool canPlay = isSelectionValidForPlay();
      widgets.add(
        Padding(
          padding: EdgeInsets.only(left: isSmallPhone ? 4.0 : (isMobile ? 8.0 : 16.0)),
          child: _PlayButton(
            canPlay: canPlay,
            onPressed: canPlay ? () => playSelectedCards() : null,
            isMobile: isMobile,
            isTablet: isTablet,
            isSmallPhone: isSmallPhone,
          ),
        ),
      );
    }

    // Wrap in FittedBox for overflow protection on small screens
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: widgets),
    );
  }

  Widget _buildSearchingContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _SearchingAnimation(),
        const SizedBox(height: 20),
        const Text(
          'Quick Play',
          style: TextStyle(
            color: Color.fromARGB(255, 0, 188, 212),
            fontFamily: 'Balatro',
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          waitingForOpponent 
              ? 'Waiting for opponent...'
              : 'Searching for game...',
          style: const TextStyle(
            color: Colors.white70,
            fontFamily: 'Balatro',
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 24),
        TextButton.icon(
          onPressed: _cancelQuickMatch,
          icon: const Icon(Icons.close, size: 18),
          label: const Text('Cancel', style: TextStyle(fontFamily: 'Balatro')),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white54,
          ),
        ),
      ],
    );
  }

  Widget buildVersusButton({required bool isMobile}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 5 : 12,
        vertical: isMobile ? 3 : 8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color.fromARGB(255, 38, 97, 246).withOpacity(0.8),
            const Color.fromARGB(255, 87, 111, 251).withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(1, 2),
          ),
        ],
        border: Border.all(
          color: const Color.fromARGB(153, 78, 78, 255).withOpacity(0.7),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showGameModeSelection(),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 6 : 12,
            vertical: isMobile ? 3 : 6,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                gameMode == 'ai' ? Icons.people : Icons.people,
                color: const Color.fromARGB(247, 226, 235, 255),
                size: isMobile ? 14 : 15,
              ),
              SizedBox(width: isMobile ? 6 : 8),
              Text(
                'Vs',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 11 : 13,
                  letterSpacing: 0.8,
                  fontFamily: 'Balatro',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildRoomSelectionOverlay({required bool isMobile}) {
    final modalMaxWidth = MediaQuery.of(context).size.width - 40;
    return Positioned.fill(
      child: Container(
        // Use fully opaque background when searching to hide card animations
        color: Colors.black.withOpacity(isSearchingForGame ? 1.0 : 0.8),
        child: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: (isMobile ? 300.0 : 400.0).clamp(0, modalMaxWidth)),
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color.fromARGB(255, 92, 90, 255).withOpacity(0.5),
                width: 1.5,
              ),
            ),
            child: isSearchingForGame
                ? _buildSearchingContent()
                : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.groups,
                  size: 60,
                  color: Color.fromARGB(255, 92, 96, 255),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Versus Mode',
                  style: TextStyle(
                    color: Color.fromARGB(255, 92, 96, 255),
                    fontFamily: 'Balatro',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                if (connectionStatus.isNotEmpty && !isSearchingForGame) ...[
                  Text(
                    connectionStatus,
                    style: TextStyle(
                      color: connectionStatus.contains('Error')
                          ? Colors.red
                          : Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                ],
                // Quick Play - Primary action
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 0, 188, 212),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    elevation: 4,
                  ),
                  onPressed: _searchForGame,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.flash_on, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Quick Play',
                        style: TextStyle(
                          fontFamily: 'Balatro',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Divider with "or"
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        color: Colors.white24,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'or use a room code',
                        style: TextStyle(
                          color: Colors.white38,
                          fontFamily: 'Balatro',
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: Colors.white24,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Room code options in a row
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          minimumSize: const Size(0, 44),
                        ),
                        onPressed: _createRoom,
                        child: const Text('Create', style: TextStyle(fontFamily: 'Balatro')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          minimumSize: const Size(0, 44),
                        ),
                        onPressed: () {
                          setState(() {
                            showJoinRoom = true;
                            showRoomSelection = false;
                          });
                        },
                        child: const Text('Join', style: TextStyle(fontFamily: 'Balatro')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _cancelRoomSelection,
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white54, fontFamily: 'Balatro'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildCreateRoomOverlay({required bool isMobile}) {
    final modalMaxWidth = MediaQuery.of(context).size.width - 40;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.8),
        child: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: (isMobile ? 300.0 : 400.0).clamp(0, modalMaxWidth)),
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color.fromARGB(255, 255, 64, 129).withOpacity(0.5),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.add_circle,
                  size: 60,
                  color: Color.fromARGB(255, 255, 64, 129),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Create Room',
                  style: TextStyle(
                    color: Color.fromARGB(255, 255, 64, 129),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Balatro',
                  ),
                ),
                const SizedBox(height: 24),
                if (waitingForOpponent) ...[
                  Text(
                    'Room Code: $roomCode',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      fontFamily: 'Balatro',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(
                    color: Color.fromARGB(255, 255, 64, 129),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Waiting for opponent...',
                    style: TextStyle(color: Color.fromARGB(179, 237, 239, 240), fontFamily: 'Balatro'),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () {
                      _leaveRoom(); // This now handles cleanup properly
                    },
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white54, fontFamily: 'Balatro'),
                    ),
                  ),
                ] else ...[
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 255, 64, 129),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    onPressed: _createRoom,
                    child: const Text('Create', style: TextStyle(fontFamily: 'Balatro')),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        showCreateRoom = false;
                        showRoomSelection = true;
                      });
                    },
                    child: const Text(
                      'Back',
                      style: TextStyle(color: Colors.white54, fontFamily: 'Balatro'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildJoinRoomOverlay({required bool isMobile}) {
    final modalMaxWidth = MediaQuery.of(context).size.width - 40;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.8),
        child: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: (isMobile ? 300.0 : 400.0).clamp(0, modalMaxWidth)),
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color.fromARGB(255, 255, 64, 129).withOpacity(0.5),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.login,
                  size: 60,
                  color: Color.fromARGB(255, 255, 64, 129),
                ),
                const SizedBox(height: 16),
                Text(
                  'Join Room',
                  style: const TextStyle(
                    fontFamily: 'Balatro',
                    color: Color.fromARGB(255, 255, 64, 129),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: roomCodeController,
                  decoration: InputDecoration(
                    hintText: 'Enter room code',
                    hintStyle: const TextStyle(
                      fontFamily: 'Balatro',
                      color: Colors.white54,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white54),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Color.fromARGB(255, 255, 64, 129),
                      ),
                    ),
                  ),
                  style: const TextStyle(
                    fontFamily: 'Balatro',
                    color: Colors.white,
                  ),
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 3,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(244, 255, 64, 128),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  onPressed: () {
                    if (roomCodeController.text.trim().isNotEmpty) {
                      _joinRoom(roomCodeController.text.trim());
                    }
                  },
                  child: const Text('Join', style: TextStyle(fontFamily: 'Balatro')),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    setState(() {
                      showJoinRoom = false;
                      showRoomSelection = true;
                      roomCodeController.clear();
                    });
                  },
                  child: const Text(
                    'Back',
                    style: TextStyle(
                      fontFamily: 'Balatro',
                      color: Colors.white54,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
Widget build(BuildContext context) {
  final screenSize = MediaQuery.of(context).size;
  final screenWidth = screenSize.width;
  final screenHeight = screenSize.height;
  
  // Improved responsive breakpoints
  final isSmallPhone = screenWidth < 360;
  final isMobile = screenWidth < 600;
  final isTablet = screenWidth >= 600 && screenWidth < 1024;
  final isDesktop = screenWidth >= 1024;
  final isLandscape = screenWidth > screenHeight && screenHeight < 500;
  final isShortScreen = screenHeight < 600 || isLandscape;
  
  // NEW: Detect mobile web on wide screens (browser on laptop/desktop)
  // This is when screen is wide but aspect ratio suggests mobile viewport
  final isMobileWebOnWideScreen = screenWidth >= 600 && 
                                    screenHeight < 900 && 
                                    screenWidth / screenHeight > 1.3;
  
  // Max width for desktop AND mobile web on wide screens to keep game centered and phone-like
  final maxGameWidth = (isDesktop || isMobileWebOnWideScreen) ? 500.0 : double.infinity;
  
  // Dynamic scaling factor based on screen width (normalized to Pixel 7's 412px)
  final screenScale = (screenWidth / 412).clamp(0.8, 1.3);
  
  // NEW: Reduce vertical spacing on mobile web wide screens to prevent overlap
  final verticalSpacingSmall = isMobileWebOnWideScreen 
      ? 3.0 
      : (isShortScreen ? 4.0 : (isMobile ? 8.0 : 12.0));
  final verticalSpacingMedium = isMobileWebOnWideScreen 
      ? 6.0 
      : (isShortScreen ? 8.0 : (isMobile ? 16.0 : 32.0));
  
  // Responsive card dimensions - smaller on mobile web wide screens
  final playerCardWidth = isMobileWebOnWideScreen
      ? 65.0
      : (isMobile 
          ? (isSmallPhone ? 65.0 : 80.0 * screenScale).clamp(60.0, 85.0)
          : (isTablet ? 60.0 : 75.0));
  final playerCardHeight = playerCardWidth * 1.31;
  
  final prizeCardWidth = isMobileWebOnWideScreen
      ? 42.0
      : (isMobile
          ? (isSmallPhone ? 45.0 : 55.0 * screenScale).clamp(42.0, 60.0)
          : (isTablet ? 55.0 : 70.0));
  final prizeCardHeight = prizeCardWidth * 1.4;
  
  final fieldCardWidth = isMobileWebOnWideScreen
      ? 60.0
      : (isMobile
          ? (isSmallPhone ? 60.0 : 75.0 * screenScale).clamp(55.0, 80.0)
          : (isTablet ? 65.0 : 80.0));
  final fieldCardHeight = fieldCardWidth * 1.4;
  
  final opponentCardWidth = isMobileWebOnWideScreen
      ? 42.0
      : (isMobile
          ? (isSmallPhone ? 45.0 : 55.0 * screenScale).clamp(42.0, 60.0)
          : (isTablet ? 55.0 : 70.0));
  final opponentCardHeight = opponentCardWidth * 1.4;
  
  final horizontalCardSpacing = isSmallPhone ? 2.0 : (isMobile ? 4.0 : 8.0);

  return Scaffold(
      appBar: null,
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
  child: Stack(
    fit: StackFit.expand,
    children: [
      // Keep a dark background behind the playmat during transitions
      Container(color: Colors.black),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 900),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: RepaintBoundary(child: child),
          );
        },
        child: RepaintBoundary(
          key: ValueKey(backgrounds[currentBackgroundIndex]),
          child: Transform.scale(
            scale: 4.25,
            child: Image.asset(
              backgrounds[currentBackgroundIndex],
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
        ),
      ),
    ],
  ),
),
            // Center game content with max width on desktop
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxGameWidth),
                child: Padding(
                  padding: EdgeInsets.all(
                    isMobile ? 16.0 : (isTablet ? 20.0 : 24.0),
                  ),
                  child: Column(
                    children: [
                      Flexible(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: EdgeInsets.only(
                              top: isShortScreen ? 60 : (isMobile ? 85 : 95),
                              bottom: isShortScreen ? 4 : (isMobile ? 8 : 16),
                          left: 0,
                          right: 0,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
// UPDATED: Opponent modifiers positioned above opponent prize cards - now shows randomly assigned modifiers
                            buildOpponentModifierDisplay(isMobile: isMobile),

                            SizedBox(height: verticalSpacingSmall),
// Opponent prize cards (top) - animate only when a new game starts (keyed by session ID)
                            Row(
                              key: ValueKey<String>('opp_prize_${opponentPrizeCards.length}_$_gameSessionId'),
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                opponentPrizeCards.length,
                                (index) => TweenAnimationBuilder<double>(
                                  key: ValueKey('opp_prize_${_gameSessionId}_$index'),
                                  tween: Tween(begin: 0.8, end: 1.0),
                                  duration: Duration(milliseconds: 300 + index * 50),
                                  curve: Curves.elasticOut,
                                  builder: (context, scale, child) {
                                    return Transform.scale(
                                      scale: scale,
                                      child: child,
                                    );
                                  },
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: horizontalCardSpacing / 2,
                                    ),
                                    child: FloatingPrizeCard(
                                      index: index,
                                      child: Container(
                                        width: prizeCardWidth,
                                        height: prizeCardHeight,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.4),
                                              blurRadius: 8,
                                              offset: const Offset(2, 4),
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                        child: CardWidget(
                                          isCardBack: true,
                                          cardBackAsset: gameMode == 'ai'
                                              ? aiOpponentCardbackAsset
                                              : (playerCardbackAssets[opponentId] ?? CardWidget.defaultCardBackAsset),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: verticalSpacingSmall),
// Opponent hand
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                opponentHand.length,
                                (_) => Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: horizontalCardSpacing / 2,
                                  ),
                                  child: Container(
                                    width: opponentCardWidth,
                                    height: opponentCardHeight,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.4),
                                          blurRadius: 8,
                                          offset: const Offset(2, 4),
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: CardWidget(
                                      isCardBack: true,
                                      cardBackAsset: gameMode == 'ai'
                                          ? aiOpponentCardbackAsset
                                          : (playerCardbackAssets[opponentId] ?? CardWidget.defaultCardBackAsset),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: verticalSpacingMedium),
// Field area
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  flex: isMobile ? 1 : 2,
                                  child: !showInitialOverlay
                                      ? Container(
                                          constraints: BoxConstraints(
                                            maxWidth: isSmallPhone
                                                ? 140
                                                : (isMobile ? 180 : (isTablet ? 200 : 250)),
                                            minHeight: isMobile ? 40 : 50,
                                            maxHeight: isShortScreen ? 60 : (isMobile ? 80 : 100),
                                          ),
                                          padding: EdgeInsets.symmetric(
                                            horizontal: isMobile ? 8 : 12,
                                            vertical: isMobile ? 6 : 8,
                                          ),
                                          margin: EdgeInsets.only(
                                            right: isMobile ? 8 : 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color.fromARGB(
                                                    180, 48, 43, 51)
                                                .withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color:
                                                  Colors.white.withOpacity(0.1),
                                              width: 0.5,
                                            ),
                                          ),
                                          alignment: Alignment.centerLeft,
                                          child: AnimatedSwitcher(
                                            duration: const Duration(milliseconds: 150),
                                            transitionBuilder: (Widget child, Animation<double> animation) {
                                              return FadeTransition(
                                                opacity: animation,
                                                child: child,
                                              );
                                            },
                                            child: activityLog.isNotEmpty
                                                ? _TypewriterText(
                                                    key: ValueKey<String>(activityLog.last + activityLog.length.toString()),
                                                    text: activityLog.last,
                                                    textAlign: TextAlign.left,
                                                    characterDuration: const Duration(milliseconds: 18),
                                                    style: TextStyle(
                                                      color: activityLogColor,
                                                      fontSize: isMobile
                                                          ? 14
                                                          : (isTablet ? 14 : 16),
                                                      height: 1.2,
                                                      fontWeight: FontWeight.w500,
                                                      fontFamily: 'Balatro',
                                                    ),
                                                  )
                                                : const SizedBox.shrink(key: ValueKey('empty')),
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                                Stack(
  clipBehavior: Clip.none,
  children: [
    AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      transitionBuilder: (Widget child,
          Animation<double> animation) {
        // Subtle downward placement animation
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0, -0.065), // Start slightly above
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ));
        
        final scaleAnimation = Tween<double>(
          begin: 1.02, // Start slightly larger (coming from above)
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ));
        
        return SlideTransition(
          position: slideAnimation,
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: ScaleTransition(
              scale: scaleAnimation,
              child: child,
            ),
          ),
        );
      },
      child: field.isNotEmpty
          ? Container(
              key: ValueKey('${field.last}_${field.length}'), // Include length so same-value cards still animate
              width: fieldCardWidth,
              height: fieldCardHeight,
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(2, 4),
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: CardWidget(
                value: field.last,
                isJoker: field.last == 'jkr',
              ),
            )
          : const SizedBox.shrink(),
    ),
    // Card splash effect
    if (_showCardSplash && field.isNotEmpty)
      Positioned.fill(
        child: Center(
          child: _CardSplashEffect(
            width: fieldCardWidth,
            height: fieldCardHeight,
          ),
        ),
      ),
    // Prize win shine animation (player wins)
    // Show the shine even when the field is empty (e.g. opponent timeout prize)
    if (_showPrizeWinShine)
      Positioned.fill(
        child: _PrizeWinShine(
          width: fieldCardWidth,
          height: fieldCardHeight,
        ),
      ),
    // Opponent win shine animation (dark grey)
    if (_showOpponentWinShine)
      Positioned.fill(
        child: _OpponentWinShine(
          width: fieldCardWidth,
          height: fieldCardHeight,
        ),
      ),
  ],
),
                                Expanded(
                                  flex: isMobile ? 1 : 2,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (!showInitialOverlay)
                                        buildTimer(
                                          isMobile: isMobile,
                                          isTablet: isTablet,
                                          isSmallPhone: isSmallPhone,
                                          isShortScreen: isShortScreen,
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: verticalSpacingMedium),
                            buildCardSelectionRow(
                              isMobile: isMobile,
                              isTablet: isTablet,
                              isSmallPhone: isSmallPhone,
                              screenScale: screenScale,
                            ),
// Player hand with turn indicator
_TurnIndicatorContainer(
  isPlayerTurn: isPlayerTurn && !gameOver,
  child: Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(playerHand.length, (index) {
      String cardValue = playerHand[index];
      bool isSelected = selectedIndices.contains(index);
      bool isInteractive = isPlayerTurn && !gameOver;
      
      return GestureDetector(
        onTap: isInteractive ? () => toggleCardSelection(index) : null,
        onVerticalDragEnd: isInteractive
            ? (details) {
                // Check if swipe was upward and fast enough
                if (details.primaryVelocity != null &&
                    details.primaryVelocity! < -300) {
                  handleSwipeUpToPlay(index);
                }
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(
            0,
            isSelected ? -12 : 0,
            0,
          ),
          child: AnimatedScale(
            scale: isSelected ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isInteractive ? 1.0 : 0.5,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? const Color.fromARGB(200, 100, 180, 255)
                        : Colors.transparent,
                    width: isSelected ? 2.5 : 0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected
                          ? const Color.fromARGB(60, 100, 180, 255)
                          : Colors.black.withOpacity(0.4),
                      blurRadius: isSelected ? 16 : 8,
                      offset: Offset(2, isSelected ? 8 : 4),
                      spreadRadius: isSelected ? 2 : 1,
                    ),
                  ],
                ),
                margin: EdgeInsets.symmetric(
                    horizontal: horizontalCardSpacing),
                child: SizedBox(
                  width: playerCardWidth,
                  height: playerCardHeight,
                  child: CardWidget(
                    value: cardValue,
                    isJoker: cardValue == 'jkr',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }),
  ),
),
                            SizedBox(height: verticalSpacingSmall),
// Player prize cards - animate only when a new game starts (keyed by session ID)
                            Row(
                              key: ValueKey<String>('player_prize_${playerPrizeCards.length}_$_gameSessionId'),
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                playerPrizeCards.length,
                                (index) => TweenAnimationBuilder<double>(
                                  key: ValueKey('player_prize_${_gameSessionId}_$index'),
                                  tween: Tween(begin: 0.8, end: 1.0),
                                  duration: Duration(milliseconds: 300 + index * 50),
                                  curve: Curves.elasticOut,
                                  builder: (context, scale, child) {
                                    return Transform.scale(
                                      scale: scale,
                                      child: child,
                                    );
                                  },
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: horizontalCardSpacing / 2,
                                    ),
                                    child: FloatingPrizeCard(
                                      index: index,
                                      child: Container(
                                        width: prizeCardWidth,
                                        height: prizeCardHeight,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.4),
                                              blurRadius: 8,
                                              offset: const Offset(2, 4),
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                        child: CardWidget(
                                          isCardBack: true,
                                          cardBackAsset: playerCardbackAssets[playerId] ?? CardWidget.defaultCardBackAsset,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: verticalSpacingSmall),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
            if (gameOver)
              Positioned.fill(
                child: _GameOverOverlay(
                  winner: winner,
                  isMobile: isMobile,
                  waitingForRematch: _waitingForRematch,
                  gameMode: gameMode,
                  onNextGame: () {
                    if (gameMode == 'human') {
                      setState(() {
                        _waitingForRematch = true;
                      });
                      _startRematch();
                    } else {
                      setState(() {
                        _setupGame();
                      });
                    }
                  },
                  onLeaveRoom: () {
                    // Ensure we leave the Firebase room and then
                    // fully prepare the app for multiplayer/initial overlay state
                    _leaveRoom();
                    _prepareForMultiplayer();
                    // Reinitialize underlying game state so the initial overlay shows a fresh game
                    _setupGame(rotateBackground: false);
                  },
                ),
              ),
            if (showInitialOverlay && !isSearchingForGame && !waitingForOpponent)
  Positioned.fill(
    child: Container(
      color: Colors.black.withOpacity(0.7),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _LongPressGlowIcon(
                  icon: Icons.content_cut_sharp,
                  size: 100,
                  baseColor: Color.fromARGB(255, 77, 104, 255),
                  baseBlurRadius: 12,
                  secondaryShadow: false,
                ),
                const SizedBox(height: 24),
                const Text(
                  ' ',
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
                    backgroundColor: Color.fromARGB(255, 95, 77, 255),
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
                    // Fully initialize a new game when Play is pressed
                    _setupGame(rotateBackground: false);
                  },
                  child: const Text(
                    'Play',
                    style: TextStyle(
                      fontFamily: 'Balatro',
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
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
                        SizedBox(width: 28),
                        Text(
                          'How to Play',
                          style: TextStyle(
                            color: const Color.fromARGB(
                                192, 242, 244, 255),
                            fontFamily: 'Balatro',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.underline,
                            decorationColor:
                                const Color.fromARGB(180, 175, 182, 223)
                                    .withOpacity(0.8),
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
                              horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color.fromARGB(
                                      255, 87, 111, 251)
                                  .withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                                _buildRuleItem(
                                  'Take turns playing card(s)'),
                                const SizedBox(height: 12),
                                _buildRuleItem(
                                  'Try to double or halve the last played card'),
                                const SizedBox(height: 12),
                                _buildRuleItem(
                                  '+ or - cards for strategic plays'),
                                const SizedBox(height: 12),
                                _buildRuleItemWithLink(
                                  'Learn more', 'https://anthonyraad.github.io/8XGuide/'),
                                const SizedBox(height: 12),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          // High score display in bottom-right
          Positioned(
            bottom: isMobile ? 20 : 30,
            right: isMobile ? 15 : 30,
            child: buildHighScore(isMobile: isMobile),
          ),
        ],
      ),
    ),
  ),
            if (showRoomSelection || isSearchingForGame)
              buildRoomSelectionOverlay(isMobile: isMobile),
            if (showCreateRoom) buildCreateRoomOverlay(isMobile: isMobile),
            if (showJoinRoom) buildJoinRoomOverlay(isMobile: isMobile),
            if (gameMode == 'ai')
              Positioned(
                top: isMobile ? 20 : 30,
                right: isMobile ? 15 : 30,
                child: Material(
                  color: Colors.transparent,
                  child: buildDifficultySelector(isMobile: isMobile),
                ),
              ),
          // Settings icon (only on initial overlay)
          if (showInitialOverlay)
            Positioned(
              bottom: isMobile ? 18 : 28,
              left: isMobile ? 15 : 30,
              child: showSettings
                  ? const SizedBox.shrink()
                  : IconButton(
                      icon: Icon(
                        Icons.settings,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.6),
                            blurRadius: 4,
                            offset: Offset(1, 1),
                          ),
                        ],
                      ),
                      iconSize: 20,
                      color: const Color.fromARGB(255, 0, 195, 255),
                      tooltip: 'Settings',
                      onPressed: () {
                        setState(() {
                          showSettings = true;
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
            ),

          // Settings modal
          if (showSettings)
            Positioned.fill(
              child: Container(
                color: Colors.transparent,
                child: Center(
                  child: Container(
                    width: isMobile ? 320 : 420,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Settings',
                          style: TextStyle(
                            fontFamily: 'Balatro',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text(
                                  'Total wins:',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Balatro',
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$totalWins',
                                  style: const TextStyle(
                                    color: Colors.blueAccent,
                                    fontFamily: 'Balatro',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Text(
                                  'Best Streak:',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Balatro',
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$highScore',
                                  style: const TextStyle(
                                    color: Colors.blueAccent,
                                    fontFamily: 'Balatro',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        CheckboxListTile(
                          value: volumeEnabled,
                          onChanged: (v) {
                            setState(() {
                              volumeEnabled = v ?? true;
                              _applyVolumeSetting();
                              _saveVolumeSetting();
                            });
                          },
                          title: Text(
                            'Volume',
                            style: const TextStyle(color: Colors.white, fontFamily: 'Balatro'),
                          ),
                          controlAffinity: ListTileControlAffinity.trailing,
                          activeColor: Colors.blueAccent,
                        ),
                        const SizedBox(height: 8),
                        // Default Difficulty selection row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Difficulty:',
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Balatro',
                                fontSize: 14,
                              ),
                            ),
                            DropdownButton<int>(
                              value: defaultAiDifficulty,
                              dropdownColor: Colors.grey[900],
                              underline: const SizedBox.shrink(),
                              items: [
                                DropdownMenuItem(
                                  value: 1,
                                  child: Text(
                                    'Dull',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Balatro',
                                    ),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 2,
                                  child: Text(
                                    'Keen',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Balatro',
                                    ),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 3,
                                  child: Text(
                                    'Sharp',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Balatro',
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (v) async {
                                if (v == null) return;
                                setState(() {
                                  defaultAiDifficulty = v;
                                  aiDifficulty = v; // Immediately reflect in selector
                                });
                                await _saveDefaultDifficulty();
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Cardback:',
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Balatro',
                                fontSize: 14,
                              ),
                            ),
                            DropdownButton<String>(
                              value: cardbackChoice,
                              dropdownColor: Colors.grey[900],
                              underline: const SizedBox.shrink(),
                              items: ['Diamond', 'Onyx', 'Amber', 'Amethyst', 'Opal']
                                  .map((name) {
                                    final locked = (name == 'Opal' && !unlockedOpal) || (name == 'Amethyst' && !unlockedAmethyst) || (name == 'Amber' && !unlockedAmber) || (name == 'Onyx' && !unlockedOnyx);
                                    return DropdownMenuItem(
                                      value: name,
                                      child: locked
                                          ? Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  name,
                                                  style: const TextStyle(
                                                    color: Colors.grey,
                                                    fontFamily: 'Balatro',
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                const Icon(
                                                  Icons.lock,
                                                  size: 14,
                                                  color: Colors.grey,
                                                ),
                                              ],
                                            )
                                          : Text(
                                              name,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontFamily: 'Balatro',
                                              ),
                                            ),
                                    );
                                  })
                                  .toList(),
                              onChanged: (v) async {
                                if (v == null) return;
                                // Prevent selecting locked options
                                if (v == 'Opal' && !unlockedOpal) {
                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Reach a 10 winstreak to unlock.', style: const TextStyle(fontFamily: 'Balatro')),
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor: Colors.black87,
                                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      elevation: 6,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                  return;
                                }
                                if (v == 'Amethyst' && !unlockedAmethyst) {
                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Reach a 7 winstreak to unlock.', style: const TextStyle(fontFamily: 'Balatro')),
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor: Colors.black87,
                                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      elevation: 6,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                  return;
                                }
                                if (v == 'Amber' && !unlockedAmber) {
                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Reach a 5 winstreak to unlock.', style: const TextStyle(fontFamily: 'Balatro')),
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor: Colors.black87,
                                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      elevation: 6,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                  return;
                                }
                                if (v == 'Onyx' && !unlockedOnyx) {
                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Reach a 3 winstreak to unlock.', style: const TextStyle(fontFamily: 'Balatro')),
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor: Colors.black87,
                                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      elevation: 6,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                  return;
                                }
                                setState(() {
                                  cardbackChoice = v;
                                  if (v == 'Opal') {
                                    selectedCardback = 'cardback5';
                                    CardWidget.defaultCardBackAsset = 'assets/images/cardback5.png';
                                  } else if (v == 'Amethyst') {
                                    selectedCardback = 'cardback4';
                                    CardWidget.defaultCardBackAsset = 'assets/images/cardback4.png';
                                  } else if (v == 'Amber') {
                                    selectedCardback = 'cardback3';
                                    CardWidget.defaultCardBackAsset = 'assets/images/cardback3.png';
                                  } else if (v == 'Onyx') {
                                    selectedCardback = 'cardback2';
                                    CardWidget.defaultCardBackAsset = 'assets/images/cardback2.png';
                                  } else {
                                    selectedCardback = 'cardback';
                                    CardWidget.defaultCardBackAsset = 'assets/images/cardback.png';
                                  }
                                });
                                await _saveCardbackChoice();
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  showSettings = false;
                                });
                              },
                              icon: const Icon(Icons.save),
                              color: Colors.white,
                              tooltip: 'Save',
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: isMobile ? 20 : 30,
              left: isMobile ? 15 : 30,
              child: AbsorbPointer(
                absorbing: showSettings,
                child: Material(
                  color: Colors.transparent,
                  child: buildVersusButton(isMobile: isMobile),
                ),
              ),
            ),
            // Persistent Exit button (visible except when on initial overlay)
if (!showInitialOverlay)
  Positioned(
    // Nudge slightly to vertically align with the win-streak widget
    bottom: isMobile ? 12 : 24,
    left: isMobile ? 14 : 30,
    child: IconButton(
      icon: Icon(
        Icons.home_filled,
        shadows: const [
          Shadow(
            color: Color.fromARGB(197, 8, 8, 8),
            blurRadius: 3,      // tight shadow
            offset: Offset(0, 1),
          ),
        ],
      ),
      iconSize: isMobile ? 23 : 27,
      color: const Color.fromARGB(220, 255, 255, 255),
      tooltip: 'Exit to Menu',
      onPressed: _handleGlobalExit,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      splashRadius: isMobile ? 16 : 18,
    ),
  ),
            if ((gameMode == 'ai' || gameMode == 'human') && !showInitialOverlay)
  Positioned(
    bottom: isMobile ? 20 : 30,
    right: isMobile ? 15 : 30,
    child: Material(
      color: Colors.transparent,
      child: buildWinStreak(isMobile: isMobile),
    ),
  ),
            Positioned(
              bottom: isShortScreen ? 30 : (isMobile ? 45 : 65),
              left: 0,
              right: 0,
              child: buildModifierCards(isMobile: isMobile, isSmallPhone: isSmallPhone),
            ),
          ],
        ),
      ),
    );
  }

// Helper method to get display symbol for modifiers
  String _getModifierDisplaySymbol(String modifierKey) {
    switch (modifierKey) {
      case 'mulligan':
        return 'M';
      case '2x':
        return '2×';
      case '+3':
        return '+3';
      case '-3':
        return '-3';
      case '-1':
        return '-1';
      case '+1':
        return '+1';
      case '+11':
        return '+11';
      case 'draw1':
        return 'D';
      case '-0.5':
        return '-½';
      case 'rewind':
        return 'R';
      default:
        return '?';
    }
  }

  Color _getModifierColor(
      String modifierType, bool used, bool isSelected, bool isDisabled) {
    if (used) return Colors.grey[800]!;
    if (isSelected) {
      return const Color.fromARGB(255, 255, 215, 0); // Gold when selected
    }
    if (isDisabled) return Colors.grey[600]!;

    // Unique colors for each modifier type
    switch (modifierType) {
      case 'mulligan':
        return const Color.fromARGB(255, 156, 39, 176); // Purple
      case '2x':
        return const Color.fromARGB(255, 239, 15, 255); // Red
      case '+3':
        return const Color.fromARGB(255, 76, 175, 80); // Green
      case '-3':
        return const Color.fromARGB(255, 121, 8, 0); // Orange
      case '+1':
        return const Color.fromARGB(255, 33, 150, 243); // Blue
      case '-1':
        return const Color.fromARGB(255, 24, 74, 8); // Amber
      case '+11':
        return const Color.fromARGB(255, 103, 58, 183); // Deep Purple
      case 'draw1':
        return const Color.fromARGB(255, 0, 150, 136); // Teal
      case '-0.5':
        return const Color.fromARGB(255, 121, 85, 72); // Brown
      case 'rewind':
        return const Color.fromARGB(255, 19, 73, 98); // Blue Grey
      default:
        return const Color.fromARGB(255, 77, 104, 255); // Default blue
    }
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
              fontFamily: 'Balatro',
            ),
          ),
        ),
      ],
    );
  }
}

Widget _buildRuleItemWithLink(String text, String url) {
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
        child: GestureDetector(
          onTap: () async {
            final Uri uri = Uri.parse(url);
            try {
              await launchUrl(
                uri,
                mode: LaunchMode.externalApplication,
                webOnlyWindowName: '_blank',
              );
            } catch (e) {
            }
          },
          child: Text(
            text,
            style: TextStyle(
              color: const Color.fromARGB(255, 100, 181, 246),
              fontSize: 14,
              height: 1.4,
              fontFamily: 'Balatro',
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ),
    ],
  );
}

class AnalogPaperTimer extends StatefulWidget {
  final int secondsLeft;
  final int totalSeconds;
  final double size;

  const AnalogPaperTimer({
    super.key,
    required this.secondsLeft,
    required this.totalSeconds,
    this.size = 90.0,
  });

  @override
  State<AnalogPaperTimer> createState() => _AnalogPaperTimerState();
}

class _AnalogPaperTimerState extends State<AnalogPaperTimer>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _updatePulseState();
  }

  @override
  void didUpdateWidget(AnalogPaperTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updatePulseState();
  }

  void _updatePulseState() {
    if (widget.secondsLeft <= 3 && widget.secondsLeft > 0) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isUrgent = widget.secondsLeft <= 3 && widget.secondsLeft > 0;
    
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: isUrgent ? _pulseAnimation.value : 1.0,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _PaperTimerPainter(
                secondsLeft: widget.secondsLeft,
                totalSeconds: widget.totalSeconds,
                isUrgent: isUrgent,
              ),
              child: Center(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontFamily: 'Balatro',
                    fontSize: widget.size * 0.30,
                    color: isUrgent 
                        ? const Color.fromARGB(255, 200, 60, 60)
                        : const Color.fromARGB(220, 60, 60, 63),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    shadows: [
                      Shadow(
                        blurRadius: isUrgent ? 8 : 2,
                        color: isUrgent 
                            ? const Color.fromARGB(100, 255, 80, 80)
                            : const Color.fromARGB(61, 90, 90, 90),
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    '${widget.secondsLeft}',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class FloatingPrizeCard extends StatelessWidget {
  final Widget child;
  final int index;

  const FloatingPrizeCard({super.key, required this.child, this.index = 0});

  @override
  Widget build(BuildContext context) {
    // Floating animation removed - just return the child
    return child;
  }
}

// Animated prize card list that handles additions/removals with flair
class AnimatedPrizeCardRow extends StatelessWidget {
  final List<String> prizeCards;
  final bool isMobile;
  final bool isTablet;
  final bool isOpponent;
  final String? cardBackAsset;

  const AnimatedPrizeCardRow({
    super.key,
    required this.prizeCards,
    required this.isMobile,
    required this.isTablet,
    this.isOpponent = false,
    this.cardBackAsset,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        prizeCards.length,
        (index) => _AnimatedPrizeCardItem(
          key: ValueKey('prize_${isOpponent ? 'opp' : 'player'}_$index'),
          index: index,
          isMobile: isMobile,
          isTablet: isTablet,
          cardBackAsset: cardBackAsset,
        ),
      ),
    );
  }
}

class _AnimatedPrizeCardItem extends StatefulWidget {
  final int index;
  final bool isMobile;
  final bool isTablet;
  final String? cardBackAsset;

  const _AnimatedPrizeCardItem({
    super.key,
    required this.index,
    required this.isMobile,
    required this.isTablet,
    this.cardBackAsset,
  });

  @override
  State<_AnimatedPrizeCardItem> createState() => _AnimatedPrizeCardItemState();
}

class _AnimatedPrizeCardItemState extends State<_AnimatedPrizeCardItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.elasticOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    // Staggered entrance
    Future.delayed(Duration(milliseconds: widget.index * 80), () {
      if (mounted) {
        _entranceController.forward();
      }
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _entranceController,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: widget.isMobile ? 2.0 : 4.0,
              ),
              child: FloatingPrizeCard(
                index: widget.index,
                child: Container(
                  width: widget.isMobile ? 55 : (widget.isTablet ? 55 : 70),
                  height: widget.isMobile ? 77 : (widget.isTablet ? 77 : 98),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(2, 4),
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: CardWidget(
                    isCardBack: true,
                    cardBackAsset: widget.cardBackAsset ?? CardWidget.defaultCardBackAsset,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class AnimatedModifierCard extends StatefulWidget {
  final String modifierType;
  final String tooltip;
  final bool used;
  final VoidCallback? onTap;
  final bool isMobile;
  final bool isSmallPhone;
  final bool isSelected;
  final String? cardBackAsset;

  const AnimatedModifierCard({
    super.key,
    required this.modifierType,
    required this.tooltip,
    required this.used,
    this.onTap,
    required this.isMobile,
    this.isSmallPhone = false,
    this.isSelected = false,
    this.cardBackAsset,
  });

  @override
  State<AnimatedModifierCard> createState() => _AnimatedModifierCardState();
}

class _AnimatedModifierCardState extends State<AnimatedModifierCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _flipAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0, // This will be 180 degrees (π radians)
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    // Start the flip animation
    Future.delayed(Duration(milliseconds: 200), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  String _getModifierAssetPath(String modifier) {
    switch (modifier) {
      case 'rewind':
        return 'assets/images/rewindmod.png';
      case 'mulligan':
        return 'assets/images/mulliganmod.png';
      case 'draw1':
        return 'assets/images/draw1mod.png';
      case '-1':
        return 'assets/images/-1mod.png';
      case '-3':
        return 'assets/images/-3mod.png';
      case '-0.5':
        return 'assets/images/-halfmod.png';
      case '+1':
        return 'assets/images/+1mod.png';
      case '+3':
        return 'assets/images/+3mod.png';
      case '+11':
        return 'assets/images/+11mod.png';
      case '2x':
        return 'assets/images/2xmod.png';
      default:
        return 'assets/images/rewindmod.png'; // fallback
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _flipAnimation,
      builder: (context, child) {
        // Show modifier card when animation value > 0.5 (90 degrees)
        final isShowingFront = _flipAnimation.value > 0.5;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(
                _flipAnimation.value * pi), // Only π radians (180 degrees)
          child: isShowingFront ? _buildFrontCard() : _buildBackCard(),
        );
      },
    );
  }

  Widget _buildFrontCard() {
    // Apply the flip transform to show the modifier card correctly
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateY(pi),
      child: _buildModifierCard(),
    );
  }

  Widget _buildBackCard() {
    return Tooltip(
      message: "Modifier Card",
      child: Container(
        width: widget.isSmallPhone ? 40 : (widget.isMobile ? 50 : 60),
        height: widget.isSmallPhone ? 56 : (widget.isMobile ? 70 : 84),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color.fromARGB(100, 134, 158, 255),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(2, 4),
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.asset(
            widget.cardBackAsset ?? CardWidget.defaultCardBackAsset,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
      ),
    );
  }

  Widget _buildModifierCard() {
    bool isDisabled = widget.onTap == null;

    Color borderColor = widget.used
        ? Colors.grey[600]!
        : (widget.isSelected
            ? const Color.fromARGB(247, 0, 255, 229)
            : (isDisabled
                ? const Color.fromARGB(100, 134, 158, 255)
                : const Color.fromARGB(255, 134, 158, 255)));

    return Tooltip(
      message: widget.used ? '${widget.tooltip} (Used)' : widget.tooltip,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Opacity(
          opacity: widget.used ? 0.3 : (isDisabled ? 0.6 : 0.95),
          child: Container(
            width: widget.isSmallPhone ? 40 : (widget.isMobile ? 50 : 60),
            height: widget.isSmallPhone ? 56 : (widget.isMobile ? 70 : 84),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: borderColor,
                width: widget.isSelected ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(2, 4),
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: ColorFiltered(
                colorFilter: widget.used
                    ? const ColorFilter.matrix([
                        0.2126,
                        0.7152,
                        0.0722,
                        0,
                        0,
                        0.2126,
                        0.7152,
                        0.0722,
                        0,
                        0,
                        0.2126,
                        0.7152,
                        0.0722,
                        0,
                        0,
                        0,
                        0,
                        0,
                        1,
                        0,
                      ])
                    : (isDisabled
                        ? ColorFilter.mode(
                            Colors.grey.withOpacity(0.5),
                            BlendMode.srcATop,
                          )
                        : const ColorFilter.mode(
                            Colors.transparent,
                            BlendMode.multiply,
                          )),
                child: Image.asset(
                  _getModifierAssetPath(widget.modifierType),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Staggered game over overlay with smooth entrance animations
class _GameOverOverlay extends StatefulWidget {
  final String? winner;
  final bool isMobile;
  final bool waitingForRematch;
  final String gameMode;
  final VoidCallback onNextGame;
  final VoidCallback onLeaveRoom;

  const _GameOverOverlay({
    required this.winner,
    required this.isMobile,
    required this.waitingForRematch,
    required this.gameMode,
    required this.onNextGame,
    required this.onLeaveRoom,
  });

  @override
  State<_GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<_GameOverOverlay>
    with TickerProviderStateMixin {
  late AnimationController _backdropController;
  late AnimationController _iconController;
  late AnimationController _textController;
  late AnimationController _buttonController;

  late Animation<double> _backdropAnimation;
  late Animation<double> _iconScaleAnimation;
  late Animation<double> _iconOpacityAnimation;
  late Animation<Offset> _textSlideAnimation;
  late Animation<double> _textOpacityAnimation;
  late Animation<double> _buttonOpacityAnimation;
  late Animation<Offset> _buttonSlideAnimation;

  @override
  void initState() {
    super.initState();

    // Backdrop fade
    _backdropController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _backdropAnimation = Tween<double>(begin: 0.0, end: 0.75).animate(
      CurvedAnimation(parent: _backdropController, curve: Curves.easeOut),
    );

    // Icon scale with subtle bounce
    _iconController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _iconScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.elasticOut),
    );
    _iconOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _iconController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    // Text slide up with fade
    _textController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic));
    _textOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );

    // Button fade and slide
    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _buttonOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeOut),
    );
    _buttonSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _buttonController, curve: Curves.easeOutCubic));

    // Start staggered animation sequence
    _startAnimationSequence();
  }

  void _startAnimationSequence() async {
    _backdropController.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    _iconController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _textController.forward();
    await Future.delayed(const Duration(milliseconds: 150));
    _buttonController.forward();
  }

  @override
  void dispose() {
    _backdropController.dispose();
    _iconController.dispose();
    _textController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWin = widget.winner == 'player';
    final accentColor = isWin ? Colors.greenAccent : Colors.redAccent;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _backdropAnimation,
        _iconScaleAnimation,
        _textSlideAnimation,
        _buttonOpacityAnimation,
      ]),
      builder: (context, child) {
        return Container(
          color: Colors.black.withOpacity(_backdropAnimation.value),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated Icon
                    Opacity(
                      opacity: _iconOpacityAnimation.value,
                      child: Transform.scale(
                        scale: _iconScaleAnimation.value,
                        child: _LongPressGlowIcon(
                          icon: isWin ? Icons.diamond_sharp : Icons.heart_broken,
                          size: 120,
                          baseColor: accentColor,
                          baseBlurRadius: 16,
                          secondaryShadow: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Animated Text
                    SlideTransition(
                      position: _textSlideAnimation,
                      child: FadeTransition(
                        opacity: _textOpacityAnimation,
                        child: Text(
                          isWin ? 'Victory!' : 'Game Over!',
                          style: TextStyle(
                            color: accentColor,
                            fontFamily: 'Balatro',
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            shadows: [
                              Shadow(blurRadius: 12, color: accentColor),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: widget.isMobile ? 16 : 32),
                    // Animated Button
                    SlideTransition(
                      position: _buttonSlideAnimation,
                      child: FadeTransition(
                        opacity: _buttonOpacityAnimation,
                        child: _AnimatedPressButton(
                          waitingForRematch: widget.waitingForRematch,
                          onPressed: widget.waitingForRematch ? null : widget.onNextGame,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Animated press button with micro-interaction
class _AnimatedPressButton extends StatefulWidget {
  final bool waitingForRematch;
  final VoidCallback? onPressed;

  const _AnimatedPressButton({
    required this.waitingForRematch,
    this.onPressed,
  });

  @override
  State<_AnimatedPressButton> createState() => _AnimatedPressButtonState();
}

class _AnimatedPressButtonState extends State<_AnimatedPressButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed != null) {
      setState(() => _isPressed = true);
      _pressController.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (_isPressed) {
      _pressController.reverse();
      setState(() => _isPressed = false);
    }
  }

  void _handleTapCancel() {
    if (_isPressed) {
      _pressController.reverse();
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.waitingForRematch
                    ? Colors.grey[700]
                    : const Color.fromARGB(255, 77, 104, 255),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color.fromARGB(240, 97, 97, 97),
                disabledForegroundColor: const Color.fromARGB(255, 230, 230, 230),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                elevation: _isPressed ? 2 : 6,
              ),
              onPressed: widget.onPressed,
              child: Text(
                widget.waitingForRematch ? 'Waiting for opponent...' : 'Next Game',
                style: const TextStyle(
                  fontFamily: 'Balatro',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Turn indicator with subtle pulsing glow
class _TurnIndicatorContainer extends StatefulWidget {
  final bool isPlayerTurn;
  final Widget child;

  const _TurnIndicatorContainer({
    required this.isPlayerTurn,
    required this.child,
  });

  @override
  State<_TurnIndicatorContainer> createState() => _TurnIndicatorContainerState();
}

class _TurnIndicatorContainerState extends State<_TurnIndicatorContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    
    if (widget.isPlayerTurn) {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_TurnIndicatorContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlayerTurn && !oldWidget.isPlayerTurn) {
      // Just became player's turn - start glow
      _glowController.forward(from: 0.0);
      _glowController.repeat(reverse: true);
    } else if (!widget.isPlayerTurn && oldWidget.isPlayerTurn) {
      // No longer player's turn - fade out
      _glowController.stop();
      _glowController.reverse();
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        final glowOpacity = widget.isPlayerTurn ? 0.04 + (_glowAnimation.value * 0.08) : 0.0;
        final blurRadius = widget.isPlayerTurn ? 16 + (_glowAnimation.value * 12) : 0.0;
        
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: widget.isPlayerTurn
                ? [
                    BoxShadow(
                      color: const Color.fromARGB(255, 100, 180, 255)
                          .withOpacity(glowOpacity),
                      blurRadius: blurRadius,
                      spreadRadius: 2 + (_glowAnimation.value * 4),
                    ),
                  ]
                : null,
          ),
          child: widget.child,
        );
      },
    );
  }
}

// Animated play button with press effect
class _PlayButton extends StatefulWidget {
  final bool canPlay;
  final VoidCallback? onPressed;
  final bool isMobile;
  final bool isTablet;
  final bool isSmallPhone;

  const _PlayButton({
    required this.canPlay,
    this.onPressed,
    required this.isMobile,
    required this.isTablet,
    this.isSmallPhone = false,
  });

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _glowAnimation = Tween<double>(begin: 8.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.canPlay) {
      setState(() => _isPressed = true);
      _controller.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (_isPressed) {
      _controller.reverse();
      setState(() => _isPressed = false);
    }
  }

  void _handleTapCancel() {
    if (_isPressed) {
      _controller.reverse();
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: widget.canPlay
                    ? [
                        BoxShadow(
                          color: const Color.fromARGB(255, 123, 207, 255)
                              .withOpacity(_isPressed ? 0.3 : 0.6),
                          blurRadius: _glowAnimation.value,
                          spreadRadius: _isPressed ? 0 : 2,
                        ),
                      ]
                    : null,
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.canPlay
                      ? const Color.fromARGB(30, 100, 180, 255)
                      : const Color.fromARGB(5, 194, 194, 194),
                  shape: const CircleBorder(),
                  padding: EdgeInsets.all(widget.isSmallPhone ? 8 : (widget.isMobile ? 12 : 18)),
                  elevation: _isPressed ? 2 : 8,
                  shadowColor: const Color.fromARGB(255, 123, 207, 255),
                ),
                onPressed: widget.onPressed,
                child: Text(
  '=',
  textAlign: TextAlign.center,
  style: TextStyle(
    fontFamily: 'Balatro',
    fontSize: widget.isSmallPhone ? 28 : (widget.isMobile ? 42 : (widget.isTablet ? 28 : 34)),
    color: widget.canPlay
        ? const Color.fromARGB(255, 237, 227, 240)
        : const Color.fromARGB(100, 237, 227, 240),
    fontWeight: FontWeight.bold,
    height: 1.0,  // Add this to remove extra line height
    shadows: [
      Shadow(
        blurRadius: widget.canPlay ? 8 : 4,
        color: widget.canPlay
            ? const Color.fromARGB(222, 219, 242, 255)
            : const Color.fromARGB(100, 219, 242, 255),
        offset: const Offset(0, 0),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Searching animation for quick match
class _SearchingAnimation extends StatefulWidget {
  const _SearchingAnimation();

  @override
  State<_SearchingAnimation> createState() => _SearchingAnimationState();
}

class _SearchingAnimationState extends State<_SearchingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _rotationAnimation = Tween<double>(begin: 0, end: 2 * pi).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer rotating ring
              Transform.rotate(
                angle: _rotationAnimation.value,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color.fromARGB(255, 0, 188, 212).withOpacity(0.3),
                      width: 3,
                    ),
                  ),
                  child: CustomPaint(
                    painter: _SearchArcPainter(
                      progress: _rotationAnimation.value / (2 * pi),
                    ),
                  ),
                ),
              ),
              // Center icon with pulse
              Transform.scale(
                scale: _pulseAnimation.value,
                child: const Icon(
                  Icons.flash_on,
                  size: 32,
                  color: Color.fromARGB(255, 0, 188, 212),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Shine animation that plays when a prize card is won
class _PrizeWinShine extends StatefulWidget {
  final double width;
  final double height;

  const _PrizeWinShine({
    required this.width,
    required this.height,
  });

  @override
  State<_PrizeWinShine> createState() => _PrizeWinShineState();
}

class _PrizeWinShineState extends State<_PrizeWinShine>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shinePosition;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 750), // Slightly slower for visibility
      vsync: this,
    );

    _shinePosition = Tween<double>(begin: -0.5, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: CustomPaint(
              painter: _ShinePainter(position: _shinePosition.value),
            ),
          ),
        );
      },
    );
  }
}

class _ShinePainter extends CustomPainter {
  final double position;

  _ShinePainter({required this.position});

  @override
  void paint(Canvas canvas, Size size) {
    final shineWidth = size.width * 0.6; // Wider shine
    final shineCenter = size.width * position;

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.transparent,
          Colors.white.withOpacity(0.1),
          Colors.white.withOpacity(0.8),  // Brighter
          Colors.yellow.withOpacity(0.6), // More golden
          Colors.white.withOpacity(0.8),  // Brighter
          Colors.white.withOpacity(0.1),
          Colors.transparent,
        ],
        stops: const [0.0, 0.15, 0.4, 0.5, 0.6, 0.85, 1.0],
      ).createShader(Rect.fromLTWH(
        shineCenter - shineWidth / 2,
        0,
        shineWidth,
        size.height,
      ));

    // Draw the shine as a rotated rectangle
    canvas.save();
    canvas.translate(shineCenter, size.height / 2);
    canvas.rotate(-0.3); // Slight angle for the shine
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset.zero,
        width: shineWidth,
        height: size.height * 1.8, // Taller to cover full card
      ),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ShinePainter oldDelegate) =>
      oldDelegate.position != position;
}

// Dark shine animation that plays when opponent wins a prize (doubles/halves successfully)
class _OpponentWinShine extends StatefulWidget {
  final double width;
  final double height;

  const _OpponentWinShine({
    required this.width,
    required this.height,
  });

  @override
  State<_OpponentWinShine> createState() => _OpponentWinShineState();
}

class _OpponentWinShineState extends State<_OpponentWinShine>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shinePosition;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 675), // 10% faster than player shine
      vsync: this,
    );

    _shinePosition = Tween<double>(begin: -0.5, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: CustomPaint(
              painter: _OpponentShinePainter(position: _shinePosition.value),
            ),
          ),
        );
      },
    );
  }
}

class _OpponentShinePainter extends CustomPainter {
  final double position;

  _OpponentShinePainter({required this.position});

  @override
  void paint(Canvas canvas, Size size) {
    final shineWidth = size.width * 0.6;
    final shineCenter = size.width * position;

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.transparent,
          Colors.grey.shade800.withOpacity(0.2),
          Colors.grey.shade600.withOpacity(0.7),
          Colors.grey.shade400.withOpacity(0.5), // Dark grey center
          Colors.grey.shade600.withOpacity(0.7),
          Colors.grey.shade800.withOpacity(0.2),
          Colors.transparent,
        ],
        stops: const [0.0, 0.15, 0.4, 0.5, 0.6, 0.85, 1.0],
      ).createShader(Rect.fromLTWH(
        shineCenter - shineWidth / 2,
        0,
        shineWidth,
        size.height,
      ));

    // Draw the shine as a rotated rectangle
    canvas.save();
    canvas.translate(shineCenter, size.height / 2);
    canvas.rotate(-0.3);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset.zero,
        width: shineWidth,
        height: size.height * 1.8,
      ),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OpponentShinePainter oldDelegate) =>
      oldDelegate.position != position;
}

class _SearchArcPainter extends CustomPainter {
  final double progress;

  _SearchArcPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color.fromARGB(255, 0, 188, 212)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.width / 2 - 2,
    );

    // Draw arc that represents searching progress
    canvas.drawArc(rect, -pi / 2, pi * 0.7, false, paint);
  }

  @override
  bool shouldRepaint(covariant _SearchArcPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// Pixelated 8-bit splash animation
class _CardSplashEffect extends StatefulWidget {
  final double width;
  final double height;

  const _CardSplashEffect({
    required this.width,
    required this.height,
  });

  @override
  State<_CardSplashEffect> createState() => _CardSplashEffectState();
}

class _CardSplashEffectState extends State<_CardSplashEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.3, end: 1.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: CustomPaint(
            size: Size(widget.width * 2, widget.height * 2),
            painter: _PixelSplashPainter(
              progress: _scaleAnimation.value,
            ),
          ),
        );
      },
    );
  }
}

// Custom painter for pixelated 8-bit splash
class _PixelSplashPainter extends CustomPainter {
  final double progress;

  _PixelSplashPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final pixelSize = 8.0; // Size of each "pixel" block
    final maxRadius = size.width * 0.4 * progress;
    
    // Create pixelated rings
    final colors = [
      const Color.fromARGB(255, 255, 255, 255),
      const Color.fromARGB(255, 100, 180, 255),
      const Color.fromARGB(255, 64, 150, 255),
      const Color.fromARGB(255, 40, 120, 230),
    ];

    // Draw 4 expanding pixelated rings
    for (int ring = 0; ring < 4; ring++) {
      final ringRadius = maxRadius * (0.4 + ring * 0.2);
      final ringColor = colors[ring % colors.length];
      
      // Calculate number of pixels around the ring
      final circumference = 2 * pi * ringRadius;
      final pixelCount = (circumference / (pixelSize * 1.5)).floor();
      
      for (int i = 0; i < pixelCount; i++) {
        final angle = (i / pixelCount) * 2 * pi;
        final x = center.dx + ringRadius * cos(angle);
        final y = center.dy + ringRadius * sin(angle);
        
        // Add some randomness to make it more 8-bit style
        final offset = (i % 3 == 0) ? pixelSize * 0.3 : 0.0;
        
        final paint = Paint()
          ..color = ringColor.withOpacity(1.0 - progress * 0.5)
          ..style = PaintingStyle.fill;
        
        // Draw square "pixels"
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(x + offset, y),
            width: pixelSize,
            height: pixelSize,
          ),
          paint,
        );
      }
    }
    
    // Add central bright pixel cluster
    final centralPixels = [
      Offset(0, 0),
      Offset(-pixelSize, 0),
      Offset(pixelSize, 0),
      Offset(0, -pixelSize),
      Offset(0, pixelSize),
      Offset(-pixelSize, -pixelSize),
      Offset(pixelSize, -pixelSize),
      Offset(-pixelSize, pixelSize),
      Offset(pixelSize, pixelSize),
    ];
    
    final centralPaint = Paint()
      ..color = Colors.white.withOpacity((1.0 - progress) * 0.8)
      ..style = PaintingStyle.fill;
    
    for (var offset in centralPixels) {
      canvas.drawRect(
        Rect.fromCenter(
          center: center + offset,
          width: pixelSize,
          height: pixelSize,
        ),
        centralPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PixelSplashPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _PaperTimerPainter extends CustomPainter {
  final int secondsLeft;
  final int totalSeconds;
  final bool isUrgent;

  _PaperTimerPainter({
    required this.secondsLeft,
    required this.totalSeconds,
    this.isUrgent = false,
  });


  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isUrgent 
          ? const Color.fromARGB(120, 200, 60, 60)
          : const Color.fromARGB(47, 67, 67, 71)
      ..strokeWidth = isUrgent ? 5 : 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    double progress = (totalSeconds - secondsLeft) / totalSeconds;
    double sweepAngle = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(
        center: size.center(Offset.zero),
        radius: size.width / 2 - 8,
      ),
      -pi / 2,
      sweepAngle,
      false,
      paint,
    );
  }


  @override
  bool shouldRepaint(covariant _PaperTimerPainter oldDelegate) => 
      oldDelegate.secondsLeft != secondsLeft || 
      oldDelegate.isUrgent != isUrgent;
}

// Generic icon that glows brighter when long-pressed
class _LongPressGlowIcon extends StatefulWidget {
  final IconData icon;
  final double size;
  final Color baseColor;
  final double baseBlurRadius;
  final bool secondaryShadow;

  const _LongPressGlowIcon({
    required this.icon,
    required this.size,
    required this.baseColor,
    this.baseBlurRadius = 12,
    this.secondaryShadow = false,
  });

  @override
  State<_LongPressGlowIcon> createState() => _LongPressGlowIconState();
}

class _LongPressGlowIconState extends State<_LongPressGlowIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _luminosityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      reverseDuration: const Duration(milliseconds: 220),
      vsync: this,
    );

    _luminosityAnimation = Tween<double>(begin: 0.0, end: 0.4).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onLongPressStart(LongPressStartDetails details) {
    _controller.forward();
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    _controller.reverse();
  }

  Color _adjustLuminosity(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final newLightness = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(newLightness).toColor();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: _onLongPressStart,
      onLongPressEnd: _onLongPressEnd,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final glowColor = _adjustLuminosity(widget.baseColor, _luminosityAnimation.value);
          final List<Shadow> shadows = [
            Shadow(
              blurRadius: widget.baseBlurRadius + (_luminosityAnimation.value * 20),
              color: glowColor.withOpacity(0.8),
            ),
          ];
          if (widget.secondaryShadow) {
            shadows.add(Shadow(
              blurRadius: (widget.baseBlurRadius * 2) + (_luminosityAnimation.value * 30),
              color: glowColor.withOpacity(0.5),
            ));
          }
          return Icon(
            widget.icon,
            size: widget.size,
            color: glowColor,
            shadows: shadows,
          );
        },
      ),
    );
  }
}

/// A text widget that animates like it's being quickly typed out
class _TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final Duration characterDuration;

  const _TypewriterText({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.left,
    this.characterDuration = const Duration(milliseconds: 25),
  });

  @override
  State<_TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<_TypewriterText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  String _displayedText = '';
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.characterDuration,
    );
    _startTyping();
  }

  @override
  void didUpdateWidget(_TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      // New text - reset and start typing again
      _currentIndex = 0;
      _displayedText = '';
      _startTyping();
    }
  }

  void _startTyping() {
    if (_currentIndex < widget.text.length) {
      Future.delayed(widget.characterDuration, () {
        if (mounted && _currentIndex < widget.text.length) {
          setState(() {
            _currentIndex++;
            _displayedText = widget.text.substring(0, _currentIndex);
          });
          _startTyping();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _displayedText,
      style: widget.style,
      textAlign: widget.textAlign,
    );
  }
}
