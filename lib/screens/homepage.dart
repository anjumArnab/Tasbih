import 'package:flutter/material.dart';
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
    _currentDhikr = widget.selectedDhikr;
    _counter = _currentDhikr?.currentCount ?? 0;

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

  @override
  void dispose() {
    _incrementController.dispose();
    _decrementController.dispose();
    super.dispose();
  }

  void _increment() async {
    setState(() {
      _counter++;
    });

    // Update the dhikr in database if we have a selected dhikr
    if (_currentDhikr != null) {
      try {
        await DbService.incrementDhikrCount(_currentDhikr!.id!);
        // Update the current dhikr object
        _currentDhikr = _currentDhikr!.copyWith(currentCount: _counter);
      } catch (e) {
        // Handle error silently or show snackbar
        debugPrint('Failed to update dhikr count: $e');
      }
    }

    _incrementController.forward().then((_) {
      _incrementController.reverse();
    });
  }

  void _decrement() async {
    setState(() {
      if (_counter > 0) _counter--;
    });

    // Update the dhikr in database if we have a selected dhikr
    if (_currentDhikr != null && _currentDhikr!.id != null) {
      try {
        await DbService.decrementDhikrCount(_currentDhikr!.id!);
        // Update the current dhikr object
        _currentDhikr = _currentDhikr!.copyWith(currentCount: _counter);
      } catch (e) {
        // Handle error silently or show snackbar
        debugPrint('Failed to update dhikr count: $e');
      }
    }

    _decrementController.forward().then((_) {
      _decrementController.reverse();
    });
  }

  void _reset() async {
    setState(() {
      _counter = 0;
    });

    // Reset the dhikr in database if we have a selected dhikr
    if (_currentDhikr != null && _currentDhikr!.id != null) {
      try {
        await DbService.resetDhikrCount(_currentDhikr!.id!);
        // Update the current dhikr object
        _currentDhikr = _currentDhikr!.copyWith(currentCount: 0);
      } catch (e) {
        // Handle error silently or show snackbar
        debugPrint('Failed to reset dhikr count: $e');
      }
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
    final backgroundColor = Colors.grey[50];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          _currentDhikr != null ? _currentDhikr!.dhikrTitle : 'Tasbih',
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
            if (_currentDhikr != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentDhikr!.dhikr,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Progress',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$_counter / ${_currentDhikr!.times}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(
                            value: _counter / _currentDhikr!.times,
                            strokeWidth: 4,
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _counter >= _currentDhikr!.times
                                  ? Colors.green
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

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
