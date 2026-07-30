import 'package:flutter/material.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/widgets/actor_avatar_image.dart';

class ActorCard extends StatelessWidget {
  const ActorCard({super.key, required this.actor, this.onTap});
  static const _labelSpacing = 4.0;

  final ActorSummary actor;
  final VoidCallback? onTap;

  static double mainAxisExtent(BuildContext context, double imageExtent) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: '演员',
        style:
            Theme.of(context).textTheme.bodyMedium ??
            DefaultTextStyle.of(context).style,
      ),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: imageExtent);
    final extent = imageExtent + _labelSpacing + textPainter.height;
    textPainter.dispose();
    return extent.ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: actor.name,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ActorAvatarImage(
                actor,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            const SizedBox(height: _labelSpacing),
            Text(
              actor.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
