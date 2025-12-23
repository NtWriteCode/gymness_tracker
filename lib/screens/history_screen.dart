import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/workout.dart';
import '../models/exercise.dart';
import '../models/location.dart';
import '../providers/workout_provider.dart';
import '../models/achievement.dart';
import 'workout_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    // Clear highlight after a short delay so it doesn't stay forever
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<WorkoutProvider>();
      if (provider.highlightedWorkoutId != null) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) provider.clearHighlight();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    
    // If we just jumped here, set up the cleanup timer
    if (provider.highlightedWorkoutId != null) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && provider.highlightedWorkoutId != null) {
          provider.clearHighlight();
        }
      });
    }

    final workouts = provider.history;

        if (workouts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No workout history yet',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Complete your first workout to see it here',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          );
        }

        // Group workouts by date
        final groupedWorkouts = <String, List<Workout>>{};
        final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
        
        for (var workout in workouts) {
          final dateKey = dateFormat.format(workout.startDateTime);
          groupedWorkouts.putIfAbsent(dateKey, () => []).add(workout);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: groupedWorkouts.length,
          itemBuilder: (context, index) {
            final dateKey = groupedWorkouts.keys.elementAt(index);
            final dayWorkouts = groupedWorkouts[dateKey]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (index > 0) const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    dateKey,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                ...dayWorkouts.map((workout) => _WorkoutCard(workout: workout)),
              ],
            );
          },
        );
  }
}

class _WorkoutCard extends StatelessWidget {
  final Workout workout;

  const _WorkoutCard({required this.workout});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<WorkoutProvider>();
    final exercises = workout.exerciseIds
        .map((id) => provider.getExerciseById(id))
        .whereType<Exercise>()
        .toList();
    
    final location = workout.locationId != null
        ? provider.locations
            .cast<SavedLocation?>()
            .firstWhere((l) => l?.id == workout.locationId, orElse: () => null)
        : null;

    final timeFormat = DateFormat('HH:mm');
    final duration = workout.endDateTime?.difference(workout.startDateTime);
    
    // Find achievements earned during this workout
    final earnedHere = allAchievements.where((a) {
      final earnedDate = provider.earnedAchievements[a.id];
      if (earnedDate == null) return false;
      // Many achievements use startDateTime exactly. 
      // Some might be slightly after (but within the workout window)
      return earnedDate.isAtSameMomentAs(workout.startDateTime) ||
             (workout.endDateTime != null && 
              earnedDate.isAfter(workout.startDateTime) && 
              earnedDate.isBefore(workout.endDateTime!.add(const Duration(seconds: 5))));
    }).toList();

    final isHighlighted = provider.highlightedWorkoutId == workout.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isHighlighted 
            ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      elevation: isHighlighted ? 8 : null,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WorkoutDetailScreen(workout: workout),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.fitness_center,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          workout.getDisplayTitle(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (location != null)
                          Text(
                            location.name,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (duration != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${duration.inMinutes} min',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        '${timeFormat.format(workout.startDateTime)} - ${workout.endDateTime != null ? timeFormat.format(workout.endDateTime!) : 'Ongoing'}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fitness_center, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        '${exercises.length} exercise${exercises.length != 1 ? 's' : ''}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                  if (workout.estimatedCalories != null && workout.estimatedCalories! > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_fire_department, size: 16, color: Colors.orange.shade700),
                        const SizedBox(width: 4),
                        Text(
                          '${workout.estimatedCalories} kcal',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                ],
              ),
              if (exercises.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: exercises.take(3).map((exercise) {
                    return Chip(
                      label: Text(
                        exercise.name,
                        style: const TextStyle(fontSize: 12),
                      ),
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList()
                    ..addAll(
                      exercises.length > 3
                          ? [
                              Chip(
                                label: Text(
                                  '+${exercises.length - 3} more',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                visualDensity: VisualDensity.compact,
                              )
                            ]
                          : [],
                    ),
                ),
              ],
              if (earnedHere.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: earnedHere.map((a) => Tooltip(
                    message: a.title,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(a.icon, size: 16, color: Theme.of(context).colorScheme.secondary),
                    ),
                  )).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
