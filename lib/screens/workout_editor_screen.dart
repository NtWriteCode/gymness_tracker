import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../models/workout.dart';
import '../models/location.dart';
import '../providers/workout_provider.dart';
import '../providers/settings_provider.dart';

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
            title: Text(workout.type == WorkoutType.gym
                ? 'Gym Workout'
                : 'Fitness Session'),
            actions: [
              TextButton(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  await workoutProvider.finishWorkout();
                  navigator.pop();
                },
                child:
                    const Text('FINISH', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ExpansionTile(
                  initiallyExpanded: true,
                  title: Text('General Info',
                      style: Theme.of(context).textTheme.titleLarge),
                  leading: const Icon(Icons.info_outline),
                  children: [
                    const Divider(),
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
              const Center(
                child: Column(
                  children: [
                    Icon(Icons.fitness_center, size: 64, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('Exercises Placeholder', style: TextStyle(color: Colors.grey)),
                    Text('(We will implement this later)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
