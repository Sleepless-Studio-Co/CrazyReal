import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'l10n/app_localizations.dart';
import 'auth/auth_service.dart';
import 'utils/media_url.dart';

final String baseUrl = apiBaseUrl;

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
  // Défis réalisables : global courant + défis de mes groupes actifs.
  List<Map<String, dynamic>> _challenges = [];
  int? _selectedChallengeId;
  String? challengeError;
  bool isUploading = false;
  List<CameraDescription> _cameras = [];
  int _currentCameraIndex = 0;
  FlashMode _currentFlashMode = FlashMode.off;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    fetchChallenges();
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

  Future<void> fetchChallenges() async {
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
        Uri.parse('$baseUrl/challenges/available'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        if (!mounted) return;
        setState(() {
          _challenges =
              data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _selectedChallengeId =
              _challenges.isNotEmpty ? _challenges.first['id'] as int : null;
          challengeError = null;
        });
      } else if (response.statusCode == 401) {
        if (mounted) {
          widget.onUnauthorized();
        }
      } else {
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          setState(() => challengeError = l10n
              .serverError('${response.statusCode}')
              .replaceAll('{code}', '${response.statusCode}'));
        }
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() => challengeError = l10n.connectionError('$e'));
      }
    }
  }

  String _challengeLabel(Map<String, dynamic> c) {
    final title = c['title']?.toString() ?? '';
    final group = c['group'];
    if (group is Map && group['name'] != null) {
      return '${group['name']} · $title';
    }
    return title;
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
      if (_selectedChallengeId != null) {
        request.fields['challengeId'] = _selectedChallengeId.toString();
      }
      var response = await request.send();

      print('Upload response status: ${response.statusCode}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.photoSentToFeed)),
          );
          widget.onPostCreated?.call();
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

  Widget _buildChallengePicker(AppLocalizations l10n) {
    if (challengeError != null) {
      return Text(
        challengeError!,
        style: const TextStyle(fontSize: 14, color: Colors.red),
        textAlign: TextAlign.center,
      );
    }
    if (_challenges.isEmpty) {
      return Text(
        l10n.loadingChallenge,
        style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
        textAlign: TextAlign.center,
      );
    }

    final selected = _challenges.firstWhere(
      (c) => c['id'] == _selectedChallengeId,
      orElse: () => _challenges.first,
    );
    final description = selected['description']?.toString() ?? '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButton<int>(
          value: selected['id'] as int,
          isExpanded: true,
          underline: const SizedBox.shrink(),
          items: _challenges
              .map((c) => DropdownMenuItem<int>(
                    value: c['id'] as int,
                    child: Text(
                      _challengeLabel(c),
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: (id) => setState(() => _selectedChallengeId = id),
        ),
        if (description.isNotEmpty)
          Text(
            description,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            color: const Color(0xFFF7EBD1),
            width: double.infinity,
            child: _buildChallengePicker(l10n),
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
              splashColor: const Color(0xFFE54128),
              focusColor: const Color(0xFFE54128),
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
