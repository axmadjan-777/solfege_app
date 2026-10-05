import '../models/song.dart';

const songCatalog = <PlayableSong>[
  PlayableSong(
    id: 'yesterday',
    title: 'Yesterday',
    artist: 'The Beatles',
    difficulty: SongDifficulty.easy,
    expectedNotes: ['G4', 'F4', 'F4'],
    notePositions: [4, 3, 3],
  ),
  PlayableSong(
    id: 'bohemian-rhapsody',
    title: 'Bohemian Rhapsody',
    artist: 'Queen',
    difficulty: SongDifficulty.medium,
    expectedNotes: ['Bb4', 'D5', 'F5'],
    notePositions: [3, 5, 7],
  ),
  PlayableSong(
    id: 'smells-like-teen-spirit',
    title: 'Smells Like Teen Spirit',
    artist: 'Nirvana',
    difficulty: SongDifficulty.medium,
    expectedNotes: ['C4', 'Eb4', 'F4'],
    notePositions: [0, 2, 3],
  ),
  PlayableSong(
    id: 'billie-jean',
    title: 'Billie Jean',
    artist: 'Michael Jackson',
    difficulty: SongDifficulty.hard,
    expectedNotes: ['F#4', 'C#4', 'E4', 'F#4'],
    notePositions: [3, 0, 2, 3],
  ),
  PlayableSong(
    id: 'i-will-always-love-you',
    title: 'I Will Always Love You',
    artist: 'Whitney Houston',
    difficulty: SongDifficulty.easy,
    expectedNotes: ['A4', 'F#4', 'E4', 'A4'],
    notePositions: [5, 3, 2, 5],
  ),
];

const songCatalogOrder = [
  'yesterday',
  'bohemian-rhapsody',
  'smells-like-teen-spirit',
  'billie-jean',
  'i-will-always-love-you',
];
