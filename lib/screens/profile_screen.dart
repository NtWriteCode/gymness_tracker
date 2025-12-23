import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/settings_provider.dart';
import '../providers/workout_provider.dart';
import '../models/achievement.dart';
import '../models/workout.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildProfileHeader(context),
        const SizedBox(height: 24),
        _buildSectionHeader(context, 'Vital Stats'),
        const SizedBox(height: 16),
        _buildWeightTrackingCard(context),
        const SizedBox(height: 32),
        _buildSectionHeader(context, 'Achievements'),
        const SizedBox(height: 16),
        _buildAchievementStats(context),
        const SizedBox(height: 16),
        _buildAchievementsCategories(context),
      ],
    );
  }

  Widget _buildAchievementStats(BuildContext context) {
    return Consumer<WorkoutProvider>(
      builder: (context, provider, _) {
        final earnedCount = provider.earnedAchievements.length;
        final totalCount = allAchievements.length;
        final progress = earnedCount / totalCount;

        return Column(
          children: [
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              minHeight: 8,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$earnedCount of $totalCount Unlocked',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${(progress * 100).round()}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        );
      }
    );
  }

  Widget _buildAchievementsCategories(BuildContext context) {
    return Consumer<WorkoutProvider>(
      builder: (context, provider, _) {
        final Map<AchievementCategory, List<Achievement>> grouped = {};
        for (var achievement in allAchievements) {
          grouped.putIfAbsent(achievement.category, () => []).add(achievement);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: grouped.entries.map((entry) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    _getCategoryName(entry.key),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          letterSpacing: 1.2,
                        ),
                  ),
                ),
                ...entry.value.map((achievement) => _buildAchievementTile(context, achievement, provider)),
                const SizedBox(height: 16),
              ],
            );
          }).toList(),
        );
      },
    );
  }

  String _getCategoryName(AchievementCategory category) {
    switch (category) {
      case AchievementCategory.power: return 'POWER & WEIGHT';
      case AchievementCategory.consistency: return 'CONSISTENCY';
      case AchievementCategory.funny: return 'FUNNY & NICE';
      case AchievementCategory.wholesome: return 'WHOLESOME';
      case AchievementCategory.secret: return 'SECRET';
    }
  }

  Widget _buildAchievementTile(BuildContext context, Achievement achievement, WorkoutProvider provider) {
    final earnedDate = provider.earnedAchievements[achievement.id];
    final isEarned = earnedDate != null;
    final isSecret = achievement.isSecret && !isEarned;

    return Card(
      elevation: isEarned ? 2 : 0.5,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isEarned 
          ? BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5), width: 1)
          : BorderSide.none,
      ),
      child: ListTile(
        onTap: isEarned ? () {
          // Find the workout that earned this
          final workout = provider.history.cast<Workout?>().firstWhere(
            (w) => w != null && (
              w.startDateTime.isAtSameMomentAs(earnedDate) || 
              (w.endDateTime != null && earnedDate.isAfter(w.startDateTime) && earnedDate.isBefore(w.endDateTime!.add(const Duration(seconds: 5))))
            ),
            orElse: () => null,
          );
          if (workout != null) {
            provider.jumpToWorkout(workout.id);
          }
        } : null,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isEarned 
              ? Theme.of(context).colorScheme.primaryContainer 
              : Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isSecret ? Icons.help_outline : achievement.icon,
            color: isEarned 
              ? Theme.of(context).colorScheme.primary 
              : Colors.grey.shade500,
            size: 24,
          ),
        ),
        title: Text(
          isSecret ? '???' : achievement.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isEarned 
              ? Theme.of(context).colorScheme.onSurface 
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        subtitle: Text(
          isSecret ? 'Keep working out to find out...' : achievement.description,
          style: TextStyle(
            fontSize: 12,
            color: isEarned 
              ? Theme.of(context).colorScheme.onSurfaceVariant 
              : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
        trailing: isEarned 
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                Text(
                  DateFormat('MM/dd/yy').format(earnedDate),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            )
          : null,
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              Icons.person,
              size: 60,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Gymness User',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(
            'Keep grinding!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildWeightTrackingCard(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: const Icon(Icons.monitor_weight_outlined, size: 30),
            title: const Text('Current Weight'),
            subtitle: const Text('Used for accurate calorie calculation'),
            trailing: Text(
              '${settings.userWeightKg} kg',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            onTap: () async {
              final controller = TextEditingController(text: settings.userWeightKg.toString());
              final result = await showDialog<String>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Edit Body Weight'),
                  content: TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Weight (kg)',
                      suffixText: 'kg',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, controller.text),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              );
              if (result != null) {
                final weight = double.tryParse(result);
                if (weight != null) {
                  settings.setUserWeight(weight);
                }
              }
            },
          ),
        );
      },
    );
  }

}
