import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/utils/media_url.dart';

void main() {
  setUp(() {
    dotenv.testLoad(mergeWith: {'API_BASE_URL': 'http://10.0.2.2:3000'});
  });

  test('returns null for null or empty urls', () {
    expect(resolveMediaUrl(null), isNull);
    expect(resolveMediaUrl(''), isNull);
  });

  test('prepends the base url to a root-relative path', () {
    expect(
      resolveMediaUrl('/uploads/a.jpg'),
      'http://10.0.2.2:3000/uploads/a.jpg',
    );
  });

  test('strips a trailing slash from the configured base url', () {
    dotenv.env['API_BASE_URL'] = 'http://10.0.2.2:3000/';
    expect(
      resolveMediaUrl('/uploads/a.jpg'),
      'http://10.0.2.2:3000/uploads/a.jpg',
    );
  });

  test('rewrites localhost/loopback hosts to the configured base host', () {
    expect(
      resolveMediaUrl('http://localhost:3000/uploads/a.jpg'),
      'http://10.0.2.2:3000/uploads/a.jpg',
    );
    expect(
      resolveMediaUrl('http://127.0.0.1:3000/uploads/a.jpg'),
      'http://10.0.2.2:3000/uploads/a.jpg',
    );
    expect(
      resolveMediaUrl('http://10.0.2.2:3000/uploads/a.jpg'),
      'http://10.0.2.2:3000/uploads/a.jpg',
    );
  });

  test('keeps a real external host untouched', () {
    const url = 'https://cdn.example.com/uploads/a.jpg';
    expect(resolveMediaUrl(url), url);
  });

  test('prepends the base url to a bare relative path', () {
    expect(
      resolveMediaUrl('uploads/a.jpg'),
      'http://10.0.2.2:3000/uploads/a.jpg',
    );
  });
}
