import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

class WakeWordService {
  sherpa_onnx.KeywordSpotter? _keywordSpotter;
  sherpa_onnx.OnlineStream? _stream;
  AudioRecorder? _audioRecorder;
  
  bool _isInitialized = false;
  bool _isListening = false;
  int _sampleRate = 16000;
  
  final StreamController<bool> _keywordDetectedController = StreamController<bool>.broadcast();
  Stream<bool> get keywordDetected => _keywordDetectedController.stream;

  Future<void> initialize() async {
    try {
      print('🎤 Initializing Wake Word Service...');
      
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        print('❌ Microphone permission denied for wake word');
        return;
      }

      // Initialize sherpa_onnx bindings
      sherpa_onnx.initBindings();

      // Configure KWS model
      final modelConfig = sherpa_onnx.OnlineModelConfig(
        transducer: const sherpa_onnx.OnlineTransducerModelConfig(
          encoder: 'assets/models/kws/encoder-epoch-12-avg-2-chunk-16-left-64.int8.onnx',
          decoder: 'assets/models/kws/decoder-epoch-12-avg-2-chunk-16-left-64.int8.onnx',
          joiner: 'assets/models/kws/joiner-epoch-12-avg-2-chunk-16-left-64.int8.onnx',
        ),
        tokens: 'assets/models/kws/tokens.txt',
        numThreads: 2,
        provider: 'cpu',
        debug: false,
        modelType: 'zipformer2',
      );

      final config = sherpa_onnx.KeywordSpotterConfig(
        model: modelConfig,
        maxActivePaths: 4,
        keywordsFile: 'assets/models/kws/keywords.txt',
      );

      _keywordSpotter = sherpa_onnx.KeywordSpotter(config);
      _stream = _keywordSpotter!.createStream();
      
      _audioRecorder = AudioRecorder();
      
      _isInitialized = true;
      print('✅ Wake Word Service initialized successfully');
    } catch (e) {
      print('❌ Failed to initialize Wake Word Service: $e');
    }
  }

  Future<void> startListening() async {
    if (!_isInitialized) {
      print('⚠️ Wake Word Service not initialized');
      return;
    }

    if (_isListening) {
      print('⚠️ Already listening for wake word');
      return;
    }

    try {
      print('🎤 Starting wake word detection...');
      
      if (await _audioRecorder!.hasPermission()) {
        const encoder = AudioEncoder.pcm16bits;
        
        if (!await _audioRecorder!.isEncoderSupported(encoder)) {
          print('❌ PCM16 encoder not supported');
          return;
        }

        const config = RecordConfig(
          encoder: encoder,
          sampleRate: 16000,
          numChannels: 1,
        );

        final stream = await _audioRecorder!.startStream(config);
        
        stream.listen(
          (data) {
            // Convert int16 PCM to float32
            final samplesFloat32 = _convertBytesToFloat32(Uint8List.fromList(data));
            
            _stream!.acceptWaveform(
              samples: samplesFloat32,
              sampleRate: _sampleRate,
            );
            
            _processAudio();
          },
          onDone: () {
            print('Audio stream stopped');
          },
        );
        
        _isListening = true;
        print('✅ Wake word detection started');
      } else {
        print('❌ Microphone permission not granted');
      }
    } catch (e) {
      print('❌ Failed to start wake word detection: $e');
    }
  }

  Float32List _convertBytesToFloat32(Uint8List bytes) {
    // Convert int16 PCM bytes to float32 samples
    final int16List = Int16List.view(bytes.buffer);
    final float32List = Float32List(int16List.length);
    
    for (int i = 0; i < int16List.length; i++) {
      // Normalize to [-1.0, 1.0]
      float32List[i] = int16List[i] / 32768.0;
    }
    
    return float32List;
  }

  void _processAudio() {
    if (_keywordSpotter == null || _stream == null) return;

    // Check if we have enough audio for decoding
    while (_keywordSpotter!.isReady(_stream!)) {
      _keywordSpotter!.decode(_stream!);
    }

    // Get detection result
    final result = _keywordSpotter!.getResult(_stream!);
    if (result.keyword.isNotEmpty) {
      print('🎯 Wake word detected: ${result.keyword}');
      _keywordDetectedController.add(true);
      
      // Reset stream for next detection
      _keywordSpotter!.reset(_stream!);
    }
  }

  void stopListening() {
    if (!_isListening) return;

    print('🛑 Stopping wake word detection...');
    _audioRecorder?.stop();
    _isListening = false;
    print('✅ Wake word detection stopped');
  }

  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;

  void dispose() {
    stopListening();
    _stream?.free();
    _keywordSpotter?.free();
    _audioRecorder?.dispose();
    _keywordDetectedController.close();
    print('🗑️ Wake Word Service disposed');
  }
}