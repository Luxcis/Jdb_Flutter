import 'package:flutter/material.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/widgets/actor_avatar_image.dart';

class ActorCard extends StatelessWidget {
  const ActorCard({super.key, required this.actor, this.onTap});
  final ActorSummary actor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: ClipOval(child: ActorAvatarImage(actor)),
          ),
          const SizedBox(height: 4),
          Text(
            actor.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
