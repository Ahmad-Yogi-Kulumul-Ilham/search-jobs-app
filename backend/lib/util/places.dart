/// What a [Place] covers.
enum PlaceKind { worldwide, region, country }

/// A country, a region, or "anywhere", as job locations name them.
class Place {
  const Place(
    this.code,
    this.name,
    this.kind, {
    this.names = const [],
    this.codes = const [],
  });

  /// Stable key stored with each job, such as `US` or `R-EU`.
  final String code;

  /// Indonesian name shown in the filter.
  final String name;
  final PlaceKind kind;

  /// Names, cities, and states that point here, matched as whole words
  /// ignoring case.
  final List<String> names;

  /// Short forms such as `US` or `UK`, matched as whole words in capitals
  /// only, so "us" in a sentence does not count.
  final List<String> codes;
}

/// The places the country filter offers, worldwide first, then regions,
/// then countries.
const List<Place> places = [
  Place(
    'WW',
    'Seluruh dunia',
    PlaceKind.worldwide,
    names: [
      'worldwide',
      'world wide',
      'anywhere',
      'global',
      'globally',
      'international',
      'all countries',
      'any country',
      'any location',
      'any',
    ],
  ),
  Place(
    'R-APAC',
    'Asia-Pasifik',
    PlaceKind.region,
    names: [
      'apac',
      'apj',
      'asia',
      'asia pacific',
      'asia-pacific',
      'southeast asia',
      'south east asia',
      'oceania',
    ],
    codes: ['SEA'],
  ),
  Place(
    'R-EU',
    'Eropa',
    PlaceKind.region,
    names: ['europe', 'european union', 'emea'],
    codes: ['EU'],
  ),
  Place(
    'R-LATAM',
    'Amerika Latin',
    PlaceKind.region,
    names: [
      'latam',
      'latin america',
      'south america',
      'central america',
      'americas',
    ],
  ),
  Place(
    'R-NA',
    'Amerika Utara',
    PlaceKind.region,
    names: ['north america', 'namer', 'amer', 'americas'],
  ),
  Place(
    'ID',
    'Indonesia',
    PlaceKind.country,
    names: [
      'indonesia',
      'jakarta',
      'bandung',
      'surabaya',
      'bali',
      'yogyakarta',
    ],
  ),
  Place(
    'SG',
    'Singapura',
    PlaceKind.country,
    names: ['singapore', 'singapura'],
  ),
  Place(
    'MY',
    'Malaysia',
    PlaceKind.country,
    names: ['malaysia', 'kuala lumpur', 'penang'],
  ),
  Place(
    'PH',
    'Filipina',
    PlaceKind.country,
    names: ['philippines', 'filipina', 'manila', 'cebu'],
  ),
  Place('TH', 'Thailand', PlaceKind.country, names: ['thailand', 'bangkok']),
  Place(
    'VN',
    'Vietnam',
    PlaceKind.country,
    names: ['vietnam', 'viet nam', 'ho chi minh', 'hanoi'],
  ),
  Place(
    'IN',
    'India',
    PlaceKind.country,
    names: [
      'india',
      'bangalore',
      'bengaluru',
      'hyderabad',
      'mumbai',
      'delhi',
      'new delhi',
      'pune',
      'chennai',
      'gurgaon',
      'gurugram',
      'noida',
    ],
  ),
  Place(
    'PK',
    'Pakistan',
    PlaceKind.country,
    names: ['pakistan', 'karachi', 'lahore'],
  ),
  Place('BD', 'Bangladesh', PlaceKind.country, names: ['bangladesh', 'dhaka']),
  Place('LK', 'Sri Lanka', PlaceKind.country, names: ['sri lanka', 'colombo']),
  Place('JP', 'Jepang', PlaceKind.country, names: ['japan', 'tokyo', 'osaka']),
  Place(
    'KR',
    'Korea Selatan',
    PlaceKind.country,
    names: ['south korea', 'korea', 'seoul'],
  ),
  Place(
    'CN',
    'Tiongkok',
    PlaceKind.country,
    names: [
      'china',
      'beijing',
      'shanghai',
      'shenzhen',
      'hangzhou',
      'guangdong',
    ],
  ),
  Place('HK', 'Hong Kong', PlaceKind.country, names: ['hong kong']),
  Place('TW', 'Taiwan', PlaceKind.country, names: ['taiwan', 'taipei']),
  Place(
    'AU',
    'Australia',
    PlaceKind.country,
    names: [
      'australia',
      'sydney',
      'melbourne',
      'brisbane',
      'perth',
      'new south wales',
      'queensland',
      'victoria',
      'tasmania',
    ],
  ),
  Place(
    'NZ',
    'Selandia Baru',
    PlaceKind.country,
    names: [
      'new zealand',
      'auckland',
      'wellington',
      'canterbury',
      'waikato',
      'taranaki',
      'southland',
      'tasman',
      'otago',
    ],
    codes: ['NZ'],
  ),
  Place(
    'AE',
    'Uni Emirat Arab',
    PlaceKind.country,
    names: ['united arab emirates', 'dubai', 'abu dhabi', 'دبي', 'الإمارات'],
    codes: ['UAE'],
  ),
  Place(
    'SA',
    'Arab Saudi',
    PlaceKind.country,
    names: ['saudi arabia', 'riyadh', 'الرياض', 'السعودية'],
    codes: ['KSA'],
  ),
  Place('IL', 'Israel', PlaceKind.country, names: ['israel', 'tel aviv']),
  Place(
    'TR',
    'Turki',
    PlaceKind.country,
    names: ['turkey', 'türkiye', 'istanbul'],
  ),
  Place('EG', 'Mesir', PlaceKind.country, names: ['egypt', 'cairo']),
  Place('NG', 'Nigeria', PlaceKind.country, names: ['nigeria', 'lagos']),
  Place('KE', 'Kenya', PlaceKind.country, names: ['kenya', 'nairobi']),
  Place(
    'ZA',
    'Afrika Selatan',
    PlaceKind.country,
    names: ['south africa', 'cape town', 'johannesburg'],
  ),
  // Not "america" on its own: "Latin America" and "North America" are
  // regions, not this country.
  Place(
    'US',
    'Amerika Serikat',
    PlaceKind.country,
    names: [
      'united states',
      'united states of america',
      'new york',
      'san francisco',
      'bay area',
      'los angeles',
      'seattle',
      'austin',
      'boston',
      'chicago',
      'denver',
      'atlanta',
      'miami',
      'washington dc',
      'washington d.c.',
      'district of columbia',
      'california',
      'texas',
      'florida',
      'colorado',
      'illinois',
      'massachusetts',
      'new jersey',
      'north carolina',
      'virginia',
      'oregon',
      'arizona',
      'utah',
      'ohio',
      'michigan',
      'pennsylvania',
      'minnesota',
      'tennessee',
      'maryland',
      'alabama',
      'alaska',
      'arkansas',
      'connecticut',
      'delaware',
      'hawaii',
      'idaho',
      'indiana',
      'iowa',
      'kansas',
      'kentucky',
      'louisiana',
      'maine',
      'mississippi',
      'missouri',
      'montana',
      'nebraska',
      'nevada',
      'new hampshire',
      'oklahoma',
      'rhode island',
      'south carolina',
      'north dakota',
      'south dakota',
      'vermont',
      'washington state',
      'west virginia',
      'wisconsin',
      'wyoming',
      'redwood city',
      'palo alto',
      'mountain view',
      'san diego',
      'portland',
      'philadelphia',
      'dallas',
      'houston',
      'phoenix',
      'salt lake city',
      'raleigh',
      'nashville',
      'pittsburgh',
      'detroit',
      'minneapolis',
      'springfield',
    ],
    codes: ['US', 'USA', 'U.S.', 'U.S.A.'],
  ),
  Place(
    'CA',
    'Kanada',
    PlaceKind.country,
    names: [
      'canada',
      'toronto',
      'vancouver',
      'montreal',
      'ontario',
      'british columbia',
      'alberta',
      'quebec',
      'saskatchewan',
      'manitoba',
      'nova scotia',
    ],
  ),
  Place(
    'MX',
    'Meksiko',
    PlaceKind.country,
    names: ['mexico', 'méxico', 'mexico city', 'guadalajara'],
  ),
  Place(
    'BR',
    'Brasil',
    PlaceKind.country,
    names: ['brazil', 'brasil', 'são paulo', 'sao paulo', 'rio de janeiro'],
  ),
  Place(
    'AR',
    'Argentina',
    PlaceKind.country,
    names: ['argentina', 'buenos aires'],
  ),
  Place(
    'CO',
    'Kolombia',
    PlaceKind.country,
    names: ['colombia', 'bogota', 'bogotá', 'medellin', 'medellín'],
  ),
  Place('CL', 'Chili', PlaceKind.country, names: ['chile', 'santiago']),
  Place('PE', 'Peru', PlaceKind.country, names: ['peru', 'lima']),
  Place('CR', 'Kosta Rika', PlaceKind.country, names: ['costa rica']),
  Place('UY', 'Uruguay', PlaceKind.country, names: ['uruguay', 'montevideo']),
  Place(
    'GB',
    'Inggris (UK)',
    PlaceKind.country,
    names: [
      'united kingdom',
      'great britain',
      'england',
      'scotland',
      // Not "wales": it would match Australia's New South Wales.
      'cardiff',
      'northern ireland',
      'london',
      'manchester',
      'edinburgh',
    ],
    codes: ['UK', 'GB'],
  ),
  Place('IE', 'Irlandia', PlaceKind.country, names: ['ireland', 'dublin']),
  Place(
    'DE',
    'Jerman',
    PlaceKind.country,
    names: ['germany', 'deutschland', 'berlin', 'munich', 'hamburg'],
  ),
  Place('FR', 'Prancis', PlaceKind.country, names: ['france', 'paris']),
  Place(
    'NL',
    'Belanda',
    PlaceKind.country,
    names: ['netherlands', 'amsterdam', 'rotterdam'],
  ),
  Place('BE', 'Belgia', PlaceKind.country, names: ['belgium', 'brussels']),
  Place(
    'ES',
    'Spanyol',
    PlaceKind.country,
    names: ['spain', 'madrid', 'barcelona'],
  ),
  Place(
    'PT',
    'Portugal',
    PlaceKind.country,
    names: ['portugal', 'lisbon', 'porto'],
  ),
  Place('IT', 'Italia', PlaceKind.country, names: ['italy', 'rome', 'milan']),
  Place(
    'CH',
    'Swiss',
    PlaceKind.country,
    names: ['switzerland', 'zurich', 'zürich', 'geneva'],
  ),
  Place('AT', 'Austria', PlaceKind.country, names: ['austria', 'vienna']),
  Place('SE', 'Swedia', PlaceKind.country, names: ['sweden', 'stockholm']),
  Place('NO', 'Norwegia', PlaceKind.country, names: ['norway', 'oslo']),
  Place('DK', 'Denmark', PlaceKind.country, names: ['denmark', 'copenhagen']),
  Place('FI', 'Finlandia', PlaceKind.country, names: ['finland', 'helsinki']),
  Place(
    'PL',
    'Polandia',
    PlaceKind.country,
    names: ['poland', 'warsaw', 'krakow', 'kraków', 'wroclaw', 'wrocław'],
  ),
  Place(
    'CZ',
    'Ceko',
    PlaceKind.country,
    names: ['czech republic', 'czechia', 'prague'],
  ),
  Place('RO', 'Rumania', PlaceKind.country, names: ['romania', 'bucharest']),
  Place('HU', 'Hungaria', PlaceKind.country, names: ['hungary', 'budapest']),
  Place('UA', 'Ukraina', PlaceKind.country, names: ['ukraine', 'kyiv', 'kiev']),
  Place('RS', 'Serbia', PlaceKind.country, names: ['serbia', 'belgrade']),
  Place('BG', 'Bulgaria', PlaceKind.country, names: ['bulgaria', 'sofia']),
  Place('HR', 'Kroasia', PlaceKind.country, names: ['croatia', 'zagreb']),
  Place('GR', 'Yunani', PlaceKind.country, names: ['greece', 'athens']),
  Place('EE', 'Estonia', PlaceKind.country, names: ['estonia', 'tallinn']),
  Place('LV', 'Latvia', PlaceKind.country, names: ['latvia', 'riga']),
  Place('LT', 'Lituania', PlaceKind.country, names: ['lithuania', 'vilnius']),
  Place(
    'CY',
    'Siprus',
    PlaceKind.country,
    names: ['cyprus', 'limassol', 'nicosia'],
  ),
  Place('SK', 'Slowakia', PlaceKind.country, names: ['slovakia', 'bratislava']),
  Place('SI', 'Slovenia', PlaceKind.country, names: ['slovenia', 'ljubljana']),
  Place('BA', 'Bosnia', PlaceKind.country, names: ['bosnia', 'sarajevo']),
  Place('LU', 'Luksemburg', PlaceKind.country, names: ['luxembourg']),
  Place(
    'KZ',
    'Kazakhstan',
    PlaceKind.country,
    names: ['kazakhstan', 'astana', 'almaty'],
  ),
  Place('QA', 'Qatar', PlaceKind.country, names: ['qatar', 'doha']),
  Place('SV', 'El Salvador', PlaceKind.country, names: ['el salvador']),
];

/// US state codes after a comma, as in `Austin, TX`. Codes shared with a
/// country's code (ID, IN, DE, AR) are left out: "Jakarta, ID" is not
/// Idaho.
final _usState = RegExp(
  r',\s*(AL|AK|AZ|CA|CO|CT|FL|GA|HI|IL|IA|KS|KY|LA|ME|MD|MA|MI|MN|MS|MO|MT|'
  r'NE|NV|NH|NJ|NM|NY|NC|ND|OH|OK|OR|PA|RI|SC|SD|TN|TX|UT|VT|VA|WA|WV|WI|WY|'
  r'DC)\b',
);

final _matchers = [
  for (final place in places)
    (
      place: place,
      names: place.names.isEmpty
          ? null
          : RegExp(
              '(?<![\\p{L}\\p{N}])(${place.names.map(RegExp.escape).join('|')})'
              '(?![\\p{L}\\p{N}])',
              caseSensitive: false,
              unicode: true,
            ),
      codes: place.codes.isEmpty
          ? null
          : RegExp(
              '(?<![A-Za-z])(${place.codes.map(RegExp.escape).join('|')})'
              '(?![A-Za-z])',
            ),
    ),
];

/// Codes of the places a free-text job location names, such as
/// `{US, CA}` for `Remote, Canada; Remote, United States`.
Set<String> placesIn(String location) {
  final text = location.trim();
  if (text.isEmpty) return const {};
  final found = <String>{
    for (final matcher in _matchers)
      if ((matcher.names?.hasMatch(text) ?? false) ||
          (matcher.codes?.hasMatch(text) ?? false))
        matcher.place.code,
  };
  if (_usState.hasMatch(text)) found.add('US');
  return found;
}

/// The place with [code], or null for an unknown code.
Place? placeByCode(String code) =>
    places.where((place) => place.code == code).firstOrNull;
