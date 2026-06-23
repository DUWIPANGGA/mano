import 'dart:async';

import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceRecognitionService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isInitialized = false;
  
  final StreamController<String> _resultController = StreamController<String>.broadcast();
  final StreamController<bool> _listeningController = StreamController<bool>.broadcast();
  final StreamController<String> _errorController = StreamController<String>.broadcast();

  Stream<String> get recognitionResult => _resultController.stream;
  Stream<bool> get listeningState => _listeningController.stream;
  Stream<String> get errorStream => _errorController.stream;

  final Map<String, String> _voiceCommands = {
    'tombol a': 'A', 'tombol b': 'B', 'tombol c': 'C', 'tombol d': 'D',
    'remote a': 'A', 'remote b': 'B', 'remote c': 'C', 'remote d': 'D',
    'button a': 'A', 'button b': 'B', 'button c': 'C', 'button d': 'D',
    'auto': 'E', 'auto mode': 'E', 'semua': 'E', 'auto abcd': 'E', 'auto a b c d': 'E',
    'off': 'F', 'matikan': 'F', 'stop': 'F',
    'built in': 'G', 'built-in': 'G', 'animasi default': 'G', 'auto all': 'G', 'semua animasi': 'G', 'all builtin': 'G',
    'animasi satu': 'N1', 'animasi 1': 'N1', 'nomor satu': 'N1',
    'animasi dua': 'N2', 'animasi 2': 'N2', 'nomor dua': 'N2',
    'animasi tiga': 'N3', 'animasi 3': 'N3', 'nomor tiga': 'N3',
    'animasi empat': 'N4', 'animasi 4': 'N4', 'nomor empat': 'N4',
    'animasi lima': 'N5', 'animasi 5': 'N5', 'nomor lima': 'N5',
    'animasi enam': 'N6', 'animasi 6': 'N6', 'nomor enam': 'N6',
    'animasi tujuh': 'N7', 'animasi 7': 'N7', 'nomor tujuh': 'N7',
    'animasi delapan': 'N8', 'animasi 8': 'N8', 'nomor delapan': 'N8',
    'animasi sembilan': 'N9', 'animasi 9': 'N9', 'nomor sembilan': 'N9',
    'animasi sepuluh': 'N10', 'animasi 10': 'N10', 'nomor sepuluh': 'N10',
    'animasi sebelas': 'N11', 'animasi 11': 'N11',
    'animasi dua belas': 'N12', 'animasi 12': 'N12',
    'animasi tiga belas': 'N13', 'animasi 13': 'N13',
    'animasi empat belas': 'N14', 'animasi 14': 'N14',
    'animasi lima belas': 'N15', 'animasi 15': 'N15',
    'animasi enam belas': 'N16', 'animasi 16': 'N16',
    'animasi tujuh belas': 'N17', 'animasi 17': 'N17',
    'animasi delapan belas': 'N18', 'animasi 18': 'N18',
    'animasi sembilan belas': 'N19', 'animasi 19': 'N19',
    'animasi dua puluh': 'N20', 'animasi 20': 'N20',
    'animasi dua satu': 'N21', 'animasi 21': 'N21',
    'animasi dua dua': 'N22', 'animasi 22': 'N22',
    'animasi dua tiga': 'N23', 'animasi 23': 'N23',
    'animasi dua empat': 'N24', 'animasi 24': 'N24',
    'animasi dua lima': 'N25', 'animasi 25': 'N25',
    'animasi dua enam': 'N26', 'animasi 26': 'N26',
    'animasi dua tujuh': 'N27', 'animasi 27': 'N27',
    'animasi dua delapan': 'N28', 'animasi 28': 'N28',
    'animasi dua sembilan': 'N29', 'animasi 29': 'N29',
    'animasi tiga puluh': 'N30', 'animasi 30': 'N30',
    'animasi tiga satu': 'N31', 'animasi 31': 'N31',
  };

  VoiceRecognitionService() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      print('🔄 Initializing speech recognition...');
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        print('❌ Izin microphone ditolak');
        _errorController.add('Izin microphone ditolak');
        return;
      }
      bool available = await _speech.initialize(
        onStatus: (status) {
          print('🎤 Status: $status');
          if (status == 'listening') {
            _isListening = true;
            _listeningController.add(true);
          } else if (status == 'done' || status == 'notListening') {
            _isListening = false;
            _listeningController.add(false);
          }
        },
        onError: (error) {
          print('❌ Speech error: ${error.errorMsg}');
          _isListening = false;
          _listeningController.add(false);
          _errorController.add('Error: ${error.errorMsg}');
        },
      );
      
      _isInitialized = available;
      if (available) {
        print('✅ Speech recognition initialized successfully');
      } else {
        print('❌ Speech recognition not available');
        _errorController.add('Speech recognition not available');
      }
    } catch (e) {
      print('❌ Initialization error: $e');
      _errorController.add('Initialization error: $e');
    }
  }

  Future<void> startListening() async {
    if (!_isInitialized) {
      print('⚠️ Not initialized, reinitializing...');
      await _initialize();
      if (!_isInitialized) {
        _errorController.add('Speech recognition not ready');
        return;
      }
    }

    if (_isListening) {
      print('⚠️ Already listening, stopping first...');
      await stopListening();
      await Future.delayed(Duration(milliseconds: 500));
    }

    try {
      print('🎤 Starting listening...');
      _isListening = true;
      _listeningController.add(true);
      bool? success = await _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            String command = result.recognizedWords.toLowerCase().trim();
            print('🎤 Recognized: "$command"');
            _processCommand(command);
            stopListening();
          }
        },
        listenFor: Duration(seconds: 10),
        pauseFor: Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      );

      if (success == true) {
        print('✅ Listening started successfully');
      } else {
        print('❌ Failed to start listening');
        _errorController.add('Failed to start listening');
      }
    } catch (e) {
      print('❌ Error starting listening: $e');
      _errorController.add('Error: $e');
      _isListening = false;
      _listeningController.add(false);
    }
  }

  Future<void> stopListening() async {
    try {
      await _speech.stop();
      _isListening = false;
      _listeningController.add(false);
      print('🛑 Listening stopped');
    } catch (e) {
      print('❌ Error stopping: $e');
      _isListening = false;
      _listeningController.add(false);
    }
  }

  void _processCommand(String command) {
    String? matchedCommand;
    
    for (final voiceCommand in _voiceCommands.keys) {
      if (command.contains(voiceCommand)) {
        matchedCommand = _voiceCommands[voiceCommand];
        break;
      }
    }

    if (matchedCommand != null) {
      print('✅ Command mapped: $command -> $matchedCommand');
      _resultController.add(matchedCommand);
    } else {
      print('❌ No match for: $command');
      _resultController.add('UNKNOWN');
    }
  }

  List<String> getAvailableCommands() {
    return _voiceCommands.keys.toList();
  }

  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;

  void dispose() {
    _speech.stop();
    _resultController.close();
    _listeningController.close();
    _errorController.close();
  }
}