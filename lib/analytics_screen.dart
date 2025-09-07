import 'package:flutter/material.dart';
import 'profile_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  final String userName;
  final ValueNotifier<ThemeMode> themeNotifier;
  final Map<String, Map<String, dynamic>> incubatorData;
  final List<Map<String, dynamic>> batchHistory;
  final Function(String)? onNavigateToDashboard;
  final Function(Map<String, Map<String, dynamic>>)? onCandlingScheduled;
  final Function(int)? onDeleteBatch;
  final VoidCallback? onBatchHistoryChanged;

  const AnalyticsScreen({
    super.key,
    required this.userName,
    required this.themeNotifier,
    required this.incubatorData,
    this.batchHistory = const [],
    this.onNavigateToDashboard,
    this.onCandlingScheduled,
    this.onDeleteBatch,
    this.onBatchHistoryChanged,
  });

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  
  // Track scheduled candling for each incubator
  Map<String, Map<String, dynamic>> scheduledCandling = {};
  
  // Local copy of batch history for reactive updates
  late List<Map<String, dynamic>> localBatchHistory;
  
  @override
  void initState() {
    super.initState();
    localBatchHistory = List.from(widget.batchHistory);
  }
  
  @override
  void didUpdateWidget(AnalyticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.batchHistory != widget.batchHistory) {
      setState(() {
        localBatchHistory = List.from(widget.batchHistory);
      });
      debugPrint('AnalyticsScreen batch history updated: ${localBatchHistory.length} batches');
    }
  }
  
  // Calculate overall hatch rate from completed batches
  double _calculateOverallHatchRate() {
    if (localBatchHistory.isEmpty) return 0.0;
    
    double totalSuccessRate = 0.0;
    int completedBatches = 0;
    
    for (var batch in localBatchHistory) {
      if (batch['hatchedCount'] != null && batch['eggCount'] != null) {
        final double successRate = (batch['hatchedCount'] / batch['eggCount']) * 100;
        totalSuccessRate += successRate;
        completedBatches++;
      }
    }
    
    return completedBatches > 0 ? totalSuccessRate / completedBatches : 0.0;
  }

  int _getTotalCompletedBatches() {
    return localBatchHistory.length;
  }

  String _getNextCandlingDate() {
    DateTime? nextCandling;
    
    widget.incubatorData.forEach((name, data) {
      final int startDateMs = data['startDate'] ?? DateTime.now().millisecondsSinceEpoch;
      final DateTime startDate = DateTime.fromMillisecondsSinceEpoch(startDateMs);
      
      final List<int> candlingDays = [7, 14, 18];
      final DateTime now = DateTime.now();
      final int daysElapsed = now.difference(startDate).inDays;
      
      // Get candling status from data
      final Map<String, dynamic> candlingDates = data['candlingDates'] ?? {};
      
      for (int day in candlingDays) {
        // Check if this candling day hasn't been completed yet
        final bool candlingDone = candlingDates['$day'] == true;
        
        if (daysElapsed < day && !candlingDone) {
          final DateTime candlingDate = startDate.add(Duration(days: day));
          if (nextCandling == null || candlingDate.isBefore(nextCandling!)) {
            nextCandling = candlingDate;
          }
          break;
        } else if (daysElapsed >= day && !candlingDone) {
          // This candling is overdue
          final DateTime candlingDate = startDate.add(Duration(days: day));
          if (nextCandling == null || candlingDate.isBefore(nextCandling!)) {
            nextCandling = candlingDate;
          }
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
    Navigator.of(context).pop();

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

    _showDatePicker(incubatorName, batchName, nextCandlingDay);
  }

  void _showDatePicker(String incubatorName, String batchName, int candlingDay) {
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

    setState(() {
      scheduledCandling[scheduleKey] = {
        'incubatorName': incubatorName,
        'batchName': batchName,
        'candlingDay': candlingDay,
        'scheduledDate': selectedDate,
        'dateScheduled': DateTime.now(),
      };
    });

    if (widget.onCandlingScheduled != null) {
      widget.onCandlingScheduled!(Map.from(scheduledCandling));
    }

    // Success confirmation
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

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
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
        automaticallyImplyLeading: false, 
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade400, Colors.green.shade300],
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
            
            Row(
              children: [
                Text(
                  'Candling Schedule',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  'Tap to schedule',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? const Color(0xFFB0B0B0) : Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            _buildCandlingTimeline(isDarkMode),
            
            const SizedBox(height: 24),
            
            // Active Batches Section
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
    if (localBatchHistory.isEmpty) {
      return SizedBox(
        width: double.infinity,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDarkMode ? const Color(0xFF333333) : Colors.grey[300]!,
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.history,
                size: 48,
                color: isDarkMode ? const Color(0xFF666666) : Colors.grey[400],
              ),
              const SizedBox(height: 12),
              Text(
                'No Batch History Yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? const Color(0xFF888888) : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Complete your first batch to see history here',
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? const Color(0xFF666666) : Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: localBatchHistory.map((batch) {
        final int eggsStarted = batch['eggCount'] ?? 0;
        final int eggsHatched = batch['hatchedCount'] ?? 0;
        final double successRate = eggsStarted > 0 ? (eggsHatched / eggsStarted) * 100 : 0.0;
        
        Color rateColor = successRate >= 85 
            ? Colors.green 
            : (successRate >= 70 ? Colors.orange : Colors.red);

        final DateTime? startDate = batch['startDate'] != null 
            ? DateTime.fromMillisecondsSinceEpoch(batch['startDate']) 
            : null;
        final DateTime? endDate = batch['completedDate'] != null 
            ? DateTime.fromMillisecondsSinceEpoch(batch['completedDate']) 
            : null;

        final String completionReason = batch['completionReason'] ?? 'Completed';
        final IconData reasonIcon = completionReason == 'Completed' 
            ? Icons.check_circle
            : completionReason == 'Replaced'
            ? Icons.swap_horiz
            : Icons.stop_circle;

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
                  reasonIcon,
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
                      batch['batchName'] ?? 'Unnamed Batch',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${batch['incubatorName'] ?? 'Unknown Incubator'} • $completionReason ${endDate != null ? '${endDate.day}/${endDate.month}/${endDate.year}' : 'Unknown Date'}',
                      style: TextStyle(
                        color: isDarkMode ? const Color(0xFFB0B0B0) : Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    if (startDate != null && endDate != null)
                      Text(
                        'Duration: ${endDate.difference(startDate).inDays} days',
                        style: TextStyle(
                          color: isDarkMode ? const Color(0xFF888888) : Colors.grey[500],
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${successRate.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: rateColor,
                    ),
                  ),
                  Text(
                    '$eggsHatched/$eggsStarted eggs',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDarkMode ? const Color(0xFFB0B0B0) : Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  size: 20,
                  color: isDarkMode ? const Color(0xFFB0B0B0) : Colors.grey[600],
                ),
                onSelected: (value) {
                  if (value == 'delete') {
                    _showDeleteBatchConfirmation(batch);
                  }
                },
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: const [
                        Icon(Icons.delete, color: Colors.red, size: 18),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
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

  void _showDeleteBatchConfirmation(Map<String, dynamic> batch) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Batch History'),
          content: Text(
            'Are you sure you want to delete "${batch['batchName'] ?? 'Unnamed Batch'}" from your batch history? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                int index = -1;
                for (int i = 0; i < localBatchHistory.length; i++) {
                  final historyBatch = localBatchHistory[i];
                  if (historyBatch['batchName'] == batch['batchName'] &&
                      historyBatch['startDate'] == batch['startDate'] &&
                      historyBatch['completedDate'] == batch['completedDate']) {
                    index = i;
                    break;
                  }
                }
                
                if (index != -1) {
                  debugPrint('Deleting batch at index $index: ${batch['batchName']}');
                  
                  widget.onDeleteBatch?.call(index);
                  
                  setState(() {
                    localBatchHistory.removeAt(index);
                  });
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Batch deleted from history'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                } else {
                  debugPrint('Batch not found for deletion: ${batch['batchName']}');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Error: Batch not found'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
