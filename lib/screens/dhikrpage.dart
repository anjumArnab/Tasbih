import 'package:flutter/material.dart';
import '../widgets/dhikr_dialog.dart';
import '../widgets/dhikr_tile.dart';
import '../models/dhikr.dart';
import '../services/db_service.dart';
import '../screens/homepage.dart';

class Dhikrpage extends StatefulWidget {
  const Dhikrpage({super.key});

  @override
  State<Dhikrpage> createState() => _DhikrpageState();
}

class _DhikrpageState extends State<Dhikrpage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Dhikr> _allDhikrList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeDatabase();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeDatabase() async {
    try {
      await DbService.init();
      await _loadDhikrList();

      // Listen to database changes
      DbService.watchDhikr().listen((event) {
        if (mounted) {
          _loadDhikrList();
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize database: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      // Initialize with mock data if database fails
      _generateMockData();
    }
  }

  Future<void> _loadDhikrList() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final dhikrList = DbService.getAllDhikr();

      setState(() {
        _allDhikrList = dhikrList;
        _isLoading = false;
      });

      // If no data exists, add some mock data
      if (_allDhikrList.isEmpty) {
        await _addMockData();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load dhikr: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addMockData() async {
    try {
      final now = DateTime.now();
      final mockDhikrList = [
        Dhikr(
          dhikrTitle: 'Subhan Allah',
          dhikr: 'سُبْحَانَ اللهِ - Glory be to Allah',
          times: 33,
          when: now.subtract(const Duration(hours: 2)),
          currentCount: 15,
        ),
        Dhikr(
          dhikrTitle: 'Alhamdulillah',
          dhikr: 'الْحَمْدُ لِلَّهِ - All praise is due to Allah',
          times: 33,
          when: now.subtract(const Duration(hours: 1)),
          currentCount: 33,
        ),
        Dhikr(
          dhikrTitle: 'Allahu Akbar',
          dhikr: 'اللهُ أَكْبَرُ - Allah is the Greatest',
          times: 34,
          when: now.subtract(const Duration(minutes: 30)),
          currentCount: 0,
        ),
      ];

      for (final dhikr in mockDhikrList) {
        await DbService.addDhikr(dhikr);
      }

      await _loadDhikrList();
    } catch (e) {
      debugPrint('Failed to add mock data: $e');
    }
  }

  void _generateMockData() {
    final now = DateTime.now();
    _allDhikrList = [
      Dhikr(
        id: 1,
        dhikrTitle: 'Subhan Allah',
        dhikr: 'سُبْحَانَ اللهِ - Glory be to Allah',
        times: 33,
        when: now.subtract(const Duration(hours: 2)),
        currentCount: 15,
      ),
      Dhikr(
        id: 2,
        dhikrTitle: 'Alhamdulillah',
        dhikr: 'الْحَمْدُ لِلَّهِ - All praise is due to Allah',
        times: 33,
        when: now.subtract(const Duration(hours: 1)),
        currentCount: 33,
      ),
      Dhikr(
        id: 3,
        dhikrTitle: 'Allahu Akbar',
        dhikr: 'اللهُ أَكْبَرُ - Allah is the Greatest',
        times: 34,
        when: now.subtract(const Duration(minutes: 30)),
        currentCount: 0,
      ),
    ];
    setState(() {
      _isLoading = false;
    });
  }

  List<Dhikr> get _upcomingDhikr {
    return DbService.getUpcomingDhikr();
  }

  List<Dhikr> get _completedDhikr {
    return DbService.getCompletedDhikr();
  }

  void _showAddDhikrDialog() {
    showDialog(
      context: context,
      builder: (context) => AddDhikrDialog(onDhikrAdded: _loadDhikrList),
    );
  }

  // Modified to navigate to Homepage with selected dhikr
  Future<void> _handleDhikrTap(Dhikr dhikr) async {
    // Navigate to Homepage with the selected dhikr
    final result = await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => Homepage(selectedDhikr: dhikr)),
    );
  }

  // Keep the original functionality for long press or show options
  Future<void> _showDhikrOptions(Dhikr dhikr) async {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(dhikr.dhikrTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(dhikr.dhikr),
                const SizedBox(height: 16),
                Text('Progress: ${dhikr.currentCount ?? 0}/${dhikr.times}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              if ((dhikr.currentCount ?? 0) < dhikr.times)
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await DbService.incrementDhikrCount(dhikr.id!);
                      Navigator.pop(context);
                      await _loadDhikrList();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to update count: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: const Text('Count +1'),
                ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _handleDhikrTap(dhikr);
                },
                child: const Text('Start Counting'),
              ),
              if (dhikr.id != null)
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: const Text('Delete Dhikr'),
                            content: const Text(
                              'Are you sure you want to delete this dhikr?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                    );

                    if (confirm == true) {
                      try {
                        await DbService.deleteDhikr(dhikr.id!);
                        await _loadDhikrList();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Dhikr deleted successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to delete dhikr: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  },
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = Colors.grey[50];
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Dhikr',
          style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black87),
        ),
        backgroundColor: backgroundColor,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black87,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Colors.black87,
          indicatorWeight: 2.0,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'All Dhikr'),
            Tab(text: 'Upcoming'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        shape: const CircleBorder(),
        onPressed: _showAddDhikrDialog,
        backgroundColor: Colors.black87,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                controller: _tabController,
                children: [
                  // All Dhikr Tab
                  _buildDhikrList(_allDhikrList, 'No dhikr added yet'),

                  // Upcoming Tab
                  _buildDhikrList(_upcomingDhikr, 'No upcoming dhikr'),

                  // Completed Tab
                  _buildDhikrList(_completedDhikr, 'No completed dhikr'),
                ],
              ),
    );
  }

  Widget _buildDhikrList(List<Dhikr> dhikrList, String emptyMessage) {
    if (dhikrList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome, size: 50, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                emptyMessage,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the + button to add your first dhikr',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDhikrList,
      child: ListView.separated(
        padding: const EdgeInsets.all(8.0),
        itemCount: dhikrList.length,
        separatorBuilder: (context, index) => const SizedBox(height: 5),
        itemBuilder: (context, index) {
          final dhikr = dhikrList[index];
          return DhikrTile(
            dhikr: dhikr,
            onTap: () => _handleDhikrTap(dhikr),
            onLongPress: () => _showDhikrOptions(dhikr),
          );
        },
      ),
    );
  }
}
