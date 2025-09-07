import 'package:flutter/material.dart';
import 'profile_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  final String userName;
  final ValueNotifier<ThemeMode> themeNotifier;
  final Map<String, Map<String, dynamic>> incubatorData;
  final Function(String)? onNavigateToDashboard;
  final Function(Map<String, Map<String, dynamic>>)? onCandlingScheduled;

  const AnalyticsScreen({
    super.key,
    required this.userName,
    required this.themeNotifier,
    required this.incubatorData,
    this.onNavigateToDashboard,
    this.onCandlingScheduled,
  });

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  
  // Track scheduled candling for each incubator
  Map<String, Map<String, dynamic>> scheduledCandling = {};
  
  // Calculate overall hatch rate from completed batches
  double _calculateOverallHatchRate() {
    // For now, return sample data - this would be calculated from actual batch history
    return 85.5; // 85.5% success rate
  }

  int _getTotalCompletedBatches() {
    // Sample data - would be calculated from batch history
    return 12;
  }

  String _getNextCandlingDate() {
    // Find the next candling date from active batches
    DateTime? nextCandling;
    
    widget.incubatorData.forEach((name, data) {
      final int startDateMs = data['startDate'] ?? DateTime.now().millisecondsSinceEpoch;
      final DateTime startDate = DateTime.fromMillisecondsSinceEpoch(startDateMs);
      
      // Candling typically done on days 7, 14, 18
      final List<int> candlingDays = [7, 14, 18];
      final DateTime now = DateTime.now();
      final int daysElapsed = now.difference(startDate).inDays;
      
      for (int day in candlingDays) {
        if (daysElapsed < day) {
          final DateTime candlingDate = startDate.add(Duration(days: day));
          if (nextCandling == null || candlingDate.isBefore(nextCandling!)) {
            nextCandling = candlingDate;
          }
          break;
        }
      }
    });
    
    if (nextCandling != null) {
      return '${nextCandling!.day}/${nextCandling!.month}/${nextCandling!.year}';
    }
    return 'No active batches';
  }

  void _navigateToDashboard(String incubatorName) {
    if (widget.onNavigateToDashboard != null) {
      widget.onNavigateToDashboard!(incubatorName);
    }
  }

  void _showCandlingScheduler() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.visibility,
                        color: Colors.orange,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Schedule Candling',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Available Incubators
                Text(
                  'Select Incubator for Candling:',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),

                // List of available incubators
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: widget.incubatorData.length,
                    itemBuilder: (context, index) {
                      final entry = widget.incubatorData.entries.elementAt(index);
                      final incubatorName = entry.key;
                      final data = entry.value;
                      final batchName = data['batchName'] ?? 'Unknown Batch';
                      final int startDateMs = data['startDate'] ?? DateTime.now().millisecondsSinceEpoch;
                      final DateTime startDate = DateTime.fromMillisecondsSinceEpoch(startDateMs);
                      final DateTime now = DateTime.now();
                      final int daysElapsed = now.difference(startDate).inDays;

                      // Determine next candling day
                      final List<int> candlingDays = [7, 14, 18];
                      int? nextCandlingDay;
                      for (int day in candlingDays) {
                        if (daysElapsed < day) {
                          nextCandlingDay = day;
                          break;
                        }
                      }

                      // Check if this candling is already scheduled
                      final String scheduleKey = nextCandlingDay != null 
                          ? '${incubatorName}_day_$nextCandlingDay' 
                          : '';
                      final bool isScheduled = scheduledCandling.containsKey(scheduleKey);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isScheduled 
                                  ? Colors.green.withValues(alpha: 0.3)
                                  : Colors.orange.withValues(alpha: 0.3),
                            ),
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isScheduled
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              isScheduled ? Icons.check_circle : Icons.egg,
                              color: isScheduled ? Colors.green : Colors.orange,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            incubatorName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(batchName),
                              if (nextCandlingDay != null && !isScheduled)
                                Text(
                                  'Next candling: Day $nextCandlingDay (${nextCandlingDay - daysElapsed} days)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w500,
                                  ),
                                )
                              else if (isScheduled)
                                Text(
                                  'Candling scheduled for Day $nextCandlingDay ✓',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.green,
                                    fontWeight: FontWeight.w500,
                                  ),
                                )
                              else
                                Text(
                                  'Candling complete',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                            ],
                          ),
                          trailing: Icon(
                            isScheduled ? Icons.check : Icons.arrow_forward_ios,
                            size: 16,
                            color: isScheduled ? Colors.green : Colors.grey[400],
                          ),
                          onTap: isScheduled ? null : () {
                            _scheduleCandling(incubatorName, batchName, nextCandlingDay);
                          },
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Info text
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tap an incubator to schedule candling reminder',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _scheduleCandling(String incubatorName, String batchName, int? nextCandlingDay) {
    Navigator.of(context).pop(); // Close the scheduler dialog

    if (nextCandlingDay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Candling is complete for $batchName'),
          backgroundColor: Colors.grey,
        ),
      );
      return;
    }

    // Check if candling is already scheduled for this incubator and day
    final String scheduleKey = '${incubatorName}_day_$nextCandlingDay';
    if (scheduledCandling.containsKey(scheduleKey)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Candling already scheduled for $incubatorName on Day $nextCandlingDay'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    // Show date picker for user to select the candling date
    _showDatePicker(incubatorName, batchName, nextCandlingDay);
  }

  void _showDatePicker(String incubatorName, String batchName, int candlingDay) {
    // Calculate suggested date (original logic)
    final data = widget.incubatorData[incubatorName];
    final int startDateMs = data?['startDate'] ?? DateTime.now().millisecondsSinceEpoch;
    final DateTime startDate = DateTime.fromMillisecondsSinceEpoch(startDateMs);
    final DateTime suggestedDate = startDate.add(Duration(days: candlingDay));
    final DateTime tomorrow = DateTime.now().add(const Duration(days: 1));
    final DateTime initialDate = suggestedDate.isAfter(tomorrow) ? suggestedDate : tomorrow;

    showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Select Candling Date',
      confirmText: 'Schedule',
      cancelText: 'Cancel',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Colors.orange,
            ),
          ),
          child: child!,
        );
      },
    ).then((selectedDate) {
      if (selectedDate != null) {
        _confirmScheduling(incubatorName, batchName, candlingDay, selectedDate);
      }
    });
  }

  void _confirmScheduling(String incubatorName, String batchName, int candlingDay, DateTime selectedDate) {
    final String scheduleKey = '${incubatorName}_day_$candlingDay';

    // Add to scheduled candling
    setState(() {
      scheduledCandling[scheduleKey] = {
        'incubatorName': incubatorName,
        'batchName': batchName,
        'candlingDay': candlingDay,
        'scheduledDate': selectedDate,
        'dateScheduled': DateTime.now(),
      };
    });

    // Notify parent about the scheduled candling
    if (widget.onCandlingScheduled != null) {
      widget.onCandlingScheduled!(Map.from(scheduledCandling));
    }

    // Show success confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Candling Scheduled Successfully!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('$incubatorName - $batchName'),
            Text('Day $candlingDay candling reminder set'),
            Text('Date: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'View Details',
          textColor: Colors.white,
          onPressed: () {
            _navigateToDashboard(incubatorName);
          },
        ),
      ),
    );
  }

  void _showBatchDetails(String incubatorName, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
        final String batchName = data['batchName'] ?? 'Unknown Batch';
        final int startDateMs = data['startDate'] ?? DateTime.now().millisecondsSinceEpoch;
        final int incubationDays = data['incubationDays'] ?? 21;
        final double temperature = data['temperature']?.toDouble() ?? 37.5;
        final double humidity = data['humidity']?.toDouble() ?? 50.0;
        final double oxygen = data['oxygen']?.toDouble() ?? 20.0;
        final double co2 = data['co2']?.toDouble() ?? 800.0;
        final bool eggTurning = data['eggTurning'] ?? true;
        final bool lighting = data['lighting'] ?? true;
        
        final DateTime startDate = DateTime.fromMillisecondsSinceEpoch(startDateMs);
        final DateTime now = DateTime.now();
        final int daysElapsed = now.difference(startDate).inDays;
        final int daysRemaining = (incubationDays - daysElapsed).clamp(0, incubationDays);

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(Icons.egg, color: Colors.blue, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            batchName,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            incubatorName,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDarkMode ? const Color(0xFFB0B0B0) : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Progress Section
                _buildDetailSection(
                  'Incubation Progress',
                  Icons.schedule,
                  Colors.orange,
                  [
                    'Started: ${startDate.day}/${startDate.month}/${startDate.year}',
                    'Day $daysElapsed of $incubationDays',
                    daysRemaining == 0 ? 'Ready to hatch!' : 
                    daysRemaining == 1 ? '1 day left' : '$daysRemaining days remaining',
                  ],
                ),

                const SizedBox(height: 16),

                // Environmental Conditions
                _buildDetailSection(
                  'Environmental Conditions',
                  Icons.thermostat,
                  Colors.green,
                  [
                    'Temperature: $temperature°C',
                    'Humidity: $humidity%',
                    'Oxygen: $oxygen%',
                    'CO₂: $co2 ppm',
                  ],
                ),

                const SizedBox(height: 16),

                // Equipment Status
                _buildDetailSection(
                  'Equipment Status',
                  Icons.settings,
                  Colors.blue,
                  [
                    'Egg Turning: ${eggTurning ? 'Active' : 'Inactive'}',
                    'Lighting: ${lighting ? 'On' : 'Off'}',
                  ],
                ),

                const SizedBox(height: 24),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Navigate to dashboard with the specific incubator selected
                      // This will be handled by the parent navigation
                      _navigateToDashboard(incubatorName);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('View Full Details'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailSection(String title, IconData icon, Color color, List<String> details) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...details.map((detail) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '• $detail',
              style: const TextStyle(fontSize: 13),
            ),
          )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // Remove back button since we're using bottom nav
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () async {
              await showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => DraggableScrollableSheet(
                  initialChildSize: 0.9,
                  minChildSize: 0.5,
                  maxChildSize: 0.95,
                  builder: (context, scrollController) => Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: ProfileScreen(
                      incubatorData: widget.incubatorData,
                      selectedIncubator: widget.incubatorData.keys.isNotEmpty 
                          ? widget.incubatorData.keys.first 
                          : '',
                      themeNotifier: widget.themeNotifier,
                      userName: widget.userName,
                      onUserNameChanged: () async {
                        // This will be handled by the parent MainNavigation
                        // via the stream-based approach we implemented
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hatch Rate Statistics Section - Convert to Banner Style
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade400, Colors.green.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.trending_up,
                    size: 48,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_calculateOverallHatchRate()}%',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Overall Success Rate',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        Text(
                          'From ${_getTotalCompletedBatches()} completed batches',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Candling Schedule - Convert to Timeline Style
            Text(
              'Candling Schedule',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            _buildCandlingTimeline(isDarkMode),
            
            const SizedBox(height: 24),
            
            // Active Batches Section - Now Clickable
            Row(
              children: [
                Text(
                  'Active Batches',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  'Tap for details',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? const Color(0xFFB0B0B0) : Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            ...widget.incubatorData.entries.map((entry) => 
              _buildClickableActiveBatchCard(entry.key, entry.value, isDarkMode)
            ),
            
            const SizedBox(height: 24),
            
            // Batch History Section
            Text(
              'Recent Batch History',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            _buildBatchHistoryList(isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildCandlingTimeline(bool isDarkMode) {
    final String nextDate = _getNextCandlingDate();
    
    return GestureDetector(
      onTap: _showCandlingScheduler,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.orange.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.visibility,
                color: Colors.orange,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Candling Schedule',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Next due: $nextDate',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.arrow_forward_ios,
                color: Colors.orange,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClickableActiveBatchCard(String incubatorName, Map<String, dynamic> data, bool isDarkMode) {
    final String batchName = data['batchName'] ?? 'Unknown Batch';
    final int startDateMs = data['startDate'] ?? DateTime.now().millisecondsSinceEpoch;
    final int incubationDays = data['incubationDays'] ?? 21;
    
    final DateTime startDate = DateTime.fromMillisecondsSinceEpoch(startDateMs);
    final DateTime now = DateTime.now();
    final int daysElapsed = now.difference(startDate).inDays;
    final int daysRemaining = (incubationDays - daysElapsed).clamp(0, incubationDays);
    
    Color statusColor = Colors.blue;

    // Calculate progress percentage
    double progress = (daysElapsed / incubationDays).clamp(0.0, 1.0);
    
    return GestureDetector(
      onTap: () => _showBatchDetails(incubatorName, data),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: statusColor.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: statusColor.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.egg, color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        batchName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        incubatorName,
                        style: TextStyle(
                          color: isDarkMode ? const Color(0xFFB0B0B0) : Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    daysRemaining == 0 ? 'Ready to hatch!' : 
                    daysRemaining == 1 ? '1 day left' : '$daysRemaining days left',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: isDarkMode ? const Color(0xFFB0B0B0) : Colors.grey[400],
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Progress Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Day $daysElapsed of $incubationDays',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? const Color(0xFFB0B0B0) : Colors.grey[600],
                      ),
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: isDarkMode ? const Color(0xFF2D2D2D) : Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  minHeight: 6,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchHistoryList(bool isDarkMode) {
    // Sample batch history data
    final List<Map<String, dynamic>> historyBatches = [
      {
        'batchName': 'Batch Z-003',
        'incubator': 'Incubator 1',
        'startDate': DateTime.now().subtract(const Duration(days: 45)),
        'endDate': DateTime.now().subtract(const Duration(days: 24)),
        'successRate': 90.0,
        'eggsStarted': 20,
        'eggsHatched': 18,
      },
      {
        'batchName': 'Batch Y-002',
        'incubator': 'Incubator 2',
        'startDate': DateTime.now().subtract(const Duration(days: 70)),
        'endDate': DateTime.now().subtract(const Duration(days: 49)),
        'successRate': 80.0,
        'eggsStarted': 15,
        'eggsHatched': 12,
      },
    ];

    return Column(
      children: historyBatches.map((batch) {
        Color rateColor = batch['successRate'] >= 85 
            ? Colors.green 
            : (batch['successRate'] >= 70 ? Colors.orange : Colors.red);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: rateColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: rateColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.history,
                  color: rateColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${batch['batchName']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${batch['incubator']} • Completed ${batch['endDate'].day}/${batch['endDate'].month}/${batch['endDate'].year}',
                      style: TextStyle(
                        color: isDarkMode ? const Color(0xFFB0B0B0) : Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${batch['successRate']}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: rateColor,
                    ),
                  ),
                  Text(
                    '${batch['eggsHatched']}/${batch['eggsStarted']} eggs',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDarkMode ? const Color(0xFFB0B0B0) : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
