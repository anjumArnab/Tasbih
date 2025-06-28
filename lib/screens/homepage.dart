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
      await DbService.init();
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
      AppSnackbar.showError(
        context,
        'Failed to load first incomplete dhikr: $e',
      );
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
      AppSnackbar.showError(
        context,
        'Failed to load next incomplete dhikr: $e',
      );
    }
  }

  @override
  void dispose() {
    _incrementController.dispose();
    _decrementController.dispose();
    super.dispose();
  }

  void _increment() async {
    if (_currentDhikr != null) {
      try {
        await DbService.incrementDhikrCount(_currentDhikr!.id!);
        final updatedDhikr = DbService.getDhikrById(_currentDhikr!.id!);
        if (updatedDhikr != null) {
          setState(() {
            _currentDhikr = updatedDhikr;
            _counter = updatedDhikr.currentCount ?? 0;
          });

          // Removed automatic switching - now only manual via button
          if ((updatedDhikr.currentCount ?? 0) >= updatedDhikr.times) {
            if (mounted) {
              AppSnackbar.showSuccess(
                context,
                '${updatedDhikr.dhikrTitle} completed! Tap "Next Dhikr" to continue.',
              );
            }
          }
        }
      } catch (e) {
        AppSnackbar.showError(context, 'Failed to update dhikr count: $e');
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
        AppSnackbar.showError(context, 'Failed to update dhikr count: $e');
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
        AppSnackbar.showError(context, 'Failed to reset dhikr count: $e');
        return;
      }
    } else {
      setState(() {
        _counter = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

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
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [backgroundColor, Colors.white],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '$_counter',
                        style: TextStyle(
                          fontSize: 60,
                          fontWeight: FontWeight.w300,
                          color: primaryColor,
                          height: 1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),
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
                          const SizedBox(height: 30),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(
                                    Icons.skip_next,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Next Dhikr',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
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
