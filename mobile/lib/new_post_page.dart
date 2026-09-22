import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'l10n/app_localizations.dart';
import 'auth/auth_service.dart';

final String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000';

enum CaptureMode { photo, video }

class NewPage extends StatefulWidget {
  const NewPage({
    super.key,
    required this.onUnauthorized,
    this.onPostCreated,
  });

  final VoidCallback onUnauthorized;
  final VoidCallback? onPostCreated;

  @override
  State<NewPage> createState() => _NewPageState();
}

class _NewPageState extends State<NewPage> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  String? challengeText;
  bool isUploading = false;
  bool isRecording = false;
  List<CameraDescription> _cameras = [];
  int _currentCameraIndex = 0;
  FlashMode _currentFlashMode = FlashMode.off;
  CaptureMode _captureMode = CaptureMode.photo;
  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    fetchChallenge();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        await _setupCameraController(_currentCameraIndex);
      }
    } catch (e) {
      print('Camera not available on this platform: $e');
    }
  }

  Future<void> _setupCameraController(int cameraIndex) async {
    await _controller?.dispose();
    _controller = CameraController(
      _cameras[cameraIndex],
      ResolutionPreset.veryHigh,
      enableAudio: _captureMode == CaptureMode.video,
    );
    _initializeControllerFuture = _controller!.initialize();
    if (_currentFlashMode != FlashMode.off) {
      try {
        await _initializeControllerFuture;
        await _controller!.setFlashMode(_currentFlashMode);
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  Future<void> _switchCaptureMode(CaptureMode mode) async {
    if (_captureMode == mode || isRecording || isUploading) return;
    setState(() => _captureMode = mode);
    await _setupCameraController(_currentCameraIndex);
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || isRecording) {
      if (_cameras.length < 2) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.onlyOneCamera)),
        );
      }
      return;
    }

    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
    await _setupCameraController(_currentCameraIndex);
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || _captureMode == CaptureMode.video) return;

    try {
      switch (_currentFlashMode) {
        case FlashMode.off:
          _currentFlashMode = FlashMode.auto;
          break;
        case FlashMode.auto:
          _currentFlashMode = FlashMode.always;
          break;
        case FlashMode.always:
          _currentFlashMode = FlashMode.torch;
          break;
        case FlashMode.torch:
          _currentFlashMode = FlashMode.off;
          break;
      }
      await _controller!.setFlashMode(_currentFlashMode);
      setState(() {});
    } catch (e) {
      print('Erreur lors du changement de flash: $e');
    }
  }

  IconData _getFlashIcon() {
    switch (_currentFlashMode) {
      case FlashMode.off:
        return Icons.flash_off;
      case FlashMode.auto:
        return Icons.flash_auto;
      case FlashMode.always:
        return Icons.flash_on;
      case FlashMode.torch:
        return Icons.flashlight_on;
    }
  }

  Future<void> fetchChallenge() async {
    try {
      final authService = AuthService();
      final token = await authService.getAccessToken();

      if (token == null) {
        if (mounted) {
          widget.onUnauthorized();
        }
        return;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/challenge/current'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (!mounted) return;
        setState(() {
          challengeText =
              data['description']?.toString() ?? data['title']?.toString();
        });
      } else if (response.statusCode == 401) {
        if (mounted) {
          widget.onUnauthorized();
        }
      } else {
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          setState(() => challengeText = l10n
              .serverError('${response.statusCode}')
              .replaceAll('{code}', '${response.statusCode}'));
        }
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() => challengeText = l10n.connectionError('$e'));
      }
    }
  }

  Future<void> _uploadMedia(String filePath, {required bool isVideo}) async {
    final l10n = AppLocalizations.of(context)!;

    try {
      setState(() => isUploading = true);

      final mediaFile = File(filePath);
      if (!await mediaFile.exists() || await mediaFile.length() == 0) {
        throw StateError('The captured media file is missing or empty');
      }

      final authService = AuthService();
      final token = await authService.getAccessToken();

      if (token == null) {
        if (!mounted) return;
        widget.onUnauthorized();
        return;
      }

      final request =
          http.MultipartRequest('POST', Uri.parse('$baseUrl/posts'));
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        filePath,
        filename: filePath.split(Platform.pathSeparator).last,
      ));
      final response = await request.send().timeout(const Duration(minutes: 5));
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isVideo ? l10n.videoSentToFeed : l10n.photoSentToFeed,
              ),
            ),
          );
          widget.onPostCreated?.call();
        }
      } else if (response.statusCode == 401) {
        if (mounted) {
          widget.onUnauthorized();
        }
      } else {
        final serverMessage = _serverErrorMessage(responseBody);
        print('Error uploading media: ${response.statusCode} - $responseBody');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(serverMessage ??
                  (isVideo ? l10n.errorSendingVideo : l10n.errorSendingPhoto)),
            ),
          );
        }
      }
    } catch (e) {
      print('Exception during upload: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isVideo ? l10n.errorSendingVideo : l10n.errorSendingPhoto,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isUploading = false);
      }
    }
  }

  String? _serverErrorMessage(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'];
        if (message is List) return message.join(', ');
        if (message is String && message.isNotEmpty) return message;
      }
    } catch (_) {}
    return null;
  }

  Future<void> takeAndUploadPicture() async {
    final l10n = AppLocalizations.of(context)!;

    if (_controller == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.cameraNotAvailable)),
      );
      return;
    }

    try {
      await _initializeControllerFuture;
      final image = await _controller!.takePicture();
      await _uploadMedia(image.path, isVideo: false);
    } catch (e) {
      print('Exception during photo capture: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorSendingPhoto)),
        );
      }
    }
  }

  void _startRecordingTimer() {
    _recordingDuration = Duration.zero;
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _recordingDuration += const Duration(seconds: 1);
        });
      }
    });
  }

  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _recordingDuration = Duration.zero;
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _toggleVideoRecording() async {
    final l10n = AppLocalizations.of(context)!;

    if (_controller == null || !_controller!.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.cameraNotAvailable)),
      );
      return;
    }

    try {
      if (isRecording) {
        final video = await _controller!.stopVideoRecording();
        _stopRecordingTimer();
        setState(() => isRecording = false);
        await _uploadMedia(video.path, isVideo: true);
      } else {
        await _controller!.startVideoRecording();
        _startRecordingTimer();
        setState(() => isRecording = true);
      }
    } catch (e) {
      print('Exception during video recording: $e');
      _stopRecordingTimer();
      if (mounted) {
        setState(() => isRecording = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorSendingVideo)),
        );
      }
    }
  }

  void _onShutterPressed() {
    if (isUploading) return;
    if (_captureMode == CaptureMode.photo) {
      takeAndUploadPicture();
    } else {
      _toggleVideoRecording();
    }
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Widget _buildModeSwitch(AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF7EBD1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8D5B5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeButton(
              label: l10n.captureModePhoto,
              icon: Icons.photo_camera_outlined,
              selected: _captureMode == CaptureMode.photo,
              enabled: !isRecording && !isUploading,
              onTap: () => _switchCaptureMode(CaptureMode.photo),
            ),
          ),
          Expanded(
            child: _ModeButton(
              label: l10n.captureModeVideo,
              icon: Icons.videocam_outlined,
              selected: _captureMode == CaptureMode.video,
              enabled: !isRecording && !isUploading,
              onTap: () => _switchCaptureMode(CaptureMode.video),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShutterButton() {
    final isVideoMode = _captureMode == CaptureMode.video;

    if (isUploading) {
      return const SizedBox(
        width: 80,
        height: 80,
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFFFE500),
            strokeWidth: 3,
          ),
        ),
      );
    }

    if (isVideoMode) {
      return GestureDetector(
        onTap: _onShutterPressed,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isRecording ? Colors.red : Colors.white,
              width: 4,
            ),
          ),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isRecording ? 32 : 56,
              height: isRecording ? 32 : 56,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: isRecording ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: isRecording ? BorderRadius.circular(8) : null,
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: 80,
      height: 80,
      child: FloatingActionButton(
        heroTag: 'photo',
        onPressed: _onShutterPressed,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        splashColor: Colors.grey.withOpacity(0.3),
        focusColor: Colors.grey.withOpacity(0.2),
        elevation: 0,
        child: const Icon(Icons.circle_outlined, size: 80),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Column(
        children: [
          Container(
            height: 90,
            padding: const EdgeInsets.all(20),
            color: const Color(0xFFF7EBD1),
            width: double.infinity,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Text(
                challengeText ?? l10n.loadingChallenge,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          _buildModeSwitch(l10n),
          Container(
            height: 560,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              color: Colors.black,
            ),
            clipBehavior: Clip.hardEdge,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _controller == null
                    ? Center(
                        child: Text(
                          l10n.cameraOnlyMobile,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : FutureBuilder<void>(
                        future: _initializeControllerFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.done) {
                            return CameraPreview(_controller!);
                          }
                          return const Center(
                              child: CircularProgressIndicator());
                        },
                      ),
                if (isRecording)
                  Positioned(
                    top: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${l10n.recordingVideo} ${_formatDuration(_recordingDuration)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Stack(
        children: [
          Positioned(
            bottom: 12,
            left: MediaQuery.of(context).size.width / 2 - 40,
            child: _buildShutterButton(),
          ),
          Positioned(
            bottom: 12,
            right: 12,
            child: FloatingActionButton(
              heroTag: 'flip',
              onPressed: (_cameras.length > 1 && !isRecording && !isUploading)
                  ? _switchCamera
                  : null,
              backgroundColor: const Color(0xFF195A3B),
              foregroundColor: Colors.white,
              splashColor: const Color(0xFFE54128),
              focusColor: const Color(0xFFE54128),
              child: const Icon(Icons.flip_camera_ios),
            ),
          ),
          if (_captureMode == CaptureMode.photo)
            Positioned(
              bottom: 12,
              left: 42,
              child: FloatingActionButton(
                heroTag: 'flash',
                onPressed: isRecording || isUploading ? null : _toggleFlash,
                backgroundColor: const Color(0xFF195A3B),
                foregroundColor: Colors.white,
                splashColor: const Color(0xFFE54128),
                focusColor: const Color(0xFFE54128),
                child: Icon(_getFlashIcon()),
              ),
            ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF195A3B) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : const Color(0xFF195A3B),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF195A3B),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
