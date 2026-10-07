import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/store.dart';
import '../services/location_service.dart';

class _StoreHit {
  final Store store;
  final double meters;
  const _StoreHit(this.store, this.meters);
}

class ResultsPage extends StatefulWidget {
  final LatLng center;
  final String label;

  const ResultsPage({super.key, required this.center, required this.label});

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  static const _radiiKm = [2, 5, 10, 25, 50];

  GoogleMapController? _mapController;
  List<_StoreHit> _all = [];
  int _radiusKm = 10;
  String _category = 'All';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snap = await FirebaseFirestore.instance.collection('stores').get();
      final hits = snap.docs.map(Store.fromDoc).map((s) {
        final d = LocationService.distanceMeters(
          widget.center.latitude,
          widget.center.longitude,
          s.lat,
          s.lng,
        );
        return _StoreHit(s, d);
      }).toList()
        ..sort((a, b) => a.meters.compareTo(b.meters));
      _all = hits;
    } catch (e) {
      _error = 'Could not load shops: $e';
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  List<_StoreHit> get _inRadius =>
      _all.where((h) => h.meters <= _radiusKm * 1000).toList();

  List<String> get _categories {
    final set = _inRadius.map((h) => h.store.category).toSet().toList()
      ..sort();
    return ['All', ...set];
  }

  List<_StoreHit> get _visible => _category == 'All'
      ? _inRadius
      : _inRadius.where((h) => h.store.category == _category).toList();

  Set<Marker> get _markers => {
        Marker(
          markerId: const MarkerId('center'),
          position: widget.center,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(title: widget.label),
        ),
        for (final h in _visible)
          Marker(
            markerId: MarkerId(h.store.id),
            position: LatLng(h.store.lat, h.store.lng),
            infoWindow: InfoWindow(
              title: h.store.name,
              snippet: LocationService.formatDistance(h.meters),
            ),
          ),
      };

  IconData _iconFor(String category) {
    switch (category.toLowerCase()) {
      case 'grocery':
        return Icons.shopping_basket_outlined;
      case 'books':
        return Icons.menu_book_outlined;
      case 'electronics':
        return Icons.devices_other_outlined;
      case 'cafe':
        return Icons.local_cafe_outlined;
      default:
        return Icons.storefront_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visible = _visible;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Shops nearby'),
            Text(
              widget.label,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                            onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    SizedBox(
                      height: 200,
                      child: GoogleMap(
                        initialCameraPosition:
                            CameraPosition(target: widget.center, zoom: 12),
                        markers: _markers,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        onMapCreated: (c) => _mapController = c,
                      ),
                    ),
                    // Radius
                    SizedBox(
                      height: 52,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                        itemCount: _radiiKm.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => ChoiceChip(
                          avatar: const Icon(Icons.radar, size: 16),
                          label: Text('${_radiiKm[i]} km'),
                          selected: _radiusKm == _radiiKm[i],
                          onSelected: (_) => setState(() {
                            _radiusKm = _radiiKm[i];
                            _category = 'All';
                          }),
                        ),
                      ),
                    ),
                    // Category
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _categories.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final c = _categories[i];
                          return FilterChip(
                            label: Text(c),
                            selected: _category == c,
                            onSelected: (_) => setState(() => _category = c),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${visible.length} shop${visible.length == 1 ? '' : 's'} found',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                    ),
                    Expanded(
                      child: visible.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'No shops within $_radiusKm km of this location.\nTry a larger radius.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              itemCount: visible.length,
                              itemBuilder: (_, i) {
                                final h = visible[i];
                                return Card(
                                  elevation: 0,
                                  color: scheme.surfaceContainerHighest,
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: scheme.primaryContainer,
                                      foregroundColor:
                                          scheme.onPrimaryContainer,
                                      child: Icon(_iconFor(h.store.category)),
                                    ),
                                    title: Text(h.store.name),
                                    subtitle: Text(h.store.category),
                                    trailing: Text(
                                      LocationService.formatDistance(h.meters),
                                      style: TextStyle(
                                        color: scheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    onTap: () => _mapController?.animateCamera(
                                      CameraUpdate.newLatLngZoom(
                                        LatLng(h.store.lat, h.store.lng),
                                        16,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
