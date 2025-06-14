import 'package:flutter/material.dart';
import '../widgets/dhikr_tile.dart';
import '../widgets/animated_circle_button.dart';
import '../screens/dhikrpage.dart';
import '../models/dhikr.dart';
import '../services/db_service.dart';

class Homepage extends StatefulWidget {
  final Dhikr? selectedDhikr;

  const Homepage({super.key, this.selectedDhikr});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> with TickerProviderStateMixin {
  int _counter = 0;
  Dhikr? _currentDhikr;
  late AnimationController _incrementController;
  late AnimationController _decrementController;
  late Animation<double> _incrementScale;
  late Animation<double> _decrementScale;

  @override
  void initState() {
    super.initState();
    _initializeDhikr();

    _incrementController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _decrementController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _incrementScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _incrementController, curve: Curves.easeInOut),
    );
    _decrementScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _decrementController, curve: Curves.easeInOut),
    );
  }

  void _initializeDhikr() {
    if (widget.selectedDhikr != null) {
      // If a specific dhikr was selected, use it
      _currentDhikr = widget.selectedDhikr;
      _counter = _currentDhikr?.currentCount ?? 0;
    } else {
      // Auto-start with first incomplete dhikr
      _loadFirstIncompleteDhikr();
    }
  }

  Future<void> _loadFirstIncompleteDhikr() async {
    try {
      // Initialize database if not already done
      await DbService.init();

      // Get all dhikrs and find the first incomplete one
      final allDhikrs = DbService.getAllDhikr();

      if (allDhikrs.isNotEmpty) {
        // Find first incomplete dhikr
        final incompleteDhikr = allDhikrs.firstWhere(
          (dhikr) => (dhikr.currentCount ?? 0) < dhikr.times,
          orElse:
              () =>
                  allDhikrs
                      .first, // Fallback to first dhikr if all are complete
        );

        setState(() {
          _currentDhikr = incompleteDhikr;
          _counter = incompleteDhikr.currentCount ?? 0;
        });
      }
    } catch (e) {
      debugPrint('Failed to load first incomplete dhikr: $e');
    }
  }

  Future<void> _loadNextIncompleteDhikr() async {
    try {
      final allDhikrs = DbService.getAllDhikr();

      if (allDhikrs.isNotEmpty && _currentDhikr != null) {
        // Find current dhikr index
        final currentIndex = allDhikrs.indexWhere(
          (dhikr) => dhikr.id == _currentDhikr!.id,
        );

        if (currentIndex != -1) {
          // Look for next incomplete dhikr starting from the next index
          Dhikr? nextDhikr;

          // First, check dhikrs after the current one
          for (int i = currentIndex + 1; i < allDhikrs.length; i++) {
            if ((allDhikrs[i].currentCount ?? 0) < allDhikrs[i].times) {
              nextDhikr = allDhikrs[i];
              break;
            }
          }

          // If no incomplete dhikr found after current, check from beginning
          if (nextDhikr == null) {
            for (int i = 0; i < currentIndex; i++) {
              if ((allDhikrs[i].currentCount ?? 0) < allDhikrs[i].times) {
                nextDhikr = allDhikrs[i];
                break;
              }
            }
          }

          // If we found a next incomplete dhikr, switch to it
          if (nextDhikr != null) {
            setState(() {
              _currentDhikr = nextDhikr;
              _counter = nextDhikr!.currentCount ?? 0;
            });

            // Show a brief message about switching to next dhikr
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Switched to: ${nextDhikr.dhikrTitle}'),
                  duration: const Duration(seconds: 2),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } else {
            // All dhikrs are complete
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All dhikrs completed! Well done!'),
                  duration: Duration(seconds: 3),
                  backgroundColor: Colors.blue,
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to load next incomplete dhikr: $e');
    }
  }

  @override
  void dispose() {
    _incrementController.dispose();
    _decrementController.dispose();
    super.dispose();
  }

  void _increment() async {
    // Update the dhikr in database first if we have a selected dhikr
    if (_currentDhikr != null) {
      try {
        await DbService.incrementDhikrCount(_currentDhikr!.id!);
        // Get the updated dhikr from database to ensure sync
        final updatedDhikr = DbService.getDhikrById(_currentDhikr!.id!);
        if (updatedDhikr != null) {
          setState(() {
            _currentDhikr = updatedDhikr;
            _counter = updatedDhikr.currentCount ?? 0;
          });

          // Check if dhikr is now complete and auto-progress
          if ((updatedDhikr.currentCount ?? 0) >= updatedDhikr.times) {
            // Wait a moment to show completion, then move to next
            Future.delayed(const Duration(milliseconds: 500), () {
              _loadNextIncompleteDhikr();
            });
          }
        }
      } catch (e) {
        debugPrint('Failed to update dhikr count: $e');
        return; // Don't update UI if database update failed
      }
    } else {
      // If no dhikr selected, just update local counter
      setState(() {
        _counter++;
      });
    }

    _incrementController.forward().then((_) {
      _incrementController.reverse();
    });
  }

  void _decrement() async {
    // Update the dhikr in database first if we have a selected dhikr
    if (_currentDhikr != null && _currentDhikr!.id != null) {
      try {
        await DbService.decrementDhikrCount(_currentDhikr!.id!);
        // Get the updated dhikr from database to ensure sync
        final updatedDhikr = DbService.getDhikrById(_currentDhikr!.id!);
        if (updatedDhikr != null) {
          setState(() {
            _currentDhikr = updatedDhikr;
            _counter = updatedDhikr.currentCount ?? 0;
          });
        }
      } catch (e) {
        debugPrint('Failed to update dhikr count: $e');
        return; // Don't update UI if database update failed
      }
    } else {
      // If no dhikr selected, just update local counter
      setState(() {
        if (_counter > 0) _counter--;
      });
    }

    _decrementController.forward().then((_) {
      _decrementController.reverse();
    });
  }

  void _reset() async {
    // Reset the dhikr in database first if we have a selected dhikr
    if (_currentDhikr != null && _currentDhikr!.id != null) {
      try {
        await DbService.resetDhikrCount(_currentDhikr!.id!);
        // Get the updated dhikr from database to ensure sync
        final updatedDhikr = DbService.getDhikrById(_currentDhikr!.id!);
        if (updatedDhikr != null) {
          setState(() {
            _currentDhikr = updatedDhikr;
            _counter = 0;
          });
        }
      } catch (e) {
        debugPrint('Failed to reset dhikr count: $e');
        return; // Don't update UI if database update failed
      }
    } else {
      // If no dhikr selected, just reset local counter
      setState(() {
        _counter = 0;
      });
    }
  }

  void _navToDhikrPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Dhikrpage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final backgroundColor = Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Tasbih',
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        backgroundColor: backgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => _navToDhikrPage(context),
            icon: const Icon(Icons.arrow_forward_ios),
          ),
          const SizedBox(width: 15),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _reset,
        backgroundColor: Colors.black87,
        shape: const CircleBorder(),
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Dhikr info section (if a dhikr is selected)
            if (_currentDhikr != null) DhikrTile(dhikr: _currentDhikr!),
            // Counter section
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '$_counter',
                      style: const TextStyle(
                        fontSize: 60,
                        fontWeight: FontWeight.w300,
                        color: Colors.black,
                        height: 1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 60),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        AnimatedCircleButton(
                          animation: _incrementScale,
                          onTap: _increment,
                          icon: Icons.keyboard_arrow_up,
                          size: screenWidth < 400 ? 120 : 150,
                          iconSize: screenWidth < 400 ? 60 : 75,
                        ),
                        const SizedBox(height: 15),
                        AnimatedCircleButton(
                          animation: _decrementScale,
                          onTap: _decrement,
                          icon: Icons.keyboard_arrow_down,
                          size: 50,
                          iconSize: 25,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Extension to add copyWith method to Dhikr model
extension DhikrExtension on Dhikr {
  Dhikr copyWith({
    int? id,
    String? dhikrTitle,
    String? dhikr,
    int? times,
    DateTime? when,
    int? currentCount,
  }) {
    return Dhikr(
      id: id ?? this.id,
      dhikrTitle: dhikrTitle ?? this.dhikrTitle,
      dhikr: dhikr ?? this.dhikr,
      times: times ?? this.times,
      when: when ?? this.when,
      currentCount: currentCount ?? this.currentCount,
    );
  }
}
