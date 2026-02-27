import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'l10n/app_localizations.dart';

final String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000';

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
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          print(l10n.loadingImagesError);
        }
      }
    } catch (e) {
      print('${AppLocalizations.of(context)?.error ?? "Error"}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
      ),
      body: imageUrls.isEmpty
          ? Center(child: Text(l10n.loading))
          : ListView.builder(
              itemCount: imageUrls.length,
              itemBuilder: (context, index) {
                return Image.network(imageUrls[index]);
              },
            ),
    );
  }
}