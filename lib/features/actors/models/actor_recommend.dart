import 'package:jade/core/models/actor.dart';
import 'package:jade/core/network/api_data.dart';

class ActorRecommend {
  const ActorRecommend({
    required this.newActors,
    required this.monthlyActors,
    required this.recommendActors,
  });

  final List<ActorSummary> newActors;
  final List<ActorSummary> monthlyActors;
  final List<ActorSummary> recommendActors;

  factory ActorRecommend.fromJson(Map<String, dynamic> json) {
    List<ActorSummary> parse(String key) => apiList(json, [key])
        .map(normalizeActorSummaryJson)
        .map(ActorSummary.fromJson)
        .toList(growable: false);

    return ActorRecommend(
      newActors: parse('new_actors'),
      monthlyActors: parse('monthly_actors'),
      recommendActors: parse('recommend_actors'),
    );
  }
}
