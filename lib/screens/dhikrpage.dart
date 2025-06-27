// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import '../screens/nav_wrapper.dart';
import '../widgets/dhikr_dialog.dart';
import '../widgets/dhikr_tile.dart';
import '../models/dhikr.dart';
import '../services/db_service.dart';

class Dhikrpage extends StatefulWidget {
  const Dhikrpage({super.key});

  @override
  State<Dhikrpage> createState() => _DhikrpageState();
}

class _DhikrpageState extends State<Dhikrpage> {
  List<Dhikr> _allDhikrList = [];
  List<Dhikr> _filteredDhikrList = [];
  bool _isLoading = true;
  String selectedFilter = 'all';

  // Add StreamSubscription to properly manage the listener
  StreamSubscription? _dhikrSubscription;

  // Updated color scheme
  static const Color primaryColor = Color(0xFF0F4C75);
  static const Color secondaryColor = Color(0xFF3282B8);
  static const Color accentColor = Color(0xFF00A8CC);
  static const Color lightAccent = Color(0xFFBBE1FA);
  static const Color backgroundColor = Color(0xFFF8FBFF);

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
  }

  @override
  void dispose() {
    // Cancel the stream subscription to prevent memory leaks
    _dhikrSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeDatabase() async {
    try {
      await DbService.init();
      await _loadDhikrList();

      // Store the subscription so we can cancel it in dispose()
      _dhikrSubscription = DbService.watchDhikr().listen((event) {
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
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadDhikrList() async {
    try {
      // Check if widget is still mounted before calling setState
      if (!mounted) return;

      setState(() {
        _isLoading = true;
      });

      final dhikrList = DbService.getAllDhikr();

      // Check again before the second setState call
      if (!mounted) return;

      setState(() {
        _allDhikrList = dhikrList;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load dhikr: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applyFilters() {
    // Only call setState if widget is still mounted
    if (!mounted) return;

    setState(() {
      switch (selectedFilter) {
        case 'upcoming':
          _filteredDhikrList = DbService.getUpcomingDhikr();
          break;
        case 'completed':
          _filteredDhikrList = DbService.getCompletedDhikr();
          break;
        case 'all':
        default:
          _filteredDhikrList = _allDhikrList;
          break;
      }
    });
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = selectedFilter == value;
    return GestureDetector(
      onTap: () {
        if (!mounted) return;
        setState(() {
          selectedFilter = value;
          _applyFilters();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient:
              isSelected
                  ? const LinearGradient(colors: [primaryColor, secondaryColor])
                  : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.grey[300]!,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _showAddDhikrDialog() {
    showDialog(
      context: context,
      builder: (context) => AddDhikrDialog(onDhikrAdded: _loadDhikrList),
    );
  }

  Future<void> _handleDhikrTap(Dhikr dhikr) async {
    await Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                NavigationWrapper(initialIndex: 0, selectedDhikr: dhikr),
      ),
      (route) => false,
    );
  }

  Future<void> _showDhikrOptions(Dhikr dhikr) async {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: Text(
              dhikr.dhikrTitle,
              style: const TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(dhikr.dhikr),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: lightAccent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Progress: ${dhikr.currentCount ?? 0}/${dhikr.times}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              if ((dhikr.currentCount ?? 0) < dhikr.times)
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [accentColor, secondaryColor],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        await DbService.incrementDhikrCount(dhikr.id!);
                        Navigator.pop(context);
                        await _loadDhikrList();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to update count: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                    ),
                    child: const Text(
                      'Count +1',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [primaryColor, secondaryColor],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _handleDhikrTap(dhikr);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                  ),
                  child: const Text(
                    'Start Counting',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              if (dhikr.id != null)
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            title: const Text(
                              'Delete Dhikr',
                              style: TextStyle(color: Colors.red),
                            ),
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

  String _getEmptyMessage() {
    switch (selectedFilter) {
      case 'upcoming':
        return 'No upcoming dhikr';
      case 'completed':
        return 'No completed dhikr';
      case 'all':
      default:
        return 'No dhikr added yet';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Dhikr',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [primaryColor, secondaryColor],
            ),
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [accentColor, secondaryColor]),
          borderRadius: BorderRadius.circular(30),
        ),
        child: FloatingActionButton(
          onPressed: _showAddDhikrDialog,
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),

                    child: Row(
                      children: [
                        _buildFilterChip('All Dhikr', 'all'),
                        const SizedBox(width: 10),
                        _buildFilterChip('Upcoming', 'upcoming'),
                        const SizedBox(width: 10),
                        _buildFilterChip('Completed', 'completed'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [backgroundColor, Colors.white],
                        ),
                      ),
                      child: _buildDhikrList(
                        _filteredDhikrList,
                        _getEmptyMessage(),
                      ),
                    ),
                  ),
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
            onUpdate: _loadDhikrList, // Refresh the list after update
            onDelete: _loadDhikrList, // Refresh the list after delete
          );
        },
      ),
    );
  }
}
