import 'package:jade/core/network/api_data.dart';

class SeriesLetter {
  const SeriesLetter({
    required this.id,
    required this.letter,
    this.description,
    this.videosCount = 0,
    this.viewsCount = 0,
    this.type = 0,
  });

  final String id;
  final String letter;
  final String? description;
  final int videosCount;
  final int viewsCount;
  final int type;

  factory SeriesLetter.fromJson(Map<String, dynamic> json) => SeriesLetter(
    id: apiString(json['id']) ?? apiString(json['letter']) ?? '',
    letter: apiString(json['letter']) ?? apiString(json['id']) ?? '',
    description: apiString(json['description']),
    videosCount: apiInt(json['videos_count'], 0),
    viewsCount: apiInt(json['views_count'], 0),
    type: apiInt(json['type'], 0),
  );
}
