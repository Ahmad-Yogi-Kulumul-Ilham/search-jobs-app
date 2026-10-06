/// Office hours of a region, expressed in Indonesian western time (WIB).
class WorkHoursEstimate {
  const WorkHoursEstimate(this.region, this.wib);

  final String region;

  /// Text such as `21.00–05.00 WIB`.
  final String wib;
}

class _Zone {
  const _Zone(this.pattern, this.zones);

  final String pattern;

  /// Region label to its standard-time UTC offset in minutes.
  final Map<String, int> zones;
}

const _zones = [
  _Zone(
    r'\b(usa?|u\.s\.a?\.?|united states|north america|americas?|canada)\b',
    {'Amerika Utara (Timur)': -300, 'Amerika Utara (Barat)': -480},
  ),
  _Zone(
    r'\b(latam|latin america|south america|brazil|argentina|chile|colombia)\b',
    {'Amerika Latin': -180},
  ),
  _Zone(r'\b(uk|united kingdom|britain|england|ireland|portugal)\b', {
    'Inggris/Irlandia': 0,
  }),
  _Zone(
    r'\b(europe|european union|eu|emea|germany|france|spain|italy|netherlands|'
    r'poland|sweden|austria|belgium|denmark|norway|switzerland)\b',
    {'Eropa Tengah': 60},
  ),
  _Zone(r'\b(africa|nigeria|kenya|egypt)\b', {'Afrika (Tengah/Selatan)': 120}),
  _Zone(r'\b(uae|dubai|middle east|saudi arabia)\b', {'Timur Tengah': 240}),
  _Zone(r'\b(india|sri lanka)\b', {'India': 330}),
  _Zone(r'\b(singapore|philippines|malaysia|china|hong kong|taiwan)\b', {
    'Singapura/Filipina': 480,
  }),
  _Zone(r'\b(japan|korea)\b', {'Jepang/Korea': 540}),
  _Zone(r'\b(australia|new zealand|anz|oceania)\b', {'Australia (Timur)': 600}),
];

const _wibOffset = 7 * 60;

/// For each region named in [location], what a 09.00–17.00 office day there
/// is in WIB. An estimate: it uses standard time, so regions with daylight
/// saving shift by an hour for part of the year, and a posting may ask for
/// other hours. Returns nothing for worldwide or unrecognized locations.
List<WorkHoursEstimate> estimateWorkHoursWib(String location) {
  final estimates = <WorkHoursEstimate>[];
  for (final zone in _zones) {
    if (!RegExp(zone.pattern, caseSensitive: false).hasMatch(location)) {
      continue;
    }
    zone.zones.forEach((region, offset) {
      final start = 9 * 60 - offset + _wibOffset;
      estimates.add(
        WorkHoursEstimate(
          region,
          '${_clock(start)}–${_clock(start + 8 * 60)} WIB',
        ),
      );
    });
  }
  return estimates;
}

String _clock(int minutes) {
  final inDay = minutes % (24 * 60);
  final hour = (inDay ~/ 60).toString().padLeft(2, '0');
  final minute = (inDay % 60).toString().padLeft(2, '0');
  return '$hour.$minute';
}
