import 'package:flutter/material.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/widgets/actor_avatar_image.dart';

class ActorCard extends StatelessWidget {
  const ActorCard({super.key, required this.actor, this.onTap});
  final ActorSummary actor;
  final VoidCallback? onTap;

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
            const SizedBox(height: 4),
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
