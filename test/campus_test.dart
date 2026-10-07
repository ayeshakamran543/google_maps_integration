import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps/campus/campus_data.dart';
import 'package:google_maps/campus/geo.dart';
import 'package:google_maps/campus/shuttle_simulator.dart';
import 'package:google_maps/campus/trip_planner.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  test('geofence accepts campus center and rejects far points', () {
    expect(Geo.insidePolygon(CampusData.center, CampusData.boundary), isTrue);
    expect(
      Geo.insidePolygon(const LatLng(33.70, 73.05), CampusData.boundary),
      isFalse,
    );
  });

  test('every stop and building is inside the geofence', () {
    for (final s in CampusData.stops) {
      expect(Geo.insidePolygon(s.position, CampusData.boundary), isTrue,
          reason: s.name);
    }
    for (final b in CampusData.buildings) {
      expect(Geo.insidePolygon(b.position, CampusData.boundary), isTrue,
          reason: b.name);
    }
  });

  test('route positions hit stops at their offsets and wrap around', () {
    for (final line in CampusData.lines) {
      final route = LineRoute(line);
      for (final stop in line.stops) {
        final p = route.positionAt(route.offsetOf(stop));
        expect(Geo.distance(p, stop.position), lessThan(0.5));
      }
      final start = route.positionAt(0);
      final end = route.positionAt(route.length - 0.01);
      expect(Geo.distance(start, end), lessThan(1));
    }
  });

  test('arrival ETAs are sorted and within one loop', () {
    final sim = ShuttleSimulator();
    final arrivals = sim.arrivalsAt(CampusData.library);
    expect(arrivals, isNotEmpty);
    for (var i = 1; i < arrivals.length; i++) {
      expect(arrivals[i].eta >= arrivals[i - 1].eta, isTrue);
    }
    sim.dispose();
  });

  test('trip planner boards and alights on the same line', () {
    final sim = ShuttleSimulator();
    final trip = TripPlanner.plan(
      sim: sim,
      origin: CampusData.demoUser,
      destination: CampusData.buildings
          .firstWhere((b) => b.name == 'Sports Complex')
          .position,
      destinationName: 'Sports Complex',
    );
    expect(trip.line.stops, containsAll([trip.boardStop, trip.alightStop]));
    expect(trip.ridePath.first, trip.boardStop.position);
    expect(trip.ridePath.last, trip.alightStop.position);
    sim.dispose();
  });
}
