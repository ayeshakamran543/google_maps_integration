import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_colors.dart';
import 'geo.dart';

/// Mock data for a fictional campus near Islamabad. In a real app this would
/// come from Firestore (the project already has cloud_firestore set up).
class Stop {
  final String id;
  final String name;
  final LatLng position;
  const Stop(this.id, this.name, this.position);
}

class Building {
  final String name;
  final String hint;
  final LatLng position;
  final IconData icon;
  const Building(this.name, this.hint, this.position, this.icon);
}

enum FacilityType {
  library('Library', Color(0xFF6C5CE7)),
  cafe('Cafe', Color(0xFFFF8A3D)),
  parking('Parking', Color(0xFF3D7BFF));

  final String label;
  final Color color;
  const FacilityType(this.label, this.color);

  IconData get icon => switch (this) {
        FacilityType.library => PhosphorIconsFill.books,
        FacilityType.cafe => PhosphorIconsFill.coffee,
        FacilityType.parking => PhosphorIconsFill.car,
      };
}

class Facility {
  final String name;
  final FacilityType type;
  final LatLng position;
  const Facility(this.name, this.type, this.position);
}

class ShuttleLine {
  final String id;
  final String name;
  final Color color;
  final List<Stop> stops;
  const ShuttleLine(this.id, this.name, this.color, this.stops);
}

class CampusData {
  static const center = LatLng(33.6430, 72.9900);

  /// Campus boundary, used for the geofence.
  static const boundary = <LatLng>[
    LatLng(33.6495, 72.9825),
    LatLng(33.6495, 72.9980),
    LatLng(33.6370, 72.9990),
    LatLng(33.6365, 72.9830),
  ];

  /// Where the user is placed when real GPS is unavailable or far from campus.
  static const demoUser = LatLng(33.6385, 72.9890);

  static const mainGate = Stop('gate', 'Main Gate', LatLng(33.6374, 72.9905));
  static const library = Stop('lib', 'Library', LatLng(33.6420, 72.9880));
  static const engineering =
      Stop('eng', 'Engineering Block', LatLng(33.6455, 72.9860));
  static const studentCenter =
      Stop('stu', 'Student Center', LatLng(33.6440, 72.9930));
  static const sports = Stop('spt', 'Sports Complex', LatLng(33.6482, 72.9902));
  static const hostels = Stop('hst', 'Hostels', LatLng(33.6400, 72.9962));
  static const medical = Stop('med', 'Medical Center', LatLng(33.6476, 72.9957));
  static const science = Stop('sci', 'Science Block', LatLng(33.6410, 72.9848));

  static const stops = <Stop>[
    mainGate,
    library,
    engineering,
    studentCenter,
    sports,
    hostels,
    medical,
    science,
  ];

  static const lines = <ShuttleLine>[
    ShuttleLine('red', 'Red Line', AppColors.coral,
        [mainGate, library, engineering, sports, studentCenter]),
    ShuttleLine('blue', 'Blue Line', AppColors.sky,
        [mainGate, hostels, medical, studentCenter]),
    ShuttleLine('green', 'Green Line', AppColors.mint,
        [science, library, studentCenter, medical, sports, engineering]),
  ];

  static final buildings = <Building>[
    Building('Central Library', 'Reading halls & study rooms',
        const LatLng(33.6424, 72.9875), PhosphorIconsFill.books),
    Building('Engineering Block', 'Labs & lecture halls',
        const LatLng(33.6460, 72.9855), PhosphorIconsFill.gear),
    Building('Student Center', 'Food court & clubs',
        const LatLng(33.6444, 72.9935), PhosphorIconsFill.usersThree),
    Building('Sports Complex', 'Gym, pool & courts',
        const LatLng(33.6487, 72.9898), PhosphorIconsFill.basketball),
    Building('Medical Center', 'Clinic & pharmacy',
        const LatLng(33.6480, 72.9962), PhosphorIconsFill.firstAid),
    Building('Science Block', 'Physics, chemistry & biology',
        const LatLng(33.6408, 72.9840), PhosphorIconsFill.flask),
    Building('Admin Office', 'Admissions & registrar',
        const LatLng(33.6385, 72.9920), PhosphorIconsFill.buildingOffice),
    Building('Boys Hostel', 'Residence hall',
        const LatLng(33.6396, 72.9970), PhosphorIconsFill.bed),
    Building('Auditorium', 'Events & convocations',
        const LatLng(33.6432, 72.9955), PhosphorIconsFill.microphoneStage),
  ];

  static const facilities = <Facility>[
    Facility('Reading Room', FacilityType.library, LatLng(33.6414, 72.9890)),
    Facility('Digital Library', FacilityType.library, LatLng(33.6450, 72.9875)),
    Facility('Bean & Books', FacilityType.cafe, LatLng(33.6428, 72.9915)),
    Facility('Campus Brew', FacilityType.cafe, LatLng(33.6392, 72.9880)),
    Facility('Chai Point', FacilityType.cafe, LatLng(33.6470, 72.9925)),
    Facility('Lot A', FacilityType.parking, LatLng(33.6380, 72.9870)),
    Facility('Lot B', FacilityType.parking, LatLng(33.6465, 72.9940)),
    Facility('Lot C', FacilityType.parking, LatLng(33.6405, 72.9935)),
  ];

  static List<ShuttleLine> linesServing(Stop stop) =>
      lines.where((l) => l.stops.contains(stop)).toList();

  static Stop nearestStop(LatLng p) => stops.reduce((a, b) =>
      Geo.distance(p, a.position) <= Geo.distance(p, b.position) ? a : b);
}
