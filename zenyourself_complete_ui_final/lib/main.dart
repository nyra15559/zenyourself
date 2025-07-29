import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(ZenYourselfApp());

class ZenYourselfApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZenYourself',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'NotoSans',
        primaryColor: Color(0xFFDEE6DF),
        scaffoldBackgroundColor: Color(0xFFFDFDFB),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: Color(0xFF5F7161),
        ),
      ),
      home: ScrollConfiguration(
        behavior: _NoGlowScrollBehavior(),
        child: SplashScreen(),
      ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Future.delayed(Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ChatScreen()),
      );
    });

    return Scaffold(
      backgroundColor: Color(0xFFF8F6F2),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.09,
              child: Image.asset(
                'assets/zen_pattern.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Color(0xFFF3EFEA),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF90B29E).withOpacity(0.15),
                        blurRadius: 16,
                        offset: Offset(0, 5),
                      )
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Image.asset('assets/logo.png'),
                  ),
                ),
                SizedBox(height: 30),
                Text(
                  'ZenYourself',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0B3D2E),
                    letterSpacing: 1.3,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Your inner voice, reconnected.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF90B29E),
                    letterSpacing: 0.7,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _NoGlowScrollBehavior extends ScrollBehavior {
  @override
  Widget buildViewportChrome(BuildContext context, Widget child, AxisDirection axisDirection) {
    return child;
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final String? mood;
  final DateTime? timestamp;
  ChatMessage({required this.text, required this.isUser, this.mood, this.timestamp});

  Map<String, dynamic> toJson() => {
    'text': text,
    'isUser': isUser,
    'mood': mood,
    'timestamp': timestamp?.toIso8601String(),
  };

  static ChatMessage fromJson(Map<String, dynamic> json) => ChatMessage(
    text: json['text'],
    isUser: json['isUser'],
    mood: json['mood'],
    timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : null,
  );
}

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _voiceInput = '';
  bool _isThinking = false;
  List<ChatMessage> _messages = [];
  String _selectedMood = '';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final log = prefs.getStringList('zen_log') ?? [];
    setState(() {
      _messages = log.map((e) => ChatMessage.fromJson(jsonDecode(e))).toList();
    });
  }

  Future<void> _saveMessages() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('zen_log', _messages.map((e) => jsonEncode(e.toJson())).toList());
  }

  void _startOrStopListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() {
        _isListening = false;
        _controller.text = _voiceInput;
        _voiceInput = '';
      });
    } else {
      bool available = await _speech.initialize();
      if (available) {
        setState(() {
          _isListening = true;
          _voiceInput = '';
        });
        _speech.listen(onResult: (result) {
          setState(() {
            _voiceInput = result.recognizedWords;
          });
        });
      }
    }
  }

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add(ChatMessage(
        text: text.trim(),
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _controller.clear();
      _isThinking = true;
    });
    _saveMessages();

    final gptResponse = await fetchGPTAnswer(text.trim());

    setState(() {
      _isThinking = false;
      _messages.add(ChatMessage(
        text: gptResponse.trim(),
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
    _saveMessages();
    Future.delayed(Duration(milliseconds: 400), _showMoodSelector);
  }

  Future<String> fetchGPTAnswer(String prompt) async {
    // DEIN API-Key HIER einsetzen!
    const apiKey = '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'; // <-- DEIN OPENAI KEY HIER!
    const endpoint = 'https://api.openai.com/v1/chat/completions';
    final response = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-3.5-turbo',
        'messages': [
          {
            'role': 'system',
            'content': 'Du bist ein ruhiger Zen-Meister. Fasse dich kurz. Stelle gezielte Gegenfragen, um die Selbstreflexion anzuregen. Keine Diagnosen.',
          },
          {'role': 'user', 'content': prompt},
        ],
        'max_tokens': 150,
      }),
    );
    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded['choices'][0]['message']['content'];
    } else {
      return 'Es gab ein Problem mit der Antwort.';
    }
  }

  void _showMoodSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFFF4F6F3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Wie fühlst du dich jetzt?",
                style: TextStyle(
                    color: Color(0xFF5F7161),
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            SizedBox(height: 12),
            Wrap(
              spacing: 10,
              children: [
                "😊 Klar",
                "😐 Neutral",
                "😢 Traurig",
                "😌 Erleichtert",
                "😶‍🌫️ Überfordert"
              ].map((mood) => ChoiceChip(
                label: Text(mood,
                    style: TextStyle(
                        color: Color(0xFF5F7161),
                        fontWeight: FontWeight.w500)),
                backgroundColor: Color(0xFFE0E5DF),
                selectedColor: Color(0xFFBFD8B8),
                selected: _selectedMood == mood,
                onSelected: (selected) {
                  setState(() => _selectedMood = mood);
                  if (_messages.isNotEmpty) {
                    final idx = _messages.lastIndexWhere((m) => m.isUser);
                    if (idx != -1 && _messages[idx].mood == null) {
                      _messages[idx] = ChatMessage(
                        text: _messages[idx].text,
                        isUser: true,
                        mood: mood,
                        timestamp: _messages[idx].timestamp,
                      );
                    }
                    _saveMessages();
                  }
                  Navigator.pop(context);
                },
              ))
                  .toList(),
            )
          ],
        ),
      ),
    );
  }

  void _showWeeklySummary() {
    final oneWeekAgo = DateTime.now().subtract(Duration(days: 7));
    final recentEntries = _messages
        .where((m) => m.isUser && m.timestamp != null && m.timestamp!.isAfter(oneWeekAgo))
        .toList();
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Color(0xFFF4F6F3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today, color: Color(0xFF5F7161)),
                  SizedBox(width: 8),
                  Text("Dein Wochenrückblick",
                      style: TextStyle(
                          color: Color(0xFF5F7161),
                          fontWeight: FontWeight.bold,
                          fontSize: 18)),
                ],
              ),
              Divider(height: 24, color: Color(0xFFD9E6D4)),
              SizedBox(
                height: 200,
                child: recentEntries.isNotEmpty
                    ? ListView(
                  children: recentEntries
                      .map((e) => Container(
                    margin: EdgeInsets.symmetric(vertical: 6),
                    padding: EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.text,
                          style: TextStyle(
                              fontSize: 15,
                              color: Color(0xFF5F7161),
                              fontWeight: FontWeight.w500),
                        ),
                        if (e.mood != null && e.mood!.isNotEmpty) ...[
                          SizedBox(height: 2),
                          Text(
                            e.mood!,
                            style: TextStyle(fontSize: 13, color: Color(0xFF9BB39C)),
                          ),
                        ],
                        SizedBox(height: 4),
                        Text(
                          _formatDate(e.timestamp!),
                          style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9BB39C)),
                        ),
                      ],
                    ),
                  ))
                      .toList(),
                )
                    : Center(
                  child: Text(
                    "Diese Woche wurde noch nichts gespeichert.",
                    style: TextStyle(
                        color: Color(0xFF7D8B72), fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFDEE6DF),
                    foregroundColor: Color(0xFF5F7161),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text("Schließen"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return "${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} – ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(72),
        child: SafeArea(
          child: Container(
            color: Color(0xFFF8F6F2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Logo als Zen-Kreis
                Padding(
                  padding: const EdgeInsets.only(left: 18, top: 8, bottom: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Color(0xFFF3EFEA),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF90B29E).withOpacity(0.09),
                          blurRadius: 9,
                          offset: Offset(0, 2),
                        )
                      ],
                    ),
                    padding: EdgeInsets.all(5),
                    child: Image.asset('assets/logo.png', height: 38),
                  ),
                ),
                // App-Name & Slogan
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('ZenYourself',
                        style: TextStyle(
                          color: Color(0xFF0B3D2E),
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          letterSpacing: 1.1,
                        ),
                      ),
                      Text(
                        'Your inner voice, reconnected.',
                        style: TextStyle(
                          color: Color(0xFF90B29E),
                          fontSize: 12,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ],
                  ),
                ),
                // Kalender-Icon (Zen)
                Padding(
                  padding: const EdgeInsets.only(right: 14, top: 4),
                  child: IconButton(
                    icon: Icon(Icons.calendar_today_rounded, color: Color(0xFF90B29E), size: 26),
                    onPressed: _showWeeklySummary,
                    splashRadius: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/zen_pattern.png',
              fit: BoxFit.cover,
              color: Colors.white.withOpacity(0.04),
              colorBlendMode: BlendMode.dstATop,
            ),
          ),
          Column(
            children: [
              if (_isThinking)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF5F7161)),
                      SizedBox(width: 8),
                      Text('ZenYourself denkt für dich nach  …', style: TextStyle(color: Color(0xFF5F7161))),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    return Align(
                      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        margin: EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: message.isUser ? Color(0xFFD9E6D4) : Color(0xFFF4F6F3),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              message.text,
                              style: TextStyle(fontSize: 16, color: Colors.black87),
                            ),
                            if (message.isUser && message.mood != null && message.mood!.isNotEmpty) ...[
                              SizedBox(height: 4),
                              Text(
                                message.mood!,
                                style: TextStyle(fontSize: 13, color: Color(0xFF9BB39C)),
                              ),
                            ]
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Eingabefeld & Buttons (ZEN-Style)
              Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(0xFFF3EFEA),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF90B29E).withOpacity(0.12),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      )
                    ],
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _startOrStopListening,
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 260),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isListening ? Color(0xFF90B29E) : Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: _isListening ? Color(0xFF90B29E).withOpacity(0.15) : Colors.transparent,
                                blurRadius: 17,
                                offset: Offset(0, 0),
                              )
                            ],
                          ),
                          padding: EdgeInsets.all(11),
                          child: Image.asset('assets/icon_voice.png', width: 26, height: 26),
                        ),
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: InputDecoration(
                            hintText: "Was bewegt dich heute?",
                            hintStyle: TextStyle(
                              color: Color(0xFF90B29E),
                              fontSize: 16.5,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.25,
                            ),
                            border: InputBorder.none,
                          ),
                          style: TextStyle(fontSize: 17.3, fontWeight: FontWeight.w500, color: Color(0xFF0B3D2E)),
                          onSubmitted: (value) => _sendMessage(value),
                        ),
                      ),
                      SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _sendMessage(_controller.text),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF0B3D2E),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF0B3D2E).withOpacity(0.14),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              )
                            ],
                          ),
                          padding: EdgeInsets.all(10),
                          child: Image.asset('assets/icon_send.png', width: 23, height: 23),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
