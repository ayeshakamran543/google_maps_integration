import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../campus/campus_data.dart';
import '../campus/shuttle_simulator.dart';
import '../campus/trip_planner.dart';
import '../theme/app_colors.dart';

String fmtDuration(Duration d) {
  if (d.inSeconds < 45) return 'Now';
  return '${(d.inSeconds / 60).round().clamp(1, 999)} min';
}

String fmtMeters(double m) =>
    m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1)} km';

/// White rounded container with a soft shadow, used for all floating UI.
class FloatingCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  const FloatingCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: AppColors.softShadow,
      ),
      child: child,
    );
  }
}

class RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surface,
        shape: const CircleBorder(),
        elevation: 6,
        shadowColor: AppColors.ink.withValues(alpha: 0.25),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Icon(icon, size: 22, color: AppColors.ink),
          ),
        ),
      ),
    );
  }
}

class SelectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final Widget? leading;
  final VoidCallback onTap;
  const SelectChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = AppColors.violet,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? color : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.10),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 6)],
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: selected ? Colors.white : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LineDot extends StatelessWidget {
  final Color color;
  final double size;
  final bool onDark;
  const LineDot(this.color, {super.key, this.size = 10, this.onDark = false});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: onDark ? Border.all(color: Colors.white, width: 1.5) : null,
        ),
      );
}

class StatusPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final Color background;
  const StatusPill({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Default bottom card: live summary + hint.
class IdleCard extends StatelessWidget {
  final int shuttleCount;
  final bool demoLocation;
  const IdleCard({
    super.key,
    required this.shuttleCount,
    required this.demoLocation,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.violetSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(PhosphorIconsFill.bus,
                color: AppColors.violet, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$shuttleCount shuttles running',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  demoLocation
                      ? 'Demo location near Main Gate · long-press the map to request a pickup'
                      : 'Long-press anywhere on the map to request a pickup',
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.3,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Walk -> ride -> walk summary for a planned trip.
class TripCard extends StatelessWidget {
  final Trip trip;
  final ShuttleSimulator sim;
  final VoidCallback onClose;
  const TripCard({
    super.key,
    required this.trip,
    required this.sim,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final wait = sim.arrivalsAt(trip.boardStop, lineId: trip.line.id).first.eta;
    // You can only catch the shuttle after walking to the stop.
    final waitAtStop = wait > trip.walkTo ? wait - trip.walkTo : Duration.zero;
    final total = (wait > trip.walkTo ? wait : trip.walkTo) +
        trip.ride +
        trip.walkFrom;

    return FloatingCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('To',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.inkSoft)),
                    Text(
                      trip.destinationName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                fmtDuration(total),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: trip.line.color,
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onClose,
                icon: const Icon(PhosphorIconsBold.x, size: 20),
                color: AppColors.inkSoft,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _Step(
            icon: PhosphorIconsBold.personSimpleWalk,
            color: AppColors.ink,
            title: 'Walk to ${trip.boardStop.name}',
            trailing: '${fmtDuration(trip.walkTo)} · ${fmtMeters(trip.walkToMeters)}',
          ),
          _Step(
            icon: PhosphorIconsFill.bus,
            color: trip.line.color,
            title: '${trip.line.name} to ${trip.alightStop.name}',
            trailing:
                'Next in ${fmtDuration(wait)} · ride ${fmtDuration(trip.ride)}',
            subtitle: waitAtStop > Duration.zero
                ? 'Wait ${fmtDuration(waitAtStop)} at the stop'
                : 'Hurry — shuttle arrives before you do',
          ),
          _Step(
            icon: PhosphorIconsBold.flagCheckered,
            color: AppColors.ink,
            title: 'Walk to ${trip.destinationName}',
            trailing:
                '${fmtDuration(trip.walkFrom)} · ${fmtMeters(trip.walkFromMeters)}',
            last: true,
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final String trailing;
  final bool last;
  const _Step({
    required this.icon,
    required this.color,
    required this.title,
    required this.trailing,
    this.subtitle,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.ink)),
                Text(subtitle ?? trailing,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.inkSoft)),
                if (subtitle != null)
                  Text(trailing,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.inkSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown after long-pressing the map, then after a ride is requested.
class PickupCard extends StatelessWidget {
  final String address;
  final bool inside;
  final Arrival? requested;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  const PickupCard({
    super.key,
    required this.address,
    required this.inside,
    required this.requested,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final r = requested;
    return FloatingCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r != null ? 'Ride requested' : 'Pickup location',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
              if (r == null)
                inside
                    ? const StatusPill(
                        icon: PhosphorIconsFill.checkCircle,
                        text: 'Inside campus zone',
                        color: AppColors.mint,
                        background: Color(0xFFE3F8F1),
                      )
                    : const StatusPill(
                        icon: PhosphorIconsFill.warning,
                        text: 'Outside zone',
                        color: AppColors.warning,
                        background: AppColors.warningSoft,
                      ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            address,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          if (r != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                LineDot(r.shuttle.line.color, size: 12),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Shuttle ${r.shuttle.id} (${r.shuttle.line.name}) arrives in ${fmtDuration(r.eta)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ] else if (!inside) ...[
            const SizedBox(height: 6),
            const Text(
              'Shuttles only pick up inside the highlighted campus boundary. Move the pin or choose a spot within it.',
              style: TextStyle(
                  fontSize: 12.5, height: 1.3, color: AppColors.warning),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.ink,
                    side: const BorderSide(color: AppColors.hairline),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(r != null ? 'Cancel ride' : 'Cancel'),
                ),
              ),
              if (r == null) ...[
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: inside ? onConfirm : null,
                    icon: const Icon(PhosphorIconsBold.check, size: 18),
                    label: const Text('Confirm pickup'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.violet,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet with live arrivals for one stop.
class StopSheet extends StatelessWidget {
  final Stop stop;
  final ShuttleSimulator sim;
  final VoidCallback onGoHere;
  const StopSheet({
    super.key,
    required this.stop,
    required this.sim,
    required this.onGoHere,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: sim,
          builder: (context, _) {
            final arrivals = sim.arrivalsAt(stop);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.hairline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.violetSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(PhosphorIconsFill.signpost,
                          color: AppColors.violet),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stop.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: AppColors.ink,
                            ),
                          ),
                          Row(
                            children: [
                              for (final l in CampusData.linesServing(stop))
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: LineDot(l.color),
                                ),
                              const SizedBox(width: 4),
                              const Text('Next arrivals',
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.inkSoft)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                for (final a in arrivals)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.canvas,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: a.shuttle.line.color,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(PhosphorIconsFill.bus,
                              size: 16, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${a.shuttle.line.name} · ${a.shuttle.id}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        Text(
                          fmtDuration(a.eta),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: a.shuttle.line.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onGoHere,
                    icon: const Icon(PhosphorIconsBold.path, size: 18),
                    label: const Text('Plan trip here'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.violet,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
