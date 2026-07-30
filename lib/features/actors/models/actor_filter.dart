enum ActorListCategory {
  censoredFemale(type: '0', gender: '0', supportsFilter: true),
  censoredMale(type: '0', gender: '1'),
  uncensored(type: '1', gender: 'all'),
  westernFemale(type: '2', gender: '0'),
  westernMale(type: '2', gender: '1');

  const ActorListCategory({
    required this.type,
    required this.gender,
    this.supportsFilter = false,
  });

  final String type;
  final String gender;
  final bool supportsFilter;
}

class ActorRange {
  const ActorRange(this.min, this.max);

  final int min;
  final int max;

  String get queryValue => '$min,$max';

  @override
  bool operator ==(Object other) =>
      other is ActorRange && other.min == min && other.max == max;

  @override
  int get hashCode => Object.hash(min, max);
}

class ActorFilter {
  const ActorFilter({
    this.age = defaultAge,
    this.height = defaultHeight,
    this.cup = defaultCup,
    this.bust = defaultBust,
    this.waist = defaultWaist,
    this.hips = defaultHips,
  });

  static const defaultAge = ActorRange(19, 65);
  static const defaultHeight = ActorRange(130, 185);
  static const defaultCup = ActorRange(0, 15);
  static const defaultBust = ActorRange(70, 120);
  static const defaultWaist = ActorRange(50, 90);
  static const defaultHips = ActorRange(70, 120);

  final ActorRange age;
  final ActorRange height;
  final ActorRange cup;
  final ActorRange bust;
  final ActorRange waist;
  final ActorRange hips;

  ActorFilter copyWith({
    ActorRange? age,
    ActorRange? height,
    ActorRange? cup,
    ActorRange? bust,
    ActorRange? waist,
    ActorRange? hips,
  }) => ActorFilter(
    age: age ?? this.age,
    height: height ?? this.height,
    cup: cup ?? this.cup,
    bust: bust ?? this.bust,
    waist: waist ?? this.waist,
    hips: hips ?? this.hips,
  );

  @override
  bool operator ==(Object other) =>
      other is ActorFilter &&
      other.age == age &&
      other.height == height &&
      other.cup == cup &&
      other.bust == bust &&
      other.waist == waist &&
      other.hips == hips;

  @override
  int get hashCode => Object.hash(age, height, cup, bust, waist, hips);

  Map<String, dynamic> toQueryParameters() => {
    if (age != defaultAge) 'age': age.queryValue,
    if (height != defaultHeight) 'height': height.queryValue,
    if (cup != defaultCup) 'cup': cup.queryValue,
    if (bust != defaultBust) 'bust': bust.queryValue,
    if (waist != defaultWaist) 'waist': waist.queryValue,
    if (hips != defaultHips) 'hips': hips.queryValue,
  };
}
