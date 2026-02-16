import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// URL DE TON API
const String baseUrl = "http://10.0.2.2:3000";

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<String> imageUrls = [];

  @override
  void initState() {
    super.initState();
    fetchImages();
  }

  Future<void> fetchImages() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/uploads'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          imageUrls = List<String>.from(data['files']);
        });
      } else {
        // Gérer l'erreur
        print('Erreur lors du chargement des images');
      }
    } catch (e) {
      print('Erreur: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CrazyReal Photos'),
      ),
      body: imageUrls.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: imageUrls.length,
              itemBuilder: (context, index) {
                return Image.network(imageUrls[index]);
              },
            ),
    );
  }
}