import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

// URL DE TON API
// ⚠️ ATTENTION : Sur l'émulateur Android, localhost s'écrit "10.0.2.2"
// Si tu es sur iOS ou Web, c'est "localhost" ou ton IP locale.
const String baseUrl = "http://localhost:3000"; 

Future<void> main() async {
  // Initialisation nécessaire pour la caméra
  WidgetsFlutterBinding.ensureInitialized();
  
  // Gérer les plateformes sans caméra (Linux, Web)
  CameraDescription? firstCamera;
  try {
    final cameras = await availableCameras();
    firstCamera = cameras.isNotEmpty ? cameras.first : null;
  } catch (e) {
    print('Camera not available on this platform: $e');
  }

  runApp(MaterialApp(
    home: CrazyRealHome(camera: firstCamera),
    theme: ThemeData.dark(), // Mode sombre pour faire "pro"
  ));
}

class CrazyRealHome extends StatefulWidget {
  final CameraDescription? camera;
  const CrazyRealHome({super.key, this.camera});

  @override
  State<CrazyRealHome> createState() => _CrazyRealHomeState();
}

class _CrazyRealHomeState extends State<CrazyRealHome> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  String challengeText = "Chargement du défi...";
  bool isUploading = false;

  @override
  void initState() {
    super.initState();
    // 1. Initialiser la caméra si disponible
    if (widget.camera != null) {
      _controller = CameraController(widget.camera!, ResolutionPreset.medium);
      _initializeControllerFuture = _controller!.initialize();
    }

    // 2. Récupérer le défi
    fetchChallenge();
  }

  // --- FONCTION 1 : Récupérer le défi ---
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

  // --- FONCTION 2 : Prendre et envoyer la photo ---
  Future<void> takeAndUploadPicture() async {
    if (_controller == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('📷 Caméra non disponible sur cette plateforme')),
      );
      return;
    }
    
    try {
      await _initializeControllerFuture;
      setState(() => isUploading = true);

      // A. Prendre la photo
      final image = await _controller!.takePicture();

      // B. Préparer l'envoi (Multipart Request)
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/posts'));
      request.files.add(await http.MultipartFile.fromPath('file', image.path));

      // C. Envoyer
      var response = await request.send();

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Photo envoyée ! Feed débloqué !')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Erreur upload')),
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
      appBar: AppBar(title: const Text('🔥 CrazyReal PoC')),
      body: Column(
        children: [
          // LE DÉFI DU JOUR
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.pinkAccent,
            width: double.infinity,
            child: Text(
              challengeText,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
          
          // LA CAMÉRA
          Expanded(
            child: _controller == null 
              ? const Center(
                  child: Text(
                    '📱 Caméra disponible uniquement sur iOS/Android',
                    style: TextStyle(fontSize: 16),
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
      
      // BOUTON PHOTO
      floatingActionButton: FloatingActionButton(
        onPressed: isUploading ? null : takeAndUploadPicture,
        backgroundColor: Colors.pinkAccent,
        child: isUploading 
          ? const CircularProgressIndicator(color: Colors.white) 
          : const Icon(Icons.camera_alt),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}