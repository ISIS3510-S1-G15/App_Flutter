import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/restaurant.dart';
import '../services/location_service.dart';
import '../services/map_tile_cache.dart';
import '../theme/app_theme.dart';
import '../widgets/back_header.dart';
import '../widgets/offline_banner.dart';
import '../widgets/primary_button.dart';

// In-app route to a restaurant using the live GPS (sensor): where the user is, how far it is and when they arrive.
// Works offline: the GPS needs no network, the distance is computed on the phone and the tiles come from
// Camilo's 7-day tile cache. Only "Open in Google Maps" needs internet
class DirectionsScreen extends StatefulWidget {
  final Restaurant restaurant;

  const DirectionsScreen({super.key, required this.restaurant});

  @override
  State<DirectionsScreen> createState() => _DirectionsScreenState();
}

class _DirectionsScreenState extends State<DirectionsScreen> with WidgetsBindingObserver {
  // GPS accuracy is a few meters, so 30 m is "you're at the door" without flickering in and out
  static const double _arrivedMeters = 30;

  Position? _position;
  StreamSubscription<Position>? _sub;
  LocationResult? _locationProblem;
  final MapController _mapController = MapController();
  final _tileProvider = MapTileCache.tileProvider(); // created once, not on every build
  bool _mapReady = false;
  bool _fittedOnce = false;

  bool _locating = false;
  bool _inBackground = false;
  // Restart the GPS on resume ONLY if this screen paused a running stream or the user went to Settings.
  // Restarting on every resume causes a loop: the permission dialog itself pauses and resumes the app
  // (same fix Camilo made in the Map)
  bool _resumeTracking = false;
  bool _openedSettings = false;

  LatLng get _destination => LatLng(widget.restaurant.latitude, widget.restaurant.longitude);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  Future<void> _start() async {
    _locating = true;
    final result = await LocationService.getCurrentLocation();
    _locating = false;
    if (!mounted) return;
    setState(() {
      _position = result.position;
      _locationProblem = result.position == null ? result : null;
    });
    if (result.position == null) return;
    _fitOnce();
    // The app went to the background while the first fix was being read: subscribe when it comes back
    if (_inBackground) {
      _resumeTracking = true;
      return;
    }
    _sub?.cancel();
    _sub = LocationService.positionStream().listen(
      (p) {
        if (mounted) setState(() => _position = p);
      },
      onError: (_) {}, // keeps the last known position if one update fails
    );
  }

  // Pausing the stream in the background saves battery: nobody is looking at the distance (slides 19)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _inBackground = true;
      if (_sub != null) {
        _sub!.cancel();
        _sub = null;
        _resumeTracking = true;
      }
    } else if (state == AppLifecycleState.resumed) {
      _inBackground = false;
      if (_sub == null && !_locating && (_resumeTracking || _openedSettings)) {
        _resumeTracking = false;
        _openedSettings = false;
        _start(); // reads the location again, in case the user turned on the GPS in Settings
      }
    }
  }

  @override
  void dispose() {
    // Unregister the location listener (slides 19, performance bugs): a forgotten GPS stream keeps
    // running and draining the battery after the screen is gone
    _sub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _mapController.dispose();
    super.dispose();
  }

  // Frames user + restaurant only the first time; after that the camera stays where the user leaves it
  void _fitOnce() {
    if (_fittedOnce || !_mapReady || _position == null) return;
    _fittedOnce = true;
    _mapController.fitCamera(CameraFit.coordinates(
      coordinates: [LatLng(_position!.latitude, _position!.longitude), _destination],
      padding: const EdgeInsets.all(60),
      maxZoom: 18,
    ));
  }

  void _onFixLocation(LocationFix fix) {
    if (fix == LocationFix.retry) {
      _start();
    } else {
      _openedSettings = true;
      LocationService.openSettingsFor(fix);
    }
  }

  // Same URL and fallback message "Get directions" used before: turn-by-turn navigation is one tap away
  Future<void> _openGoogleMaps() async {
    final r = widget.restaurant;
    final url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${r.latitude},${r.longitude}&travelmode=walking');
    var opened = false;
    try {
      opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the map')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.restaurant;
    final user = _position == null ? null : LatLng(_position!.latitude, _position!.longitude);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            BackHeader(eyebrow: 'Directions', title: r.name, onBack: () => Navigator.of(context).pop()),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _destination,
                      initialZoom: 17,
                      onMapReady: () {
                        _mapReady = true;
                        _fitOnce();
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.app_flutter',
                        tileProvider: _tileProvider,
                      ),
                      // Straight line on purpose: a real route needs an external routing service (another
                      // network dependency); on campus distances are short and Google Maps covers turn-by-turn
                      if (user != null)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: [user, _destination],
                              color: AppColors.accent,
                              strokeWidth: 4,
                              pattern: const StrokePattern.dotted(),
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _destination,
                            width: 36,
                            height: 36,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4)],
                              ),
                              child: const Icon(Icons.restaurant, size: 18, color: Colors.white),
                            ),
                          ),
                          if (user != null)
                            Marker(
                              point: user,
                              width: 20,
                              height: 20,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                  boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.4), blurRadius: 8)],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
                    ],
                  ),
                ),
              ),
            ),
            const OfflineBanner(
              margin: EdgeInsets.fromLTRB(16, 12, 16, 0),
              message: "You're offline. The map and your distance still work; Google Maps needs internet.",
            ),
            _buildPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildPanel() {
    final r = widget.restaurant;
    final problem = _locationProblem;
    final distance = _position == null ? null : LocationService.distanceTo(_position!, r.latitude, r.longitude);

    final Widget status;
    if (distance != null && distance <= _arrivedMeters) {
      status = _statusRow(Icons.check_circle, AppColors.open, "You've arrived at ${r.name}", null);
    } else if (distance != null) {
      status = _statusRow(
        Icons.directions_walk,
        AppColors.accent,
        '${LocationService.formatDistance(distance)} · ${LocationService.walkingMinutes(distance)} min walk',
        'Straight-line distance · updates as you walk',
      );
    } else if (problem != null) {
      status = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _statusRow(Icons.location_off, AppColors.closed, problem.error!, null),
          const SizedBox(height: 12),
          AppPrimaryButton(
            label: problem.fix == LocationFix.retry ? 'Try again' : 'Open settings',
            onTap: () => _onFixLocation(problem.fix),
          ),
        ],
      );
    } else {
      status = _statusRow(Icons.my_location, AppColors.muted, 'Finding your location…', null);
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          status,
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _openGoogleMaps,
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Open in Google Maps'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: AppColors.accent),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusRow(IconData icon, Color color, String title, String? subtitle) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.cardTitle.copyWith(fontSize: 15)),
              if (subtitle != null)
                Text(subtitle, style: AppTextStyles.body.copyWith(fontSize: 11, color: AppColors.muted)),
            ],
          ),
        ),
      ],
    );
  }
}
