import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'l10n/app_localizations.dart';
import 'auth/auth_service.dart';

final String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000';

class NewPage extends StatefulWidget {
  const NewPage({super.key, required this.onUnauthorized});

  final VoidCallback onUnauthorized;

  @override
  State<NewPage> createState() => _NewPageState();
}

class _NewPageState extends State<NewPage> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  String? challengeText;
  bool isUploading = false;
  List<CameraDescription> _cameras = [];
  int _currentCameraIndex = 0;
  FlashMode _currentFlashMode = FlashMode.off;

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
        _controller = CameraController(_cameras[_currentCameraIndex], ResolutionPreset.veryHigh);
        _initializeControllerFuture = _controller!.initialize();
        setState(() {});
      }
    } catch (e) {
      print('Camera not available on this platform: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.onlyOneCamera)),
      );
      return;
    }

    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
    await _controller?.dispose();
    
    _controller = CameraController(_cameras[_currentCameraIndex], ResolutionPreset.veryHigh);
    _initializeControllerFuture = _controller!.initialize();
    setState(() {});
  }

  Future<void> _toggleFlash() async {
    if (_controller == null) return;

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
          challengeText = data['content'];
        });
      } else if (response.statusCode == 401) {
        if (mounted) {
          widget.onUnauthorized();
        }
      } else {
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          setState(() => challengeText = l10n.serverError('${response.statusCode}').replaceAll('{code}', '${response.statusCode}'));
        }
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() => challengeText = l10n.connectionError('$e'));
      }
    }
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
      setState(() => isUploading = true);

      final authService = AuthService();
      final token = await authService.getAccessToken();
      
      if (token == null) {
        if (!mounted) return;
        widget.onUnauthorized();
        return;
      }

      final image = await _controller!.takePicture();
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/posts'));
      
      request.headers['Authorization'] = 'Bearer $token';
      
      request.files.add(await http.MultipartFile.fromPath('file', image.path));
      var response = await request.send();

      print('Upload response status: ${response.statusCode}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        print('Upload successful: $responseBody');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.photoSentToFeed)),
          );
        }
      } else if (response.statusCode == 401) {
        if (mounted) {
          widget.onUnauthorized();
        }
      } else {
        final responseBody = await response.stream.bytesToString();
        print('Error uploading photo: ${response.statusCode} - $responseBody');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.errorSendingPhoto)),
          );
        }
      }
    } catch (e) {
      print('Exception during upload: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorSendingPhoto)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isUploading = false);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
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
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // LA CAMÉRA
          Container(
            height: 600,
            width: double.infinity,
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              color: Colors.black,
            ),
            clipBehavior: Clip.hardEdge,
            child: _controller == null
              ? Center(
                  child: Text(
                    l10n.cameraOnlyMobile,
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                )
              : FutureBuilder<void>(
                  future: _initializeControllerFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done) {
                      return CameraPreview(_controller!);
                    } else {
                      return const Center(child: CircularProgressIndicator());
                    }
                  },
                ),
          ),
        ],
      ),

      // BOUTONS FLOTTANTS
      floatingActionButton: Stack(
        children: [
          // BOUTON PHOTO CENTRÉ
          Positioned(
            bottom: 12,
            left: MediaQuery.of(context).size.width / 2 - 25,
            child: SizedBox(
              width: 80,
              height: 80,
              child: FloatingActionButton(
                heroTag: 'photo',
                onPressed: isUploading ? null : takeAndUploadPicture,
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                splashColor: Colors.grey.withOpacity(0.3),
                focusColor: Colors.grey.withOpacity(0.2),
                elevation: 0,
                child: isUploading
                  ? const CircularProgressIndicator(color: Color(0xFFFFE500), strokeWidth: 3)
                  : const Icon(Icons.circle_outlined, size: 80),
              ),
            ),
          ),
          // BOUTON FLIP À DROITE
          Positioned(
            bottom: 12,
            right: 12,
            child: FloatingActionButton(
              heroTag: 'flip',
              onPressed: _cameras.length > 1 ? _switchCamera : null,
              backgroundColor: const Color(0xFF195A3B),
              foregroundColor: Colors.white,
              splashColor: Color(0xFFE54128),
              focusColor: Color(0xFFE54128),
              child: const Icon(Icons.flip_camera_ios),
            ),
          ),
          // BOUTON FLASH
          Positioned(
            bottom: 12,
            left: 42,
            child: FloatingActionButton(
              heroTag: 'flash',
              onPressed: _toggleFlash,
              backgroundColor: const Color(0xFF195A3B),
              foregroundColor: Colors.white,
              splashColor: Color(0xFFE54128),
              focusColor: Color(0xFFE54128),
              child: Icon(_getFlashIcon()),
            ),
          ),
        ],
      ),
    );
  }
}
