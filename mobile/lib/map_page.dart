import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import 'l10n/app_localizations.dart';
import 'services/api_exception.dart';
import 'services/feed_service.dart';

const Color _inkColor = Color(0xFF3B2A21);
const Color _inkMuted = Color(0xFF6A4A3B);
const Color _cardColor = Color(0xFFFFF7E6);
const Color _accentColor = Color(0xFFB85C38);

// Centre par défaut si la localisation est refusée.
const LatLng _paris = LatLng(48.8566, 2.3522);
const List<int> _radiusOptions = [1, 2, 5, 10, 20, 30];

// Icônes choisissables par l'admin (clé stockée en base dans Challenge.icon).
const Map<String, IconData> challengeIcons = {
  'camera': Icons.photo_camera,
  'run': Icons.directions_run,
  'bike': Icons.directions_bike,
  'sport': Icons.sports_soccer,
  'water': Icons.pool,
  'nature': Icons.park,
  'food': Icons.restaurant,
  'drink': Icons.local_cafe,
  'music': Icons.music_note,
  'art': Icons.palette,
  'culture': Icons.museum,
  'party': Icons.celebration,
  'shopping': Icons.shopping_bag,
  'star': Icons.star,
};

IconData challengeIcon(Object? key) =>
    challengeIcons[key] ?? Icons.photo_camera;

// Fond de carte épuré : MapTiler si MAPTILER_KEY est dans .env, sinon
// Esri Light Gray (sans clé, mais sans noms de rues).
final String? _mapTilerKey = dotenv.maybeGet('MAPTILER_KEY');
final String _tileUrl = _mapTilerKey != null && _mapTilerKey!.isNotEmpty
    ? 'https://api.maptiler.com/maps/dataviz-light/256/{z}/{x}/{y}.png?key=$_mapTilerKey'
    : 'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}';
final String _tileAttribution = _mapTilerKey != null && _mapTilerKey!.isNotEmpty
    ? '© MapTiler · © OpenStreetMap'
    : '© Esri';

class MapPage extends StatefulWidget {
  const MapPage({
    super.key,
    required this.onUnauthorized,
    required this.onSendChallenge,
  });

  final VoidCallback onUnauthorized;
  // Ouvre la caméra sur ce défi.
  final ValueChanged<Map<String, dynamic>> onSendChallenge;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final FeedService _feedService = FeedService();
  final MapController _mapController = MapController();

  LatLng _center = _paris;
  LatLng? _myPosition;
  int _radiusKm = 10;
  bool _loading = false;
  List<Map<String, dynamic>> _challenges = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _locate());
  }

  Future<void> _locate() async {
    final deniedMessage = AppLocalizations.of(context)!.mapLocationDenied;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage(deniedMessage);
      } else {
        final pos = await Geolocator.getCurrentPosition();
        _myPosition = LatLng(pos.latitude, pos.longitude);
        _center = _myPosition!;
        _mapController.move(_center, _zoomFor(_radiusKm));
      }
    } catch (_) {
      // Service de localisation coupé : on reste sur le centre par défaut.
    }
    await _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final challenges = await _feedService.fetchNearbyChallenges(
        _center.latitude,
        _center.longitude,
        _radiusKm,
      );
      if (mounted) setState(() => _challenges = challenges);
    } on UnauthorizedException {
      widget.onUnauthorized();
    } catch (e) {
      _showMessage(e is ApiException ? e.message : e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // Zoom approximatif pour que le cercle tienne à l'écran.
  double _zoomFor(int km) => switch (km) {
        <= 1 => 14,
        <= 2 => 13,
        <= 5 => 12,
        <= 10 => 11,
        <= 20 => 10,
        _ => 9.5,
      };

  void _setRadius(int km) {
    setState(() => _radiusKm = km);
    _mapController.move(_center, _zoomFor(km));
    _fetch();
  }

  Future<void> _showChallenge(Map<String, dynamic> challenge) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ChallengeDialog(
        challenge: challenge,
        feedService: _feedService,
        onUnauthorized: widget.onUnauthorized,
        onSend: () {
          Navigator.pop(context);
          widget.onSendChallenge(challenge);
        },
      ),
    );
    // L'inscription a pu changer pendant la popup.
    if (mounted) setState(() {});
  }

  // Épingle en goutte (Icons.location_on) + icône du défi + badge inscrits.
  Widget _buildMarker(Map<String, dynamic> challenge) {
    final live = challenge['isLive'] == true;
    final count = (challenge['participants'] as num?)?.toInt() ?? 0;
    return GestureDetector(
      onTap: () => _showChallenge(challenge),
      child: Semantics(
        button: true,
        label: challenge['title']?.toString(),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Icon(
              Icons.location_on,
              size: 52,
              color: live ? _accentColor : _inkMuted,
              shadows: const [Shadow(blurRadius: 4, color: Colors.black38)],
            ),
            // Le trou de location_on est centré à ~19.5px du haut pour size 52.
            Positioned(
              top: 7.5,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  challengeIcon(challenge['icon']),
                  size: 16,
                  color: live ? _accentColor : _inkMuted,
                ),
              ),
            ),
            if (count > 0)
              Positioned(
                top: -4,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: _inkColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: _zoomFor(_radiusKm),
              minZoom: 8,
              maxZoom: 18,
              // La carte se déplace librement, la zone de recherche reste
              // centrée sur la position : seul le rayon (chips) la change.
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: _tileUrl,
                maxNativeZoom: 16,
                userAgentPackageName: 'com.example.mobile',
                panBuffer: 0,
                tileDisplay: const TileDisplay.instantaneous(),
              ),
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _center,
                    radius: _radiusKm * 1000,
                    useRadiusInMeter: true,
                    color: _accentColor.withValues(alpha: 0.06),
                    borderColor: _accentColor.withValues(alpha: 0.5),
                    borderStrokeWidth: 1.5,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  if (_myPosition != null)
                    Marker(
                      point: _myPosition!,
                      width: 16,
                      height: 16,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                      ),
                    ),
                  for (final challenge in _challenges)
                    Marker(
                      point: LatLng(
                        (challenge['latitude'] as num).toDouble(),
                        (challenge['longitude'] as num).toDouble(),
                      ),
                      width: 52,
                      height: 52,
                      // Pointe de la goutte sur la position.
                      alignment: Alignment.topCenter,
                      child: _buildMarker(challenge),
                    ),
                ],
              ),
              SimpleAttributionWidget(source: Text(_tileAttribution)),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Card(
                color: _cardColor,
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.mapChallengesWithin(_challenges.length, _radiusKm),
                              style: GoogleFonts.karla(
                                color: _inkColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (_loading)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final km in _radiusOptions)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: Text('$km km'),
                                  selected: km == _radiusKm,
                                  selectedColor: _accentColor.withValues(alpha: 0.3),
                                  visualDensity: VisualDensity.compact,
                                  onSelected: (_) => _setRadius(km),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _myPosition == null
          ? null
          : FloatingActionButton(
              backgroundColor: _accentColor,
              tooltip: l10n.mapRecenter,
              onPressed: () => _mapController.move(_center, _zoomFor(_radiusKm)),
              child: const Icon(Icons.my_location, color: Colors.white),
            ),
    );
  }
}

/// Popup d'un défi de la carte : compte à rebours, inscription, envoi.
class _ChallengeDialog extends StatefulWidget {
  const _ChallengeDialog({
    required this.challenge,
    required this.feedService,
    required this.onUnauthorized,
    required this.onSend,
  });

  // Mis à jour en place (registered / participants) pour la carte.
  final Map<String, dynamic> challenge;
  final FeedService feedService;
  final VoidCallback onUnauthorized;
  final VoidCallback onSend;

  @override
  State<_ChallengeDialog> createState() => _ChallengeDialogState();
}

class _ChallengeDialogState extends State<_ChallengeDialog> {
  late final Timer _ticker;
  bool _saving = false;

  Map<String, dynamic> get _c => widget.challenge;
  DateTime get _startsAt => DateTime.parse(_c['date'].toString()).toLocal();
  DateTime get _endsAt => DateTime.parse(_c['endsAt'].toString()).toLocal();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final time =
        '${two(d.inHours.remainder(24))}h ${two(d.inMinutes.remainder(60))}m ${two(d.inSeconds.remainder(60))}s';
    return d.inDays > 0 ? '${d.inDays}j $time' : time;
  }

  Future<void> _toggleRegistration() async {
    setState(() => _saving = true);
    try {
      final state = await widget.feedService.setChallengeRegistration(
        _c['id'] as int,
        registered: _c['registered'] != true,
      );
      _c['registered'] = state['registered'];
      _c['participants'] = state['participants'];
    } on UnauthorizedException {
      widget.onUnauthorized();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final live = !now.isBefore(_startsAt) && now.isBefore(_endsAt);
    final ended = !now.isBefore(_endsAt);
    final registered = _c['registered'] == true;
    final distance = (_c['distanceKm'] as num?)?.toDouble() ?? 0;

    return AlertDialog(
      backgroundColor: _cardColor,
      title: Text(
        _c['title']?.toString() ?? '',
        style: GoogleFonts.dmSerifDisplay(color: _inkColor, fontSize: 22),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Chip(
            avatar: Icon(
              challengeIcon(_c['icon']),
              size: 16,
              color: live ? Colors.white : _accentColor,
            ),
            label: Text(live ? l10n.mapLive : l10n.mapUpcoming),
            backgroundColor:
                live ? _accentColor : _accentColor.withValues(alpha: 0.15),
            labelStyle: TextStyle(color: live ? Colors.white : _accentColor),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(height: 8),
          Text(
            _c['description']?.toString() ?? '',
            style: GoogleFonts.karla(color: _inkColor, fontSize: 15),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.timer_outlined, color: _accentColor, size: 20),
              const SizedBox(width: 6),
              Text(
                live
                    ? l10n.mapEndsIn(_format(_endsAt.difference(now)))
                    : l10n.mapStartsIn(_format(_startsAt.difference(now))),
                style: GoogleFonts.karla(
                  color: _inkColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${l10n.mapDistance(distance.toStringAsFixed(1))} · '
            '${l10n.mapParticipants((_c['participants'] as num?)?.toInt() ?? 0)} · '
            '${l10n.mapCompleted((_c['completed'] as num?)?.toInt() ?? 0)}',
            style: GoogleFonts.karla(color: _inkMuted, fontSize: 13),
          ),
        ],
      ),
      actionsOverflowButtonSpacing: 8,
      actions: ended
          ? null
          : [
              OutlinedButton(
                onPressed: _saving ? null : _toggleRegistration,
                style: OutlinedButton.styleFrom(foregroundColor: _accentColor),
                child: Text(
                  registered
                      ? l10n.mapRegistered
                      : (live ? l10n.mapJoin : l10n.mapRegister),
                ),
              ),
              if (live)
                FilledButton.icon(
                  onPressed: widget.onSend,
                  style: FilledButton.styleFrom(backgroundColor: _accentColor),
                  icon: const Icon(Icons.photo_camera),
                  label: Text(l10n.mapSendChallenge),
                ),
            ],
    );
  }
}
