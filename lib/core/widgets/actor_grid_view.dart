import 'package:flutter/material.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/widgets/actor_card.dart';
import 'package:jade/core/widgets/pagination_controller.dart';

class ActorGridView extends StatelessWidget {
  const ActorGridView({super.key, required this.controller, this.onActorTap});

  final PaginationController<ActorSummary> controller;
  final void Function(ActorSummary)? onActorTap;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification && n.metrics.extentAfter < 200) {
          controller.fetchMore();
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: controller.refresh,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.7,
          ),
          itemCount: controller.items.length,
          padding: const EdgeInsets.all(8),
          itemBuilder: (_, i) => ActorCard(
            actor: controller.items[i],
            onTap: onActorTap != null
                ? () => onActorTap!(controller.items[i])
                : null,
          ),
        ),
      ),
    );
  }
}
