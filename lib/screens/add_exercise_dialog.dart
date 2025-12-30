import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/exercise.dart';
import '../providers/workout_provider.dart';

class AddExerciseDialog extends StatefulWidget {
  const AddExerciseDialog({super.key});

  @override
  State<AddExerciseDialog> createState() => _AddExerciseDialogState();
}

class _AddExerciseDialogState extends State<AddExerciseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  ExerciseType _type = ExerciseType.gym;
  final List<ExerciseSet> _sets = [ExerciseSet(reps: 1, weightKg: 0.0)];
  final List<TextEditingController> _weightControllers = [TextEditingController(text: '')];
  final List<TextEditingController> _repsControllers = [TextEditingController(text: '1')];
  final List<TextEditingController> _distanceControllers = [TextEditingController(text: '')];
  final List<TextEditingController> _durationSetControllers = [TextEditingController(text: '')];

  Timer? _stopwatch;
  int _elapsedSeconds = 0;
  bool _isTimerRunning = false;
  final _durationController = TextEditingController(text: '');

  @override
  void dispose() {
    _stopwatch?.cancel();
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

  void _toggleStopwatch() {
    if (_isTimerRunning) {
      _stopwatch?.cancel();
      final minutes = (_elapsedSeconds / 60).ceil();
      _durationController.text = minutes.toString();
    } else {
      _elapsedSeconds = 0;
      _stopwatch = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _elapsedSeconds++;
        });
      });
    }
    setState(() {
      _isTimerRunning = !_isTimerRunning;
    });
  }

  String _formatStopwatch() {
    final minutes = _elapsedSeconds ~/ 60;
    final seconds = _elapsedSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
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
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
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
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _durationController,
                          decoration: InputDecoration(
                            labelText: 'Optional Total Duration',
                            border: const OutlineInputBorder(),
                            suffixText: 'min',
                            isDense: true,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isTimerRunning ? Icons.stop : Icons.timer,
                                color: _isTimerRunning ? Colors.red : null,
                              ),
                              onPressed: _toggleStopwatch,
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          readOnly: _isTimerRunning,
                        ),
                      ),
                    ],
                  ),
                ],
                if (_isTimerRunning) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      _formatStopwatch(),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
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
                      onPressed: () {
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
                          provider.addExerciseToWorkout(exercise);
                          Navigator.pop(context);
                        }
                      },
                      child: const Text('Add Exercise'),
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
