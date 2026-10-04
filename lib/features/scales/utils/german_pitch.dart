/// Display names for the existing solfège spellings. The music engine keeps
/// its internal note names; only text shown to the user is rewritten.
String germanPitch(String name) {
  return _pitches[name] ?? name;
}

String germanPitches(Iterable<String> names, {String separator = ' · '}) {
  return names.map(germanPitch).join(separator);
}

const _pitches = {
  'до': 'C',
  'ре': 'D',
  'ми': 'E',
  'фа': 'F',
  'соль': 'G',
  'ля': 'A',
  'си': 'H',
  'до-диез': 'Cis',
  'ре-диез': 'Dis',
  'ми-диез': 'Eis',
  'фа-диез': 'Fis',
  'соль-диез': 'Gis',
  'ля-диез': 'Ais',
  'си-диез': 'His',
  'до-бемоль': 'Ces',
  'ре-бемоль': 'Des',
  'ми-бемоль': 'Es',
  'фа-бемоль': 'Fes',
  'соль-бемоль': 'Ges',
  'ля-бемоль': 'As',
  'си-бемоль': 'B',
  'до-дубль-диез': 'Cisis',
  'ре-дубль-диез': 'Disis',
  'ми-дубль-диез': 'Eisis',
  'фа-дубль-диез': 'Fisis',
  'соль-дубль-диез': 'Gisis',
  'ля-дубль-диез': 'Aisis',
  'си-дубль-диез': 'Hisis',
  'до-дубль-бемоль': 'Ceses',
  'ре-дубль-бемоль': 'Deses',
  'ми-дубль-бемоль': 'Eses',
  'фа-дубль-бемоль': 'Feses',
  'соль-дубль-бемоль': 'Geses',
  'ля-дубль-бемоль': 'Ases',
  'си-дубль-бемоль': 'Heses',
};
