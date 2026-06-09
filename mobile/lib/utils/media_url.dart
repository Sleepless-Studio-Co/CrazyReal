import 'package:flutter_dotenv/flutter_dotenv.dart';

String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000';

String? resolveMediaUrl(String? rawUrl) {
  if (rawUrl == null || rawUrl.isEmpty) return null;

  final configuredBase = apiBaseUrl.endsWith('/')
      ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
      : apiBaseUrl;
  final configuredUri = Uri.tryParse(configuredBase);

  if (rawUrl.startsWith('/')) {
    return '$configuredBase$rawUrl';
  }

  final uri = Uri.tryParse(rawUrl);
  if (uri != null && uri.hasScheme) {
    final host = uri.host.toLowerCase();
    if ((host == 'localhost' ||
            host == '127.0.0.1' ||
            host == '10.0.2.2') &&
        configuredUri != null) {
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
