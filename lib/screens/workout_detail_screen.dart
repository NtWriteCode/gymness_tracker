import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../models/workout.dart';
import '../models/location.dart';
import '../models/exercise.dart';
import '../providers/workout_provider.dart';
import '../providers/settings_provider.dart';
import 'edit_exercise_dialog.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final Workout workout;

  const WorkoutDetailScreen({super.key, required this.workout});

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  final _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  late Workout _workout;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _workout = widget.workout;
  }

  Future<void> _pickDateTime(BuildContext context, bool isStart) async {
    final provider = context.read<WorkoutProvider>();

    final initialDate =
        (isStart ? _workout.startDateTime : _workout.endDateTime) ??
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
        setState(() {
          if (isStart) {
            _workout = _workout.copyWith(startDateTime: newDateTime);
          } else {
            _workout = _workout.copyWith(endDateTime: newDateTime);
          }
        });
        await provider.updateWorkoutInHistory(_workout);
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
    WorkoutProvider provider,
  ) {
    final controller = TextEditingController(
      text: _workout.estimatedCalories != null ? _workout.estimatedCalories.toString() : '',
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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
              Workout updated;
              if (text.isEmpty) {
                updated = _workout.copyWith(
                  estimatedCalories: null,
                  isCaloriesManuallySet: false,
                );
              } else {
                final cals = int.tryParse(text);
                if (cals != null) {
                  updated = _workout.copyWith(
                    estimatedCalories: cals,
                    isCaloriesManuallySet: true,
                  );
                } else {
                  return;
                }
              }
              
              setState(() {
                _workout = provider.recalculateWorkoutCalories(updated);
              });
              await provider.updateWorkoutInHistory(_workout);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditTitleDialog(BuildContext context, WorkoutProvider provider) {
    final controller = TextEditingController(text: _workout.customTitle ?? '');
    
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
              setState(() {
                _workout = _workout.copyWith(
                  customTitle: newTitle.isEmpty ? null : newTitle,
                );
              });
              await provider.updateWorkoutInHistory(_workout);
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
        final exercises = _workout.exerciseIds
            .map((id) => workoutProvider.getExerciseById(id))
            .whereType<Exercise>()
            .toList();

        final selectedLocation = _workout.locationId != null
            ? workoutProvider.locations
                .cast<SavedLocation?>()
                .firstWhere((l) => l?.id == _workout.locationId,
                    orElse: () => null)
            : null;

        return Scaffold(
          appBar: AppBar(
            title: GestureDetector(
              onTap: _isEditing
                  ? () {
                      _showEditTitleDialog(context, workoutProvider);
                    }
                  : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      _workout.getDisplayTitle(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_isEditing) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.edit, size: 18),
                  ],
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(_isEditing ? Icons.check : Icons.edit),
                onPressed: () {
                  setState(() {
                    _isEditing = !_isEditing;
                  });
                },
                tooltip: _isEditing ? 'Done Editing' : 'Edit Workout',
              ),
              PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete Workout', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'delete') {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Workout'),
                        content: const Text(
                            'Are you sure you want to delete this workout? This cannot be undone.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () async {
                              await workoutProvider.deleteWorkout(_workout.id);
                              if (context.mounted) {
                                Navigator.pop(context); // Close dialog
                                Navigator.pop(context); // Close detail screen
                              }
                            },
                            child: const Text('Delete',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  }
                },
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
                      trailing: _isEditing
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.gps_fixed),
                                  tooltip: 'Auto-detect Location',
                                  onPressed: () async {
                                    final scaffoldMessenger =
                                        ScaffoldMessenger.of(context);
                                    final loc = await workoutProvider
                                        .findAutoLocation(
                                            settingsProvider.gpsRadius);
                                    if (loc != null) {
                                      setState(() {
                                        _workout = _workout.copyWith(
                                            locationId: loc.id);
                                      });
                                      await workoutProvider
                                          .updateWorkoutInHistory(_workout);
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
                                  onSelected: (loc) async {
                                    setState(() {
                                      _workout =
                                          _workout.copyWith(locationId: loc.id);
                                    });
                                    await workoutProvider
                                        .updateWorkoutInHistory(_workout);
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
                            )
                          : null,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.play_arrow),
                      title: Text(
                        _dateFormat.format(_workout.startDateTime),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      subtitle: const Text('Start Time'),
                    ),
                    if (_isEditing)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 8.0),
                        child: Row(
                          children: [
                            const SizedBox(width: 56),
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
                        _workout.endDateTime != null
                            ? _dateFormat.format(_workout.endDateTime!)
                            : 'Not finished yet',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      subtitle: const Text('End Time'),
                    ),
                    if (_isEditing)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                        child: Row(
                          children: [
                            const SizedBox(width: 56),
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      setState(() {
                                        _workout = _workout.copyWith(
                                            endDateTime: DateTime.now());
                                      });
                                      await workoutProvider
                                          .updateWorkoutInHistory(_workout);
                                    },
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
                          if (_isEditing)
                            FilledButton.icon(
                              onPressed: () async {
                                final result = await showDialog<Exercise>(
                                  context: context,
                                  builder: (context) => _AddExerciseToHistoryDialog(
                                    workoutId: _workout.id,
                                  ),
                                );
                                
                                if (result != null) {
                                  setState(() {
                                    final newWorkout = _workout.copyWith(
                                      exerciseIds: [
                                        ..._workout.exerciseIds,
                                        result.id
                                      ],
                                    );
                                    _workout = workoutProvider.recalculateWorkoutCalories(newWorkout);
                                  });
                                  await workoutProvider.updateWorkoutInHistory(_workout);
                                }
                              },
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add'),
                            ),
                        ],
                      ),
                    ),
                    if (exercises.isEmpty)
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
                                'No exercises',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontSize: 16,
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
                        itemCount: exercises.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final exercise = exercises[index];
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text('${index + 1}'),
                            ),
                            title: Text(
                              exercise.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
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
                            trailing: _isEditing
                                ? IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Remove Exercise'),
                                          content: Text(
                                              'Remove "${exercise.name}" from this workout?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: const Text('Cancel'),
                                            ),
                                             TextButton(
                                              onPressed: () async {
                                                final navigator = Navigator.of(context);
                                                setState(() {
                                                  final newWorkout = _workout.copyWith(
                                                    exerciseIds: _workout
                                                        .exerciseIds
                                                        .where((id) =>
                                                            id != exercise.id)
                                                        .toList(),
                                                  );
                                                  _workout = workoutProvider.recalculateWorkoutCalories(newWorkout);
                                                });
                                                await workoutProvider
                                                    .updateWorkoutInHistory(
                                                        _workout);
                                                navigator.pop();
                                              },
                                              child: const Text('Remove'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  )
                                : null,
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
                          if (_isEditing) ...[
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () => _showOverrideCaloriesDialog(
                                context,
                                workoutProvider,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${_workout.estimatedCalories ?? 0}',
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'kcal',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                      if (_workout.isCaloriesManuallySet)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            '(Manually set by user)',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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

// Custom dialog for adding exercises to history workouts
class _AddExerciseToHistoryDialog extends StatefulWidget {
  final String workoutId;

  const _AddExerciseToHistoryDialog({
    required this.workoutId,
  });

  @override
  State<_AddExerciseToHistoryDialog> createState() =>
      _AddExerciseToHistoryDialogState();
}

class _AddExerciseToHistoryDialogState
    extends State<_AddExerciseToHistoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  ExerciseType _type = ExerciseType.gym;
  final List<ExerciseSet> _sets = [ExerciseSet(reps: 1, weightKg: 0.0)];
  final List<TextEditingController> _weightControllers = [TextEditingController(text: '')];
  final List<TextEditingController> _repsControllers = [TextEditingController(text: '1')];
  final List<TextEditingController> _distanceControllers = [TextEditingController(text: '')];
  final List<TextEditingController> _durationSetControllers = [TextEditingController(text: '')];
  final _durationController = TextEditingController(text: '');

  @override
  void dispose() {
    _nameController.dispose();
    for (var c in _weightControllers) {
      c.dispose();
    }
    for (var c in _repsControllers) {
      c.dispose();
    }
    for (var c in _distanceControllers) {
      c.dispose();
    }
    for (var c in _durationSetControllers) {
      c.dispose();
    }
    _durationController.dispose();
    super.dispose();
  }

  void _addSet() {
    setState(() {
      _sets.add(ExerciseSet(reps: 1, weightKg: 0.0));
      _weightControllers.add(TextEditingController(text: ''));
      _repsControllers.add(TextEditingController(text: '1'));
      _distanceControllers.add(TextEditingController(text: ''));
      _durationSetControllers.add(TextEditingController(text: ''));
    });
  }

  void _duplicateSet(int index) {
    setState(() {
      final sourceSet = _sets[index];
      _sets.add(sourceSet.copyWith());
      _weightControllers.add(TextEditingController(text: _weightControllers[index].text));
      _repsControllers.add(TextEditingController(text: _repsControllers[index].text));
      _distanceControllers.add(TextEditingController(text: _distanceControllers[index].text));
      _durationSetControllers.add(TextEditingController(text: _durationSetControllers[index].text));
    });
  }

  void _removeSet(int index) {
    if (_sets.length <= 1) return;
    setState(() {
      _sets.removeAt(index);
      _weightControllers[index].dispose();
      _weightControllers.removeAt(index);
      _repsControllers[index].dispose();
      _repsControllers.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<WorkoutProvider>();
    final exerciseNames = provider.exerciseNames;

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 500, maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Add Exercise',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    IconButton(
                      icon: Icon(_type == ExerciseType.gym ? Icons.fitness_center : Icons.directions_run),
                      onPressed: () {
                        setState(() {
                          _type = _type == ExerciseType.gym ? ExerciseType.cardio : ExerciseType.gym;
                        });
                      },
                      tooltip: 'Toggle Gym/Cardio',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<String>.empty();
                    }
                    return exerciseNames.where((String option) {
                      return option
                          .toLowerCase()
                          .contains(textEditingValue.text.toLowerCase());
                    });
                  },
                  onSelected: (String selection) {
                    _nameController.text = selection;
                  },
                  fieldViewBuilder:
                      (context, controller, focusNode, onFieldSubmitted) {
                    _nameController.text = controller.text;
                    _nameController.selection = controller.selection;
                    return TextFormField(
                      controller: _nameController,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Exercise Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.fitness_center),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter exercise name';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        controller.text = value;
                        controller.selection = _nameController.selection;
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _sets.length,
                    itemBuilder: (context, index) {
                      if (_type == ExerciseType.gym) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24,
                                child: Text('${index + 1}', 
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _weightControllers[index],
                                  decoration: const InputDecoration(
                                    labelText: 'Weight',
                                    suffixText: 'kg',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _repsControllers[index],
                                  decoration: const InputDecoration(
                                    labelText: 'Reps',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                        );
                      } else {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24,
                                child: Text('${index + 1}', 
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _distanceControllers[index],
                                  decoration: const InputDecoration(
                                    labelText: 'Distance',
                                    suffixText: 'km',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _durationSetControllers[index],
                                  decoration: const InputDecoration(
                                    labelText: 'Time',
                                    suffixText: 'min',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
                ),
                Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: _addSet,
                      icon: const Icon(Icons.add),
                      tooltip: 'Add set',
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 12),
                    IconButton.filledTonal(
                      onPressed: () => _duplicateSet(_sets.length - 1),
                      icon: const Icon(Icons.copy),
                      tooltip: 'Duplicate last',
                      visualDensity: VisualDensity.compact,
                    ),
                    if (_sets.length > 1) ...[
                      const SizedBox(width: 12),
                      IconButton.filledTonal(
                        onPressed: () => _removeSet(_sets.length - 1),
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                        tooltip: 'Remove last',
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ],
                ),
                if (_type == ExerciseType.gym) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _durationController,
                    decoration: const InputDecoration(
                      labelText: 'Optional Total Duration',
                      border: OutlineInputBorder(),
                      suffixText: 'min',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          final List<ExerciseSet> totalSets = [];
                          for (int i = 0; i < _sets.length; i++) {
                            if (_type == ExerciseType.gym) {
                              totalSets.add(ExerciseSet(
                                reps: int.tryParse(_repsControllers[i].text) ?? 0,
                                weightKg: double.tryParse(_weightControllers[i].text) ?? 0.0,
                              ));
                            } else {
                              totalSets.add(ExerciseSet(
                                distanceKm: double.tryParse(_distanceControllers[i].text) ?? 0.0,
                                durationMinutes: int.tryParse(_durationSetControllers[i].text) ?? 0,
                              ));
                            }
                          }
                          
                          if (_type == ExerciseType.gym && totalSets.isNotEmpty) {
                            final totalMinutes = int.tryParse(_durationController.text) ?? 0;
                            totalSets[0].durationMinutes = totalMinutes;
                          }

                          final exercise = Exercise(
                            id: const Uuid().v4(),
                            type: _type,
                            name: _nameController.text.trim(),
                            sets: totalSets,
                          );
                          
                          await provider.saveExercise(exercise);
                          
                          if (context.mounted) {
                            Navigator.pop(context, exercise);
                          }
                        }
                      },
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
