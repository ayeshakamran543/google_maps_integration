import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'campus_data.dart';
import 'geo.dart';

/// A closed loop through a line's stops, with cumulative distances so a
/// shuttle can be placed anywhere along it by a single "distance traveled".
class LineRoute {
  final ShuttleLine line;
  final List<LatLng> points;
  final List<double> cumulative; // distance from stop 0 to stop i
  final double length;

  LineRoute._(this.line, this.points, this.cumulative, this.length);

  factory LineRoute(ShuttleLine line) {
    final pts = line.stops.map((s) => s.position).toList();
    final cum = <double>[0];
    for (var i = 0; i < pts.length; i++) {
      cum.add(cum.last + Geo.distance(pts[i], pts[(i + 1) % pts.length]));
    }
    final total = cum.removeLast();
    return LineRoute._(line, pts, cum, total);
  }

  /// The full loop as a closed polyline.
  List<LatLng> get loop => [...points, points.first];

  double offsetOf(Stop stop) => cumulative[line.stops.indexOf(stop)];

  int _segmentAt(double d) {
    var i = 0;
    while (i < points.length - 1 && cumulative[i + 1] <= d) {
      i++;
    }
    return i;
  }

  LatLng positionAt(double d) {
    d %= length;
    final i = _segmentAt(d);
    final a = points[i];
    final b = points[(i + 1) % points.length];
    final segLen = (i + 1 < cumulative.length ? cumulative[i + 1] : length) -
        cumulative[i];
    return Geo.lerp(a, b, segLen == 0 ? 0 : (d - cumulative[i]) / segLen);
  }

  double headingAt(double d) {
    final i = _segmentAt(d % length);
    return Geo.bearing(points[i], points[(i + 1) % points.length]);
  }

  /// Distance from [from] forward along the loop to [to].
  double distanceBetween(Stop from, Stop to) =>
      (offsetOf(to) - offsetOf(from) + length) % length;

  /// Stop positions from [from] forward to [to] (inclusive), wrapping.
  List<LatLng> pathBetween(Stop from, Stop to) {
    final n = points.length;
    var i = line.stops.indexOf(from);
    final end = line.stops.indexOf(to);
    final out = [points[i]];
    while (i != end) {
      i = (i + 1) % n;
      out.add(points[i]);
    }
    return out;
  }
}

class Shuttle {
  final String id;
  final LineRoute route;
  double distance; // along the loop
  Shuttle(this.id, this.route, this.distance);

  ShuttleLine get line => route.line;
  LatLng get position => route.positionAt(distance);
  double get heading => route.headingAt(distance);
}

class Arrival {
  final Shuttle shuttle;
  final Duration eta;
  const Arrival(this.shuttle, this.eta);
}

/// Moves mock shuttles along their routes. Swap [_tick] for a Firestore
/// stream to track real vehicles.
class ShuttleSimulator extends ChangeNotifier {
  /// Faster than a real shuttle so the demo is watchable.
  static const speed = 9.0; // m/s
  static const _tickEvery = Duration(milliseconds: 250);

  final Map<String, LineRoute> routes = {
    for (final l in CampusData.lines) l.id: LineRoute(l),
  };
  late final List<Shuttle> shuttles;
  Timer? _timer;

  ShuttleSimulator() {
    shuttles = [
      for (final route in routes.values)
        for (var k = 0; k < 2; k++)
          Shuttle(
            '${route.line.id[0].toUpperCase()}${k + 1}',
            route,
            route.length * k / 2,
          ),
    ];
  }

  void start() {
    _timer ??= Timer.periodic(_tickEvery, (_) => _tick());
  }

  void _tick() {
    final step = speed * _tickEvery.inMilliseconds / 1000;
    for (final s in shuttles) {
      s.distance = (s.distance + step) % s.route.length;
    }
    notifyListeners();
  }

  /// Upcoming arrivals at [stop], soonest first.
  List<Arrival> arrivalsAt(Stop stop, {String? lineId}) {
    final out = <Arrival>[];
    for (final s in shuttles) {
      if (!s.line.stops.contains(stop)) continue;
      if (lineId != null && s.line.id != lineId) continue;
      final meters = (s.route.offsetOf(stop) - s.distance + s.route.length) %
          s.route.length;
      out.add(Arrival(s, Duration(seconds: (meters / speed).round())));
    }
    out.sort((a, b) => a.eta.compareTo(b.eta));
    return out;
  }

  /// Soonest shuttle by straight-line distance, for pickup requests.
  Arrival nearestTo(LatLng p) {
    final s = shuttles.reduce((a, b) =>
        Geo.distance(p, a.position) <= Geo.distance(p, b.position) ? a : b);
    return Arrival(
      s,
      Duration(seconds: (Geo.distance(p, s.position) / speed).round()),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
