import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'package:flutter_markdown/flutter_markdown.dart' as md;
import 'package:markdown/markdown.dart' show ExtensionSet, markdownToHtml;
// ADD THIS DIRECTLY UNDER THE LAST import line
import 'package:http/http.dart' as http;

// II. Constants & Configuration
const List<String> _apiKeys = [
  "AIzaSyAH7hEUdCKg4Xz9DY2o7L5rKUTzKeGgZTo",
  "AIzaSyC-poPHj48tXFB-iGm3AU4a1LZZrybceBI",
  "AIzaSyBXsVo7_UV1kQldbyK1Wac0Pg93hO_YbxQ",
  "AIzaSyCMG09YASV3mMzA1L5xkCpHg3YnxF1Q-YY",
  "AIzaSyBFudpCvW3o8kfgNMHD51W_8LBI-CHfeHw",
  "AIzaSyDlGuX-YvSbAVCJnqCon9_rKyoTHcj2AEM",
  "AIzaSyCjlP5geVvYO0z0uhi9mfHfPSpiaGoaCxc",
  "AIzaSyAYMn009A9cEGr7mwLvub8z2TG-wAIcOQw",
  "AIzaSyB_Ot1o-jRM-ud6rUFUY8dvHrcPySBEuRE",
  "AIzaSyCY8hTigQge9ko0lvlFuyGyd_bTZHHMfUo",
  "AIzaSyActDl-A58V1RzfGGnpuG6qvxp2ctNs67k",
  "AIzaSyBZ2zebFHAoyvXRN7Fv2lgANtfookqz3qE",
  "AIzaSyB6PHVfM8t1PT_RfXB_wWz4C8CzXodmkH0",
  "AIzaSyA0J91k0wRcSNkdx5qWSHw3lcwzBfagOcU",
  "AIzaSyBL9GWrEAhhPXx1OA10DfjvaYZoZyUCnyI",
];

const String _geminiProModel = "models/gemini-2.5-flash";
const String _googleApiBaseUrl =
    "https://generativelanguage.googleapis.com/v1beta/";
const String _aiStudioUrl = "https://aistudio.google.com/app/apikey";
const String _supportWhatsAppNumber = "256775306245";
const List<String> _validRecipientNumbers = ["0775306245", "0750122999"];
const String _backdoorCode = "FrostMournsBeyondWall#13";
const int _backdoorCredits = 150;
const int _manualCodeValidityMinutes = 6;
const Map<int, int> _paymentTiers = {5000: 500, 10000: 1200, 50000: 5500};
const int MAX_IMAGE_DIMENSION = 2048;
const int JPEG_QUALITY = 80;
const int API_TIMEOUT_SECONDS = 420;
const int MIN_BATCH_SIZE_FOR_SPLIT = 1;
const int MONDAY_CREDIT_BONUS = 10;
const int DOWNLOAD_SERVER_TIMEOUT_SECONDS = 120;
const int GRADING_BATCH_SIZE = 10;
const double GRADING_TEMPERATURE = 0.0;
const int GRADING_FEEDBACK_DETAIL = 5;
final DateTime _freePeriodEndDate = DateTime(2026, 8, 31, 23, 59, 59);

enum ToastType { success, error, warning, info }

enum GradingMode { text, images }

class StudentSubmission {
  String name;
  List<String> imagePaths;
  StudentSubmission({required this.name, required this.imagePaths});
  Map<String, dynamic> toJson() => {
        'name': name,
        'imagePaths': imagePaths,
      };
  factory StudentSubmission.fromJson(Map<String, dynamic> json) =>
      StudentSubmission(
        name: json['name'] ?? 'Unknown Student',
        imagePaths: List<String>.from(json['imagePaths'] ?? []),
      );
}

class GradeResult {
  String name;
  int? marks_obtained;
  int? marks_possible;
  String feedback;
  int attempts;
  String status;
  List<Map<String, dynamic>> marksBreakdown;
  int imageCount;

  int? get score {
    if (marks_obtained != null &&
        marks_possible != null &&
        marks_possible! > 0) {
      return ((marks_obtained! / marks_possible!) * 100).round();
    }
    if (marks_obtained == null &&
        marks_possible == null &&
        _legacyScore != null) {
      return _legacyScore;
    }
    return null;
  }

  int? _legacyScore;
  GradeResult({
    required this.name,
    this.marks_obtained,
    this.marks_possible,
    required this.feedback,
    this.attempts = 1,
    required this.status,
    int? legacyScore,
    this.marksBreakdown = const [],
    this.imageCount = 0,
  }) : _legacyScore = legacyScore;
  Map<String, dynamic> toJson() => {
        'name': name,
        'score': score,
        'marks_obtained': marks_obtained,
        'marks_possible': marks_possible,
        'feedback': feedback,
        'attempts': attempts,
        'status': status,
        'marksBreakdown': marksBreakdown,
        'imageCount': imageCount,
      };
  factory GradeResult.fromJson(Map<String, dynamic> json) {
    return GradeResult(
      name: json['name'] ?? 'Unknown Student',
      marks_obtained: json['marks_obtained'],
      marks_possible: json['marks_possible'],
      feedback: json['feedback'] ?? '',
      attempts: json['attempts'] ?? 1,
      status: json['status'] ?? 'failed_processing',
      legacyScore: json['score'],
      marksBreakdown:
          List<Map<String, dynamic>>.from(json['marksBreakdown'] ?? []),
      imageCount: json['imageCount'] ?? 0,
    );
  }
}

class ThemeNotifier extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;
  ThemeNotifier() {
    _loadThemePreference();
  }
  void _loadThemePreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isDarkMode = prefs.getBool('dark_mode') ?? false;
    _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void toggleTheme() async {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', _themeMode == ThemeMode.dark);
    notifyListeners();
  }
}

final ThemeNotifier _themeNotifier = ThemeNotifier();

class ChangeNotifierProvider<T extends ChangeNotifier>
    extends InheritedNotifier<T> {
  const ChangeNotifierProvider({
    Key? key,
    required T notifierInstance,
    required Widget child,
  }) : super(key: key, notifier: notifierInstance, child: child);
  static T of<T extends ChangeNotifier>(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<ChangeNotifierProvider<T>>();
    assert(provider != null, 'No ChangeNotifierProvider<$T> found in context.');
    return provider!.notifier!;
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider<ThemeNotifier>(
      notifierInstance: _themeNotifier,
      child: const AIGraderApp(),
    ),
  );
}

class AIGraderApp extends StatelessWidget {
  const AIGraderApp({super.key});
  @override
  Widget build(BuildContext context) {
    final themeNotifier = ChangeNotifierProvider.of<ThemeNotifier>(context);
    const Color iconPrimaryTeal = Color(0xFF5F9EA0);
    const Color iconLightBlueAccent = Color(0xFFA8D8E0);
    const Color iconOffWhite = Color(0xFFF5F5F5);
    const Color iconDarkGrey = Color(0xFF36454F);
    const Color iconRedAccent = Color(0xFFD32F2F);
    final ThemeData lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: iconPrimaryTeal,
        brightness: Brightness.light,
        primary: iconPrimaryTeal,
        onPrimary: Colors.white,
        secondary: iconLightBlueAccent,
        onSecondary: iconDarkGrey,
        error: iconRedAccent,
        onError: Colors.white,
        background: iconOffWhite,
        onBackground: iconDarkGrey,
        surface: Colors.white,
        onSurface: iconDarkGrey,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: iconPrimaryTeal,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: iconPrimaryTeal,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: iconPrimaryTeal.withOpacity(0.7)),
          foregroundColor: iconPrimaryTeal,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: iconPrimaryTeal, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.grey.shade50.withOpacity(0.5),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: iconPrimaryTeal,
        inactiveTrackColor: iconPrimaryTeal.withOpacity(0.3),
        thumbColor: iconPrimaryTeal,
        overlayColor: iconPrimaryTeal.withOpacity(0.2),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: iconPrimaryTeal.withOpacity(0.15),
        labelStyle: TextStyle(
            color: iconPrimaryTeal
                .withBlue(iconPrimaryTeal.blue - 20)
                .withGreen(iconPrimaryTeal.green - 20)),
        iconTheme: IconThemeData(
            color: iconPrimaryTeal
                .withBlue(iconPrimaryTeal.blue - 20)
                .withGreen(iconPrimaryTeal.green - 20)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide.none,
      ),
      textTheme: const TextTheme().copyWith(
        titleLarge: const TextTheme().titleLarge?.copyWith(
              color: iconPrimaryTeal,
            ),
      ),
    );
    const Color iconDarkPrimary = Color(0xFF4A7C85);
    const Color iconDarkSurface = Color(0xFF2D3A40);
    const Color iconDarkOnSurface = Color(0xFFE0E0E0);
    final ThemeData darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: iconDarkPrimary,
        brightness: Brightness.dark,
        primary: iconDarkPrimary,
        onPrimary: iconDarkOnSurface,
        secondary: iconLightBlueAccent.withOpacity(0.8),
        onSecondary: iconDarkSurface,
        error: Colors.redAccent.shade100,
        onError: iconDarkSurface,
        background: const Color(0xFF1E2A32),
        onBackground: iconDarkOnSurface,
        surface: iconDarkSurface,
        onSurface: iconDarkOnSurface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: iconDarkSurface,
        foregroundColor: iconDarkOnSurface,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: iconDarkSurface
            .withGreen(iconDarkSurface.green + 5)
            .withBlue(iconDarkSurface.blue + 5),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: iconLightBlueAccent.withOpacity(0.8),
          foregroundColor: iconDarkSurface,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: iconLightBlueAccent.withOpacity(0.7)),
          foregroundColor: iconLightBlueAccent.withOpacity(0.9),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide:
              BorderSide(color: iconLightBlueAccent.withOpacity(0.8), width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.grey.shade800.withOpacity(0.5),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: iconLightBlueAccent.withOpacity(0.8),
        inactiveTrackColor: iconLightBlueAccent.withOpacity(0.3),
        thumbColor: iconLightBlueAccent.withOpacity(0.9),
        overlayColor: iconLightBlueAccent.withOpacity(0.2),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: iconDarkPrimary.withOpacity(0.3),
        labelStyle: TextStyle(color: iconDarkOnSurface.withOpacity(0.9)),
        iconTheme: IconThemeData(color: iconDarkOnSurface.withOpacity(0.9)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide.none,
      ),
      textTheme: const TextTheme().copyWith(
        titleLarge: const TextTheme().titleLarge?.copyWith(
              color: iconLightBlueAccent.withOpacity(0.9),
            ),
      ),
    );
    return MaterialApp(
      title: 'AI Grader',
      themeMode: themeNotifier.themeMode,
      theme: lightTheme,
      darkTheme: darkTheme,
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ADD THIS RIGHT BEFORE  class MainScreen extends StatefulWidget {
Future<void> _sendReport({
  required String reportType,
  required String contextIdentifier,
  required String content,
}) async {
  try {
    await http.post(
      Uri.parse(
          'https://script.google.com/macros/s/AKfycbzeMKyx1CPOYVLAyytARedNbjNqPyH6QNvZyz3b9zu1kT7Lp3dgqxFxOJXmrEAN8-NfzQ/exec'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'reportType': reportType,
        'contextIdentifier': contextIdentifier,
        'content': content,
      }),
    );
  } catch (_) {}
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class LocalFileServer {
  HttpServer? _server;
  Timer? _stopTimer;
  File? _fileToServe;
  String? _fileName;
  String? _mimeType;

  Future<String?> start(File fileToServe, String fileName, String mimeType,
      {required VoidCallback onTimeout}) async {
    await stop();
    _fileToServe = fileToServe;
    _fileName = fileName;
    _mimeType = mimeType;

    final router = shelf_router.Router();
    router.get('/download', _downloadHandler);

    try {
      _server = await shelf_io.serve(router, InternetAddress.anyIPv4, 0);
      developer
          .log('Local server started at http://localhost:${_server!.port}');

      _stopTimer =
          Timer(const Duration(seconds: DOWNLOAD_SERVER_TIMEOUT_SECONDS), () {
        developer.log('Download server timed out. Stopping.');
        stop();
        onTimeout();
      });

      return 'http://localhost:${_server!.port}/download';
    } catch (e) {
      developer.log('Error starting local server: $e');
      return null;
    }
  }

  Future<void> stop() async {
    _stopTimer?.cancel();
    _stopTimer = null;
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
      developer.log('Local server stopped.');
    }
  }

  shelf.Response _downloadHandler(shelf.Request request) {
    if (_fileToServe == null || !_fileToServe!.existsSync()) {
      return shelf.Response.notFound('File not found');
    }

    return shelf.Response.ok(
      _fileToServe!.openRead(),
      headers: {
        'Content-Type': _mimeType!,
        'Content-Disposition': 'attachment; filename="${_fileName!}"',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET',
        'Access-Control-Expose-Headers': 'Content-Disposition'
      },
    );
  }
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  final LocalFileServer _localFileServer = LocalFileServer();
  int _currentApiKeyIndex = 0;
  bool _isDownloadServerActive = false;
  int _remainingImageCredits = 0;
  GradingMode _gradingMode = GradingMode.images;
  List<String> _solutionGuideImagePaths = [];
  String? _solutionText;
  String? _solutionTextError;
  List<String> _questionPaperImagePaths = [];
  String? _generatedSolutionGuide;
  String? _guideGenerationError;
  bool _guideGenerationRecitationError = false;
  List<StudentSubmission> _submissions = [];
  List<GradeResult> _gradeResults = [];
  bool _isGrading = false;
  bool _isProcessingReference = false;
  String _processingReferenceMessage = "";
  bool _isCancellationRequested = false;
  String _gradingStatusMessage = "";
  String? _resultError;
  bool _isVerifyingPayment = false;
  String _paymentVerificationStatus = "";
  bool _isManualMode = false;
  final _manualNameController = TextEditingController();
  final _manualNameFocusNode = FocusNode();
  List<String> _manualImages = [];
  bool _isAddingStudent = false;
  bool isProcessingExcel = false;
  String? _toastMessage;
  ToastType? _toastType;
  Timer? _toastTimer;
  bool _isFreePeriodActive = false;
  late String _studentsJsonPath;
  late String _gradesJsonPath;
  late String _solutionExtractedTextPath;
  late String _solutionImagesJsonPath;
  late String _questionPaperImagesJsonPath;
  late String _generatedSolutionGuideTextPath;
  late String _gradingReferenceDataPath;
  final ImagePicker _imagePicker = ImagePicker();
  Set<String> _usedTransactionIds = {}; // Use a Set for efficient lookups
  final String _usedTxnIdsKey = 'usedTransactionIds';

  int _totalStudentsToGrade = 0;
  int _studentsGradedSoFar = 0;
  Map<String, dynamic>? _gradingReferenceData;

  // State variables for responsive image processing
  int _solutionGuideProcessingCount = 0;
  int _questionPaperProcessingCount = 0;
  int _manualImageProcessingCount = 0;
  int _batchImageProcessingCount = 0;

  List<String> _batchImages = [];
  final _batchNameController = TextEditingController();
  final _batchNameFocusNode = FocusNode();
  bool _resultsReversed = false; // <-- ADD THIS LINE

  Timer? _keepAwakeTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePathsAndLoadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _localFileServer.stop();
    _manualNameController.dispose();
    _manualNameFocusNode.dispose();
    _batchNameController.dispose();
    _batchNameFocusNode.dispose();
    _toastTimer?.cancel();
    _stopKeepAwakeTimer();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && _isDownloadServerActive) {
      _localFileServer.stop();
      if (mounted) setState(() => _isDownloadServerActive = false);
    }
  }

  void _startKeepAwakeTimer() {
    _keepAwakeTimer?.cancel();
    _keepAwakeTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      developer.log("Keep-awake timer tick...");
    });
    developer.log("Keep-awake timer started.");
  }

  void _stopKeepAwakeTimer() {
    _keepAwakeTimer?.cancel();
    _keepAwakeTimer = null;
    developer.log("Keep-awake timer stopped.");
  }

  Future<void> _initializePathsAndLoadData() async {
    setState(() {
      _isFreePeriodActive = DateTime.now().isBefore(_freePeriodEndDate);
    });
    final docDir = await getApplicationDocumentsDirectory();
    _studentsJsonPath = '${docDir.path}/students.json';
    _gradesJsonPath = '${docDir.path}/grades.json';
    _solutionExtractedTextPath = '${docDir.path}/solution_extracted.txt';
    _solutionImagesJsonPath = '${docDir.path}/solution_images.json';
    _questionPaperImagesJsonPath = '${docDir.path}/question_paper_images.json';
    _generatedSolutionGuideTextPath =
        '${docDir.path}/generated_solution_guide.txt';
    _gradingReferenceDataPath = '${docDir.path}/grading_reference_data.json';
    await _loadUsedTransactionIds();
    await _loadApiKeyIndex();
    await _loadCredits();
    if (!_isFreePeriodActive) await _checkForMondayCredits();
    await _loadGradingSettings();
    await _loadSolutionGuide();
    await _loadQuestionPaper();
    await _loadGradingReferenceData();
    await _loadSubmissions();
    await _loadGradeResults();

    if (mounted) {
      setState(() {
        _totalStudentsToGrade = _submissions.length;
      });
    }

    if (mounted) setState(() {});
  }

  Future<void> _loadUsedTransactionIds() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> idList = prefs.getStringList(_usedTxnIdsKey) ?? [];
    setState(() {
      _usedTransactionIds = idList.toSet();
    });
    developer.log("Loaded ${_usedTransactionIds.length} used transaction IDs.");
  }

  Future<void> _saveUsedTransactionId(String transactionId) async {
    if (transactionId.isEmpty) return;

    setState(() {
      _usedTransactionIds.add(transactionId);
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_usedTxnIdsKey, _usedTransactionIds.toList());
    developer.log(
        "Saved new transaction ID. Total count: ${_usedTransactionIds.length}");
  }

  Future<void> _loadApiKeyIndex() async {
    final prefs = await SharedPreferences.getInstance();
    _currentApiKeyIndex = prefs.getInt('currentApiKeyIndex') ?? 0;
    if (_currentApiKeyIndex >= _apiKeys.length) {
      _currentApiKeyIndex = 0;
    }
    developer.log("Loaded API Key Index: $_currentApiKeyIndex");
    if (mounted) setState(() {});
  }

  Future<void> _saveCurrentApiKeyIndex(int lastUsedIndex) async {
    final nextIndex = (lastUsedIndex + 1) % _apiKeys.length;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('currentApiKeyIndex', nextIndex);
    developer.log(
        "Saved NEXT API Key Index: $nextIndex (last used: $lastUsedIndex)");
  }

  Future<void> _startDownload({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    try {
      final directory = await getTemporaryDirectory();
      final filePath = path.join(directory.path, fileName);
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);

      final url =
          await _localFileServer.start(file, fileName, mimeType, onTimeout: () {
        if (mounted) setState(() => _isDownloadServerActive = false);
      });

      if (url != null) {
        if (mounted) setState(() => _isDownloadServerActive = true);
        await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      _showToast("Could not start download", ToastType.error);
    }
  }

  void _showViewTextDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Expanded(child: Text(title)),
            IconButton(
              icon: const Icon(Icons.flag_outlined, color: Colors.redAccent),
              tooltip: 'Report this guide',
              onPressed: () {
                _sendReport(
                  reportType: 'inaccurate_guide',
                  contextIdentifier:
                      title, // "Extracted Solution Guide" or "Generated Solution Guide"
                  content: content,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Guide flagged – thank you!')),
                );
                Navigator.of(dialogContext).pop(); // close popup after report
              },
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.6,
          child: SingleChildScrollView(
            child: md.MarkdownBody(
              data: content,
              selectable: true,
              extensionSet: ExtensionSet.gitHubWeb,
            ),
          ),
        ),
        actions: <Widget>[
          ElevatedButton.icon(
            icon: const Icon(Icons.file_download_outlined),
            label: const Text("Download as HTML"),
            onPressed: _isDownloadServerActive
                ? null
                : () async {
                    String htmlContent = markdownToHtml(
                      content,
                      extensionSet: ExtensionSet.gitHubWeb,
                    );
                    String cleanTitle = "Solution Guide";
                    String fullHtml = """
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${htmlEscape.convert(cleanTitle)}</title>
  <style>body { font-family: sans-serif; padding: 1.5em; line-height: 1.6; } code { background-color: #f0f0f0; padding: 2px 4px; border-radius: 3px; }</style>
</head>
<body>
  $htmlContent
</body>
</html>
""";
                    final Uint8List htmlBytes =
                        Uint8List.fromList(utf8.encode(fullHtml));
                    await _startDownload(
                      bytes: htmlBytes,
                      fileName: "${cleanTitle.replaceAll(' ', '_')}.html",
                      mimeType: "text/html",
                    );
                    if (mounted) Navigator.of(dialogContext).pop();
                  },
          ),
          TextButton(
            child: const Text("Close"),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadResultsExcel() async {
    if (_gradeResults.isEmpty) {
      _showToast("No results to download.", ToastType.info);
      return;
    }
    if (_isDownloadServerActive) {
      _showToast("Another download is already in progress.", ToastType.warning);
      return;
    }
    if (mounted) setState(() => isProcessingExcel = true);

    try {
      List<GradeResult> sortedResults = List.from(_gradeResults);
      sortedResults.sort((a, b) => a.name.compareTo(b.name));

      var excel = excel_lib.Excel.createExcel();
      excel_lib.Sheet sheetObject = excel['Sheet1'];

      // Define styles
      excel_lib.CellStyle headerStyle = excel_lib.CellStyle(
        bold: true,
        horizontalAlign: excel_lib.HorizontalAlign.Center,
        verticalAlign: excel_lib.VerticalAlign.Center,
        textWrapping: excel_lib.TextWrapping.WrapText,
      );

      excel_lib.CellStyle dataCellStyle = excel_lib.CellStyle(
        horizontalAlign: excel_lib.HorizontalAlign.Left,
        verticalAlign: excel_lib.VerticalAlign.Top,
        textWrapping: excel_lib.TextWrapping.WrapText,
      );

      excel_lib.CellStyle centeredCellStyle = excel_lib.CellStyle(
        horizontalAlign: excel_lib.HorizontalAlign.Center,
        verticalAlign: excel_lib.VerticalAlign.Center,
        textWrapping: excel_lib.TextWrapping.WrapText,
      );

      // Set headers
      List<String> headers = ["Student Name", "Score (%)", "Feedback"];
      for (int i = 0; i < headers.length; i++) {
        var cell = sheetObject.cell(
            excel_lib.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = headers[i];
        cell.cellStyle = headerStyle;
      }

      // Process and add data rows
      for (int i = 0; i < sortedResults.length; i++) {
        final result = sortedResults[i];
        int currentRowIndex = i + 1;

        // Student Name
        sheetObject.cell(excel_lib.CellIndex.indexByColumnRow(
            columnIndex: 0, rowIndex: currentRowIndex))
          ..value = result.name
          ..cellStyle = centeredCellStyle;

        // Score (%)
        sheetObject.cell(excel_lib.CellIndex.indexByColumnRow(
            columnIndex: 1, rowIndex: currentRowIndex))
          ..value = result.score ?? "N/A"
          ..cellStyle = centeredCellStyle;

        // Feedback - Cleaned and formatted
        String cleanFeedback = _cleanMarkdown(result.feedback);
        sheetObject.cell(excel_lib.CellIndex.indexByColumnRow(
            columnIndex: 2, rowIndex: currentRowIndex))
          ..value = cleanFeedback
          ..cellStyle = centeredCellStyle;
      }

      // Set column widths (only supported method)
      sheetObject.setColWidth(0, 30); // Student Name
      sheetObject.setColWidth(1, 15); // Score
      sheetObject.setColWidth(2, 80); // Feedback

      List<int>? fileBytes = excel.save();
      if (fileBytes == null) {
        _showToast("Failed to encode Excel file.", ToastType.error);
        if (mounted) setState(() => isProcessingExcel = false);
        return;
      }

      await _startDownload(
        bytes: Uint8List.fromList(fileBytes),
        fileName:
            "Grading_Results_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx",
        mimeType:
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      );
    } catch (e, s) {
      _showToast("Error preparing Excel file: $e", ToastType.error);
      developer.log("Excel Export error: $e", error: e, stackTrace: s);
    } finally {
      if (mounted) setState(() => isProcessingExcel = false);
    }
  }

  String _cleanMarkdown(String markdownText) {
    String cleaned = markdownText;
    cleaned = cleaned.replaceAll(
        RegExp(r'^\s*([*-]|\d+\.)\s+', multiLine: true), '• ');
    cleaned = cleaned
        .replaceAll(RegExp(r'#+\s*'), '')
        .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1')
        .replaceAll(RegExp(r'__(.*?)__'), r'$1')
        .replaceAll(RegExp(r'\*(.*?)\*'), r'$1')
        .replaceAll(RegExp(r'_(.*?)_'), r'$1')
        .replaceAll(RegExp(r'`(.*?)`'), r'$1')
        .replaceAll(RegExp(r'\[(.*?)\]\(.*?\)'), r'$1')
        .replaceAll(RegExp(r'---'), '');
    cleaned = cleaned
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r' {2,}', multiLine: true), ' ')
        .trim();
    return cleaned;
  }

  Future<void> _checkForMondayCredits() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    if (today.weekday != DateTime.monday) return;
    final todayDateString = DateFormat('yyyy-MM-dd').format(today);
    final lastAwardDate = prefs.getString('lastMondayCreditAwardedDate');
    if (lastAwardDate != todayDateString) {
      await _updateCredits(MONDAY_CREDIT_BONUS, add: true);
      await prefs.setString('lastMondayCreditAwardedDate', todayDateString);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showToast(
            "It's Monday! Here are $MONDAY_CREDIT_BONUS free credits to start your week.",
            ToastType.success,
            durationSeconds: 6);
      });
    }
  }

  Future<void> _saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<String?> _loadString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  Future<void> _saveInt(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
    developer.log("Saved int to SharedPreferences: $key = $value");
  }

  Future<int?> _loadInt(String key) async {
    final prefs = await SharedPreferences.getInstance();
    int? value = prefs.getInt(key);
    developer.log("Loaded int from SharedPreferences: $key = $value");
    return value;
  }

  Future<void> _saveJsonFile(String path, dynamic jsonData) async {
    try {
      final file = File(path);
      await file.writeAsString(jsonEncode(jsonData));
      developer.log("Saved JSON to $path");
    } catch (e) {
      developer.log("Error saving JSON to $path: $e", error: e);
      _showToast(
          "Error saving data: ${e.toString().substring(0, math.min(e.toString().length, 50))}",
          ToastType.error);
    }
  }

  Future<dynamic> _loadJsonFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        final content = await file.readAsString();
        developer.log("Loaded JSON from $path");
        return jsonDecode(content);
      }
    } catch (e) {
      developer.log(
          "Error loading or parsing JSON from $path: $e. Deleting corrupted file.",
          error: e);
      _showToast("Error loading data file. It might have been corrupted.",
          ToastType.warning);
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (delErr) {
        developer.log("Error deleting corrupted file $path: $delErr",
            error: delErr);
      }
    }
    return null;
  }

  Future<void> _saveTextFile(String path, String text) async {
    try {
      final file = File(path);
      await file.writeAsString(text);
      developer.log("Saved text to $path");
    } catch (e) {
      developer.log("Error saving text to $path: $e", error: e);
      _showToast(
          "Error saving text data: ${e.toString().substring(0, math.min(e.toString().length, 50))}",
          ToastType.error);
    }
  }

  Future<String?> _loadTextFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        developer.log("Loaded text from $path");
        return await file.readAsString();
      }
    } catch (e) {
      developer.log("Error loading text from $path: $e", error: e);
      _showToast("Error loading text file. It might have been corrupted.",
          ToastType.warning);
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (delErr) {
        developer.log("Error deleting corrupted text file $path: $delErr",
            error: delErr);
      }
    }
    return null;
  }

  Future<List<String>> _validateImagePaths(List<String> paths) async {
    List<String> validPaths = [];
    for (String path in paths) {
      try {
        final file = File(path);
        if (await file.exists() && await file.length() > 0) {
          validPaths.add(path);
        } else {
          developer.log("Invalid image path removed: $path");
        }
      } catch (e) {
        developer.log("Error validating image path $path: $e", error: e);
      }
    }
    return validPaths;
  }

  void _showToast(String message, ToastType type, {int durationSeconds = 4}) {
    if (!mounted) return;
    _toastTimer?.cancel();
    setState(() {
      _toastMessage = message;
      _toastType = type;
    });
    _toastTimer = Timer(Duration(seconds: durationSeconds), () {
      if (!mounted) return;
      setState(() {
        _toastMessage = null;
        _toastType = null;
      });
    });
  }

  Widget _buildToastWidget() {
    if (_toastMessage == null || _toastType == null) {
      return const SizedBox.shrink();
    }
    Color backgroundColor;
    Color foregroundColor;
    Color borderColor;
    IconData iconData;
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    switch (_toastType!) {
      case ToastType.success:
        backgroundColor =
            isDark ? Colors.green.shade800 : Colors.green.shade100;
        foregroundColor =
            isDark ? Colors.green.shade100 : Colors.green.shade800;
        borderColor = Colors.green.shade600;
        iconData = Icons.check_circle_outline;
        break;
      case ToastType.error:
        backgroundColor = isDark ? Colors.red.shade800 : Colors.red.shade100;
        foregroundColor = isDark ? Colors.red.shade100 : Colors.red.shade800;
        borderColor = Colors.red.shade600;
        iconData = Icons.error_outline;
        break;
      case ToastType.warning:
        backgroundColor =
            isDark ? Colors.orange.shade800 : Colors.orange.shade100;
        foregroundColor =
            isDark ? Colors.orange.shade100 : Colors.orange.shade800;
        borderColor = Colors.orange.shade600;
        iconData = Icons.warning_amber_outlined;
        break;
      case ToastType.info:
        backgroundColor = isDark ? Colors.blue.shade800 : Colors.blue.shade100;
        foregroundColor = isDark ? Colors.blue.shade100 : Colors.blue.shade800;
        borderColor = Colors.blue.shade600;
        iconData = Icons.info_outline;
        break;
    }
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: borderColor, width: 5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconData, color: foregroundColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _toastMessage!,
                style: TextStyle(
                    color: foregroundColor, fontWeight: FontWeight.w500),
                softWrap: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadCredits() async {
    _remainingImageCredits = (await _loadInt('remainingImageCredits')) ?? 0;
    if (mounted) setState(() {});
    developer.log("Credits loaded: $_remainingImageCredits");
  }

  Future<void> _updateCredits(int creditsChange, {bool add = true}) async {
    int newCreditValue;
    if (add) {
      newCreditValue = _remainingImageCredits + creditsChange;
    } else {
      newCreditValue = creditsChange;
    }
    if (newCreditValue < 0) newCreditValue = 0;
    if (mounted) {
      setState(() {
        _remainingImageCredits = newCreditValue;
      });
    }
    await _saveInt('remainingImageCredits', newCreditValue);
    developer.log(
        "Credits updated to: $newCreditValue. Change was: $creditsChange (add: $add)");
  }

  Future<void> _pickPaymentScreenshot() async {
    final XFile? pickedFile =
        await _imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final Uint8List imageBytes = await pickedFile.readAsBytes();
      final String imagePath = await _processAndSaveImage(imageBytes);
      if (imagePath.isEmpty) {
        return;
      }

      if (mounted) {
        setState(() {
          _isVerifyingPayment = true;
          _paymentVerificationStatus =
              "Verifying payment records... this may take a moment.";
        });
      }
      try {
        Map<String, dynamic> isolateArgs = {
          'apiKeys': _apiKeys,
          'currentApiKeyIndex': _currentApiKeyIndex,
          'imagePath': imagePath,
          'validRecipients': _validRecipientNumbers,
          'paymentTiers': _paymentTiers,
        };
        Map<String, dynamic> verificationResult =
            await compute(_verifyPaymentScreenshotIsolate, isolateArgs);

        if (verificationResult['usedKeyIndex'] != null) {
          await _saveCurrentApiKeyIndex(verificationResult['usedKeyIndex']);
        }

        if (!mounted) return;

        final String genericFailureMessage =
            "We could not confirm your payment at this time. Please ensure your payment was successful and try again. If the issue persists, please contact support with your transaction details.";

        if (verificationResult['error'] != null ||
            verificationResult['outcome'] == null) {
          developer.log(
              "Payment verification failed at AI level: ${verificationResult['error'] ?? 'No outcome'}");
          _paymentVerificationStatus = genericFailureMessage;
          _showToast(genericFailureMessage, ToastType.error,
              durationSeconds: 6);
          if (mounted) setState(() => _isVerifyingPayment = false);
          return;
        }

        final String outcome = verificationResult['outcome'];
        final String? transactionId =
            verificationResult['transaction_id_detected'];
        final String? timeString =
            verificationResult['transaction_time_detected'];
        final int? amountTierKey = verificationResult['amount_tier'];

        developer.log(
            "Payment verification AI result (for internal debugging): ${jsonEncode(verificationResult)}");

        if (transactionId != null &&
            _usedTransactionIds.contains(transactionId)) {
          developer
              .log("REJECTED: Re-used transaction ID detected: $transactionId");
          _paymentVerificationStatus = genericFailureMessage;
          _showToast(genericFailureMessage, ToastType.error,
              durationSeconds: 6);
          if (mounted) setState(() => _isVerifyingPayment = false);
          return;
        }

        bool isTimeValid = false;
        if (timeString != null) {
          try {
            DateTime? transactionTime = _parseToLocalToday(timeString);
            if (transactionTime != null) {
              Duration difference = DateTime.now().difference(transactionTime);
              if (difference.inMinutes.abs() <= _manualCodeValidityMinutes &&
                  !transactionTime.isAfter(DateTime.now())) {
                isTimeValid = true;
              }
            }
          } catch (e) {
            developer.log("Could not parse time from AI: $timeString",
                error: e);
          }
        }

        if (outcome == 'verified' &&
            isTimeValid &&
            transactionId != null &&
            transactionId.isNotEmpty &&
            amountTierKey != null &&
            _paymentTiers.containsKey(amountTierKey)) {
          int creditsToAdd = _paymentTiers[amountTierKey]!;
          await _updateCredits(creditsToAdd, add: true);
          await _saveUsedTransactionId(transactionId);

          _paymentVerificationStatus =
              "Payment confirmed! $creditsToAdd credits have been successfully added to your account.";
          _showToast(
              "$creditsToAdd credits added successfully!", ToastType.success);
        } else {
          developer.log(
              "REJECTED: Payment failed validation checks. Outcome: $outcome, TimeValid: $isTimeValid, TxnID: $transactionId");
          _paymentVerificationStatus = genericFailureMessage;
          _showToast(genericFailureMessage, ToastType.warning,
              durationSeconds: 6);
        }
      } catch (e) {
        if (!mounted) return;
        developer.log("Exception during payment verification process: $e",
            error: e);
        _paymentVerificationStatus =
            "A system error occurred while verifying payment. Please try again or contact support.";
        _showToast("Error verifying payment. Please contact support.",
            ToastType.error);
      } finally {
        if (mounted) setState(() => _isVerifyingPayment = false);
      }
    } else {
      _showToast("Payment screenshot selection cancelled.", ToastType.info);
    }
  }

  void _showManualCodeDialog() {
    final codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Enter Manual Code"),
        content: TextField(
          controller: codeController,
          autofocus: true,
          decoration: const InputDecoration(hintText: "Enter code"),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            child: const Text("Verify Code"),
            onPressed: () {
              _verifyManualCode(codeController.text);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  void _verifyManualCode(String code) async {
    if (code == _backdoorCode) {
      _updateCredits(_backdoorCredits, add: true);
      _showToast("Backdoor activated! $_backdoorCredits credits added.",
          ToastType.success);
      developer.log("Backdoor code used.");
      return;
    }

    // Check if code was already used
    final prefs = await SharedPreferences.getInstance();
    final usedCodes = prefs.getStringList('usedManualCodes') ?? [];
    if (usedCodes.contains(code)) {
      _showToast("This code has already been used.", ToastType.error);
      return;
    }

    List<String> parts = code.split('-');
    if (parts.length != 3) {
      _showToast("Invalid code format.", ToastType.error);
      return;
    }

    try {
      int transformedAmount = int.parse(parts[0]);
      int timestampMillis = int.parse(parts[1]);
      int checksum = int.parse(parts[2]);
      int nowMillis = DateTime.now().millisecondsSinceEpoch;
      int validityMillis = _manualCodeValidityMinutes * 60 * 1000;

      if (nowMillis - timestampMillis > validityMillis) {
        _showToast("Code expired.", ToastType.error);
        return;
      }

      if (timestampMillis > nowMillis + (60 * 1000)) {
        _showToast("Code from the future? Invalid timestamp.", ToastType.error);
        return;
      }

      bool codeValid = false;
      for (int originalAmount in _paymentTiers.keys) {
        int calculatedTransformedAmount =
            originalAmount ^ (timestampMillis % 10000);
        if (calculatedTransformedAmount == transformedAmount) {
          int calculatedChecksum = (originalAmount + timestampMillis) % 97;
          if (calculatedChecksum == checksum) {
            // Mark code as used before granting credits
            usedCodes.add(code);
            await prefs.setStringList('usedManualCodes', usedCodes);

            int creditsToAdd = _paymentTiers[originalAmount]!;
            _updateCredits(creditsToAdd, add: true);
            _showToast("$creditsToAdd credits added via manual code!",
                ToastType.success);
            codeValid = true;
            break;
          }
        }
      }

      if (!codeValid) {
        _showToast(
            "Invalid or checksum failed for manual code.", ToastType.error);
      }
    } catch (e) {
      _showToast("Error parsing manual code.", ToastType.error);
      developer.log("Manual code parsing error: $e", error: e);
    }
  }

  Future<void> _cleanExpiredManualCodes() async {
    final prefs = await SharedPreferences.getInstance();
    final usedCodes = prefs.getStringList('usedManualCodes') ?? [];
    final now = DateTime.now().millisecondsSinceEpoch;
    final validityMillis = _manualCodeValidityMinutes * 60 * 1000;

    final validCodes = usedCodes.where((code) {
      try {
        final parts = code.split('-');
        if (parts.length != 3) return false;
        final timestampMillis = int.parse(parts[1]);
        return (now - timestampMillis) <= validityMillis;
      } catch (e) {
        return false;
      }
    }).toList();

    if (validCodes.length != usedCodes.length) {
      await prefs.setStringList('usedManualCodes', validCodes);
    }
  }

  Future<void> _contactSupport() async {
    final Uri whatsappUri = Uri.parse(
        "https://wa.me/$_supportWhatsAppNumber?text=Hello AI Grader Support, I need help.");
    if (!await launchUrl(whatsappUri, mode: LaunchMode.externalApplication)) {
      _showToast("Could not launch WhatsApp.", ToastType.error);
    }
  }

  Widget _buildPaymentSection() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: const Icon(Icons.account_balance_wallet_outlined),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Image Credits"),
            Text("$_remainingImageCredits",
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Instructions for Topping Up Credits:",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text("Send payment (UGX) to either:"),
                const SizedBox(height: 4),

                // --- YOUR CORRECTLY IMPLEMENTED WIDGET IS HERE ---
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // First Phone Number with Copy Button
                      Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              _formatPhoneNumberForDisplay(
                                  _normalizeUgandanPhoneNumber(
                                          _validRecipientNumbers[0]) ??
                                      _validRecipientNumbers[0]),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.content_copy, size: 20),
                            tooltip: 'Copy Number',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(
                                  text: _validRecipientNumbers[0]));
                              _showToast('Number copied!', ToastType.info);
                            },
                          ),
                        ],
                      ),
                      if (_validRecipientNumbers.length > 1) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 2.0),
                          child: Text("OR",
                              style: TextStyle(fontStyle: FontStyle.italic)),
                        ),
                        // Second Phone Number with Copy Button
                        Row(
                          children: [
                            Expanded(
                              child: SelectableText(
                                _formatPhoneNumberForDisplay(
                                    _normalizeUgandanPhoneNumber(
                                            _validRecipientNumbers[1]) ??
                                        _validRecipientNumbers[1]),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.content_copy, size: 20),
                              tooltip: 'Copy Number',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(
                                    text: _validRecipientNumbers[1]));
                                _showToast('Number copied!', ToastType.info);
                              },
                            ),
                          ],
                        ),
                      ]
                    ],
                  ),
                ),
                // --- END OF YOUR IMPLEMENTATION ---

                const SizedBox(height: 8),
                const Text("Available Tiers (UGX: Credits):"),
                ..._paymentTiers.entries.map((e) => Padding(
                      padding: const EdgeInsets.only(left: 8.0, top: 2.0),
                      child: Text("  ${e.key} UGX : ${e.value} Credits"),
                    )),
                Padding(
                  padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
                  child: Chip(
                    avatar: Icon(Icons.auto_awesome,
                        size: 18, color: Theme.of(context).colorScheme.primary),
                    label: const Text(
                        "Note: You get 10 FREE credits every Monday!"),
                    backgroundColor:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    side: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.2)),
                  ),
                ),
                const SizedBox(height: 12),
                const Text("1. Make your payment via Mobile Money."),
                const Text(
                    "2. Take a screenshot of the payment confirmation message."),
                const Text(
                    "3. Upload the screenshot below - your credits will be updated in seconds!"),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      icon: _isVerifyingPayment
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.cloud_upload_outlined),
                      label: const Text("Upload Screenshot"),
                      onPressed: (_isGrading || _isVerifyingPayment)
                          ? null
                          : _pickPaymentScreenshot,
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.code_outlined),
                      label: const Text("Manual Code"),
                      onPressed: (_isGrading || _isVerifyingPayment)
                          ? null
                          : _showManualCodeDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.support_agent_outlined),
                    label: const Text("Contact Support"),
                    onPressed: _contactSupport,
                  ),
                ),
                if (_paymentVerificationStatus.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text("Status: $_paymentVerificationStatus",
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.8))),
                ],
              ],
            ),
          )
        ],
      ),
    );
  }

  Future<void> _loadGradingSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _gradingMode = GradingMode
        .values[prefs.getInt('gradingMode') ?? GradingMode.images.index];
    if (mounted) setState(() {});
  }

  Future<void> _saveGradingMode() async {
    await _saveInt('gradingMode', _gradingMode.index);
  }

  Future<String> _processAndSaveImage(Uint8List imageBytes) async {
    try {
      final Uint8List? compressedBytes =
          await compute(_compressImageIsolate, imageBytes);

      if (compressedBytes == null) {
        return "";
      }

      final tempDir = await getTemporaryDirectory();
      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(99999)}.jpg';
      final String newFilePath = path.join(tempDir.path, fileName);
      final File newFile = File(newFilePath);
      await newFile.writeAsBytes(compressedBytes, flush: true);

      developer.log('Saved PRE-PROCESSED image to: $newFilePath');
      return newFilePath;
    } catch (e) {
      developer.log("Error during image processing: $e");
      return "";
    }
  }

  Future<void> _processImageAndAddToState(
      XFile pickedFile,
      List<String> targetList,
      ValueSetter<int> incrementCounter,
      VoidCallback decrementCounter) async {
    if (!mounted) return;
    incrementCounter(1);

    try {
      final bytes = await pickedFile.readAsBytes();
      final newPath = await _processAndSaveImage(bytes);

      if (newPath.isNotEmpty && mounted) {
        setState(() {
          targetList.add(newPath);
        });
      } else {
        if (mounted) _showToast("Failed to process an image.", ToastType.error);
      }
    } catch (e) {
      if (mounted)
        _showToast("Failed to process an image: $e", ToastType.error);
    } finally {
      if (mounted) {
        decrementCounter();
      }
    }
  }

  Future<void> _pickImagesForReference(ImageSource source,
      {required bool forSolutionGuide}) async {
    List<XFile>? pickedFiles;
    if (source == ImageSource.gallery) {
      pickedFiles = await _imagePicker.pickMultiImage();
    } else {
      final XFile? photo = await _imagePicker.pickImage(source: source);
      if (photo != null) pickedFiles = [photo];
    }

    if (pickedFiles != null && pickedFiles.isNotEmpty) {
      List<Future<void>> processingFutures = [];

      if (forSolutionGuide) {
        setState(() {
          _solutionGuideProcessingCount += pickedFiles!.length;
        });
        for (final file in pickedFiles) {
          processingFutures.add(_processImageAndAddToState(
              file, _solutionGuideImagePaths, (_) {}, () {
            setState(() => _solutionGuideProcessingCount--);
          }));
        }
        _solutionText = null;
        _solutionTextError = null;
        _gradingReferenceData = null;
      } else {
        setState(() {
          _questionPaperProcessingCount += pickedFiles!.length;
        });
        for (final file in pickedFiles) {
          processingFutures.add(_processImageAndAddToState(
              file, _questionPaperImagePaths, (_) {}, () {
            setState(() => _questionPaperProcessingCount--);
          }));
        }
        _generatedSolutionGuide = null;
        _guideGenerationError = null;
        _guideGenerationRecitationError = false;
        _gradingReferenceData = null;
      }

      await Future.wait(processingFutures);

      if (forSolutionGuide) {
        await _saveSolutionGuideImages();
        developer.log("Persisted solution guide image paths.");
      } else {
        await _saveQuestionPaperImages();
        developer.log("Persisted question paper image paths.");
      }
    }
  }

  Future<void> _loadSolutionGuide() async {
    var imagePathsData = await _loadJsonFile(_solutionImagesJsonPath);
    if (imagePathsData != null && imagePathsData is List) {
      _solutionGuideImagePaths =
          await _validateImagePaths(List<String>.from(imagePathsData));
      if (_solutionGuideImagePaths.length != imagePathsData.length) {
        await _saveSolutionGuideImages();
      }
    }
    _solutionText = await _loadTextFile(_solutionExtractedTextPath);
    if (mounted) setState(() {});
  }

  Future<void> _loadGradingReferenceData() async {
    var data = await _loadJsonFile(_gradingReferenceDataPath);
    if (data != null && data is Map<String, dynamic>) {
      if (data.containsKey('solution_text') &&
          data.containsKey('total_possible_marks')) {
        _gradingReferenceData = data;
        developer.log("Loaded cached grading reference data.");
        if (mounted) {
          setState(() {
            if (_gradingMode == GradingMode.text) {
              _solutionText = data['solution_text'];
            } else {
              _generatedSolutionGuide = data['solution_text'];
            }
          });
        }
      }
    }
  }

  Future<void> _saveSolutionGuideImages() async {
    await _saveJsonFile(_solutionImagesJsonPath, _solutionGuideImagePaths);
  }

  Future<void> _saveSolutionText() async {
    if (_solutionText != null) {
      await _saveTextFile(_solutionExtractedTextPath, _solutionText!);
    } else {
      final file = File(_solutionExtractedTextPath);
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> _loadQuestionPaper() async {
    var imagePathsData = await _loadJsonFile(_questionPaperImagesJsonPath);
    if (imagePathsData != null && imagePathsData is List) {
      _questionPaperImagePaths =
          await _validateImagePaths(List<String>.from(imagePathsData));
      if (_questionPaperImagePaths.length != imagePathsData.length) {
        await _saveQuestionPaperImages();
      }
    }
    _generatedSolutionGuide =
        await _loadTextFile(_generatedSolutionGuideTextPath);
    if (mounted) setState(() {});
  }

  Future<void> _saveQuestionPaperImages() async {
    await _saveJsonFile(_questionPaperImagesJsonPath, _questionPaperImagePaths);
  }

  Future<void> _saveGeneratedSolutionGuide() async {
    if (_generatedSolutionGuide != null) {
      await _saveTextFile(
          _generatedSolutionGuideTextPath, _generatedSolutionGuide!);
    } else {
      final file = File(_generatedSolutionGuideTextPath);
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> _processReferenceMaterial(
      {bool calledFromGrading = false}) async {
    String context;
    List<String> imagePaths;
    if (_gradingMode == GradingMode.text) {
      if (_solutionGuideImagePaths.isEmpty) {
        if (!calledFromGrading) {
          _showToast("No solution guide images to process.", ToastType.info);
        }
        return;
      }
      if (_gradingReferenceData != null) {
        if (!calledFromGrading) {
          _showToast("Solution guide already processed.", ToastType.info);
        }
        return;
      }
      context = "solution_guide";
      imagePaths = _solutionGuideImagePaths;
      if (mounted) {
        setState(() {
          _solutionTextError = null;
          if (!calledFromGrading) {
            _isProcessingReference = true;
            _processingReferenceMessage =
                "Extracting text & total marks from solution guide...";
          }
        });
      }
    } else {
      if (_questionPaperImagePaths.isEmpty) {
        if (!calledFromGrading) {
          _showToast("No question paper images to process.", ToastType.info);
        }
        return;
      }
      if (_gradingReferenceData != null) {
        if (!calledFromGrading) {
          _showToast("Solution guide already generated.", ToastType.info);
        }
        return;
      }
      _guideGenerationRecitationError = false;
      context = "question_paper";
      imagePaths = _questionPaperImagePaths;
      if (mounted) {
        setState(() {
          _guideGenerationError = null;
          if (!calledFromGrading) {
            _isProcessingReference = true;
            _processingReferenceMessage =
                "Generating solution guide & total marks from question paper...";
          }
        });
      }
    }
    int creditsRequired = imagePaths.length;
    if (!_isFreePeriodActive) {
      if (_remainingImageCredits < creditsRequired) {
        String msg =
            "Not enough credits to process reference material. Required: $creditsRequired, Available: $_remainingImageCredits";
        if (!calledFromGrading) _showToast(msg, ToastType.warning);
        if (mounted) {
          if (_gradingMode == GradingMode.text) {
            setState(() => _solutionTextError = msg);
          } else {
            setState(() => _guideGenerationError = msg);
          }
          setState(() => _isProcessingReference = false);
        }
        return;
      }
    }
    try {
      Map<String, dynamic> isolateArgs = {
        'apiKeys': _apiKeys,
        'currentApiKeyIndex': _currentApiKeyIndex,
        'imagePaths': imagePaths,
        'context': context
      };
      Map<String, dynamic> result =
          await compute(_processReferenceMaterialIsolate, isolateArgs);

      if (result['usedKeyIndex'] != null) {
        await _saveCurrentApiKeyIndex(result['usedKeyIndex']);
      }

      if (!mounted) return;
      if (result['error'] != null) {
        final errorMessage =
            "Failed to process reference material: ${result['error']}";
        if (context == "solution_guide") {
          setState(() => _solutionTextError = errorMessage);
        } else {
          setState(() {
            _guideGenerationError = errorMessage;
            if (result['recitationError'] == true) {
              _guideGenerationRecitationError = true;
            }
          });
        }
      } else {
        if (!_isFreePeriodActive) {
          await _updateCredits(-creditsRequired, add: true);
        }

        int totalPossibleMarks = _calculateTotalPossibleMarks(
          idealScores: result['ideal_student_scores'] ?? [],
        );

        setState(() {
          _gradingReferenceData = {
            'solution_text': result['solution_text'],
            'total_possible_marks': totalPossibleMarks,
            'marks_allocation': result['marks_allocation'] ?? [],
          };
          if (context == "solution_guide") {
            _solutionText = result['solution_text'];
            _saveSolutionText();
          } else {
            _generatedSolutionGuide = result['solution_text'];
            _saveGeneratedSolutionGuide();
          }
        });
        await _saveJsonFile(_gradingReferenceDataPath, _gradingReferenceData);
      }
    } catch (e) {
      if (!mounted) return;
      String errorMsg = "Processing failed. Please try again.";
      if (context == "solution_guide") {
        setState(() => _solutionTextError = errorMsg);
      } else {
        setState(() => _guideGenerationError = errorMsg);
      }
      developer.log("Reference processing error: $e", error: e);
    } finally {
      if (!mounted) return;
      setState(() {
        _isProcessingReference = false;
        _processingReferenceMessage = "";
      });
    }
  }

  void _clearReferenceMaterial() {
    if (mounted) {
      setState(() {
        if (_gradingMode == GradingMode.text) {
          _solutionGuideImagePaths.clear();
          _solutionText = null;
          _solutionTextError = null;
          _gradingReferenceData = null;
          _saveSolutionGuideImages();
          _saveSolutionText();
          _showToast("Solution guide images and extracted text cleared.",
              ToastType.info);
        } else {
          _questionPaperImagePaths.clear();
          _generatedSolutionGuide = null;
          _guideGenerationError = null;
          _guideGenerationRecitationError = false;
          _gradingReferenceData = null;
          _saveQuestionPaperImages();
          _saveGeneratedSolutionGuide();
          _showToast("Question paper images and generated guide cleared.",
              ToastType.info);
        }
      });
      final refDataFile = File(_gradingReferenceDataPath);
      refDataFile.exists().then((exists) {
        if (exists) refDataFile.delete();
        developer.log("Cleared cached grading reference data file.");
      });
    }
  }

  void _retryReferenceGeneration() async {
    final imagePaths = _gradingMode == GradingMode.text
        ? _solutionGuideImagePaths
        : _questionPaperImagePaths;
    if (imagePaths.isEmpty) {
      _showToast("No images to process.", ToastType.warning);
      return;
    }

    final creditsRequired = imagePaths.length;
    if (_remainingImageCredits < creditsRequired) {
      _showToast(
          "Not enough credits to re-generate. Required: $creditsRequired.",
          ToastType.warning);
      return;
    }

    _showToast("Re-generating guide...", ToastType.info);
    if (mounted) {
      setState(() {
        _gradingReferenceData = null;
        if (_gradingMode == GradingMode.text) {
          _solutionText = null;
          _solutionTextError = null;
        } else {
          _generatedSolutionGuide = null;
          _guideGenerationError = null;
          _guideGenerationRecitationError = false;
        }
      });

      final refDataFile = File(_gradingReferenceDataPath);
      if (await refDataFile.exists()) {
        await refDataFile.delete();
      }
      _processReferenceMaterial();
    }
  }

  Widget _buildGradingReferenceSection() {
    return _AppCard(
      title: "Grading Reference",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<GradingMode>(
            segments: const <ButtonSegment<GradingMode>>[
              ButtonSegment<GradingMode>(
                  value: GradingMode.text,
                  label: Text('Solution Guide'),
                  icon: Icon(Icons.description_outlined)),
              ButtonSegment<GradingMode>(
                  value: GradingMode.images,
                  label: Text('Question Paper'),
                  icon: Icon(Icons.image_search_outlined)),
            ],
            selected: <GradingMode>{_gradingMode},
            onSelectionChanged: _isGrading || _isProcessingReference
                ? null
                : (Set<GradingMode> newSelection) {
                    if (mounted) {
                      setState(() {
                        _gradingMode = newSelection.first;
                        _saveGradingMode();
                      });
                    }
                  },
          ),
          const SizedBox(height: 16),
          if (_gradingMode == GradingMode.text) _buildSolutionGuideModeUI(),
          if (_gradingMode == GradingMode.images) _buildQuestionPaperModeUI(),
        ],
      ),
    );
  }

  Widget _buildSolutionGuideModeUI() {
    final bool canProcess =
        _remainingImageCredits >= _solutionGuideImagePaths.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Provide Solution Guide (Images):",
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text("Upload"),
              onPressed: _isGrading || _isProcessingReference
                  ? null
                  : () => _pickImagesForReference(ImageSource.gallery,
                      forSolutionGuide: true),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text("Camera"),
              onPressed: _isGrading || _isProcessingReference
                  ? null
                  : () => _pickImagesForReference(ImageSource.camera,
                      forSolutionGuide: true),
            ),
          ],
        ),
        if (_solutionGuideImagePaths.isNotEmpty ||
            _solutionGuideProcessingCount > 0) ...[
          const SizedBox(height: 8),
          Text("${_solutionGuideImagePaths.length} solution image(s) loaded."),
          _ImagePreviewRow(
              imagePaths: _solutionGuideImagePaths,
              processingCount: _solutionGuideProcessingCount),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _isGrading || _isProcessingReference
                    ? null
                    : _clearReferenceMaterial,
                child: const Text("Clear Images & Guide",
                    style: TextStyle(color: Colors.redAccent)),
              ),
              if (!_isProcessingReference &&
                  !_isGrading &&
                  (_gradingReferenceData != null || _solutionTextError != null))
                Tooltip(
                  message: canProcess
                      ? "Re-generate Guide from Images"
                      : "Not enough credits",
                  child: IconButton(
                    icon: const Icon(Icons.refresh),
                    color: Theme.of(context).colorScheme.secondary,
                    onPressed: canProcess ? _retryReferenceGeneration : null,
                  ),
                )
            ],
          ),
        ],
        const SizedBox(height: 8),
        if (_solutionGuideImagePaths.isEmpty &&
            _solutionGuideProcessingCount == 0)
          const Text("Upload or take photos of the solution guide."),
        if (_isProcessingReference && _gradingMode == GradingMode.text) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
          const SizedBox(height: 4),
          Text(_processingReferenceMessage),
        ],
        if (!_isProcessingReference &&
            _gradingReferenceData != null &&
            _solutionText != null)
          Row(
            children: [
              Expanded(
                  child: _buildInfoBox(
                      title: "Text & Total Marks Extracted",
                      message:
                          "Ready for grading. Total Marks: ${_gradingReferenceData!['total_possible_marks']}",
                      type: ToastType.success,
                      context: context)),
              IconButton(
                  icon: const Icon(Icons.visibility_outlined),
                  tooltip: "View Extracted Text",
                  onPressed: () => _showViewTextDialog(
                      "Extracted Solution Guide", _solutionText!)),
            ],
          ),
        if (!_isProcessingReference && _solutionTextError != null)
          _buildErrorBox(
              title: "Solution Text Error",
              message: _solutionTextError!,
              context: context),
        if (!_isProcessingReference &&
            _solutionGuideImagePaths.isNotEmpty &&
            _solutionGuideProcessingCount == 0 &&
            _gradingReferenceData == null &&
            _solutionTextError == null &&
            !_isGrading)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: ElevatedButton(
                onPressed:
                    canProcess ? () => _processReferenceMaterial() : null,
                child: Text(canProcess
                    ? "Process Solution Images Now"
                    : "Not Enough Credits")),
          ),
      ],
    );
  }

  Widget _buildQuestionPaperModeUI() {
    final bool canProcess =
        _remainingImageCredits >= _questionPaperImagePaths.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Provide Question Paper Image(s):",
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text("Upload"),
              onPressed: _isGrading || _isProcessingReference
                  ? null
                  : () => _pickImagesForReference(ImageSource.gallery,
                      forSolutionGuide: false),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text("Camera"),
              onPressed: _isGrading || _isProcessingReference
                  ? null
                  : () => _pickImagesForReference(ImageSource.camera,
                      forSolutionGuide: false),
            ),
          ],
        ),
        if (_questionPaperImagePaths.isNotEmpty ||
            _questionPaperProcessingCount > 0) ...[
          const SizedBox(height: 8),
          Text(
              "${_questionPaperImagePaths.length} question paper image(s) loaded."),
          _ImagePreviewRow(
              imagePaths: _questionPaperImagePaths,
              processingCount: _questionPaperProcessingCount),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _isGrading || _isProcessingReference
                    ? null
                    : _clearReferenceMaterial,
                child: const Text("Clear Images & Guide",
                    style: TextStyle(color: Colors.redAccent)),
              ),
              if (!_isProcessingReference &&
                  !_isGrading &&
                  (_gradingReferenceData != null ||
                      _guideGenerationError != null))
                Tooltip(
                  message: canProcess
                      ? "Re-generate Guide from Images"
                      : "Not enough credits",
                  child: IconButton(
                    icon: const Icon(Icons.refresh),
                    color: Theme.of(context).colorScheme.secondary,
                    onPressed: canProcess ? _retryReferenceGeneration : null,
                  ),
                )
            ],
          ),
        ],
        const SizedBox(height: 8),
        if (_isProcessingReference && _gradingMode == GradingMode.images) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
          const SizedBox(height: 4),
          Text(_processingReferenceMessage),
        ],
        if (!_isProcessingReference &&
            _questionPaperImagePaths.isEmpty &&
            _questionPaperProcessingCount == 0)
          const Text(
              "Upload question paper images to generate a solution guide automatically."),
        if (!_isProcessingReference && _guideGenerationRecitationError)
          _buildErrorBox(
            title: "Guide Generation Blocked",
            message: _guideGenerationError ??
                "Guide generation was blocked due to potential copyrighted material in the question paper. Please create a solution guide manually in 'Solution Guide' mode, or use a different question paper.",
            context: context,
          ),
        if (!_isProcessingReference &&
            _guideGenerationError != null &&
            !_guideGenerationRecitationError)
          _buildErrorBox(
              title: "Guide Generation Error",
              message: _guideGenerationError!,
              context: context),
        if (!_isProcessingReference &&
            _gradingReferenceData != null &&
            _generatedSolutionGuide != null &&
            !_guideGenerationRecitationError)
          Row(
            children: [
              Expanded(
                  child: _buildInfoBox(
                      title: "Solution Guide Generated",
                      message:
                          "Ready for grading. Total Marks: ${_gradingReferenceData!['total_possible_marks']}",
                      type: ToastType.success,
                      context: context)),
              IconButton(
                  icon: const Icon(Icons.visibility_outlined),
                  tooltip: "View Generated Guide",
                  onPressed: () => _showViewTextDialog(
                      "Generated Solution Guide", _generatedSolutionGuide!)),
            ],
          ),
        if (!_isProcessingReference &&
            _questionPaperImagePaths.isNotEmpty &&
            _questionPaperProcessingCount == 0 &&
            _gradingReferenceData == null &&
            (_guideGenerationError == null || _guideGenerationError!.isEmpty) &&
            !_guideGenerationRecitationError &&
            !_isGrading)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: ElevatedButton(
                onPressed:
                    canProcess ? () => _processReferenceMaterial() : null,
                child: Text(canProcess
                    ? "Generate Guide from QP Now"
                    : "Not Enough Credits")),
          ),
      ],
    );
  }

  Future<void> _loadSubmissions() async {
    var data = await _loadJsonFile(_studentsJsonPath);
    if (data != null && data is List) {
      List<StudentSubmission> loadedSubmissions = [];
      bool listChanged = false;
      for (var item in data) {
        try {
          StudentSubmission submission = StudentSubmission.fromJson(item);
          List<String> validPaths =
              await _validateImagePaths(submission.imagePaths);
          if (validPaths.isNotEmpty) {
            if (validPaths.length != submission.imagePaths.length) {
              submission.imagePaths = validPaths;
              listChanged = true;
            }
            loadedSubmissions.add(submission);
          } else {
            developer.log(
                "Submission for ${submission.name} removed due to no valid images.");
            listChanged = true;
          }
        } catch (e) {
          developer.log("Error loading a student submission: $e", error: e);
          listChanged = true;
        }
      }
      _submissions = loadedSubmissions;
      if (listChanged) {
        await _saveSubmissions();
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _saveSubmissions() async {
    await _saveJsonFile(
        _studentsJsonPath, _submissions.map((s) => s.toJson()).toList());
  }

  void _deleteStudent(int index) {
    if (index < 0 || index >= _submissions.length) return;

    final String studentNameToDelete = _submissions[index].name;

    if (mounted) {
      setState(() {
        _submissions.removeAt(index);
        _gradeResults
            .removeWhere((result) => result.name == studentNameToDelete);
      });

      _saveSubmissions();
      _saveGradeResults();

      _showToast("Student '$studentNameToDelete' deleted.", ToastType.info);
    }
  }

  Future<void> _pickBatchSubmissions() async {
    final List<XFile>? pickedFiles = await _imagePicker.pickMultiImage();

    if (pickedFiles != null && pickedFiles.isNotEmpty) {
      setState(() {
        _batchImageProcessingCount = pickedFiles.length;
      });
      for (final file in pickedFiles) {
        _processImageAndAddToState(file, _batchImages, (_) {}, () {
          setState(() => _batchImageProcessingCount--);
        });
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _batchNameFocusNode.requestFocus();
        }
      });
    } else {
      _showToast(
          "Image selection cancelled or no images selected.", ToastType.info);
    }
  }

  void _addBatchStudent() {
    String name = _batchNameController.text.trim();
    if (name.isEmpty) {
      _showToast("Student name cannot be empty.", ToastType.warning);
      _batchNameFocusNode.requestFocus();
      return;
    }
    if (_batchImages.isEmpty) {
      _showToast("No images to add for this student.", ToastType.warning);
      return;
    }

    if (_submissions.any((s) => s.name.toLowerCase() == name.toLowerCase())) {
      _showToast(
          "Student name '$name' already exists. Please use a unique name.",
          ToastType.warning);
      _batchNameController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _batchNameController.text.length,
      );
      _batchNameFocusNode.requestFocus();
      return;
    }

    _submissions.add(
        StudentSubmission(name: name, imagePaths: List.from(_batchImages)));
    _saveSubmissions();
    _showToast("Student '$name' added with ${_batchImages.length} image(s).",
        ToastType.success);

    setState(() {
      _batchImages.clear();
      _batchNameController.clear();
      _batchImageProcessingCount = 0;
    });
  }

  Future<void> _takeManualPhoto() async {
    final XFile? photo =
        await _imagePicker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      _processImageAndAddToState(photo, _manualImages, (count) {
        setState(() => _manualImageProcessingCount += count);
      }, () {
        setState(() => _manualImageProcessingCount--);
      });
    }
  }

  void _clearManualImages() {
    if (mounted) setState(() => _manualImages.clear());
  }

  void _toggleManualMode() {
    if (mounted) {
      setState(() {
        if (_isManualMode) {
          if (_manualNameController.text.isNotEmpty ||
              _manualImages.isNotEmpty ||
              _manualImageProcessingCount > 0) {
            _showConfirmationDialog(
                title: "Unsaved Manual Entry",
                content:
                    "You have unsaved data for '${_manualNameController.text}'. Add student or discard changes?",
                confirmText: "Add Student",
                onConfirm: () async {
                  await _addManualStudent();
                  _clearManualEntryFields(clearName: true);
                  if (mounted) setState(() => _isManualMode = false);
                },
                onCancel: () {
                  _clearManualEntryFields(clearName: true);
                  if (mounted) setState(() => _isManualMode = false);
                });
            return;
          } else {
            _isManualMode = false;
          }
        } else {
          _isManualMode = true;
          _manualNameController.clear();
          _manualImages.clear();
          _manualImageProcessingCount = 0;
          _manualNameFocusNode.requestFocus();
        }
      });
    }
  }

  Future<void> _addManualStudent() async {
    String name = _manualNameController.text.trim();
    if (name.isEmpty) {
      _showToast("Student name cannot be empty.", ToastType.warning);
      _manualNameFocusNode.requestFocus();
      return;
    }

    if (mounted) {
      setState(() {
        _isAddingStudent = true;
      });
    }

    if (_manualImages.isEmpty) {
      _showToast("At least one image of work is required for $name.",
          ToastType.warning);
      if (mounted) setState(() => _isAddingStudent = false);
      return;
    }

    if (_submissions.any((s) => s.name.toLowerCase() == name.toLowerCase())) {
      _showToast(
          "Student name '$name' already exists. Please use a unique name.",
          ToastType.warning);
      _manualNameController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _manualNameController.text.length,
      );
      _manualNameFocusNode.requestFocus();
      if (mounted) setState(() => _isAddingStudent = false);
      return;
    }

    _submissions.add(
        StudentSubmission(name: name, imagePaths: List.from(_manualImages)));
    await _saveSubmissions();
    _showToast("Student '$name' added with ${_manualImages.length} image(s).",
        ToastType.success);

    if (mounted) {
      setState(() {
        _clearManualEntryFields(clearName: true);
        _isAddingStudent = false;
      });

      // V-- THIS IS THE NEW, MORE FORCEFUL FIX --V
      // This is a multi-step process to guarantee the keyboard appears.
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && _isManualMode) {
          // Step 1: Ensure the TextField has focus. This is crucial because it
          // tells the system WHICH text field the keyboard is for.
          _manualNameFocusNode.requestFocus();

          // Step 2: Manually COMMAND the keyboard to show.
          // This is the direct instruction you were looking for.
          SystemChannels.textInput.invokeMethod('TextInput.show');
        }
      });
      // ^-- END OF FIX --^
    }
  }

  void _clearManualEntryFields({bool clearName = true}) {
    if (clearName) _manualNameController.clear();
    if (mounted) {
      setState(() {
        _manualImages.clear();
        _manualImageProcessingCount = 0;
      });
    }
  }

  void _clearAllSubmissions() {
    _showConfirmationDialog(
        title: "Confirm Clear",
        content:
            "Are you sure you want to clear all student submissions and their grading results?",
        confirmText: "Clear All",
        onConfirm: () {
          if (mounted) {
            setState(() {
              _submissions.clear();
              _gradeResults.clear();
            });
          }
          _saveSubmissions();
          _saveGradeResults();
          _showToast("All submissions and results cleared.", ToastType.info);
        });
  }

  Widget _buildStudentSubmissionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Student Submissions (${_submissions.length})",
                  style: Theme.of(context).textTheme.titleLarge),
              if (_submissions.isNotEmpty && !_isGrading)
                TextButton(
                    onPressed: _clearAllSubmissions,
                    child: const Text("Clear All",
                        style: TextStyle(color: Colors.redAccent))),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text("Upload Script"),
                  onPressed:
                      _isGrading || _isManualMode || _batchImages.isNotEmpty
                          ? null
                          : _pickBatchSubmissions,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(_isManualMode ? Icons.done_all : Icons.edit_note),
                  label: Text(
                      _isManualMode ? "Finish Entry Mode" : "Manual Entry"),
                  style: _isManualMode
                      ? OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2),
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.1),
                        )
                      : null,
                  onPressed: _isGrading ? null : _toggleManualMode,
                ),
              ),
            ],
          ),
        ),
        if (_batchImages.isNotEmpty || _batchImageProcessingCount > 0)
          _buildBatchEntryCard(),
        if (_isManualMode) _buildManualEntryCard(),
        const SizedBox(height: 8),
        if (_submissions.isEmpty && !_isManualMode && _batchImages.isEmpty)
          const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: Text("No student submissions added yet."))),
        if (_submissions.isNotEmpty)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _submissions.length,
            itemBuilder: (context, index) {
              final submission = _submissions[index];
              GradeResult? result = _gradeResults.firstWhere(
                  (r) => r.name == submission.name,
                  orElse: () => GradeResult(
                      name: submission.name, status: "pending", feedback: ""));
              IconData statusIcon = Icons.pending_outlined;
              Color? statusColor;
              if (_isGrading &&
                  _gradingStatusMessage.contains(submission.name)) {
                statusIcon = Icons.hourglass_empty_outlined;
              } else if (result.status == "success") {
                statusIcon = Icons.check_circle_outline;
                statusColor = Colors.green;
              } else if (result.status.startsWith("failed")) {
                statusIcon = Icons.error_outline;
                statusColor = Colors.red;
              } else if (result.status == "cancelled") {
                statusIcon = Icons.cancel_outlined;
                statusColor = Colors.orange;
              } else if (result.status == "missing_from_response") {
                statusIcon = Icons.help_outline_rounded;
                statusColor = Colors.blueGrey;
              }
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: result.status != "pending" && statusColor != null
                    ? statusColor.withOpacity(0.1)
                    : null,
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(submission.name,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text("${submission.imagePaths.length} image(s)"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (submission.imagePaths.isNotEmpty)
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.file(File(submission.imagePaths.first),
                                fit: BoxFit.cover,
                                cacheHeight: (40 *
                                        MediaQuery.of(context).devicePixelRatio)
                                    .round(),
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.broken_image)),
                          ),
                        ),
                      if (submission.imagePaths.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: Text("+${submission.imagePaths.length - 1}",
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).hintColor)),
                        ),
                      const SizedBox(width: 8),
                      Icon(statusIcon, color: statusColor),
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            color: Theme.of(context).colorScheme.error),
                        tooltip: "Delete ${submission.name}",
                        onPressed: _isGrading
                            ? null
                            : () {
                                _showConfirmationDialog(
                                  title: "Delete Student?",
                                  content:
                                      "Are you sure you want to permanently delete '${submission.name}' and any associated grade results?",
                                  confirmText: "Delete",
                                  onConfirm: () => _deleteStudent(index),
                                );
                              },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildManualEntryCard() {
    bool hasPendingJobs = _manualImageProcessingCount > 0;
    String photoStatusText =
        "${_manualImages.length} photo(s) added for current student.";
    if (hasPendingJobs) {
      photoStatusText += " ($_manualImageProcessingCount processing...)";
    }

    return _AppCard(
      title: "Manual Student Entry",
      borderColor: Theme.of(context).colorScheme.primary,
      child: Column(
        children: [
          TextField(
              controller: _manualNameController,
              focusNode: _manualNameFocusNode,
              enabled: !_isAddingStudent,
              decoration: const InputDecoration(labelText: "Student Name")),
          const SizedBox(height: 12),
          Material(
            color:
                Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8.0),
            elevation: 0.5,
            child: InkWell(
              onTap: _isAddingStudent ? null : _takeManualPhoto,
              borderRadius: BorderRadius.circular(8.0),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    Icon(Icons.camera_alt_outlined,
                        color:
                            Theme.of(context).colorScheme.onPrimaryContainer),
                    const SizedBox(width: 16.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Add Photo of Work (Camera)",
                              style: TextStyle(
                                  fontSize: 16,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer)),
                          Text(photoStatusText,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer
                                          .withOpacity(0.7))),
                        ],
                      ),
                    ),
                    if (_manualImages.isNotEmpty || hasPendingJobs)
                      IconButton(
                        icon: Icon(Icons.delete_sweep_outlined,
                            color: Theme.of(context).colorScheme.error),
                        onPressed: _isAddingStudent ? null : _clearManualImages,
                        tooltip: "Clear Photos for this Student",
                      )
                    else
                      const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),
          if (_manualImages.isNotEmpty || hasPendingJobs) ...[
            const SizedBox(height: 8),
            _ImagePreviewRow(
              imagePaths: _manualImages,
              processingCount: _manualImageProcessingCount,
              onImageTap: _isAddingStudent
                  ? null
                  : (idx) {
                      _showConfirmationDialog(
                          title: "Remove This Photo?",
                          content:
                              "Do you want to remove this specific photo from the current student's entry?",
                          confirmText: "Remove Photo",
                          onConfirm: () {
                            if (mounted) {
                              setState(() => _manualImages.removeAt(idx));
                            }
                          });
                    },
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                icon: _isAddingStudent
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.person_add_alt_1_outlined),
                label:
                    Text(_isAddingStudent ? "Adding..." : "Add This Student"),
                onPressed: _isAddingStudent || hasPendingJobs
                    ? null
                    : _addManualStudent,
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBatchEntryCard() {
    bool hasPendingJobs = _batchImageProcessingCount > 0;

    return _AppCard(
      title: "Add Uploaded Student",
      borderColor: Theme.of(context).colorScheme.secondary,
      child: Column(
        children: [
          TextField(
              controller: _batchNameController,
              focusNode: _batchNameFocusNode,
              decoration: const InputDecoration(labelText: "Student Name")),
          const SizedBox(height: 12),
          _ImagePreviewRow(
            imagePaths: _batchImages,
            processingCount: _batchImageProcessingCount,
            onImageTap: (idx) {
              _showConfirmationDialog(
                  title: "Remove This Photo?",
                  content: "Do you want to remove this photo from the batch?",
                  confirmText: "Remove Photo",
                  onConfirm: () {
                    if (mounted) {
                      setState(() => _batchImages.removeAt(idx));
                    }
                  });
            },
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                  onPressed: () {
                    setState(() {
                      _batchImages.clear();
                      _batchNameController.clear();
                      _batchImageProcessingCount = 0;
                    });
                  },
                  child: Text("Cancel",
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error))),
              ElevatedButton.icon(
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text("Add This Student"),
                onPressed: hasPendingJobs ? null : _addBatchStudent,
              ),
            ],
          )
        ],
      ),
    );
  }

  Future<void> _startGrading() async {
    if (_submissions.isEmpty) {
      _showToast("No student submissions to grade.", ToastType.error);
      return;
    }

    _showToast(
      "Starting... Please keep the app open and screen on.",
      ToastType.info,
      durationSeconds: 8,
    );
    _startKeepAwakeTimer();

    setState(() {
      _isGrading = true;
      _isCancellationRequested = false;
      _gradeResults.clear();
      _resultError = null;
      _studentsGradedSoFar = 0;
      _totalStudentsToGrade = _submissions.length;
      _gradingStatusMessage =
          "Initializing grading for $_totalStudentsToGrade students...";
    });
    await _saveGradeResults(); // Clear previous results

    try {
      if (_gradingReferenceData == null) {
        setState(() {
          _gradingStatusMessage = _gradingMode == GradingMode.text
              ? "Processing solution guide..."
              : "Generating solution guide...";
        });
        await _processReferenceMaterial(calledFromGrading: true);
        if (!mounted || _gradingReferenceData == null) {
          _showToast(
              "Failed to process reference material. Cannot start grading.",
              ToastType.error);
          setState(() => _isGrading = false);
          _stopKeepAwakeTimer();
          return;
        }
      }

      List<StudentSubmission> submissionsToGrade = [];
      for (final submission in _submissions) {
        final validPaths = await _validateImagePaths(submission.imagePaths);
        if (validPaths.length != submission.imagePaths.length ||
            validPaths.isEmpty) {
          setState(() {
            _gradeResults.add(GradeResult(
              name: submission.name,
              status: "failed_processing",
              feedback:
                  "One or more image files for this submission could not be read or were missing.",
              imageCount: submission.imagePaths.length,
            ));
            _studentsGradedSoFar++;
          });
        } else {
          submissionsToGrade.add(submission);
        }
      }
      await _saveGradeResults();

      await _processNextBatch(submissionsToGrade, 0);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGrading = false;
          _resultError = "An unexpected error started the grading process: $e";
        });
      }
      _showToast("An unexpected error occurred: $e", ToastType.error);
      _stopKeepAwakeTimer();
    }
  }

  // OLD _processNextBatch (for reference)
// Future<void> _processNextBatch(List<StudentSubmission> remainingSubmissions) async { ... }

// NEW AND IMPROVED _processNextBatch
  Future<void> _processNextBatch(
      List<StudentSubmission> remainingSubmissions, int gradedCount) async {
    if (remainingSubmissions.isEmpty || _isCancellationRequested) {
      if (mounted) {
        setState(() {
          _isGrading = false;
          _gradingStatusMessage = _isCancellationRequested
              ? "Grading cancelled."
              : "Grading complete!";
        });
      }
      _isCancellationRequested = false;
      _stopKeepAwakeTimer();
      return;
    }

    final int batchSize =
        math.min(GRADING_BATCH_SIZE, remainingSubmissions.length);
    final List<StudentSubmission> currentChunk =
        remainingSubmissions.sublist(0, batchSize);
    final List<StudentSubmission> nextSubmissions =
        remainingSubmissions.sublist(batchSize);

    // Pass the current number of graded students as the starting index
    await _processGradingChunk(currentChunk, gradedCount);

    if (mounted) {
      // For the next recursive call, update the count
      await _processNextBatch(nextSubmissions, gradedCount + batchSize);
    }
  }

  Future<void> _processGradingChunk(
      List<StudentSubmission> submissions, int startingIndex) async {
    if (submissions.isEmpty || _isCancellationRequested) {
      return;
    }

    if (mounted) {
      final int startNumber = startingIndex + 1;
      final int endNumber = startingIndex + submissions.length;
      setState(() {
        _gradingStatusMessage =
            "Grading students $startNumber to $endNumber of $_totalStudentsToGrade...";
      });
    }

    int creditsRequired =
        submissions.fold(0, (sum, s) => sum + s.imagePaths.length);
    if (!_isFreePeriodActive) {
      if (_remainingImageCredits < creditsRequired) {
        for (final sub in submissions) {
          _gradeResults.add(GradeResult(
            name: sub.name,
            status: "failed_processing",
            feedback:
                "Grading stopped. Not enough credits to process this student.",
            imageCount: sub.imagePaths.length,
          ));
          if (mounted) {
            setState(() {
              _studentsGradedSoFar++;
            });
          }
        }
        if (mounted) {
          setState(() {
            _resultError = "Insufficient credits to continue.";
          });
        }
        _showToast(
            "Grading stopped due to insufficient credits.", ToastType.error);
        return;
      }
    }

    Map<String, dynamic> isolateArgs = {
      'apiKeys': _apiKeys,
      'currentApiKeyIndex': _currentApiKeyIndex,
      'submissions': submissions.map((s) => s.toJson()).toList(),
      'gradingModeIndex': _gradingMode.index,
      'gradingReferenceData': _gradingReferenceData,
      'temperatureLevel': GRADING_TEMPERATURE,
    };

    try {
      Map<String, dynamic> gradingOutput =
          await compute(_runGradingIsolate, isolateArgs);
      if (!mounted) return;

      if (gradingOutput['usedKeyIndex'] != null) {
        await _saveCurrentApiKeyIndex(gradingOutput['usedKeyIndex']);
      }

      // If the entire call failed without returning a results list, split and retry.
// PASTE THIS DEFINITIVE BLOCK IN ITS PLACE
//
// This is the final, correct retry logic.
      String errorMessage = gradingOutput['error']?.toString() ?? "";
      bool isHardApiError = gradingOutput['results'] == null;
      bool isInvalidJsonError =
          errorMessage.contains('Invalid or empty JSON response from AI');

// A retry is needed if it's a hard API error OR our specific invalid JSON error.
      if ((isHardApiError || isInvalidJsonError) && submissions.length > 1) {
        if (mounted) {
          setState(() =>
              _gradingStatusMessage = "A batch failed. Isolating the issue...");
        }
        developer.log(
            "Batch of ${submissions.length} failed with a retryable error. Splitting.");
        final mid = (submissions.length / 2).ceil();

        await _processGradingChunk(submissions.sublist(0, mid), startingIndex);
        await _processGradingChunk(
            submissions.sublist(mid), startingIndex + mid);
        return; // IMPORTANT: Stop processing this chunk and let the retries handle it.
      }

      List<dynamic> resultsData = gradingOutput['results'] ?? [];
      List<GradeResult> newResults =
          resultsData.map((r) => GradeResult.fromJson(r)).toList();

      int creditsToDeduct = 0;
      for (var result in newResults) {
        if (result.status == "success") {
          creditsToDeduct += result.imageCount;
        }
      }
      if (creditsToDeduct > 0 && !_isFreePeriodActive) {
        await _updateCredits(-creditsToDeduct, add: true);
      }

      setState(() {
        // Remove any placeholders if they exist, then add final results
        _gradeResults
            .removeWhere((r) => submissions.any((s) => s.name == r.name));
        _gradeResults.addAll(newResults);
        _studentsGradedSoFar += newResults.length;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _resultError = "A critical error occurred processing a batch: $e";
        });
      }
    } finally {
      if (mounted) await _saveGradeResults();
    }
  }

  void _cancelGrading() {
    if (_isGrading && mounted) {
      _stopKeepAwakeTimer();
      setState(() {
        _isCancellationRequested = true;
        _gradingStatusMessage =
            "Cancellation requested... Finishing current operation...";
      });
      _showToast("Cancellation requested. The process will stop shortly.",
          ToastType.info);
    }
  }

  String _getStartGradingButtonText() {
    if (_gradingMode == GradingMode.text) {
      if (_solutionGuideImagePaths.isEmpty && _gradingReferenceData == null) {
        return "Add Solution Guide";
      }
    } else {
      if (_guideGenerationRecitationError) {
        return "Copyright Issue: Use Solution Mode";
      }
      if (_questionPaperImagePaths.isEmpty && _gradingReferenceData == null) {
        return "Add Question Paper";
      }
    }
    if (_submissions.isEmpty) return "Add Submissions";
    int creditsRequired = 0;
    if (_gradingReferenceData == null) {
      creditsRequired += _gradingMode == GradingMode.text
          ? _solutionGuideImagePaths.length
          : _questionPaperImagePaths.length;
    }
    for (var sub in _submissions) {
      creditsRequired += sub.imagePaths.length;
    }
    if (!_isFreePeriodActive &&
        creditsRequired > _remainingImageCredits &&
        creditsRequired > 0) {
      return "Insufficient Credits ($creditsRequired needed)";
    }
    return "Start AI Grading";
  }

  bool _canStartGrading() {
    if (_isProcessingReference || _isGrading) return false;
    if (_submissions.isEmpty) return false;
    if (_solutionGuideProcessingCount > 0 || _questionPaperProcessingCount > 0)
      return false;
    bool referenceAvailable = false;
    if (_gradingMode == GradingMode.text) {
      referenceAvailable =
          _gradingReferenceData != null || _solutionGuideImagePaths.isNotEmpty;
    } else {
      if (_guideGenerationRecitationError) return false;
      referenceAvailable =
          _gradingReferenceData != null || _questionPaperImagePaths.isNotEmpty;
    }
    if (!referenceAvailable) return false;
    int creditsRequired = 0;
    if (_gradingReferenceData == null) {
      creditsRequired += _gradingMode == GradingMode.text
          ? _solutionGuideImagePaths.length
          : _questionPaperImagePaths.length;
    }
    for (var sub in _submissions) {
      creditsRequired += sub.imagePaths.length;
    }
    if (!_isFreePeriodActive &&
        creditsRequired > _remainingImageCredits &&
        creditsRequired > 0) {
      return false;
    }
    return true;
  }

  Widget _buildGradingActionSection() {
    String buttonText = _getStartGradingButtonText();
    bool canStart = _canStartGrading();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 16.0),
      child: Column(
        children: [
          if (_isGrading) ...[
            if (_gradingStatusMessage.contains("solution guide") ||
                _gradingStatusMessage.contains("Initializing"))
              const LinearProgressIndicator()
            else
              LinearProgressIndicator(
                value: _totalStudentsToGrade > 0
                    ? _studentsGradedSoFar / _totalStudentsToGrade
                    : 0,
                valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary),
                backgroundColor:
                    Theme.of(context).colorScheme.primary.withOpacity(0.3),
                minHeight: 6,
              ),
            const SizedBox(height: 8),
            Text(_gradingStatusMessage, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.cancel_outlined),
              label: const Text("Cancel Grading"),
              style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error),
              onPressed: _isCancellationRequested ? null : _cancelGrading,
            ),
          ] else ...[
            Tooltip(
              message: canStart ? "Begin grading process" : buttonText,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.auto_fix_high_outlined),
                label: Text(buttonText, style: const TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50)),
                onPressed: canStart ? _startGrading : null,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _loadGradeResults() async {
    var data = await _loadJsonFile(_gradesJsonPath);
    if (data != null && data is List) {
      _gradeResults = data.map((item) => GradeResult.fromJson(item)).toList();
    }
    if (mounted) setState(() {});
  }

  Future<void> _saveGradeResults() async {
    await _saveJsonFile(
        _gradesJsonPath, _gradeResults.map((r) => r.toJson()).toList());
  }

  Widget _buildResultsSection() {
    if (_gradeResults.isEmpty && !_isGrading) {
      return const SizedBox.shrink();
    }
    if (_isGrading && _gradeResults.isEmpty && _resultError == null) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(
            child: Text("Grading in progress... Results will appear here.")),
      );
    }

    int successCount = _gradeResults.where((r) => r.status == "success").length;
    int failedCount =
        _gradeResults.where((r) => r.status.startsWith("failed_")).length;
    int cancelledCount =
        _gradeResults.where((r) => r.status == "cancelled").length;

    // --- NEW: Create a list for display based on the reversed flag ---
    final List<GradeResult> displayResults =
        _resultsReversed ? _gradeResults.reversed.toList() : _gradeResults;

    return _AppCard(
      title: "Grading Results",
      // --- NEW: Add an action button to the card header to reverse the sort ---
      actions: [
        if (_gradeResults.length > 1)
          IconButton(
            icon: const Icon(Icons.swap_vert),
            tooltip: "Reverse Order",
            onPressed: () {
              setState(() {
                _resultsReversed = !_resultsReversed;
              });
            },
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .secondaryContainer
                    .withOpacity(0.5),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  width: 1,
                )),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "AI grading provides a strong starting point. Please review results for accuracy. Especially with regards to tallying scores, advanced maths, and diagram analysis",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
              "Showing ${displayResults.length} of ${_totalStudentsToGrade} Result(s): $successCount Successful, $failedCount Failed, $cancelledCount Cancelled.",
              style: const TextStyle(fontWeight: FontWeight.bold)),
          if (_resultError != null)
            _buildErrorBox(
                title: "Grading Batch Error",
                message: _resultError!,
                context: context),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: isProcessingExcel
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.file_download_outlined),
            label:
                Text(isProcessingExcel ? "Processing..." : "Download Results"),
            onPressed: (displayResults.isEmpty ||
                    isProcessingExcel ||
                    _isDownloadServerActive)
                ? null
                : _downloadResultsExcel,
          ),
          const SizedBox(height: 8),
          // --- MODIFIED: Use the new 'displayResults' list ---
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayResults.length,
            itemBuilder: (context, index) {
              final result = displayResults[index];
              Color cardColor;
              IconData statusIcon;
              switch (result.status) {
                case "success":
                  cardColor = Colors.green.withOpacity(0.1);
                  statusIcon = Icons.check_circle;
                  break;
                case "failed_ai":
                case "failed_processing":
                  cardColor = Colors.red.withOpacity(0.1);
                  statusIcon = Icons.error;
                  break;
                case "cancelled":
                  cardColor = Colors.orange.withOpacity(0.1);
                  statusIcon = Icons.cancel;
                  break;
                case "missing_from_response":
                  cardColor = Colors.blueGrey.withOpacity(0.1);
                  statusIcon = Icons.help_outline_rounded;
                  break;
                default:
                  cardColor = Colors.grey.withOpacity(0.1);
                  statusIcon = Icons.pending_actions_outlined;
              }
              return Card(
                color: cardColor,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                              child: Text(result.name,
                                  style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold))),
                          if (result.status == "success" &&
                              result.score != null)
                            _ScoreCircle(score: result.score!, size: 40)
                          else
                            Icon(statusIcon,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white70
                                    : Colors.black54),
                          IconButton(
                            icon: const Icon(Icons.flag_outlined),
                            tooltip: 'Report this feedback',
                            onPressed: () {
                              _sendReport(
                                reportType: 'inappropriate',
                                contextIdentifier: result.name,
                                content: result.feedback,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Report sent – thank you!')),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                          "Status: ${result.status.replaceAll('_', ' ').capitalize()}",
                          style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Theme.of(context).hintColor)),
                      if (result.attempts > 1)
                        Text("(Processed in ${result.attempts} attempts)",
                            style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).hintColor)),
                      const SizedBox(height: 8),
                      const Text("Feedback:",
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      md.MarkdownBody(
                        data: result.feedback.isEmpty
                            ? "No feedback provided."
                            : result.feedback,
                        selectable: true,
                        extensionSet: ExtensionSet.gitHubWeb,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showConfirmationDialog(
      {required String title,
      required String content,
      required String confirmText,
      required VoidCallback onConfirm,
      VoidCallback? onCancel}) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
                child: const Text("Cancel"),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  onCancel?.call();
                }),
            ElevatedButton(
                child: Text(confirmText),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  onConfirm();
                }),
          ],
        );
      },
    );
  }

  int _calculateTotalPossibleMarks({
    required List<dynamic> idealScores,
  }) {
    int totalMarks = 0;
    try {
      for (var item in idealScores) {
        if (item is Map<String, dynamic> && item.containsKey('marks')) {
          final int? marks = int.tryParse(item['marks'].toString());
          if (marks != null) {
            totalMarks += marks;
          }
        }
      }
    } catch (e) {
      developer.log("Error calculating total possible marks from ideal scores",
          error: e);
      return 0;
    }
    return totalMarks;
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = ChangeNotifierProvider.of<ThemeNotifier>(context);
    bool isDarkMode = themeNotifier.themeMode == ThemeMode.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text("AI Grader",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).appBarTheme.foregroundColor)),
        actions: [
          if (!_isFreePeriodActive)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Chip(
                avatar: Icon(Icons.monetization_on_outlined,
                    color: Theme.of(context).chipTheme.iconTheme?.color),
                label: Text("Credits: $_remainingImageCredits",
                    style: Theme.of(context).chipTheme.labelStyle),
                backgroundColor: Theme.of(context).chipTheme.backgroundColor,
              ),
            ),
          IconButton(
            icon: Icon(isDarkMode
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined),
            tooltip:
                isDarkMode ? "Switch to Light Theme" : "Switch to Dark Theme",
            onPressed: () => themeNotifier.toggleTheme(),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(8.0),
            children: <Widget>[
              if (!_isFreePeriodActive) _buildPaymentSection(),
              _buildGradingReferenceSection(),
              _buildStudentSubmissionsSection(),
              _buildGradingActionSection(),
              if (_isGrading || _gradeResults.isNotEmpty)
                _buildResultsSection(),
              const SizedBox(height: 70),
            ],
          ),
          if (_isDownloadServerActive)
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton(
                backgroundColor: Colors.green,
                onPressed: () {
                  _localFileServer.stop();
                  setState(() => _isDownloadServerActive = false);
                },
                child: const Icon(Icons.download_done),
              ),
            ),
          if (_toastMessage != null)
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Center(child: _buildToastWidget()),
            ),
        ],
      ),
    );
  }
}

// =========================================================================
// == TOP-LEVEL FUNCTIONS & HELPER WIDGETS ==
// =========================================================================

Uint8List? _compressImageIsolate(Uint8List originalBytes) {
  try {
    img.Image? decodedImage = img.decodeImage(originalBytes);
    if (decodedImage == null) {
      developer.log("Isolate: Failed to decode image.");
      return null;
    }

    img.Image resizedImage = decodedImage;
    if (decodedImage.width > MAX_IMAGE_DIMENSION ||
        decodedImage.height > MAX_IMAGE_DIMENSION) {
      resizedImage = (decodedImage.width > decodedImage.height)
          ? img.copyResize(decodedImage, width: MAX_IMAGE_DIMENSION)
          : img.copyResize(decodedImage, height: MAX_IMAGE_DIMENSION);
    }
    return Uint8List.fromList(
        img.encodeJpg(resizedImage, quality: JPEG_QUALITY));
  } catch (e) {
    developer.log("Isolate: Error during image compression: $e");
    return null;
  }
}

int _calculateScoreFromBreakdown(List<dynamic> breakdownList) {
  int totalObtained = 0;
  try {
    for (var item in breakdownList) {
      if (item is Map<String, dynamic>) {
        final dynamic obtainedValue = item['obtained'];
        if (obtainedValue != null) {
          final int? obtained = int.tryParse(obtainedValue.toString());
          if (obtained != null) {
            totalObtained += obtained;
          }
        }
      }
    }
  } catch (e) {
    developer.log("Error calculating score from breakdown: $e", error: e);
    return 0;
  }
  return totalObtained;
}

Future<Map<String, dynamic>> _runGradingIsolate(
    Map<String, dynamic> args) async {
  List<String> apiKeys = List<String>.from(args['apiKeys']);
  int currentApiKeyIndex = args['currentApiKeyIndex'];
  List<StudentSubmission> submissions = (args['submissions'] as List)
      .map((s) => StudentSubmission.fromJson(s))
      .toList();
  Map<String, dynamic>? gradingReferenceData = args['gradingReferenceData'];
  double temperature = args['temperatureLevel'];
  String? solutionText = gradingReferenceData?['solution_text'];
  int? totalPossibleMarks = gradingReferenceData?['total_possible_marks'];

  if (solutionText == null || totalPossibleMarks == null) {
    List<GradeResult> results = submissions
        .map((sub) => GradeResult(
              name: sub.name,
              feedback: "Grading failed: The solution guide was not available.",
              status: "failed_processing",
              imageCount: sub.imagePaths.length,
            ))
        .toList();
    return {
      'results': results.map((r) => r.toJson()).toList(),
      'error': 'Solution guide or total marks missing in grading isolate.',
    };
  }

  List<Map<String, dynamic>> studentWorkParts = [];
  List<String> studentNamesInBatch = [];

  for (var submission in submissions) {
    studentNamesInBatch.add(submission.name);
    studentWorkParts
        .add({'text': "START OF WORK FOR STUDENT: ${submission.name}"});
    for (var imagePath in submission.imagePaths) {
      var imgData = await _processAndEncodeImageIsolateHelper({
        'imagePath': imagePath,
        'contextDescription': "work_for_${submission.name}"
      });
      if (imgData['error'] != null) {
        List<GradeResult> results = [];
        for (var sub in submissions) {
          results.add(GradeResult(
            name: sub.name,
            feedback:
                "Grading failed: Could not process an image file for ${sub.name}.",
            status: "failed_processing",
            imageCount: sub.imagePaths.length,
          ));
        }
        return {
          'results': results.map((r) => r.toJson()).toList(),
          'error': 'Image encoding failed during grading.',
        };
      }
      studentWorkParts.add({
        'inline_data': {
          'mime_type': imgData['mime_type'],
          'data': imgData['data']
        }
      });
    }
    studentWorkParts
        .add({'text': "END OF WORK FOR STUDENT: ${submission.name}"});
  }

  final List<dynamic>? marksAllocation =
      gradingReferenceData?['marks_allocation'] as List<dynamic>?;
  final String marksAllocationForPrompt =
      marksAllocation != null ? jsonEncode(marksAllocation) : "[]";

  String mainPrompt = """
    You are an expert AI Grader, acting as a mentor. Your goal is to provide feedback that is not just accurate, but also educational for the student.

    **CONTEXT AND RULES (STRICT):**
    
    1.  **Official Solution Guide:** You MUST adhere to the following solution guide for determining correctness.
        --- START OF SOLUTION GUIDE ---
        $solutionText
        --- END OF SOLUTION GUIDE ---

    2.  **Official Marking Scheme:** You MUST use this exact marking scheme. DO NOT deviate or invent your own marks.
        --- START OF MARKING SCHEME (JSON) ---
        $marksAllocationForPrompt
        --- END OF MARKING SCHEME ---

    **PROCESS FOR EACH STUDENT (Follow these 4 steps strictly):**
    1.  **Analyze and Grade:** For each question, compare the student's work to the solution guide and use the **Official Marking Scheme** to award marks (`X`).
    2.  **Format Score Correctly:** When you state the score for a part, look up the corresponding question in the **Official Marking Scheme** to find its maximum possible marks (`Y`) and format the score as `(X/Y marks)`.
    3.  **Create Structured Breakdown:** Create a machine-readable report of only the marks the student obtained for each sub-part. This must match the keys from the Official Marking Scheme.
    4.  **Write High-Quality, Student-Centric Feedback:** This is the most important step.
        -   **Speak to the Student as if they are your student:** Write directly to the student using "you" and "your". (e.g., "You did a great job...", "Your final answer...").
        -   **Be Full of Life:** Avoid dry, robotic statements.
        -   **Embed marks allocations in this feedback so that the student see how many manrks they scored at each scoring point in the solution guide. 
        -   **Do not say things like according to the solution guide/from the solution guide. Sound authoritative in your words because truth is absolute. Only use the solution guide as a guide.
        -   **Explain the "Why":** Clearly explain *why* they got the marks they did. For correct answers, praise their methodology ("Your use of the formula was good!"). For incorrect answers, explain *why* they lost the marks ("You lost a mark here because the units were missing.").
        -   **Give Actionable Advice:** Provide concrete advice on how to improve at the end of the feedback. (e.g., "Next time, remember to double-check your calculations," or "Let's review the chapter on kinetic energy to solidify this concept.").

    **JSON OUTPUT FORMAT (MANDATORY AND STRICT):**
    Your response must be a single, valid JSON object with a single key `"results"`, which is a list. Each object in the list represents one student and MUST have exactly these THREE keys:
    
    1.  `"name"`: (string) The student's name.
    2.  `"feedback"`: (string) The complete, high-quality feedback text, including the correctly formatted `(X/Y marks)` for each part that shd get scored as per the solution guide.
    3.  `"marks_breakdown"`: (list of objects) A list containing only the marks the student **obtained**. The keys in this breakdown should match the question identifiers from the official marking scheme.

    **EXAMPLE OF A SINGLE STUDENT OBJECT:**
    ```json
    {
      "name": "Alice",
      "feedback": "### Question 1\\n**(a)** Alice, you've done an excellent job stating the formula here, that's a good start!...... (1/1 marks)\\n**(b)** Your approach to this part was good, but it looks like there was a calculation error in the final step. It's always good to double-check the math!. (2/5 marks)",
      "marks_breakdown": [
        { "question": "Q1 a", "obtained": 1 },
        { "question": "Q1 b", "obtained": 2 }
      ]
    }
    ```
    You must provide a result object in this exact format for every single student in this batch: ${studentNamesInBatch.join(', ')}.
    """;

  List<Map<String, dynamic>> requestParts = [
    {'text': mainPrompt},
    ...studentWorkParts
  ];

  Map<String, dynamic> apiResponse = await _callGeminiApiWithRotation(
      apiKeys, currentApiKeyIndex, requestParts,
      model: _geminiProModel, temperature: temperature, useJsonMode: true);

  if (apiResponse['error'] != null) {
    List<GradeResult> results = [];
    for (var submission in submissions) {
      results.add(GradeResult(
        name: submission.name,
        feedback: "Grading failed due to an API error: ${apiResponse['error']}",
        status: "failed_ai",
        imageCount: submission.imagePaths.length,
      ));
    }
    return {
      'results': results.map((r) => r.toJson()).toList(),
      'error': apiResponse['error'],
      'usedKeyIndex': apiResponse['usedKeyIndex'],
    };
  }

  final Map<String, dynamic> parsedJson =
      _robustlyParseJson(apiResponse['text'] ?? "");
  List<GradeResult> processedResults = [];

  // Handle both single object and list of objects
  List<dynamic> resultsList = [];
  if (parsedJson.containsKey('results') && parsedJson['results'] is List) {
    resultsList = parsedJson['results'];
  } else if (parsedJson.containsKey('name')) {
    resultsList = [parsedJson]; // Wrap single object in a list
  }

  if (resultsList.isEmpty) {
    List<GradeResult> results = submissions
        .map((sub) => GradeResult(
              name: sub.name,
              feedback:
                  "⚠️  The AI had trouble reading this particular image set. "
                  "This usually happens when an image is blurry, very dark, or has unusual handwriting. "
                  "Try:\n"
                  "1. Retake or rescan the page with better lighting.\n"
                  "2. Make sure each page is clearly visible and not folded.\n"
                  "3. Then re-add this student and grade again.",
              status: "failed_ai",
              imageCount: sub.imagePaths.length,
            ))
        .toList();
    return {
      'results': results.map((r) => r.toJson()).toList(),
      'error': 'Invalid or empty JSON response from AI.',
      'usedKeyIndex': apiResponse['usedKeyIndex'],
    };
  }

  for (var item in resultsList) {
    if (item is Map<String, dynamic> &&
        item.containsKey('name') &&
        item.containsKey('feedback') &&
        item.containsKey('marks_breakdown') &&
        item['marks_breakdown'] is List) {
      String studentName = item['name'];
      final originalSubmission = submissions.firstWhere(
          (sub) => sub.name == studentName,
          orElse: () => StudentSubmission(name: '', imagePaths: []));
      if (originalSubmission.name.isNotEmpty) {
        processedResults.add(GradeResult(
          name: studentName,
          marks_obtained: _calculateScoreFromBreakdown(item['marks_breakdown']),
          marks_possible: totalPossibleMarks,
          feedback: item['feedback'],
          status: "success",
          marksBreakdown:
              List<Map<String, dynamic>>.from(item['marks_breakdown']),
          imageCount: originalSubmission.imagePaths.length,
        ));
      }
    }
  }

  for (var submission in submissions) {
    if (!processedResults.any((res) => res.name == submission.name)) {
      processedResults.add(GradeResult(
        name: submission.name,
        feedback:
            "Processing failed for this student. The AI did not include them in its response for this batch.",
        status: "missing_from_response",
        imageCount: submission.imagePaths.length,
      ));
    }
  }

  return {
    'results': processedResults.map((r) => r.toJson()).toList(),
    'usedKeyIndex': apiResponse['usedKeyIndex'],
  };
}

Future<Map<String, dynamic>> _processReferenceMaterialIsolate(
    Map<String, dynamic> args) async {
  List<String> apiKeys = List<String>.from(args['apiKeys']);
  int currentApiKeyIndex = args['currentApiKeyIndex'];
  List<String> imagePaths = List<String>.from(args['imagePaths']);
  String context = args['context'];

  List<Map<String, dynamic>> imageParts = [];
  for (int i = 0; i < imagePaths.length; i++) {
    Map<String, dynamic> imageProcessResult =
        await _processAndEncodeImageIsolateHelper({
      'imagePath': imagePaths[i],
      'contextDescription': '${context}_image_${i + 1}'
    });
    if (imageProcessResult['error'] != null) {
      return {'error': 'Reference processing failed at image encoding'};
    }
    imageParts.add({
      'inline_data': {
        'mime_type': imageProcessResult['mime_type'],
        'data': imageProcessResult['data']
      }
    });
  }

  String prompt;
  if (context == "solution_guide") {
    prompt = """
    You are an expert AI assistant specializing in document analysis. Your task is to meticulously analyze the provided images and perform three tasks with high fidelity.

    **Task 1: Accurate Transcription**
    Your primary goal is to accurately transcribe all text from the images. The transcription should be a faithful representation of the content.
    - You SHOULD very professionally format the text in the photos, like making some fonts larger or making some texts bold as you judge, but the original text itself MUST remain unaltered.
    - DO NOT add any of your own commentary or explanations. Your role is to transcribe, not to interpret or summarize.
    - DO NOT omit any part of the text, unless you can clearly see that it's not part of the solution guide the user intends (e.g., page footers, unrelated notes).

    **Task 2: Marks Allocation**
    Analyze the text you transcribed. If it already contains a clear marks allocation scheme, extract it. If it does NOT, you must create a logical one. For each question and sub-part, determine a reasonable mark value based on its complexity. The output should be a structured list.

    **Task 3: Ideal Student Simulation**
    Based on any instructions in the text (e.g., "Answer any 4 questions") and the marks you allocated, determine which questions an ideal student would answer to maximize their score. Report the marks for each of these chosen questions.

    **JSON OUTPUT FORMAT (MANDATORY):**
    Your response must be a single, valid JSON object with the following three keys:
    {
      "solution_text": "...",
      "marks_allocation": [ {"question": "Q1 a", "marks": 5}, {"question": "Q1 b", "marks": 10} ],
      "ideal_student_scores": [ {"question": "Q1 a", "marks": 5}, {"question": "Q1 b", "marks": 10} ]
    }
    """;
  } else {
    // Question Paper
    prompt = """
    You are an Expert Examination Assessor. Your task is to create a complete Examiner's Marking Guide from the provided question paper images. This is a technical task requiring a specific output format.

    **Primary Tasks:**
    1.  **Generate Solutions:** For every question and sub-part, provide a detailed, step-by-step solution.
    2.  **Embed Marks Allocation:** This is a critical instruction. For every step in your solution that earns a mark, you MUST indicate it directly in the text using a clear marker. For example:
        - Correct formula stated: *(01 mark)*
        - Correct substitution of values: *(03 marks)*
        - Final correct answer: *(01 mark)*
        The `solution_text` you generate MUST be a detailed marking guide, not just a list of answers.
    3.  **Analyze Instructions:** Identify any specific instructions, such as "Answer any FIVE questions."
    4.  **Simulate Ideal Student:** Based on the instructions and your marks scheme, report which questions and their corresponding marks an ideal student would answer to get the maximum possible score.
    5.  **Format your marking guide professionally with each question part/subpart starting on a new line.

    **EXAMPLE `solution_text` FORMAT:**
    ```
    ### Question 1
    **(a)** The formula for kinetic energy is KE = 1/2 * m * v^2. *(01 - 1 mark for correct formula)*
    **(b)** Substituting the values: KE = 0.5 * 10kg * (5m/s)^2. *(03 - 3 marks for correct substitution)*
    Final answer: KE = 125 J. *(01 - 1 mark for correct final answer with units)*
    ```

    **JSON OUTPUT FORMAT (MANDATORY):**
    Your response must be a single, valid JSON object with the following three keys:
    {
      "solution_text": "...",
      "marks_allocation": [ {"question": "Q1 a", "marks": 1}, {"question": "Q1 b", "marks": 2} ],
      "ideal_student_scores": [ {"question": "Q1 a", "marks": 1}, {"question": "Q1 b", "marks": 2} ]
    }
    """;
  }

  List<Map<String, dynamic>> parts = [
    {'text': prompt},
    ...imageParts
  ];

  const int maxRetries = 3;
  for (int i = 0; i < maxRetries; i++) {
    developer.log("Processing reference material, attempt ${i + 1}...");
    final response = await _callGeminiApiWithRotation(
        apiKeys, currentApiKeyIndex, parts,
        model: _geminiProModel, temperature: 0.0, useJsonMode: true);

    if (response['error'] == null) {
      final Map<String, dynamic> parsedJson =
          _robustlyParseJson(response['text']);
      final String? solutionText = parsedJson['solution_text'] as String?;
      final List<dynamic>? idealScores =
          parsedJson['ideal_student_scores'] as List?;

      if (solutionText != null &&
          solutionText.isNotEmpty &&
          idealScores != null &&
          idealScores.isNotEmpty) {
        developer.log("Successfully processed reference on attempt ${i + 1}.");
        final List<dynamic>? marksAllocation =
            parsedJson['marks_allocation'] as List?;

        return {
          'solution_text': solutionText,
          'ideal_student_scores': idealScores,
          'marks_allocation': marksAllocation ?? [],
          'usedKeyIndex': response['usedKeyIndex']
        };
      }
    } else if (response['recitationError'] == true) {
      return response;
    }
    developer.log("Attempt ${i + 1} failed. Retrying if possible...");
    if (i < maxRetries - 1) {
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  developer
      .log("Failed to process reference material after $maxRetries attempts.");
  return {
    'error':
        "Please check your internet connection and try again. Or try uploading your own solution/marking guide"
  };
}

Map<String, dynamic> _robustlyParseJson(String rawTextFromApi) {
  String text = rawTextFromApi.trim();
  try {
    return jsonDecode(text) as Map<String, dynamic>;
  } catch (e) {/* In case of failure, try to extract from markdown block */}
  try {
    final regex = RegExp(r'```json\s*([\s\S]*?)\s*```', multiLine: true);
    final match = regex.firstMatch(text);
    if (match != null && match.group(1) != null) {
      return jsonDecode(match.group(1)!) as Map<String, dynamic>;
    }
  } catch (e) {/* In case of failure, try to extract from raw string */}
  try {
    int startIndex = text.indexOf('{');
    int endIndex = text.lastIndexOf('}');
    if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
      String jsonBlock = text.substring(startIndex, endIndex + 1);
      return jsonDecode(jsonBlock) as Map<String, dynamic>;
    }
  } catch (e) {/* All parsing failed */}
  developer.log("Robust Parser: All layers failed for input: $rawTextFromApi");
  return {};
}

Future<Map<String, dynamic>> _callGeminiApiWithRotation(
  List<String> apiKeys,
  int startingIndex,
  List<Map<String, dynamic>> parts, {
  String model = _geminiProModel,
  double temperature = 0.4,
  bool useJsonMode = false,
}) async {
  int attemptCount = 0;
  List<int> triedIndices = [];

  if (apiKeys.isEmpty) {
    return {
      'error': 'Configuration issue: No API keys provided.',
      'usedKeyIndex': startingIndex
    };
  }

  while (attemptCount < apiKeys.length) {
    int effectiveIndex = (startingIndex + attemptCount) % apiKeys.length;

    if (triedIndices.contains(effectiveIndex)) {
      attemptCount++;
      continue;
    }

    triedIndices.add(effectiveIndex);
    String currentKey = apiKeys[effectiveIndex];

    developer.log(
        "→ Using Key ${effectiveIndex + 1}/${apiKeys.length}: ${currentKey.substring(0, 6)}...");

    final response = await _callGeminiApi(currentKey, parts,
        model: model, temperature: temperature, useJsonMode: useJsonMode);

    if (response['error'] != null) {
      String error = response['error'].toString();
      String upperError = error.toUpperCase();

      bool isKeyProblem = upperError.contains("QUOTA") ||
          upperError.contains("429") ||
          upperError.contains("RESOURCE_EXHAUSTED") ||
          upperError.contains("403") ||
          (upperError.contains("400") &&
              upperError.contains("API KEY NOT VALID"));

      if (isKeyProblem) {
        developer.log(
            "← Key ${effectiveIndex + 1} failed (Quota/Forbidden/Invalid). Rotating to next key.");
        attemptCount++;
        continue;
      }

      developer.log(
          "← Key ${effectiveIndex + 1} failed with a non-recoverable error: $error");
      return {
        ...response,
        'error': 'Processing error. Please try again later. Details: $error',
        'usedKeyIndex': effectiveIndex
      };
    }

    developer.log("← Key ${effectiveIndex + 1} succeeded");
    return {...response, 'usedKeyIndex': effectiveIndex};
  }

  developer.log("← All API keys failed. No more keys to try.");
  return {
    'error':
        'All available API keys have exceeded their quota. Please try again later.',
    'triedIndices': triedIndices
  };
}

Future<Map<String, dynamic>> _processAndEncodeImageIsolateHelper(
    Map<String, dynamic> args) async {
  String imagePath = args['imagePath'];
  String contextDescription = args['contextDescription'] ?? 'image';
  developer.log(
      "Isolate: Reading and encoding pre-compressed image $imagePath for $contextDescription");
  try {
    File imageFile = File(imagePath);
    if (!await imageFile.exists()) {
      return {'error': 'Pre-processed file not found: $imagePath'};
    }
    Uint8List imageBytes = await imageFile.readAsBytes();
    String base64Image = base64Encode(imageBytes);
    return {'mime_type': 'image/jpeg', 'data': base64Image};
  } catch (e, s) {
    developer.log("Isolate: Error encoding image $imagePath: $e",
        error: e, stackTrace: s);
    return {'error': 'Failed to encode image $imagePath: $e'};
  }
}

Future<Map<String, dynamic>> _callGeminiApi(
    String apiKey, List<Map<String, dynamic>> parts,
    {String model = _geminiProModel,
    double temperature = 0.4,
    bool useJsonMode = false}) async {
  final url = Uri.parse("$_googleApiBaseUrl$model:generateContent?key=$apiKey");
  final headers = {'Content-Type': 'application/json; charset=utf-8'};

  final Map<String, dynamic> generationConfig = {
    'temperature': temperature,
    'maxOutputTokens': 64000,
    'thinkingConfig': {'thinkingBudget': 0},
  };
  if (useJsonMode) {
    generationConfig['responseMimeType'] = 'application/json';
  }

  final body = jsonEncode({
    'contents': [
      {'parts': parts},
    ],
    'generationConfig': generationConfig,
    "safetySettings": [
      {
        "category": "HARM_CATEGORY_HARASSMENT",
        "threshold": "BLOCK_MEDIUM_AND_ABOVE"
      },
      {
        "category": "HARM_CATEGORY_HATE_SPEECH",
        "threshold": "BLOCK_MEDIUM_AND_ABOVE"
      },
      {
        "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
        "threshold": "BLOCK_MEDIUM_AND_ABOVE"
      },
      {
        "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
        "threshold": "BLOCK_MEDIUM_AND_ABOVE"
      }
    ]
  });

  try {
    final response = await http
        .post(url, headers: headers, body: body)
        .timeout(const Duration(seconds: API_TIMEOUT_SECONDS));

    final String responseBody =
        utf8.decode(response.bodyBytes, allowMalformed: true);

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(responseBody);

      if (jsonResponse['promptFeedback'] != null &&
          jsonResponse['promptFeedback']['blockReason'] != null) {
        String reason = jsonResponse['promptFeedback']['blockReason'];
        developer.log("Content blocked by safety filters: $reason");
        return {
          'error': 'Request blocked by safety filters: $reason',
          'recitationError': reason.toUpperCase().contains("RECITATION"),
        };
      }

      final text = jsonResponse['candidates']?[0]?['content']?['parts']?[0]
          ?['text'] as String?;

      if (text != null) {
        return {'text': text};
      } else {
        developer.log(
            "API response format unexpected, no text found. Body: $responseBody");
        return {
          'error': 'Unexpected API response format: No text content found.'
        };
      }
    } else {
      developer
          .log("Gemini API Error: ${response.statusCode}\nBody: $responseBody");
      return {'error': 'API Error ${response.statusCode}: $responseBody'};
    }
  } on TimeoutException {
    return {
      'error':
          'Request timed out after $API_TIMEOUT_SECONDS seconds. Please check your internet connection'
    };
  } on FormatException catch (e) {
    developer.log("Failed to parse JSON response from API.", error: e);
    return {'error': 'Invalid API response structure.'};
  } on http.ClientException catch (e) {
    developer.log("Client-side network error: $e", error: e);
    return {
      'error':
          'Network error. Please check your internet connection and try again.'
    };
  } catch (e) {
    developer.log("An unexpected error occurred in _callGeminiApi: $e",
        error: e);
    return {
      'error': 'An unexpected error occurred. Please try again. Details: $e'
    };
  }
}

class _ImagePreviewRow extends StatelessWidget {
  final List<String> imagePaths;
  final Function(int)? onImageTap;
  final int processingCount;

  const _ImagePreviewRow({
    required this.imagePaths,
    this.onImageTap,
    this.processingCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (imagePaths.isEmpty && processingCount == 0) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 70,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: imagePaths.length + processingCount,
        itemBuilder: (context, index) {
          if (index >= imagePaths.length) {
            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Container(
                  width: 60,
                  height: 60,
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                  ),
                ),
              ),
            );
          }

          final path = imagePaths[index];
          return GestureDetector(
            onTap: onImageTap != null ? () => onImageTap!(index) : null,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.file(
                  File(path),
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  cacheHeight:
                      (60 * MediaQuery.of(context).devicePixelRatio).round(),
                  frameBuilder: (BuildContext context, Widget child, int? frame,
                      bool wasSynchronouslyLoaded) {
                    if (wasSynchronouslyLoaded) return child;
                    return AnimatedOpacity(
                        opacity: frame == null ? 0 : 1,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        child: child);
                  },
                  errorBuilder: (context, error, stackTrace) {
                    developer.log("Error loading image for preview: $path",
                        error: error, stackTrace: stackTrace);
                    return Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image_outlined,
                            color: Colors.grey));
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

Widget _buildErrorBox(
    {required String title,
    required String message,
    required BuildContext context}) {
  return Card(
    color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.7),
    margin: const EdgeInsets.symmetric(vertical: 8),
    child: Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline,
              color: Theme.of(context).colorScheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onErrorContainer)),
                SelectableText(message,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildInfoBox(
    {required String title,
    required String message,
    required ToastType type,
    required BuildContext context}) {
  Color containerColor;
  Color contentColor;
  IconData iconData;
  switch (type) {
    case ToastType.warning:
      containerColor =
          Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.7);
      contentColor = Theme.of(context).colorScheme.onTertiaryContainer;
      iconData = Icons.warning_amber_outlined;
      break;
    case ToastType.info:
      containerColor =
          Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.7);
      contentColor = Theme.of(context).colorScheme.onSecondaryContainer;
      iconData = Icons.info_outline;
      break;
    case ToastType.success:
      containerColor = Colors.green.withOpacity(0.15);
      contentColor = Theme.of(context).brightness == Brightness.dark
          ? Colors.green.shade200
          : Colors.green.shade800;
      iconData = Icons.check_circle_outline;
      break;
    default:
      containerColor =
          Theme.of(context).colorScheme.errorContainer.withOpacity(0.7);
      contentColor = Theme.of(context).colorScheme.onErrorContainer;
      iconData = Icons.error_outline;
  }
  return Card(
    color: containerColor,
    margin: const EdgeInsets.symmetric(vertical: 8),
    child: Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(iconData, color: contentColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: contentColor)),
                SelectableText(message, style: TextStyle(color: contentColor)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ScoreCircle extends StatelessWidget {
  final int score;
  final double size;
  const _ScoreCircle({required this.score, this.size = 50.0});
  @override
  Widget build(BuildContext context) {
    double progress = score / 100.0;
    Color progressColor;
    if (score >= 80) {
      progressColor = Colors.green;
    } else if (score >= 60) {
      progressColor = Colors.lightGreen;
    } else if (score >= 40) {
      progressColor = Colors.orange;
    } else {
      progressColor = Colors.red;
    }
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: size * 0.12,
            backgroundColor: Colors.grey.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          ),
          Text("$score",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: size * 0.35,
                  color: Theme.of(context).textTheme.bodyLarge?.color)),
        ],
      ),
    );
  }
}

class _AppCard extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Color? borderColor;
  const _AppCard(
      {required this.title,
      required this.child,
      this.actions,
      this.borderColor});
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: borderColor != null
            ? BorderSide(color: borderColor!, width: 1.5)
            : BorderSide.none,
      ),
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: borderColor ??
                              Theme.of(context).colorScheme.primary)),
                ),
                if (actions != null) ...actions!,
              ],
            ),
            const Divider(height: 20, thickness: 1),
            child,
          ],
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return "";
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}

String? _normalizeUgandanPhoneNumber(String? number) {
  if (number == null || number.trim().isEmpty) {
    return null;
  }

  String cleanedNumber = number.replaceAll(RegExp(r'[^\d+]'), '');

  if (cleanedNumber.startsWith('+256')) {
    if (cleanedNumber.length == 13) return cleanedNumber;
  } else if (cleanedNumber.startsWith('256')) {
    if (cleanedNumber.length == 12) return '+$cleanedNumber';
  } else if (cleanedNumber.startsWith('07')) {
    if (cleanedNumber.length == 10) {
      return '+256${cleanedNumber.substring(1)}';
    }
  } else if (cleanedNumber.length == 9 && (cleanedNumber.startsWith('7'))) {
    return '+256$cleanedNumber';
  }

  developer.log("Could not normalize phone number: $number");
  return number;
}

DateTime? _parseToLocalToday(String timeString) {
  final now = DateTime.now();

  List<DateFormat> formats = [
    DateFormat.Hm(),
    DateFormat.Hms(),
    DateFormat.j(),
    DateFormat.jm(),
    DateFormat.jms(),
  ];

  for (var format in formats) {
    try {
      final parsedTime = format.parse(timeString);
      return DateTime(now.year, now.month, now.day, parsedTime.hour,
          parsedTime.minute, parsedTime.second);
    } catch (e) {
      // Continue to next format
    }
  }

  developer
      .log("Could not parse time string with any known format: $timeString");
  return null;
}

Future<Map<String, dynamic>> _verifyPaymentScreenshotIsolate(
    Map<String, dynamic> args) async {
  List<String> apiKeys = List<String>.from(args['apiKeys']);
  int currentApiKeyIndex = args['currentApiKeyIndex'];
  String imagePath = args['imagePath'];
  List<String> validRecipients = List<String>.from(args['validRecipients']);
  Map<int, int> paymentTiers =
      (args['paymentTiers'] as Map).map((k, v) => MapEntry(k as int, v as int));

  Map<String, dynamic> imageProcessResult =
      await _processAndEncodeImageIsolateHelper(
          {'imagePath': imagePath, 'contextDescription': 'payment_screenshot'});
  if (imageProcessResult['error'] != null) {
    return {'error': 'Payment verification failed at image processing'};
  }

  String prompt = """
    You are a meticulous financial verification assistant. Your task is to analyze the provided image of a mobile money confirmation and determine if it's a valid payment, while also extracting key details.

    **VALID RECIPIENT PHONE NUMBERS**: ${validRecipients.join(', ')}
    **VALID PAYMENT TIERS (UGX)**: ${paymentTiers.keys.join(', ')}

    **Analysis Steps:**
    1.  **Recipient Check**: Does the image clearly show the payment was sent to one of the valid recipient numbers?
    2.  **Amount Check**: Does the image show a payment amount that exactly matches one of the valid payment tiers?
    3.  **Status Check**: Does the image confirm the transaction was successful? Look for words like "sent," "completed," or "successful."
    4.  **Time Extraction**: Find the time the transaction was made. This is often next to or above the message text (e.g., "10:45 AM", "13:15"). Report this time string exactly as you see it.
    5.  **Transaction ID Extraction**: Find the Transaction ID of the payment message. This is a long alphanumeric/numeric string, often labeled "Transaction ID", "Txn ID", "ID", or similar. Extract this value precisely.
    6.  **Final Decision**: If the first three conditions are clearly met, the payment is "verified." Otherwise, it is "not_verified."

    **JSON OUTPUT FORMAT (MANDATORY):**
    Your response must be a single, valid JSON object with the following keys:
    
    - `"outcome"`: (string) Must be either `"verified"` or `"not_verified"`.
    - `"reason"`: (string) A brief, clear explanation for your decision (for internal logging).
    - `"amount_tier"`: (integer or null) If verified, the integer value of the payment tier (e.g., 5000). If not verified, this must be `null`.
    - `"transaction_time_detected"`: (string or null) The time string you extracted from the screenshot (e.g., "1:30 PM", "14:05").
    - `"recipient_number_detected"`: (string or null) The recipient number detected in the image.
    - `"transaction_id_detected"`: (string or null) The transaction ID detected in the image.
    """;

  List<Map<String, dynamic>> parts = [
    {'text': prompt},
    {
      'inline_data': {
        'mime_type': imageProcessResult['mime_type'],
        'data': imageProcessResult['data']
      }
    }
  ];
  final response = await _callGeminiApiWithRotation(
      apiKeys, currentApiKeyIndex, parts,
      model: _geminiProModel, temperature: 0.0, useJsonMode: true);

  if (response['error'] != null) {
    return {
      'error': 'Payment verification failed.',
      'details': response['error']
    };
  }

  Map<String, dynamic> parsedJson = _robustlyParseJson(response['text']);
  parsedJson['usedKeyIndex'] = response['usedKeyIndex'];
  return parsedJson;
}

String _formatPhoneNumberForDisplay(String normalizedNumber) {
  if (normalizedNumber.startsWith('+256')) {
    if (normalizedNumber.length == 13) {
      return '0' + normalizedNumber.substring(4);
    }
  }
  return normalizedNumber;
}
