import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000';

class NewPage extends StatefulWidget {
  const NewPage({super.key});

  @override
  State<NewPage> createState() => _NewPageState();
}

class _NewPageState extends State<NewPage> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  String challengeText = "Chargement du défi...";
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Une seule caméra disponible')),
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
      final response = await http.get(Uri.parse('$baseUrl/challenge/current'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          challengeText = data['content'];
        });
      } else {
        setState(() => challengeText = "Erreur serveur: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => challengeText = "Erreur connexion: $e");
    }
  }

  Future<void> takeAndUploadPicture() async {
    if (_controller == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Caméra non disponible !')),
      );
      return;
    }

    try {
      await _initializeControllerFuture;
      setState(() => isUploading = true);

      final image = await _controller!.takePicture();
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/posts'));
      request.files.add(await http.MultipartFile.fromPath('file', image.path));
      var response = await request.send();

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo envoyée dans ton Feed !')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Erreur lors de l\'envoi de la photo')),
        );
      }
    } catch (e) {
      print(e);
    } finally {
      setState(() => isUploading = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                challengeText,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // LA CAMÉRA
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                color: Colors.black,
              ),
              clipBehavior: Clip.hardEdge,
              child: _controller == null
                ? const Center(
                    child: Text(
                      '📱 Caméra disponible uniquement sur iOS/Android',
                      style: TextStyle(fontSize: 16, color: Colors.white),
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