import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/workout_provider.dart';
import '../providers/settings_provider.dart';
import '../models/workout.dart';

enum StatsPeriod { week, month, year, all }

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  DateTime _focusedMonth = DateTime.now();
  StatsPeriod _selectedPeriod = StatsPeriod.month;
  
  int _caloriesTapCount = 0;
  int _volumeTapCount = 0;
  int _durationTapCount = 0;
  int _workoutsTapCount = 0;
  int _topExercisesTapCount = 0;
  static const int _easterEggThreshold = 7;

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return Consumer<WorkoutProvider>(
          builder: (context, provider, child) {
            final now = DateTime.now();
            
            List<Workout> filteredWorkouts;
            String sectionTitle;
            
            switch (_selectedPeriod) {
              case StatsPeriod.week:
                final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
                final firstDayOfWeek = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
                filteredWorkouts = provider.history.where((w) => w.startDateTime.isAfter(firstDayOfWeek) || w.startDateTime.isAtSameMomentAs(firstDayOfWeek)).toList();
                sectionTitle = 'This Week';
                break;
              case StatsPeriod.month:
                final firstDayOfMonth = DateTime(now.year, now.month, 1);
                filteredWorkouts = provider.history.where((w) => w.startDateTime.isAfter(firstDayOfMonth) || w.startDateTime.isAtSameMomentAs(firstDayOfMonth)).toList();
                sectionTitle = 'This Month';
                break;
              case StatsPeriod.year:
                final firstDayOfYear = DateTime(now.year, 1, 1);
                filteredWorkouts = provider.history.where((w) => w.startDateTime.isAfter(firstDayOfYear) || w.startDateTime.isAtSameMomentAs(firstDayOfYear)).toList();
                sectionTitle = 'This Year';
                break;
              case StatsPeriod.all:
                filteredWorkouts = provider.history;
                sectionTitle = 'Lifetime Stats';
                break;
            }

            DateTime getStartDate() {
              switch (_selectedPeriod) {
                case StatsPeriod.week:
                  final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
                  return DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
                case StatsPeriod.month:
                  return DateTime(now.year, now.month, 1);
                case StatsPeriod.year:
                  return DateTime(now.year, 1, 1);
                case StatsPeriod.all:
                  if (provider.history.isEmpty) return now;
                  return provider.history.reduce((a, b) => a.startDateTime.isBefore(b.startDateTime) ? a : b).startDateTime;
              }
            }

            // Calculate Stats
            int totalCalories = 0;
            double totalVolume = 0;
            int totalDurationMinutes = 0;
            
            for (final Workout workout in filteredWorkouts) {
              totalCalories += workout.estimatedCalories ?? 0;
              totalVolume += provider.getWorkoutVolume(workout);
              if (workout.endDateTime != null) {
                totalDurationMinutes += workout.endDateTime!.difference(workout.startDateTime).inMinutes;
              }
            }

            // Calculate Top 3 Exercises
            final Map<String, int> exerciseFrequency = {};
            for (final workout in filteredWorkouts) {
              for (final exerciseId in workout.exerciseIds) {
                final exercise = provider.getExerciseById(exerciseId);
                if (exercise != null) {
                  exerciseFrequency[exercise.name] = (exerciseFrequency[exercise.name] ?? 0) + 1;
                }
              }
            }
            final topExercises = exerciseFrequency.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            final top5 = topExercises.take(5).toList();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionHeader(context, sectionTitle),
                const SizedBox(height: 12),
                _buildPeriodToggle(),
                const SizedBox(height: 16),
                _buildOverviewStatsGrid(context, provider, filteredWorkouts, totalCalories, totalVolume, totalDurationMinutes),
                const SizedBox(height: 16),
                _buildTopExercisesBlock(context, top5),
                const SizedBox(height: 32),
                _buildSectionHeader(context, 'Personal Records'),
                const SizedBox(height: 16),
                ..._buildPersonalRecords(context, provider),
                const SizedBox(height: 32),
                _buildSectionHeader(context, 'Progress Charts'),
                const SizedBox(height: 16),
                _buildProgressCharts(context, provider, filteredWorkouts, getStartDate()),
                const SizedBox(height: 32),
                _buildSectionHeader(context, 'Consistency Heatmap'),
                const SizedBox(height: 16),
                _buildHeatmapNavigation(context),
                const SizedBox(height: 8),
                _buildHeatmap(context, provider),
                const SizedBox(height: 12),
                _buildHeatmapLegend(context),
                const SizedBox(height: 32),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildHeatmapNavigation(BuildContext context) {
    final monthFormat = DateFormat('MMMM yyyy');
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            setState(() {
              _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
            });
          },
        ),
        Text(
          monthFormat.format(_focusedMonth),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () {
            setState(() {
              _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
            });
          },
        ),
      ],
    );
  }

  Widget _buildHeatmap(BuildContext context, WorkoutProvider provider) {
    // Get days in month
    final lastDay = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final daysInMonth = lastDay.day;

    // Map workouts to days
    final Map<int, double> dailyVolume = {};
    for (final workout in provider.history) {
      if (workout.startDateTime.year == _focusedMonth.year && 
          workout.startDateTime.month == _focusedMonth.month) {
        double vol = 0;
        for (final id in workout.exerciseIds) {
          final ex = provider.getExerciseById(id);
          if (ex != null) vol += ex.totalWeightLifted;
        }
        dailyVolume[workout.startDateTime.day] = (dailyVolume[workout.startDateTime.day] ?? 0) + vol;
      }
    }

    // Determine recovery days (day after a workout day)
    final Set<int> recoveryDays = {};
    for (int day = 1; day <= daysInMonth; day++) {
      if (dailyVolume.containsKey(day)) {
        if (day < daysInMonth) {
          recoveryDays.add(day + 1);
        }
      }
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: daysInMonth,
      itemBuilder: (context, index) {
        final day = index + 1;
        final volume = dailyVolume[day] ?? 0;
        final isRecovery = recoveryDays.contains(day) && volume == 0;
        
        Color cellColor;
        if (volume > 0) {
          // Intensity shades (Emerald/Green GitHub Style)
          if (volume <= 1000) {
            cellColor = const Color(0xFFC6E48B); // GitHub Light Green
          } else if (volume <= 3000) {
            cellColor = const Color(0xFF7BC96F); // GitHub Medium Green
          } else if (volume <= 6000) {
            cellColor = const Color(0xFF239A3B); // GitHub Dark Green
          } else if (volume <= 10000) {
            cellColor = const Color(0xFF196127); // GitHub Very Dark Green
          } else {
            cellColor = const Color(0xFF0D3D18); // Deep Forest
          }
        } else if (isRecovery) {
          cellColor = Colors.amber.shade200; // Recovery Day (Amber)
        } else {
          cellColor = Theme.of(context).brightness == Brightness.dark 
            ? Colors.grey.shade900 
            : Colors.grey.shade100; // Rest Day
        }

        return Container(
          decoration: BoxDecoration(
            color: cellColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade300, width: 0.5),
          ),
          child: Center(
            child: Text(
              day.toString(),
              style: TextStyle(
                fontSize: 10,
                color: volume > 3000 
                  ? Colors.white 
                  : (Theme.of(context).brightness == Brightness.dark && volume == 0 
                      ? Colors.white70 
                      : Colors.black87),
                fontWeight: volume > 0 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeatmapLegend(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Intensity: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(width: 4),
            _buildLegendBox(const Color(0xFFC6E48B)),
            _buildLegendBox(const Color(0xFF7BC96F)),
            _buildLegendBox(const Color(0xFF239A3B)),
            _buildLegendBox(const Color(0xFF196127)),
            _buildLegendBox(const Color(0xFF0D3D18)),
            const SizedBox(width: 8),
            const Icon(Icons.whatshot, size: 14, color: Colors.orange),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendIconBox(Colors.amber.shade200, Icons.eco, 'Recovery', Colors.green.shade700),
            const SizedBox(width: 16),
            _buildLegendIconBox(Colors.grey.shade100, Icons.bedtime, 'Rest', Colors.blueGrey),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendBox(Color color) {
    return Container(
      width: 12,
      height: 12,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
      ),
    );
  }

  Widget _buildLegendIconBox(Color bgColor, IconData icon, String label, Color iconColor) {
    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade300, width: 0.5),
          ),
          child: Icon(icon, size: 10, color: iconColor),
        ),
        const SizedBox(width: 6),
        Text(
          label, 
          style: TextStyle(
            fontSize: 12, 
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCharts(BuildContext context, WorkoutProvider provider, List<Workout> filteredWorkouts, DateTime startDate) {
    if (provider.history.isEmpty) {
      return const Center(child: Text('No chart data available.'));
    }
    
    return _buildCalculatedCharts(context, provider, filteredWorkouts, startDate);
  }


  Widget _buildCalculatedCharts(BuildContext context, WorkoutProvider provider, List<Workout> filteredWorkouts, DateTime startDate) {
    // Sort history
    final history = List<Workout>.from(filteredWorkouts);
    history.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));

    if (history.isEmpty) {
      return const Center(child: Text('No workouts in the selected period.'));
    }

    // Prepare data
    final List<FlSpot> calorieSpots = [];
    final List<FlSpot> volumeSpots = [];
    
    for (int i = 0; i < history.length; i++) {
      final workout = history[i];
      final dayIndex = workout.startDateTime.difference(startDate).inDays.toDouble();
      
      // Calorie Spot
      calorieSpots.add(FlSpot(dayIndex, (workout.estimatedCalories ?? 0).toDouble()));
      
      // Volume Spot
      double volume = 0;
      for (final id in workout.exerciseIds) {
        final ex = provider.getExerciseById(id);
        if (ex != null) volume += ex.totalWeightLifted;
      }
      volumeSpots.add(FlSpot(dayIndex, volume));
    }

    return Column(
      children: [
        _buildChartCard(
          context,
          'Calories Burned',
          calorieSpots,
          Colors.orange,
          'kcal',
          startDate,
        ),
        const SizedBox(height: 16),
        _buildChartCard(
          context,
          'Weight Volume',
          volumeSpots,
          Colors.purple,
          'kg',
          startDate,
        ),
      ],
    );
  }

  Widget _buildChartCard(
    BuildContext context,
    String title,
    List<FlSpot> spots,
    Color color,
    String unit,
    DateTime startDate,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              value.toInt().toString(),
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: spots.length > 1 ? (spots.last.x - spots.first.x) / 3 : 1,
                        getTitlesWidget: (value, meta) {
                          final date = startDate.add(Duration(days: value.toInt()));
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              DateFormat('MM/dd').format(date),
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: spots.length > 1,
                      color: color,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: color.withValues(alpha: 0.2),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (spot) => color.withValues(alpha: 0.8),
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((touchedSpot) {
                          final date = startDate.add(Duration(days: touchedSpot.x.toInt()));
                          return LineTooltipItem(
                            '${DateFormat('MMM d').format(date)}\n${touchedSpot.y.round()} $unit',
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPersonalRecords(BuildContext context, WorkoutProvider provider) {
    if (provider.history.isEmpty) {
      return [const Center(child: Text('No workouts logged yet.'))];
    }

    Workout? maxCaloriesWorkout;
    Workout? maxVolumeWorkout;
    Workout? maxDurationWorkout;

    double maxVolume = 0;
    int maxDurationSec = 0;

    final dateFormat = DateFormat('MMM d, yyyy');

    for (final workout in provider.history) {
      // Calories
      if (maxCaloriesWorkout == null || 
          (workout.estimatedCalories ?? 0) > (maxCaloriesWorkout.estimatedCalories ?? 0)) {
        if ((workout.estimatedCalories ?? 0) > 0) {
          maxCaloriesWorkout = workout;
        }
      }

      // Volume
      double currentVolume = 0;
      for (final id in workout.exerciseIds) {
        final ex = provider.getExerciseById(id);
        if (ex != null) currentVolume += ex.totalWeightLifted;
      }
      if (currentVolume > maxVolume) {
        maxVolume = currentVolume;
        maxVolumeWorkout = workout;
      }

      // Duration
      if (workout.endDateTime != null) {
        final duration = workout.endDateTime!.difference(workout.startDateTime).inSeconds;
        if (duration > maxDurationSec) {
          maxDurationSec = duration;
          maxDurationWorkout = workout;
        }
      }
    }

    return [
      Card(
        elevation: 2,
        child: Column(
          children: [
            if (maxCaloriesWorkout != null)
              _buildRecordTile(
                context,
                'Most Calories Burned',
                '${maxCaloriesWorkout.estimatedCalories} kcal',
                dateFormat.format(maxCaloriesWorkout.startDateTime),
                Icons.local_fire_department,
                Colors.orange,
              ),
            if (maxVolumeWorkout != null)
              _buildRecordTile(
                context,
                'Highest Weight Volume',
                '${maxVolume.round()} kg',
                dateFormat.format(maxVolumeWorkout.startDateTime),
                Icons.line_weight,
                Colors.purple,
              ),
            if (maxDurationWorkout != null)
              _buildRecordTile(
                context,
                'Longest Workout',
                '${(maxDurationSec / 60).round()} min',
                dateFormat.format(maxDurationWorkout.startDateTime),
                Icons.timer,
                Colors.green,
              ),
          ],
        ),
      ),
    ];
  }

  Widget _buildRecordTile(
    BuildContext context,
    String label,
    String value,
    String date,
    IconData icon,
    Color color,
  ) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.1),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('Achieved on $date'),
      trailing: Text(
        value,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }

  Widget _buildPeriodToggle() {
    return SegmentedButton<StatsPeriod>(
      segments: const [
        ButtonSegment(value: StatsPeriod.week, label: Text('Week')),
        ButtonSegment(value: StatsPeriod.month, label: Text('Month')),
        ButtonSegment(value: StatsPeriod.year, label: Text('Year')),
        ButtonSegment(value: StatsPeriod.all, label: Text('All')),
      ],
      selected: {_selectedPeriod},
      onSelectionChanged: (Set<StatsPeriod> newSelection) {
        setState(() {
          _selectedPeriod = newSelection.first;
        });
      },
      showSelectedIcon: false,
    );
  }

  Widget _buildOverviewStatsGrid(BuildContext context, WorkoutProvider provider, List<Workout> workouts, int calories, double weight, int durationMinutes) {
    final count = workouts.length;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.0,
      children: [
        _buildStatCard(
          context,
          'Workouts',
          Text(count.toString(), 
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          Icons.fitness_center,
          Colors.blue,
          onTap: () {
            setState(() => _workoutsTapCount++);
            if (_workoutsTapCount >= _easterEggThreshold) {
              _workoutsTapCount = 0;
              _showWorkoutsEasterEgg(context, provider, workouts);
            }
          },
        ),
        _buildStatCard(
          context,
          'Total Duration',
          Text('${durationMinutes ~/ 60}h ${durationMinutes % 60}m', 
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.teal,
            ),
          ),
          Icons.timer,
          Colors.teal,
          onTap: () {
            setState(() => _durationTapCount++);
            if (_durationTapCount >= _easterEggThreshold) {
              _durationTapCount = 0;
              _showDurationEasterEgg(context, durationMinutes);
            }
          },
        ),
        _buildStatCard(
          context,
          'Calories',
          Text('$calories kcal', 
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          Icons.local_fire_department,
          Colors.orange,
          onTap: () {
            setState(() => _caloriesTapCount++);
            if (_caloriesTapCount >= _easterEggThreshold) {
              _caloriesTapCount = 0;
              _showCaloriesEasterEgg(context, calories);
            }
          },
        ),
        _buildStatCard(
          context,
          'Volume',
          Text('${weight.round()} kg', 
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.purple,
            ),
          ),
          Icons.line_weight,
          Colors.purple,
          onTap: () {
            setState(() => _volumeTapCount++);
            if (_volumeTapCount >= _easterEggThreshold) {
              _volumeTapCount = 0;
              _showVolumeEasterEgg(context, provider, weight);
            }
          },
        ),
      ],
    );
  }

  Widget _buildTopExercisesBlock(BuildContext context, List<MapEntry<String, int>> top5) {
    if (top5.isEmpty) return const SizedBox.shrink();
    final top3 = top5.take(3).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          setState(() => _topExercisesTapCount++);
          if (_topExercisesTapCount >= _easterEggThreshold) {
            _topExercisesTapCount = 0;
            _showTopExercisesEasterEgg(context, top5);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Top Exercises',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: top3.asMap().entries.map((entry) {
                  final index = entry.key;
                  final exercise = entry.value.key;
                  final colors = [Colors.amber, Colors.blueGrey, Colors.brown.shade300];
                  
                  return Expanded(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: colors[index].withValues(alpha: 0.2),
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: colors[index],
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          exercise,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    Widget valueWidget,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.1),
                color.withValues(alpha: 0.05),
              ],
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: valueWidget,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCaloriesEasterEgg(BuildContext context, int calories) {
    final fatKg = calories / 7700;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(child: Text('Calorie Magic')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Did you know?'),
            const SizedBox(height: 16),
            Text(
              '${NumberFormat('#,###').format(calories)} kcal',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const Text('is equivalent to burning about'),
            const SizedBox(height: 8),
            Text(
              '${fatKg.toStringAsFixed(2)} kg',
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                fontSize: 24, 
                color: Theme.of(context).colorScheme.primary
              ),
            ),
            const Text('of pure body fat! 🧈'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mind Blown'),
          ),
        ],
      ),
    );
  }

  void _showVolumeEasterEgg(BuildContext context, WorkoutProvider provider, double volume) {
    final equivalent = provider.getFunnyWeightEquivalent(volume);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.fitness_center, color: Colors.purple),
            SizedBox(width: 8),
            Expanded(child: Text('Heavy Lifter!')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Text(
                WorkoutProvider.getWeightEmoji(equivalent['name']),
                style: const TextStyle(fontSize: 48),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Your total volume of'),
            Text(
              '${volume.round()} kg',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const Text('is the same as lifting'),
            const SizedBox(height: 8),
            Text(
              '${equivalent['count']} ${equivalent['name']}!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                fontSize: 20, 
                color: Theme.of(context).colorScheme.primary
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Impressive'),
          ),
        ],
      ),
    );
  }

  void _showDurationEasterEgg(BuildContext context, int totalMinutes) {
    if (totalMinutes <= 0) return;

    final List<Map<String, dynamic>> movies = [
      {'name': 'The Lord of the Rings (Full Extended)', 'length': 682, 'emoji': '🧙‍♂️'},
      {'name': 'Harry Potter (First Movie)', 'length': 152, 'emoji': '⚡'},
      {'name': 'Titanic', 'length': 194, 'emoji': '🚢'},
      {'name': 'Jurassic Park', 'length': 127, 'emoji': '🦖'},
      {'name': 'Star Wars: A New Hope', 'length': 121, 'emoji': '⚔️'},
      {'name': 'Pirates of the Caribbean', 'length': 143, 'emoji': '🏴‍☠️'},
      {'name': 'Forrest Gump', 'length': 142, 'emoji': '👟'},
      {'name': 'The Terminator', 'length': 107, 'emoji': '🌑'},
      {'name': 'The Lion King', 'length': 88, 'emoji': '🦁'},
      {'name': 'Avengers: Endgame', 'length': 181, 'emoji': '🦸‍♂️'},
      {'name': 'The Dark Knight', 'length': 152, 'emoji': '🦇'},
      {'name': 'Transformers', 'length': 144, 'emoji': '🤖'},
      {'name': 'Shrek', 'length': 90, 'emoji': '🧅'},
      {'name': 'Interstellar', 'length': 169, 'emoji': '🪐'},
    ];

    final movie = (movies..shuffle()).first;
    final count = totalMinutes / movie['length'];
    final countStr = count < 1.0 ? count.toStringAsFixed(1) : count.toStringAsFixed(1);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.movie, color: Colors.teal.shade700),
            const SizedBox(width: 8),
            const Expanded(child: Text('Movie Marathon')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              movie['emoji'],
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 16),
            const Text('In the time you spent training,'),
            const Text('you could have watched'),
            const SizedBox(height: 12),
            Text(
              movie['name'],
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              '$countStr times!',
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                fontSize: 24, 
                color: Theme.of(context).colorScheme.primary
              ),
            ),
            const SizedBox(height: 12),
            const Text('The grind is real. 💪'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Worth it'),
          ),
        ],
      ),
    );
  }

  void _showWorkoutsEasterEgg(BuildContext context, WorkoutProvider provider, List<Workout> workouts) {
    final count = workouts.length;
    
    // Leg Day Detector
    int legDays = 0;
    for (final workout in workouts) {
      bool isLegDay = false;
      for (final id in workout.exerciseIds) {
        final ex = provider.getExerciseById(id);
        if (ex != null) {
          final name = ex.name.toLowerCase();
          if (name.contains('leg') || name.contains('láb')) {
            isLegDay = true;
            break;
          }
        }
      }
      if (isLegDay) legDays++;
    }
    final legPercent = workouts.isEmpty ? 0 : (legDays / workouts.length * 100).round();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.star, color: Colors.blue),
            SizedBox(width: 8),
            Expanded(child: Text('Leg Day Investigator')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🍗',
              style: TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 16),
            Text(
              'Out of $count workouts, $legDays were Leg Days ($legPercent%). Your quads called, they want a vacation! 🍗',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Stay Grinding'),
          ),
        ],
      ),
    );
  }

  void _showTopExercisesEasterEgg(BuildContext context, List<MapEntry<String, int>> top5) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.insights, color: Colors.amber),
            SizedBox(width: 8),
            Expanded(child: Text('Exercise Breakdown')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Here are your top 5 most frequent exercises and how many times you performed them:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            ...top5.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 12, 
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.key,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      '${item.value}x',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
