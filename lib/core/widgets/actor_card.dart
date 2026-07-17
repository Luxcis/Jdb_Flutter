import 'package:flutter/material.dart';
import 'package:jade/core/models/actor.dart';

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
          CircleAvatar(
            radius: 36,
            backgroundImage: actor.avatarUrl.startsWith('http')
                ? NetworkImage(actor.avatarUrl) as ImageProvider
                : NetworkImage(
                    'https://tp.spfcas.com/rhe951l4q/${actor.avatarUrl}'),
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
