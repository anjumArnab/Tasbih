// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../widgets/app_snack_bar.dart';
import '../widgets/dhikr_tile.dart';
import '../widgets/animated_circle_button.dart';
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

  static const Color primaryColor = Color(0xFF0F4C75);
  static const Color secondaryColor = Color(0xFF3282B8);
  static const Color accentColor = Color(0xFF00A8CC);
  static const Color backgroundColor = Color(0xFFF8FBFF);

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
      _currentDhikr = widget.selectedDhikr;
      _counter = _currentDhikr?.currentCount ?? 0;
    } else {
      _loadFirstIncompleteDhikr();
    }
  }

  Future<void> _loadFirstIncompleteDhikr() async {
    try {
      // Ensure database is initialized before proceeding
      if (!DbService.isInitialized) {
        await DbService.init();
      }

      final allDhikrs = DbService.getAllDhikr();

      if (allDhikrs.isNotEmpty) {
        final incompleteDhikr = allDhikrs.firstWhere(
          (dhikr) => (dhikr.currentCount ?? 0) < dhikr.times,
          orElse: () => allDhikrs.first,
        );

        setState(() {
          _currentDhikr = incompleteDhikr;
          _counter = incompleteDhikr.currentCount ?? 0;
        });
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          'Failed to load first incomplete dhikr: $e',
        );
      }
    }
  }

  Future<void> _loadNextIncompleteDhikr() async {
    try {
      final allDhikrs = DbService.getAllDhikr();

      if (allDhikrs.isNotEmpty && _currentDhikr != null) {
        final currentIndex = allDhikrs.indexWhere(
          (dhikr) => dhikr.id == _currentDhikr!.id,
        );

        if (currentIndex != -1) {
          Dhikr? nextDhikr;

          for (int i = currentIndex + 1; i < allDhikrs.length; i++) {
            if ((allDhikrs[i].currentCount ?? 0) < allDhikrs[i].times) {
              nextDhikr = allDhikrs[i];
              break;
            }
          }

          if (nextDhikr == null) {
            for (int i = 0; i < currentIndex; i++) {
              if ((allDhikrs[i].currentCount ?? 0) < allDhikrs[i].times) {
                nextDhikr = allDhikrs[i];
                break;
              }
            }
          }

          if (nextDhikr != null) {
            setState(() {
              _currentDhikr = nextDhikr;
              _counter = nextDhikr!.currentCount ?? 0;
            });

            if (mounted) {
              AppSnackbar.showSuccess(
                context,
                'Switched to: ${nextDhikr.dhikrTitle}',
              );
            }
          } else {
            if (mounted) {
              AppSnackbar.showInfo(context, 'All dhikrs completed! Well done!');
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          'Failed to load next incomplete dhikr: $e',
        );
      }
    }
  }

  void _increment() async {
    if (_currentDhikr != null) {
      try {
        // Store the previous count before incrementing
        final previousCount = _currentDhikr!.currentCount ?? 0;

        await DbService.incrementDhikrCount(_currentDhikr!.id!);
        final updatedDhikr = DbService.getDhikrById(_currentDhikr!.id!);
        if (updatedDhikr != null) {
          final newCount = updatedDhikr.currentCount ?? 0;

          setState(() {
            _currentDhikr = updatedDhikr;
            _counter = newCount;
          });

          // Show completion message only when transitioning from incomplete to complete
          // i.e., when previousCount < times and newCount >= times
          if (previousCount < updatedDhikr.times &&
              newCount >= updatedDhikr.times) {
            if (mounted) {
              AppSnackbar.showSuccess(
                context,
                '${updatedDhikr.dhikrTitle} completed! Tap "Next Dhikr" to continue.',
              );
            }
          }
        }
      } catch (e) {
        if (mounted) {
          AppSnackbar.showError(context, 'Failed to update dhikr count: $e');
        }
        return;
      }
    } else {
      setState(() {
        _counter++;
      });
    }

    _incrementController.forward().then((_) {
      _incrementController.reverse();
    });
  }

  void _decrement() async {
    if (_currentDhikr != null && _currentDhikr!.id != null) {
      try {
        await DbService.decrementDhikrCount(_currentDhikr!.id!);
        final updatedDhikr = DbService.getDhikrById(_currentDhikr!.id!);
        if (updatedDhikr != null) {
          setState(() {
            _currentDhikr = updatedDhikr;
            _counter = updatedDhikr.currentCount ?? 0;
          });
        }
      } catch (e) {
        if (mounted) {
          AppSnackbar.showError(context, 'Failed to update dhikr count: $e');
        }
        return;
      }
    } else {
      setState(() {
        if (_counter > 0) _counter--;
      });
    }

    _decrementController.forward().then((_) {
      _decrementController.reverse();
    });
  }

  void _reset() async {
    if (_currentDhikr != null && _currentDhikr!.id != null) {
      try {
        await DbService.resetDhikrCount(_currentDhikr!.id!);
        final updatedDhikr = DbService.getDhikrById(_currentDhikr!.id!);
        if (updatedDhikr != null) {
          setState(() {
            _currentDhikr = updatedDhikr;
            _counter = 0;
          });
        }
      } catch (e) {
        if (mounted) {
          AppSnackbar.showError(context, 'Failed to reset dhikr count: $e');
        }
        return;
      }
    } else {
      setState(() {
        _counter = 0;
      });
    }
  }

  @override
  void dispose() {
    _incrementController.dispose();
    _decrementController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Tasbih',
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
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [accentColor, secondaryColor]),
          borderRadius: BorderRadius.circular(30),
        ),
        child: FloatingActionButton(
          onPressed: _reset,
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.refresh, color: Colors.white, size: 28),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_currentDhikr != null) DhikrTile(dhikr: _currentDhikr!),
            Expanded(
              child: Container(
                color: backgroundColor,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 20.0,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Counter Display
                      Text(
                        '$_counter',
                        style: TextStyle(
                          fontSize: screenHeight < 600 ? 44 : 56,
                          fontWeight: FontWeight.w300,
                          color: primaryColor,
                          height: 1,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      // Buttons Section
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Increment Button
                          AnimatedCircleButton(
                            animation: _incrementScale,
                            onTap: _increment,
                            icon: Icons.keyboard_arrow_up,
                            size: screenWidth < 400 ? 80 : 100,
                            iconSize: screenWidth < 400 ? 40 : 50,
                          ),

                          SizedBox(height: screenHeight < 600 ? 8 : 12),

                          // Decrement Button
                          AnimatedCircleButton(
                            animation: _decrementScale,
                            onTap: _decrement,
                            icon: Icons.keyboard_arrow_down,
                            size: screenHeight < 600 ? 35 : 45,
                            iconSize: screenHeight < 600 ? 18 : 22,
                          ),

                          SizedBox(height: screenHeight < 600 ? 16 : 24),

                          // Next Dhikr Button
                          Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [accentColor, secondaryColor],
                              ),
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: accentColor.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _loadNextIncompleteDhikr,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                elevation: 0,
                                padding: EdgeInsets.symmetric(
                                  horizontal: screenWidth < 400 ? 18 : 20,
                                  vertical: screenHeight < 600 ? 8 : 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.skip_next,
                                    color: Colors.white,
                                    size: screenHeight < 600 ? 16 : 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Next Dhikr',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: screenHeight < 600 ? 13 : 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
