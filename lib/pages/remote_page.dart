import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:iTen/constants/app_colors.dart';
import 'package:iTen/services/socket_service.dart';
import 'package:iTen/services/voice_recognition_service.dart';
import 'package:iTen/services/wake_word_service.dart';

class RemotePage extends StatefulWidget {
  final SocketService socketService;

  const RemotePage({super.key, required this.socketService});

  @override
  State<RemotePage> createState() => _RemotePageState();
}

class _RemotePageState extends State<RemotePage> {
  final VoiceRecognitionService _voiceService = VoiceRecognitionService();
  final WakeWordService _wakeWordService = WakeWordService();
  final FlutterTts _tts = FlutterTts();
  bool _isVoiceListening = false;
  bool _isWakeWordEnabled = false;

  final Map<String, bool> _buttonsState = {
    'Auto ABCD': false,
    'Auto All': false,
    'A': false,
    'B': false,
    'C': false,
    'D': false,
  };

  static const Map<String, String> _voiceResponses = {
    'A': 'Siap, remote A dinyalakan',
    'B': 'Siap, remote B dinyalakan',
    'C': 'Siap, remote C dinyalakan',
    'D': 'Siap, remote D dinyalakan',
    'E': 'Siap, mode Auto ABCD dinyalakan',
    'F': 'Semua animasi dimatikan',
    'G': 'Siap, mode Auto All Builtin dinyalakan',
  };

  String _getAnimationResponse(int num) {
    return 'Siap, animasi $num dinyalakan';
  }

  @override
  void initState() {
    super.initState();
    _initTts();
    _initWakeWord();

    // Listen untuk messages dari socket
    widget.socketService.messages.listen((message) {
      _handleSocketMessage(message);
    });

    // Listen untuk voice recognition results
    _voiceService.recognitionResult.listen((command) {
      _handleVoiceCommand(command);
    });
    _voiceService.listeningState.listen((listening) {
      setState(() { _isVoiceListening = listening; });
    });

    // Listen untuk wake word detection
    _wakeWordService.keywordDetected.listen((detected) {
      if (detected) {
        _onWakeWordDetected();
      }
    });
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('id-ID');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> _initWakeWord() async {
    await _wakeWordService.initialize();
  }

  void _onWakeWordDetected() {
    print('🎯 Wake word detected! Responding...');
    _speak('Iya bos');
    
    // Start listening for command after wake word
    Future.delayed(Duration(milliseconds: 500), () {
      _voiceService.startListening();
    });
  }

  void _toggleWakeWord() {
    setState(() {
      _isWakeWordEnabled = !_isWakeWordEnabled;
      if (_isWakeWordEnabled) {
        _wakeWordService.startListening();
      } else {
        _wakeWordService.stopListening();
      }
    });
  }

  Future<void> _speak(String text) async {
    await _tts.speak(text);
  }

  void _handleSocketMessage(String message) {
    print('RemotePage received: $message');
    // Handle responses dari device jika diperlukan
    if (message.startsWith('info,')) {
      final infoMessage = message.substring(5);
      _showSnackBar(infoMessage);
    }
  }

  static const Map<String, String> _commandNames = {
    'A': 'A', 'B': 'B', 'C': 'C', 'D': 'D',
    'E': 'Auto ABCD', 'F': 'Turn Off', 'G': 'Auto All',
  };

  void _handleVoiceCommand(String command) {
    // Cek animasi N1-N31
    if (command.startsWith('N') && command.length > 1) {
      final num = int.tryParse(command.substring(1));
      if (num != null && num >= 1 && num <= 31) {
        if (!widget.socketService.isConnected) {
          _showSnackBar('Gagal menyalakan remote Animasi $num, harap hubungkan device terlebih dahulu');
          _speak('Gagal menyalakan remote Animasi $num, harap hubungkan device terlebih dahulu');
          return;
        }
        widget.socketService.builtinAnimation(num);
        _showSnackBar('Animasi $num dijalankan');
        _speak(_getAnimationResponse(num));
        return;
      }
    }

    // Cek apakah command dikenal
    if (!_commandNames.containsKey(command)) {
      _showSnackBar('Maaf, perintah tidak diketahui');
      _speak('Maaf, perintah tidak diketahui');
      return;
    }

    // Command dikenal, cek koneksi
    String remoteName = _commandNames[command]!;
    if (!widget.socketService.isConnected) {
      _showSnackBar('Gagal menyalakan remote $remoteName, harap hubungkan device terlebih dahulu');
      _speak('Gagal menyalakan remote $remoteName, harap hubungkan device terlebih dahulu');
      return;
    }

    switch (command) {
      case 'A': _toggleButton('A'); _speak(_voiceResponses['A']!); break;
      case 'B': _toggleButton('B'); _speak(_voiceResponses['B']!); break;
      case 'C': _toggleButton('C'); _speak(_voiceResponses['C']!); break;
      case 'D': _toggleButton('D'); _speak(_voiceResponses['D']!); break;
      case 'E': _toggleButton('Auto ABCD'); _speak(_voiceResponses['E']!); break;
      case 'F':
        widget.socketService.turnOff();
        setState(() { _buttonsState.updateAll((key, value) => false); });
        _speak(_voiceResponses['F']!);
        break;
      case 'G': _toggleButton('Auto All'); _speak(_voiceResponses['G']!); break;
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.neonGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _tts.stop();
    _voiceService.dispose();
    _wakeWordService.dispose();
    super.dispose();
  }

  void _showMoreModal(BuildContext context) {
    int? _selectedAnimation;
    bool _isAnimationActive = false;

    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      backgroundColor: AppColors.darkGrey,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header KEMBALI
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlack,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.neonGreen),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'KEMBALI',
                            style: TextStyle(
                              color: AppColors.neonGreen,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Icon(Icons.arrow_upward, color: AppColors.neonGreen),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Grid untuk tombol builtin animations 3-31
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1,
                          ),
                      itemCount: 29, // 3 sampai 31 = 29 item
                      itemBuilder: (context, index) {
                        final animNumber = index + 3; // 3 sampai 31
                        final isSelected =
                            _selectedAnimation == animNumber &&
                            _isAnimationActive;

                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                              if (_selectedAnimation == animNumber &&
                                  _isAnimationActive) {
                                // Klik kedua - matikan
                                _isAnimationActive = false;
                                _selectedAnimation = null;
                                widget.socketService.turnOff();
                                // _showSnackBar('Animasi dimatikan');
                              } else {
                                // Klik pertama - nyalakan
                                _selectedAnimation = animNumber;
                                _isAnimationActive = true;
                                widget.socketService.builtinAnimation(
                                  animNumber,
                                );
                                // _showSnackBar('Animasi $animNumber dijalankan');
                              }
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.neonGreen
                                  : AppColors.primaryBlack,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.neonGreen,
                                width: isSelected ? 3 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppColors.neonGreen.withOpacity(
                                          0.6,
                                        ),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Center(
                              child: Text(
                                animNumber.toString(),
                                style: TextStyle(
                                  color: isSelected
                                      ? AppColors.primaryBlack
                                      : AppColors.pureWhite,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _toggleButton(String label) {
    setState(() {
      // Untuk semua tombol: jika tombol yang sama diklik dan sedang aktif, matikan
      if (_buttonsState[label] == true) {
        _buttonsState[label] = false;
        widget.socketService.turnOff();
        // _showSnackBar('Animasi dimatikan');
      } else {
        // Jika tombol berbeda atau belum aktif, reset semua dan nyalakan yang diklik
        _buttonsState.updateAll((key, value) => false);
        _buttonsState[label] = true;

        // Kirim command sesuai tombol
        switch (label) {
          case 'Auto ABCD':
            widget.socketService.autoABCD();
            // _showSnackBar('Auto ABCD Mode');
            break;
          case 'Auto All':
            widget.socketService.autoAllBuiltin();
            // _showSnackBar('Auto All Builtin Mode');
            break;
          case 'A':
            widget.socketService.remoteA();
            // _showSnackBar('Tombol A - Animasi 1');
            break;
          case 'B':
            widget.socketService.remoteB();
            // _showSnackBar('Tombol B - Animasi 2');
            break;
          case 'C':
            widget.socketService.remoteC();
            // _showSnackBar('Tombol C - Animasi 3');
            break;
          case 'D':
            widget.socketService.remoteD();
            // _showSnackBar('Tombol D - Animasi 4');
            break;
        }
      }
    });
  }

  Widget _buildAutoButton(String label) {
    final isActive = _buttonsState[label] ?? false;

    return GestureDetector(
      onTap: () => _toggleButton(label),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive ? AppColors.neonGreen : AppColors.primaryBlack,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.neonGreen, width: 2),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.neonGreen.withOpacity(0.4),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppColors.primaryBlack : AppColors.pureWhite,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(
              isActive ? Icons.pause : Icons.play_arrow,
              color: isActive ? AppColors.primaryBlack : AppColors.neonGreen,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Container untuk tombol Auto ABCD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.darkGrey,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.neonGreen),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Remote Control',
                    style: TextStyle(
                      color: AppColors.neonGreen,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Pilih mode animasi atau tombol remote',
                    style: TextStyle(color: AppColors.pureWhite, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  _buildAutoButton('Auto ABCD'),
                  _buildAutoButton('Auto All'),
                  _buildAutoButton('A'),
                  _buildAutoButton('B'),
                  _buildAutoButton('C'),
                  _buildAutoButton('D'),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Menu More dan Mic
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Menu More
                Expanded(
                  child: GestureDetector(
                    onTap: () => widget.socketService.isConnected
                        ? _showMoreModal(context)
                        : _showSnackBar(
                            'Harap connect ke device terlebih dahulu',
                          ),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.darkGrey,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.neonGreen),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.more_horiz, color: AppColors.neonGreen),
                          SizedBox(width: 8),
                          Text(
                            'More Animations (3-31)',
                            style: TextStyle(
                              color: AppColors.neonGreen,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Wake Word Toggle
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _isWakeWordEnabled ? AppColors.neonGreen : AppColors.darkGrey,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.neonGreen),
                  ),
                  child: IconButton(
                    icon: Icon(
                      _isWakeWordEnabled ? Icons.record_voice_over : Icons.voice_over_off,
                      color: _isWakeWordEnabled ? AppColors.primaryBlack : AppColors.neonGreen,
                    ),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      _toggleWakeWord();
                    },
                  ),
                ),

                const SizedBox(width: 8),

                // Mic (Voice Recognition)
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _isVoiceListening ? AppColors.neonGreen : AppColors.darkGrey,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.neonGreen),
                  ),
                  child: IconButton(
                    icon: Icon(
                      _isVoiceListening ? Icons.mic : Icons.mic_off,
                      color: _isVoiceListening ? AppColors.primaryBlack : AppColors.neonGreen,
                    ),
                    onPressed: () {
                      if (_isVoiceListening) {
                        _voiceService.stopListening();
                        HapticFeedback.lightImpact();
                      } else {
                        HapticFeedback.mediumImpact();
                        _voiceService.startListening();
                      }
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
