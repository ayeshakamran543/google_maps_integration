import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/location_service.dart';
import 'results_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  // Fallback so the map is never blank (Islamabad).
  static const LatLng _fallbackCenter = LatLng(33.6844, 73.0479);

  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  GoogleMapController? _mapController;

  LatLng _selected = _fallbackCenter;
  String _label = 'Islamabad (default)';
  bool _hasUserLocation = false;
  bool _searching = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _useMyLocation(animate: false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _useMyLocation({bool animate = true}) async {
    final result = await LocationService.getCurrentPosition();
    if (!mounted) return;
    if (result.status == LocationResultStatus.granted) {
      final pos = LatLng(result.position!.latitude, result.position!.longitude);
      setState(() {
        _hasUserLocation = true;
        _message = null;
        _selected = pos;
        _label = 'Your location';
        _searchController.clear();
      });
      if (animate) _moveCamera(pos);
    } else {
      setState(() {
        _message = switch (result.status) {
          LocationResultStatus.serviceOff => 'Location is turned off.',
          LocationResultStatus.deniedForever =>
            'Location permission is blocked. Enable it in settings.',
          _ => 'Could not get your location. Search for a place instead.',
        };
      });
      if (animate) _moveCamera(_selected);
    }
  }

  void _moveCamera(LatLng target, {double zoom = 14}) {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, zoom));
  }

  /// Native geocoder first (works offline-ish on real devices); falls back to
  /// OpenStreetMap Nominatim, since emulators often have no native geocoder.
  Future<LatLng?> _geocode(String query) async {
    try {
      final results = await Geocoding().locationFromAddress(query);
      if (results.isNotEmpty) {
        return LatLng(results.first.latitude, results.first.longitude);
      }
    } catch (_) {}

    final client = HttpClient();
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'json',
        'limit': '1',
      });
      final req = await client.getUrl(uri);
      req.headers.set('User-Agent', 'google_maps_store_locator');
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      final list = jsonDecode(body) as List;
      if (list.isEmpty) return null;
      return LatLng(
        double.parse(list.first['lat'] as String),
        double.parse(list.first['lon'] as String),
      );
    } finally {
      client.close();
    }
  }

  Future<void> _search(String query) async {
    query = query.trim();
    if (query.isEmpty) return;
    _searchFocus.unfocus();
    setState(() {
      _searching = true;
      _message = null;
    });
    try {
      final pos = await _geocode(query);
      if (!mounted) return;
      if (pos == null) {
        setState(() => _message = 'No place found for "$query".');
      } else {
        setState(() {
          _selected = pos;
          _label = query;
        });
        _moveCamera(pos);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Search failed. Check your connection.');
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _onMapTap(LatLng pos) {
    _searchFocus.unfocus();
    setState(() {
      _selected = pos;
      _label = 'Dropped pin';
      _searchController.clear();
    });
  }

  void _findShops() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultsPage(center: _selected, label: _label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _selected, zoom: 14),
            myLocationEnabled: _hasUserLocation,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            padding: EdgeInsets.only(bottom: 150, top: topInset + 70),
            markers: {
              Marker(
                markerId: const MarkerId('selected'),
                position: _selected,
                draggable: true,
                infoWindow: InfoWindow(title: _label),
                onDragEnd: (p) => setState(() {
                  _selected = p;
                  _label = 'Dropped pin';
                  _searchController.clear();
                }),
              ),
            },
            onMapCreated: (c) => _mapController = c,
            onTap: _onMapTap,
          ),

          // Search field
          Positioned(
            top: topInset + 12,
            left: 16,
            right: 16,
            child: Material(
              elevation: 6,
              shadowColor: Colors.black38,
              borderRadius: BorderRadius.circular(28),
              color: scheme.surface,
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                textInputAction: TextInputAction.search,
                onSubmitted: _search,
                decoration: InputDecoration(
                  hintText: 'Search a city, area or address',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  prefixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () => _search(_searchController.text),
                  ),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),

          // My-location button
          Positioned(
            right: 16,
            bottom: 170,
            child: FloatingActionButton.small(
              heroTag: 'my_location',
              tooltip: 'Use my location',
              backgroundColor: scheme.surface,
              onPressed: _useMyLocation,
              child: const Icon(Icons.my_location),
            ),
          ),

          // Bottom panel
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(24),
              color: scheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.place, color: scheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _message!,
                        style: TextStyle(color: scheme.error),
                      ),
                    ] else ...[
                      const SizedBox(height: 4),
                      Text(
                        'Tap the map or drag the pin to adjust.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _findShops,
                        icon: const Icon(Icons.storefront),
                        label: const Text('Find shops here'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
