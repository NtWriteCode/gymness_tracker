import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../models/workout.dart';
import '../models/location.dart';
import '../providers/workout_provider.dart';
import '../providers/settings_provider.dart';
import 'add_exercise_dialog.dart';
import 'edit_exercise_dialog.dart';
import 'workout_summary_dialog.dart';
import '../models/exercise.dart';

class WorkoutEditorScreen extends StatefulWidget {
  const WorkoutEditorScreen({super.key});

  @override
  State<WorkoutEditorScreen> createState() => _WorkoutEditorScreenState();
}

class _WorkoutEditorScreenState extends State<WorkoutEditorScreen> {
  final _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  Future<void> _pickDateTime(BuildContext context, bool isStart) async {
    final provider = context.read<WorkoutProvider>();
    final workout = provider.activeWorkout;
    if (workout == null) return;

    final initialDate =
        (isStart ? workout.startDateTime : workout.endDateTime) ??
            DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (date != null && context.mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
      );

      if (time != null) {
        final newDateTime =
            DateTime(date.year, date.month, date.day, time.hour, time.minute);
        if (isStart) {
          provider.updateActiveWorkout(workout.copyWith(startDateTime: newDateTime));
        } else {
          provider.updateActiveWorkout(workout.copyWith(endDateTime: newDateTime));
        }
      }
    }
  }

  void _showAddLocationDialog(BuildContext context) {
    String name = '';
    final provider = context.read<WorkoutProvider>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Location'),
        content: TextField(
          decoration: const InputDecoration(labelText: 'Store/Gym Name'),
          onChanged: (val) => name = val,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (name.isNotEmpty) {
                await provider.addLocation(name);
                navigator.pop();
              }
            },
            child: const Text('Add (No GPS)'),
          ),
          TextButton(
            onPressed: () async {
              if (name.isNotEmpty) {
                navigator.pop();
                scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text('Getting current location...')));
                try {
                  final position = await Geolocator.getCurrentPosition();
                  await provider.addLocation(name,
                      lat: position.latitude, lng: position.longitude);
                  scaffoldMessenger.showSnackBar(
                      SnackBar(content: Text('Added $name with GPS.')));
                } catch (e) {
                  scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text('Failed to get location.')));
                }
              }
            },
            child: const Text('Add with GPS'),
          ),
        ],
      ),
    );
  }

  void _showOverrideCaloriesDialog(
    BuildContext context,
    Workout workout,
    WorkoutProvider provider,
  ) {
    final controller = TextEditingController(
      text: workout.estimatedCalories != null ? workout.estimatedCalories.toString() : '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Calories Burned'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Calories (kcal)',
                border: OutlineInputBorder(),
                suffixText: 'kcal',
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Text(
              'Leave empty to revert to automatic calculation.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) {
                // Revert to auto calculation
                final updated = workout.copyWith(
                  estimatedCalories: null,
                  isCaloriesManuallySet: false,
                );
                await provider.updateActiveWorkout(updated);
                provider.recalculateWorkoutCalories(updated); // This will trigger recalculation in provider via notifyListeners soon
                // Actually, provider should handle it when we update active workout if isCaloriesManuallySet is false.
                // Oh wait, my provider updateActiveWorkout doesn't recalculate. Let's fix that too.
              } else {
                final cals = int.tryParse(text);
                if (cals != null) {
                  await provider.updateActiveWorkout(
                    workout.copyWith(
                      estimatedCalories: cals,
                      isCaloriesManuallySet: true,
                    ),
                  );
                }
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditTitleDialog(BuildContext context, Workout workout, WorkoutProvider provider) {
    final controller = TextEditingController(text: workout.customTitle ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Workout Title'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Custom Title (optional)',
            hintText: 'Workout',
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newTitle = controller.text.trim();
              await provider.updateActiveWorkout(
                workout.copyWith(customTitle: newTitle.isEmpty ? null : newTitle),
              );
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<WorkoutProvider, SettingsProvider>(
      builder: (context, workoutProvider, settingsProvider, child) {
        final workout = workoutProvider.activeWorkout;
        if (workout == null) {
          return const Scaffold(body: Center(child: Text('No active workout')));
        }

        final selectedLocation = workout.locationId != null
            ? workoutProvider.locations
                .cast<SavedLocation?>()
                .firstWhere((l) => l?.id == workout.locationId, orElse: () => null)
            : null;

        return Scaffold(
          appBar: AppBar(
            title: GestureDetector(
              onTap: () {
                _showEditTitleDialog(context, workout, workoutProvider);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      workout.getDisplayTitle(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.edit, size: 18),
                ],
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: FilledButton(
                  onPressed: workoutProvider.activeWorkoutExercises.isNotEmpty
                      ? () async {
                          final navigator = Navigator.of(context);
                          final workoutCopy = workoutProvider.activeWorkout;
                          if (workoutCopy == null) return;
                          
                          final newAchievements = await workoutProvider.finishWorkout();
                          
                          if (context.mounted) {
                            await showDialog(
                              context: context,
                              builder: (context) => WorkoutSummaryDialog(
                                workout: workoutCopy,
                                newAchievements: newAchievements,
                              ),
                            );
                            navigator.pop();
                          }
                        }
                      : null,
                  child: const Text('FINISH'),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ExpansionTile(
                  initiallyExpanded: true,
                  shape: const Border(),
                  collapsedShape: const Border(),
                  title: Text('General Info',
                      style: Theme.of(context).textTheme.titleLarge),
                  leading: const Icon(Icons.info_outline),
                  children: [
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.location_on),
                      title: Text(
                        selectedLocation?.name ?? 'No Location Selected',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      subtitle: const Text('Workout Location'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.gps_fixed),
                            tooltip: 'Auto-detect Location',
                            onPressed: () async {
                              final scaffoldMessenger =
                                  ScaffoldMessenger.of(context);
                              final loc = await workoutProvider
                                  .findAutoLocation(settingsProvider.gpsRadius);
                              if (loc != null) {
                                workoutProvider.updateActiveWorkout(
                                    workout.copyWith(locationId: loc.id));
                              } else {
                                scaffoldMessenger.showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'No saved location found within radius or permission denied.')),
                                );
                              }
                            },
                          ),
                          PopupMenuButton<SavedLocation>(
                            icon: const Icon(Icons.arrow_drop_down),
                            onSelected: (loc) {
                              workoutProvider.updateActiveWorkout(
                                  workout.copyWith(locationId: loc.id));
                            },
                            itemBuilder: (context) {
                              return [
                                ...workoutProvider.locations
                                    .map((loc) => PopupMenuItem(
                                          value: loc,
                                          child: Text(loc.name),
                                        )),
                                PopupMenuItem(
                                  onTap: () {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                      if (context.mounted) {
                                        _showAddLocationDialog(context);
                                      }
                                    });
                                  },
                                  child: const Text('+ Add New Location',
                                      style: TextStyle(color: Colors.blue)),
                                ),
                              ];
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.play_arrow),
                      title: Text(
                        _dateFormat.format(workout.startDateTime),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      subtitle: const Text('Start Time'),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 8.0),
                      child: Row(
                        children: [
                          const SizedBox(width: 56), // Match ListTile leading width
                          ElevatedButton.icon(
                            onPressed: () => _pickDateTime(context, true),
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('Change'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.stop),
                      title: Text(
                        workout.endDateTime != null
                            ? _dateFormat.format(workout.endDateTime!)
                            : 'Not finished yet',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      subtitle: const Text('End Time'),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                      child: Row(
                        children: [
                          const SizedBox(width: 56), // Match ListTile leading width
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => workoutProvider.updateActiveWorkout(
                                      workout.copyWith(endDateTime: DateTime.now())),
                                  icon: const Icon(Icons.access_time, size: 18),
                                  label: const Text('Set to Now'),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _pickDateTime(context, false),
                                  icon: const Icon(Icons.edit, size: 18),
                                  label: const Text('Change'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const Icon(Icons.fitness_center),
                          const SizedBox(width: 12),
                          Text(
                            'Exercises',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Spacer(),
                          FilledButton.icon(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => const AddExerciseDialog(),
                              );
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add'),
                          ),
                        ],
                      ),
                    ),
                    if (workoutProvider.activeWorkoutExercises.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.fitness_center_outlined,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No exercises yet',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap "Add" to start tracking',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: workoutProvider.activeWorkoutExercises.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final exercise = workoutProvider.activeWorkoutExercises[index];
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text('${index + 1}'),
                            ),
                            title: Text(
                              exercise.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: exercise.sets.map((set) => Chip(
                                    label: Text(
                                      exercise.type == ExerciseType.gym 
                                          ? '${set.weightKg}kg × ${set.reps}' 
                                          : '${set.distanceKm}km in ${set.durationMinutes}min', 
                                      style: const TextStyle(fontSize: 10)
                                    ),
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  )).toList(),
                                ),
                                if (exercise.type == ExerciseType.gym && exercise.durationMinutes > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text('${exercise.durationMinutes} min', style: Theme.of(context).textTheme.bodySmall),
                                  ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Remove Exercise'),
                                    content: Text('Remove "${exercise.name}" from this workout?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          workoutProvider.removeExerciseFromWorkout(exercise.id);
                                          Navigator.pop(context);
                                        },
                                        child: const Text('Remove'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => EditExerciseDialog(exercise: exercise),
                              );
                            },
                            isThreeLine: true,
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.local_fire_department, color: Colors.orange),
                          const SizedBox(width: 12),
                          Text(
                            'Estimated Calories',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => _showOverrideCaloriesDialog(
                              context,
                              workout,
                              workoutProvider,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${workout.estimatedCalories ?? 0}',
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'kcal',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.grey,
                                ),
                          ),
                        ],
                      ),
                      if (workout.isCaloriesManuallySet)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            '(Manually set by user)',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
