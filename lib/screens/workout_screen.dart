import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/workout_provider.dart';
import '../models/workout.dart';
import 'workout_editor_screen.dart';

class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({super.key});

  void _navigateToEditor(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const WorkoutEditorScreen()),
    );
  }

  void _showStartDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start New Workout'),
        content: const Text('What type of training are you doing today?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement Fitness
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fitness training is TODO!')));
            },
            child: const Text('Fitness'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<WorkoutProvider>().startWorkout(WorkoutType.gym);
              if (context.mounted) _navigateToEditor(context);
            },
            child: const Text('Gym'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutProvider>(
      builder: (context, provider, child) {
        final active = provider.activeWorkout;

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (active != null) ...[
                Text(
                  'Workout in progress...',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Started at ${active.startDateTime.hour}:${active.startDateTime.minute.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => _navigateToEditor(context),
                  icon: const Icon(Icons.edit),
                  label: const Text('Continue Workout'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
              ] else ...[
                const Icon(Icons.fitness_center_outlined, size: 100, color: Colors.grey),
                const SizedBox(height: 24),
                Text(
                  'No active workout',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => _showStartDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Start New Workout'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
