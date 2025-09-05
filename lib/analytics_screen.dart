import 'package:flutter/material.dart';
import 'profile_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  final String userName;
  final ValueNotifier<ThemeMode> themeNotifier;
  final Map<String, Map<String, dynamic>> incubatorData;

  const AnalyticsScreen({
    super.key,
    required this.userName,
    required this.themeNotifier,
    required this.incubatorData,
  });

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  
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
            // Hatch Rate Statistics Section
            Text(
              'Hatch Rate Statistics',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Overall Success Rate',
                    '${_calculateOverallHatchRate()}%',
                    Icons.trending_up,
                    Colors.green,
                    isDarkMode,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Total Batches',
                    _getTotalCompletedBatches().toString(),
                    Icons.egg,
                    Colors.blue,
                    isDarkMode,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Candling Schedule Section
            Text(
              'Candling Schedule',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            _buildCandlingCard(isDarkMode),
            
            const SizedBox(height: 24),
            
            // Active Batches Section
            Text(
              'Active Batches',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            ...widget.incubatorData.entries.map((entry) => 
              _buildActiveBatchCard(entry.key, entry.value, isDarkMode)
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
            
            _buildBatchHistorySection(isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, bool isDarkMode) {
    return Card(
      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? const Color(0xFFB0B0B0) : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCandlingCard(bool isDarkMode) {
    final String nextDate = _getNextCandlingDate();
    
    return Card(
      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              Icons.visibility,
              color: Colors.orange,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next Candling Due',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    nextDate,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: isDarkMode ? const Color(0xFFB0B0B0) : Colors.grey[400],
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveBatchCard(String incubatorName, Map<String, dynamic> data, bool isDarkMode) {
    final String batchName = data['batchName'] ?? 'Unknown Batch';
    final int startDateMs = data['startDate'] ?? DateTime.now().millisecondsSinceEpoch;
    final int incubationDays = data['incubationDays'] ?? 21;
    
    final DateTime startDate = DateTime.fromMillisecondsSinceEpoch(startDateMs);
    final DateTime now = DateTime.now();
    final int daysElapsed = now.difference(startDate).inDays;
    final int daysRemaining = (incubationDays - daysElapsed).clamp(0, incubationDays);
    
    Color statusColor = daysRemaining <= 3 
        ? Colors.orange 
        : (isDarkMode ? const Color(0xFF6BB6FF) : Colors.blue);
    
    return Card(
      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(Icons.egg, color: statusColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$batchName ($incubatorName)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Day $daysElapsed of $incubationDays',
                    style: TextStyle(
                      color: isDarkMode ? const Color(0xFFB0B0B0) : Colors.grey[600],
                      fontSize: 12,
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
                daysRemaining > 0 ? '$daysRemaining days left' : 'Ready!',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchHistorySection(bool isDarkMode) {
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
        return Card(
          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Icon(
                  Icons.history,
                  color: batch['successRate'] >= 85 
                      ? Colors.green 
                      : (batch['successRate'] >= 70 ? Colors.orange : Colors.red),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${batch['batchName']} (${batch['incubator']})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Completed ${batch['endDate'].day}/${batch['endDate'].month}/${batch['endDate'].year}',
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
                        color: batch['successRate'] >= 85 
                            ? Colors.green 
                            : (batch['successRate'] >= 70 ? Colors.orange : Colors.red),
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
          ),
        );
      }).toList(),
    );
  }
}
