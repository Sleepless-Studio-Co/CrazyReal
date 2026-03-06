import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'l10n/app_localizations.dart';
import 'auth/auth_service.dart';

final String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.onUnauthorized});

  final VoidCallback onUnauthorized;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<dynamic> posts = [];
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    fetchPosts();
  }

  Future<void> fetchPosts() async {
    try {
      final token = await _authService.getAccessToken();

      if (token == null) {
        if (mounted) {
          widget.onUnauthorized();
        }
        return;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/posts'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          posts = data;
        });
      } else if (response.statusCode == 401) {
        if (mounted) {
          widget.onUnauthorized();
        }
      } else {
        print('Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
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
      body: posts.isEmpty
          ? Center(child: Text(l10n.loading))
          : ListView.builder(
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 30.0),
                        child: Row(
                          children: [
                            const Icon(Icons.account_circle, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              post['user']['username'],
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 600,
                        margin: const EdgeInsets.symmetric(horizontal: 8.0),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(25),
                          child: Image.network(
                            post['photoUrl'],
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
