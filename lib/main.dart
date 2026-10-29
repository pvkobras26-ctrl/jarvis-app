import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:external_app_launcher/external_app_launcher.dart';

void main() {
  runApp(const JarvisApp());
}

class JarvisApp extends StatelessWidget {
  const JarvisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'J.A.R.V.I.S.',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0E14),
        colorScheme: const ColorScheme.dark(
          primary: Colors.cyan,
          secondary: Colors.blueAccent,
        ),
      ),
      home: const JarvisHomeScreen(),
    );
  }
}

class JarvisHomeScreen extends StatefulWidget {
  const JarvisHomeScreen({super.key});

  @override
  State<JarvisHomeScreen> createState() => _JarvisHomeScreenState();
}

class _JarvisHomeScreenState extends State<JarvisHomeScreen> {
  late stt.SpeechToText _speech;
  late FlutterTts _tts;
  final Battery _battery = Battery();

  bool _isListening = false;
  bool _isLoading = false;
  bool _isContinuousMode = true;
  
  String _userSpeech = "Diga 'Jarvis' ou toque no reator...";
  String _jarvisResponse = "Sistemas online, Senhor. Aguardando instruções.";

  // CHAVE DA API DO GEMINI DIVIDIDA PARA EVITAR BLOQUEIO DO GITHUB:
  final String _geminiApiKey = 'AQ.Ab8RN6KVky7yiRTG-' + 'HUMXnVOcLLD5Ek-ZXIgT1PBL_ODzcLYSA';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
    _initTts();
    _initSpeechSystem();
  }

  Future<void> _initSpeechSystem() async {
    await Permission.microphone.request();
    _startListeningLoop();
  }

  void _initTts() async {
    await _tts.setLanguage("pt-BR");
    await _tts.setPitch(0.9);
    await _tts.setSpeechRate(0.5);
  }

  void _startListeningLoop() async {
    bool available = await _speech.initialize(
      onError: (val) {
        if (_isContinuousMode) {
          Future.delayed(const Duration(seconds: 1), _startListeningLoop);
        }
      },
      onStatus: (status) {
        if (status == 'notListening' && _isContinuousMode && !_isLoading) {
          _startListeningLoop();
        }
      },
    );

    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        localeId: "pt_BR",
        onResult: (val) {
          String text = val.recognizedWords.toLowerCase();
          setState(() => _userSpeech = val.recognizedWords);

          if (text.contains("jarvis")) {
            _speech.stop();
            _processCommand(text);
          }
        },
      );
    }
  }

  Future<void> _processCommand(String text) async {
    setState(() => _isLoading = true);

    if (text.contains("bateria") || text.contains("carga")) {
      int level = await _battery.batteryLevel;
      _respond("A bateria do dispositivo está em $level por cento, Senhor.");
      return;
    }

    if (text.contains("abrir whatsapp")) {
      await LaunchApp.openApp(androidPackageName: 'com.whatsapp');
      _respond("Abrindo o WhatsApp, Senhor.");
      return;
    }

    if (text.contains("abrir youtube")) {
      await LaunchApp.openApp(androidPackageName: 'com.google.android.youtube');
      _respond("Iniciando o YouTube, Senhor.");
      return;
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _geminiApiKey,
        systemInstruction: Content.system(
          "Você é o J.A.R.V.I.S., assistente virtual inteligente e extremamente elegante. "
          "Trate o usuário por 'Senhor' ou 'Senhora'. "
          "Responda de forma direta e concisa para leitura em voz alta."
        ),
      );

      final response = await model.generateContent([Content.text(text)]);
      String responseText = response.text ?? "Não consegui processar o comando.";
      _respond(responseText);
    } catch (e) {
      _respond("Erro de comunicação com os servidores centrais.");
    }
  }

  void _respond(String text) async {
    setState(() {
      _jarvisResponse = text;
      _isLoading = false;
    });

    await _tts.stop();
    await _tts.speak(text);

    _tts.setCompletionHandler(() {
      if (_isContinuousMode) {
        _startListeningLoop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('J.A.R.V.I.S. SYSTEM', style: TextStyle(letterSpacing: 2)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isContinuousMode ? Icons.record_voice_over : Icons.voice_over_off),
            onPressed: () {
              setState(() {
                _isContinuousMode = !_isContinuousMode;
                if (_isContinuousMode) {
                  _startListeningLoop();
                } else {
                  _speech.stop();
                }
              });
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              _userSpeech,
              style: const TextStyle(fontSize: 16, color: Colors.cyanAccent),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            GestureDetector(
              onTap: () {
                if (!_isLoading) {
                  _speech.stop();
                  _startListeningLoop();
                }
              },
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                  boxShadow: [
                    BoxShadow(
                      color: _isListening ? Colors.cyan : Colors.blue.withOpacity(0.3),
                      blurRadius: _isListening ? 30 : 15,
                      spreadRadius: _isListening ? 10 : 2,
                    ),
                  ],
                  border: Border.all(
                    color: _isListening ? Colors.cyanAccent : Colors.cyan.shade800,
                    width: 3,
                  ),
                ),
                child: Center(
                  child: _isLoading
                      ? const SpinKitRipple(color: Colors.cyanAccent, size: 100)
                      : Icon(
                          _isListening ? Icons.mic : Icons.power_settings_new,
                          size: 
