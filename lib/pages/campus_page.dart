import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../campus/campus_data.dart';
import '../campus/geo.dart';
import '../campus/map_style.dart';
import '../campus/marker_icons.dart';
import '../campus/shuttle_simulator.dart';
import '../campus/trip_planner.dart';
import '../services/location_service.dart';
import '../theme/app_colors.dart';
import '../widgets/campus_widgets.dart';

class CampusPage extends StatefulWidget {
  const CampusPage({super.key});

  @override
  State<CampusPage> createState() => _CampusPageState();
}

class _CampusPageState extends State<CampusPage> {
  static const _nearbyRadius = 400.0; // meters

  final _sim = ShuttleSimulator();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  GoogleMapController? _map;
  MarkerIcons? _icons;

  LatLng _user = CampusData.demoUser;
  bool _demoLocation = true;

  String? _selectedLineId;
  final Set<FacilityType> _facilityFilter = {};
  Trip? _trip;

  LatLng? _pickup;
  String _pickupAddress = '';
  Shuttle? _requestedShuttle;
  int _pickupToken = 0; // discards stale reverse-geocode results

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() => setState(() {}));
    _sim.addListener(_onTick);
    _sim.start();
    MarkerIcons.load().then((icons) {
      if (mounted) setState(() => _icons = icons);
    });
    _locateUser(animate: false);
  }

  @override
  void dispose() {
    _sim.removeListener(_onTick);
    _sim.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------- location

  Future<void> _locateUser({bool animate = true}) async {
    final result = await LocationService.getCurrentPosition();
    if (!mounted) return;
    final p = result.position;
    final onCampus = p != null &&
        Geo.distance(LatLng(p.latitude, p.longitude), CampusData.center) <
            2500;
    setState(() {
      _user = onCampus ? LatLng(p.latitude, p.longitude) : CampusData.demoUser;
      _demoLocation = !onCampus;
    });
    if (animate) {
      _map?.animateCamera(CameraUpdate.newLatLngZoom(_user, 17));
    }
  }

  // ------------------------------------------------------------------ search

  List<Building> get _suggestions {
    final q = _searchController.text.trim().toLowerCase();
    return CampusData.buildings
        .where((b) => q.isEmpty || b.name.toLowerCase().contains(q))
        .toList();
  }

  void _planTo(LatLng destination, String name) {
    _searchFocus.unfocus();
    final trip = TripPlanner.plan(
      sim: _sim,
      origin: _user,
      destination: destination,
      destinationName: name,
    );
    setState(() {
      _trip = trip;
      _pickup = null;
      _requestedShuttle = null;
      _selectedLineId = null;
    });
    _fit([_user, destination, ...trip.ridePath]);
  }

  void _clearTrip() => setState(() {
        _trip = null;
        _searchController.clear();
      });

  void _fit(List<LatLng> points) {
    _map?.animateCamera(
      CameraUpdate.newLatLngBounds(Geo.boundsOf(points), 70),
    );
  }

  // ------------------------------------------------------------------ pickup

  Future<void> _dropPickup(LatLng pos) async {
    _searchFocus.unfocus();
    final token = ++_pickupToken;
    setState(() {
      _pickup = pos;
      _pickupAddress = 'Finding address…';
      _requestedShuttle = null;
      _trip = null;
    });
    var address =
        '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
    try {
      final places = await Geocoding().placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (places.isNotEmpty) {
        final p = places.first;
        final parts = [p.name, p.street, p.subLocality]
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .toSet()
            .take(2);
        if (parts.isNotEmpty) address = parts.join(', ');
      }
    } catch (_) {
      // Emulators often lack a geocoder; the coordinates are a fine fallback.
    }
    if (mounted && token == _pickupToken) {
      setState(() => _pickupAddress = address);
    }
  }

  bool get _pickupInside =>
      _pickup != null && Geo.insidePolygon(_pickup!, CampusData.boundary);

  void _confirmPickup() {
    final arrival = _sim.nearestTo(_pickup!);
    setState(() => _requestedShuttle = arrival.shuttle);
  }

  void _cancelPickup() {
    _pickupToken++;
    setState(() {
      _pickup = null;
      _requestedShuttle = null;
    });
  }

  // ------------------------------------------------------------------ stops

  void _openStop(Stop stop) {
    _searchFocus.unfocus();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StopSheet(
        stop: stop,
        sim: _sim,
        onGoHere: () {
          Navigator.pop(sheetContext);
          _planTo(stop.position, stop.name);
        },
      ),
    );
  }

  // ----------------------------------------------------------- map overlays

  Set<Polyline> get _polylines {
    final out = <Polyline>{};
    final tripLine = _trip?.line.id;
    for (final line in CampusData.lines) {
      final focused = _trip != null
          ? line.id == tripLine
          : _selectedLineId == null || _selectedLineId == line.id;
      out.add(Polyline(
        polylineId: PolylineId(line.id),
        points: _sim.routes[line.id]!.loop,
        color: line.color.withValues(alpha: focused ? 0.9 : 0.22),
        width: focused && _selectedLineId == line.id ? 8 : 6,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
        consumeTapEvents: true,
        zIndex: focused ? 2 : 1,
        onTap: () => setState(() {
          _trip = null;
          _selectedLineId = _selectedLineId == line.id ? null : line.id;
        }),
      ));
    }

    final trip = _trip;
    if (trip != null) {
      out.addAll([
        Polyline(
          polylineId: const PolylineId('trip_casing'),
          points: trip.ridePath,
          color: Colors.white,
          width: 14,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
          zIndex: 4,
        ),
        Polyline(
          polylineId: const PolylineId('trip_ride'),
          points: trip.ridePath,
          color: trip.line.color,
          width: 9,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
          zIndex: 5,
        ),
        Polyline(
          polylineId: const PolylineId('trip_walk_to'),
          points: [trip.origin, trip.boardStop.position],
          color: AppColors.ink,
          width: 5,
          patterns: [PatternItem.dot, PatternItem.gap(8)],
          zIndex: 6,
        ),
        Polyline(
          polylineId: const PolylineId('trip_walk_from'),
          points: [trip.alightStop.position, trip.destination],
          color: AppColors.ink,
          width: 5,
          patterns: [PatternItem.dot, PatternItem.gap(8)],
          zIndex: 6,
        ),
      ]);
    }
    return out;
  }

  Set<Marker> get _markers {
    final icons = _icons!;
    final out = <Marker>{};
    final trip = _trip;

    for (final stop in CampusData.stops) {
      final active = trip != null &&
          (stop == trip.boardStop || stop == trip.alightStop);
      out.add(Marker(
        markerId: MarkerId('stop_${stop.id}'),
        position: stop.position,
        icon: active ? icons.stopActive : icons.stop,
        anchor: const Offset(0.5, 0.5),
        zIndexInt: active ? 4 : 2,
        onTap: () => _openStop(stop),
      ));
    }

    for (final s in _sim.shuttles) {
      final dimmed = _trip != null
          ? s.line != _trip!.line
          : _selectedLineId != null && s.line.id != _selectedLineId;
      out.add(Marker(
        markerId: MarkerId('shuttle_${s.id}'),
        position: s.position,
        icon: icons.shuttles[s.line.id]!,
        rotation: s.heading,
        flat: true,
        anchor: const Offset(0.5, 0.5),
        alpha: dimmed ? 0.35 : 1,
        zIndexInt: 6,
        infoWindow: InfoWindow(title: '${s.line.name} · ${s.id}'),
      ));
    }

    out.add(Marker(
      markerId: const MarkerId('user'),
      position: _user,
      icon: icons.user,
      anchor: const Offset(0.5, 0.5),
      zIndexInt: 5,
    ));

    for (final f in CampusData.facilities) {
      if (!_facilityFilter.contains(f.type)) continue;
      out.add(Marker(
        markerId: MarkerId('fac_${f.name}'),
        position: f.position,
        icon: icons.facilities[f.type]!,
        anchor: const Offset(0.5, 0.5),
        zIndexInt: 3,
        infoWindow: InfoWindow(title: f.name, snippet: f.type.label),
      ));
    }

    if (trip != null) {
      out.add(Marker(
        markerId: const MarkerId('destination'),
        position: trip.destination,
        icon: icons.destination,
        anchor: const Offset(0.5, 0.88),
        zIndexInt: 7,
      ));
    }

    if (_pickup != null) {
      out.add(Marker(
        markerId: const MarkerId('pickup'),
        position: _pickup!,
        icon: _pickupInside ? icons.pickup : icons.pickupOutside,
        anchor: const Offset(0.5, 0.88),
        draggable: _requestedShuttle == null,
        zIndexInt: 7,
        onDragEnd: _dropPickup,
      ));
    }
    return out;
  }

  int _nearbyCount(FacilityType type) => CampusData.facilities
      .where((f) =>
          f.type == type &&
          Geo.distance(_user, f.position) <= _nearbyRadius)
      .length;

  // ------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    if (_icons == null) {
      return const Scaffold(
        backgroundColor: AppColors.canvas,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.violet),
        ),
      );
    }

    final showSuggestions = _searchFocus.hasFocus;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition:
                const CameraPosition(target: CampusData.center, zoom: 16),
            padding: const EdgeInsets.only(top: 170, bottom: 290),
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            polylines: _polylines,
            markers: _markers,
            polygons: {
              Polygon(
                polygonId: const PolygonId('campus'),
                points: CampusData.boundary,
                fillColor: AppColors.violet.withValues(alpha: 0.07),
                strokeColor: AppColors.violet.withValues(alpha: 0.7),
                strokeWidth: 3,
              ),
            },
            circles: {
              Circle(
                circleId: const CircleId('nearby'),
                center: _user,
                radius: _nearbyRadius,
                fillColor: AppColors.sky.withValues(alpha: 0.08),
                strokeColor: AppColors.sky.withValues(alpha: 0.45),
                strokeWidth: 2,
              ),
            },
            onMapCreated: (c) {
              _map = c;
              // ignore: deprecated_member_use
              c.setMapStyle(campusMapStyle);
            },
            onTap: (_) => _searchFocus.unfocus(),
            onLongPress: _dropPickup,
          ),

          // Top: search, suggestions, line filter
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchField(),
                  if (showSuggestions) ...[
                    const SizedBox(height: 8),
                    _buildSuggestions(),
                  ] else ...[
                    const SizedBox(height: 12),
                    _buildLineChips(),
                  ],
                ],
              ),
            ),
          ),

          // Bottom: facility chips + locate button, then the state card
          Positioned(
            left: 16,
            right: 16,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildFacilityChips()),
                        const SizedBox(width: 10),
                        RoundIconButton(
                          icon: PhosphorIconsBold.crosshairSimple,
                          tooltip: 'My location',
                          onTap: _locateUser,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildBottomCard(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppColors.softShadow,
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        onChanged: (_) => setState(() {}),
        textInputAction: TextInputAction.search,
        onSubmitted: (_) {
          final s = _suggestions;
          if (s.isNotEmpty) _planTo(s.first.position, s.first.name);
        },
        style: const TextStyle(
            fontWeight: FontWeight.w600, color: AppColors.ink),
        decoration: InputDecoration(
          hintText: 'Where to on campus?',
          hintStyle: const TextStyle(color: AppColors.inkSoft),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 17),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 6),
            child: Icon(PhosphorIconsBold.magnifyingGlass,
                color: AppColors.violet),
          ),
          suffixIcon: _searchController.text.isEmpty && _trip == null
              ? null
              : IconButton(
                  icon: const Icon(PhosphorIconsBold.x, size: 18),
                  color: AppColors.inkSoft,
                  onPressed: () {
                    _searchFocus.unfocus();
                    _clearTrip();
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    final items = _suggestions;
    return FloatingCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.4,
        ),
        child: items.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No buildings match.',
                    style: TextStyle(color: AppColors.inkSoft)),
              )
            : ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final b = items[i];
                  return ListTile(
                    onTap: () {
                      _searchController.text = b.name;
                      _planTo(b.position, b.name);
                    },
                    leading: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: AppColors.violetSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(b.icon, size: 20, color: AppColors.violet),
                    ),
                    title: Text(b.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink)),
                    subtitle: Text(
                      '${b.hint} · ${fmtMeters(Geo.distance(_user, b.position))}',
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.inkSoft),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildLineChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          SelectChip(
            label: 'All lines',
            selected: _selectedLineId == null && _trip == null,
            onTap: () => setState(() {
              _selectedLineId = null;
              _trip = null;
            }),
          ),
          for (final line in CampusData.lines) ...[
            const SizedBox(width: 8),
            SelectChip(
              label: line.name,
              color: line.color,
              selected: _selectedLineId == line.id,
              leading: LineDot(
                _selectedLineId == line.id ? Colors.white : line.color,
              ),
              onTap: () {
                setState(() {
                  _trip = null;
                  _selectedLineId =
                      _selectedLineId == line.id ? null : line.id;
                });
                if (_selectedLineId != null) {
                  _fit(_sim.routes[line.id]!.points);
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFacilityChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final type in FacilityType.values) ...[
            SelectChip(
              label: '${type.label} · ${_nearbyCount(type)}',
              color: type.color,
              selected: _facilityFilter.contains(type),
              leading: Icon(
                type.icon,
                size: 16,
                color: _facilityFilter.contains(type)
                    ? Colors.white
                    : type.color,
              ),
              onTap: () => setState(() {
                _facilityFilter.contains(type)
                    ? _facilityFilter.remove(type)
                    : _facilityFilter.add(type);
              }),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomCard() {
    if (_pickup != null) {
      final requested = _requestedShuttle;
      return PickupCard(
        address: _pickupAddress,
        inside: _pickupInside,
        requested: requested == null
            ? null
            : Arrival(
                requested,
                Duration(
                  seconds: (Geo.distance(requested.position, _pickup!) /
                          ShuttleSimulator.speed)
                      .round(),
                ),
              ),
        onConfirm: _confirmPickup,
        onCancel: _cancelPickup,
      );
    }
    if (_trip != null) {
      return TripCard(trip: _trip!, sim: _sim, onClose: _clearTrip);
    }
    return IdleCard(
      shuttleCount: _sim.shuttles.length,
      demoLocation: _demoLocation,
    );
  }
}
