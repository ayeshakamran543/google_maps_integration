/// Soft lavender/blue map theme with points of interest and transit hidden so
/// the shuttle overlays stand out.
const campusMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#f1f2f9"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#6b7092"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#ffffff"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"visibility":"on"},{"color":"#dff3ea"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#e3e5f1"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#ffe9c7"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#cfe0ff"}]}
]
''';
