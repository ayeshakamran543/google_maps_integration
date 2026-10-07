import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'campus_data.dart';
import 'geo.dart';
import 'shuttle_simulator.dart';

/// Walk -> shuttle -> walk plan on a single line.
class Trip {
  final String destinationName;
  final LatLng origin;
  final LatLng destination;
  final ShuttleLine line;
  final Stop boardStop;
  final Stop alightStop;
  final List<LatLng> ridePath;
  final double walkToMeters;
  final double rideMeters;
  final double walkFromMeters;

  const Trip({
    required this.destinationName,
    required this.origin,
    required this.destination,
    required this.line,
    required this.boardStop,
    required this.alightStop,
    required this.ridePath,
    required this.walkToMeters,
    required this.rideMeters,
    required this.walkFromMeters,
  });

  static const walkSpeed = 1.3; // m/s

  Duration get walkTo => Duration(seconds: (walkToMeters / walkSpeed).round());
  Duration get walkFrom =>
      Duration(seconds: (walkFromMeters / walkSpeed).round());
  Duration get ride =>
      Duration(seconds: (rideMeters / ShuttleSimulator.speed).round());
}

class TripPlanner {
  /// Picks the line + stop pair that minimizes walking, with riding counted
  /// at a lower weight.
  static Trip plan({
    required ShuttleSimulator sim,
    required LatLng origin,
    required LatLng destination,
    required String destinationName,
  }) {
    Trip? best;
    var bestCost = double.infinity;

    for (final line in CampusData.lines) {
      final route = sim.routes[line.id]!;
      for (final a in line.stops) {
        for (final b in line.stops) {
          if (a == b) continue;
          final walkTo = Geo.distance(origin, a.position);
          final walkFrom = Geo.distance(b.position, destination);
          final ride = route.distanceBetween(a, b);
          final cost = walkTo + walkFrom + ride * 0.25;
          if (cost < bestCost) {
            bestCost = cost;
            best = Trip(
              destinationName: destinationName,
              origin: origin,
              destination: destination,
              line: line,
              boardStop: a,
              alightStop: b,
              ridePath: route.pathBetween(a, b),
              walkToMeters: walkTo,
              rideMeters: ride,
              walkFromMeters: walkFrom,
            );
          }
        }
      }
    }
    return best!;
  }
}
