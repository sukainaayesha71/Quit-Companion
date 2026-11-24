/// SRDS 4.2 (Mental Health Safeguards): helplines shown on the Crisis
/// Support screen.
///
/// Every entry was checked against the listed source on 2026-11-23. Do NOT
/// add or edit a number without re-verifying it against the organization's
/// own site or a recognized directory (Find A Helpline / ThroughLine,
/// Befrienders Worldwide, WHO). A wrong number in a crisis is harmful. Hours
/// are shown exactly as the source states them; where sources disagree, the
/// entry says so rather than guessing.
library;

enum HelplineRegion { pakistan, international }

class CrisisHelpline {
  final String id;
  final String name;
  final String description;
  final HelplineRegion region;

  /// Number shown to the user, formatted as the source formats it.
  final String? displayNumber;

  /// Digits passed to `tel:` / `sms:`.
  final String? dialNumber;
  final bool supportsText;
  final String? website;
  final String hours;
  final bool isEmergency;

  /// Where this entry was verified (kept for audit, not shown in the UI).
  final String source;

  const CrisisHelpline({
    required this.id,
    required this.name,
    required this.description,
    required this.region,
    required this.hours,
    required this.source,
    this.displayNumber,
    this.dialNumber,
    this.supportsText = false,
    this.website,
    this.isEmergency = false,
  });
}

const crisisHelplines = <CrisisHelpline>[
  CrisisHelpline(
    id: 'pk_rescue_1122',
    name: 'Rescue 1122',
    description:
        'Pakistan emergency and ambulance service. Call if you or someone '
        'else is in immediate danger.',
    region: HelplineRegion.pakistan,
    displayNumber: '1122',
    dialNumber: '1122',
    hours: '24/7',
    isEmergency: true,
    source:
        'rescue.gov.pk (Emergency Services Department); Find A Helpline '
        'Pakistan page "Emergency Services" link (tel:1122)',
  ),
  CrisisHelpline(
    id: 'pk_umang',
    name: 'Umang Pakistan',
    description:
        'Free, confidential mental health helpline run by psychologists. '
        'Urdu, English and regional languages.',
    region: HelplineRegion.pakistan,
    displayNumber: '0311-7786264',
    dialNumber: '03117786264',
    // Umang's own website was unreachable on 2026-11-23 (empty directory
    // listing). Express Tribune (10 Oct 2024) and Umang's official X
    // profile list it as 24/7; one directory (worldhotlines.org) lists
    // shorter hours. Normal call charges may apply.
    hours: 'Listed as 24/7 (hours may vary). Normal call charges may apply.',
    source:
        'Express Tribune, 10 Oct 2024 (story/2501993); Umang official X '
        'profile @PakistanUmang. Primary website down at verification time.',
  ),
  CrisisHelpline(
    id: 'pk_rozan',
    name: 'Rozan Counseling Helpline',
    description:
        'Free telephone counselling for emotional and psychological '
        'support. Also offers email counselling (helpline@rozan.org).',
    region: HelplineRegion.pakistan,
    displayNumber: '0304-111-1741',
    dialNumber: '03041111741',
    website: 'https://rozan.org/counseling-services/',
    hours: 'Mon–Fri, 9:00 am – 5:00 pm (Ramadan: 10:00 am – 6:00 pm)',
    source:
        'rozan.org/counseling-services (official); Find A Helpline Pakistan '
        'listing',
  ),
  CrisisHelpline(
    id: 'intl_find_a_helpline',
    name: 'Find A Helpline',
    description:
        'Free directory of verified crisis and emotional-support helplines '
        'in 175+ countries. Use it if you are outside Pakistan.',
    region: HelplineRegion.international,
    website: 'https://findahelpline.com',
    hours: 'Website — helpline hours vary by country',
    source: 'findahelpline.com/about (ThroughLine; IASP partner)',
  ),
  CrisisHelpline(
    id: 'intl_988',
    name: '988 Suicide & Crisis Lifeline (USA)',
    description: 'Free, confidential emotional support by call, text or chat.',
    region: HelplineRegion.international,
    displayNumber: '988',
    dialNumber: '988',
    supportsText: true,
    website: 'https://988lifeline.org',
    hours: '24/7',
    source: '988lifeline.org (official); SAMHSA 988 fact sheet',
  ),
  CrisisHelpline(
    id: 'intl_samaritans',
    name: 'Samaritans (UK & Ireland)',
    description: 'Free to call from any phone, any time.',
    region: HelplineRegion.international,
    displayNumber: '116 123',
    dialNumber: '116123',
    website: 'https://www.samaritans.org',
    hours: '24/7',
    source: 'samaritans.org/how-we-can-help/contact-samaritan (official)',
  ),
];
