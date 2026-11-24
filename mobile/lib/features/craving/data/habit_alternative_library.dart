import 'package:quit_companion/features/craving/models/habit_alternative.dart';

/// FR7: "sourced from a fixed, pre-vetted content library drawn from
/// WHO/CDC and peer-reviewed cessation literature. No human clinical-
/// advisor review step exists; no free-form AI-generated advice text is
/// permitted." This is that library — the same five items originally
/// hard-coded into HighRiskScreen (docs/UI_Design/6a.png) when Module 7
/// didn't exist yet, now promoted to a shared, reusable content module so
/// any screen can read it, not just the one that happened to draft it
/// first.
const habitAlternativeLibrary = <HabitAlternative>[
  HabitAlternative(
    alternativeId: 'breathing',
    title: '4-7-8 Breathing',
    description: 'Calm your nervous system in under a minute',
    category: AlternativeCategory.exercise,
    instructions:
        'Follow the bubble: breathe in as it grows, hold while it stays full, and '
        'breathe out as it shrinks. Six calming cycles, guided for you.',
  ),
  HabitAlternative(
    alternativeId: 'cold_water',
    title: 'Drink Cold Water',
    description: 'A quick reset for your senses',
    category: AlternativeCategory.quickFix,
    instructions:
        'Drink a full glass of cold water slowly. The cold sensation and the pause '
        'both help the craving pass.',
  ),
  HabitAlternative(
    alternativeId: 'short_walk',
    title: 'Take a Short Walk',
    description: 'Just 5 minutes can shift your mood',
    category: AlternativeCategory.exercise,
    instructions:
        'Step outside or walk down the hall for 5 minutes. Moving your body and '
        'changing your environment both help interrupt a craving.',
  ),
  HabitAlternative(
    alternativeId: 'bubble_pop',
    title: 'Bubble Pop Mini-Game',
    description: 'A calm, self-paced distraction',
    category: AlternativeCategory.game,
    instructions:
        'Open the Bubble Pop mini-game and pop bubbles at your own pace, for as '
        'long as you like. A short, absorbing distraction is often enough to let a craving pass.',
  ),
  HabitAlternative(
    alternativeId: 'word_puzzle',
    title: 'Quick Word Puzzle',
    description: 'Keep your hands and mind busy',
    category: AlternativeCategory.game,
    instructions:
        'Open the Word Puzzle mini-game and find the hidden calming words at your '
        'own pace. Keeping your hands and mind occupied is a proven craving-management technique.',
  ),
  HabitAlternative(
    alternativeId: 'tap_pop',
    title: 'Tap & Pop',
    description: 'A quick 30-second reflex challenge',
    category: AlternativeCategory.game,
    instructions:
        'Tap the dot before it fades — see how many you can pop in 30 seconds.',
  ),
  HabitAlternative(
    alternativeId: 'memory_match',
    title: 'Memory Match',
    description: 'A quick icon-matching game',
    category: AlternativeCategory.game,
    instructions: 'Flip two cards at a time and find every matching pair.',
  ),
  HabitAlternative(
    alternativeId: 'craving_countdown',
    title: 'Craving Countdown Challenge',
    description: 'Commit to beating this craving for 3 minutes',
    category: AlternativeCategory.quickFix,
    instructions:
        'Stay with the feeling until the ring fills — you\'ve got this.',
  ),
];
