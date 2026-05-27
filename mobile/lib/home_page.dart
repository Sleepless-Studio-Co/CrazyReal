import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import 'auth/auth_service.dart';
import 'l10n/app_localizations.dart';

final String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000';

const Color _inkColor = Color(0xFF3B2A21);
const Color _inkMuted = Color(0xFF6A4A3B);
const Color _cardColor = Color(0xFFFFF7E6);

class _AvatarOption {
  const _AvatarOption({
    required this.id,
    required this.background,
    required this.foreground,
    required this.icon,
  });

  final String id;
  final Color background;
  final Color foreground;
  final IconData icon;
}

const List<_AvatarOption> _avatarOptions = [
  _AvatarOption(
    id: 'ember',
    background: Color(0xFFE9B384),
    foreground: Color(0xFF3C2A21),
    icon: Icons.whatshot_outlined,
  ),
  _AvatarOption(
    id: 'sea',
    background: Color(0xFF9FC0B9),
    foreground: Color(0xFF1E3D3A),
    icon: Icons.waves_outlined,
  ),
  _AvatarOption(
    id: 'citrus',
    background: Color(0xFFF7E27C),
    foreground: Color(0xFF5E4B0A),
    icon: Icons.emoji_food_beverage_outlined,
  ),
  _AvatarOption(
    id: 'berry',
    background: Color(0xFFD4A5A5),
    foreground: Color(0xFF4D2020),
    icon: Icons.favorite_border,
  ),
  _AvatarOption(
    id: 'noon',
    background: Color(0xFFB1C5E5),
    foreground: Color(0xFF1F2F4A),
    icon: Icons.sports_tennis_outlined,
  ),
  _AvatarOption(
    id: 'terra',
    background: Color(0xFFCBB39B),
    foreground: Color(0xFF4E3722),
    icon: Icons.terrain_outlined,
  ),
];

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.onUnauthorized});

  final VoidCallback onUnauthorized;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<dynamic> posts = [];
  final AuthService _authService = AuthService();
  bool _isLoading = true;

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

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          posts = data;
          _isLoading = false;
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
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('${AppLocalizations.of(context)?.error ?? "Error"}: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle, style: _titleStyle(context)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchPosts,
              child: posts.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Text(
                            l10n.noPostsYet,
                            style: _mutedStyle(context),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                      itemCount: posts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final post = posts[index];
                        final user = post['user'] ?? {};
                        final username = user['username']?.toString() ?? '';
                        return _buildPostCard(
                          context,
                          username: username,
                          avatarUrl: _resolveMediaUrl(user['avatarUrl']?.toString()),
                          avatarKey: user['avatarKey']?.toString(),
                          photoUrl: _resolveMediaUrl(post['photoUrl']?.toString()) ?? '',
                        );
                      },
                    ),
            ),
    );
  }

  Widget _buildPostCard(
    BuildContext context, {
    required String username,
    required String? avatarUrl,
    required String? avatarKey,
    required String photoUrl,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF0DFC2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F2E1B0F),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                _buildAvatarForUser(
                  username: username,
                  avatarUrl: avatarUrl,
                  avatarKey: avatarKey,
                  size: 44,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    username.isEmpty ? 'Unknown' : username,
                    style: _valueStyle(context),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.more_horiz, color: _inkMuted),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: 4 / 5,
              child: Image.network(
                photoUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: const Color(0xFFEEDCC5),
                    child: const Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: const Color(0xFFEEDCC5),
                    child: Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: _inkMuted,
                        size: 42,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'CrazyReal',
                    style: _labelStyle(context),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.favorite_border, color: _inkMuted),
                const SizedBox(width: 10),
                const Icon(Icons.chat_bubble_outline, color: _inkMuted),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarForUser({
    required String username,
    required String? avatarUrl,
    required String? avatarKey,
    double size = 40,
  }) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFEEDCC5),
        ),
        child: ClipOval(
          child: Image.network(
            avatarUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildFallbackAvatar(username, avatarKey, size);
            },
          ),
        ),
      );
    }

    return _buildFallbackAvatar(username, avatarKey, size);
  }

  Widget _buildFallbackAvatar(String username, String? avatarKey, double size) {
    final option = _resolveAvatarOption(username, avatarKey);
    final isBaseAvatar = avatarKey != null && avatarKey.isNotEmpty;
    final label = username.isNotEmpty ? username[0].toUpperCase() : '?';

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: option.background,
      child: isBaseAvatar
          ? Icon(option.icon, color: option.foreground, size: size * 0.5)
          : Text(
              label,
              style: GoogleFonts.karla(
                color: option.foreground,
                fontSize: size * 0.44,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }

  _AvatarOption _resolveAvatarOption(String username, String? avatarKey) {
    if (avatarKey != null && avatarKey.isNotEmpty) {
      return _avatarOptions.firstWhere(
        (option) => option.id == avatarKey,
        orElse: () => _avatarOptions.first,
      );
    }

    final avatarIndex = _hashString(username) % _avatarOptions.length;
    return _avatarOptions[avatarIndex];
  }

  int _hashString(String value) {
    if (value.isEmpty) return 0;
    var hash = 0;
    for (final code in value.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return hash;
  }

  String? _resolveMediaUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) return null;

    final configuredBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final configuredUri = Uri.tryParse(configuredBase);

    if (rawUrl.startsWith('/')) {
      return '$configuredBase$rawUrl';
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri != null && uri.hasScheme) {
      final host = uri.host.toLowerCase();
      if ((host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2') && configuredUri != null) {
        return uri
            .replace(
              scheme: configuredUri.scheme,
              host: configuredUri.host,
              port: configuredUri.hasPort ? configuredUri.port : null,
            )
            .toString();
      }
      return rawUrl;
    }

    return '$configuredBase/$rawUrl';
  }

  TextStyle _titleStyle(BuildContext context) {
    return GoogleFonts.dmSerifDisplay(
      color: _inkColor,
      fontSize: 24,
      letterSpacing: 0.2,
    );
  }

  TextStyle _labelStyle(BuildContext context) {
    return GoogleFonts.karla(
      color: _inkMuted,
      fontSize: 12.5,
      letterSpacing: 0.2,
      fontWeight: FontWeight.w600,
    );
  }

  TextStyle _valueStyle(BuildContext context) {
    return GoogleFonts.karla(
      color: _inkColor,
      fontSize: 16,
      fontWeight: FontWeight.w700,
    );
  }

  TextStyle _mutedStyle(BuildContext context) {
    return GoogleFonts.karla(
      color: _inkMuted,
      fontSize: 14,
    );
  }
}
