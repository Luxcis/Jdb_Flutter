import 'package:flutter/material.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/widgets/cached_image.dart';

class ActorAvatarImage extends StatelessWidget {
  const ActorAvatarImage(
    this.actor, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final ActorSummary actor;
  final double? width;
  final double? height;
  final BoxFit fit;

  String get fallbackAsset => actor.gender?.toLowerCase() == 'male'
      ? 'assets/images/actor_unknow_male_200x200.jpg'
      : 'assets/images/actor_unknow_200x200.jpg';

  @override
  Widget build(BuildContext context) {
    return CachedImage(
      actor.avatarUrl,
      width: width,
      height: height,
      fit: fit,
      fallbackAsset: fallbackAsset,
      semanticLabel: actor.name,
    );
  }
}
