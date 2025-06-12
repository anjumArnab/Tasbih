import 'package:flutter/material.dart';
import '../widgets/animated_circle_button.dart';
import '../screens/dhikrpage.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> with TickerProviderStateMixin {
  int _counter = 0;
  late AnimationController _incrementController;
  late AnimationController _decrementController;
  late Animation<double> _incrementScale;
  late Animation<double> _decrementScale;

  @override
  void initState() {
    super.initState();
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

  void _increment() {
    setState(() {
      _counter++;
    });
    _incrementController.forward().then((_) {
      _incrementController.reverse();
    });
  }

  void _decrement() {
    setState(() {
      if (_counter > 0) _counter--;
    });
    _decrementController.forward().then((_) {
      _decrementController.reverse();
    });
  }

  void _reset() {
    setState(() {
      _counter = 0;
    });
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
        title: const Text(
          'Tasbih',
          style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black87),
        ),
        backgroundColor: backgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => _navToDhikrPage(context),
            icon: const Icon(Icons.arrow_forward_ios),
          ),
          const SizedBox(width: 10),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _reset,
        backgroundColor: Colors.black87,
        shape: const CircleBorder(),
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
      body: SafeArea(
        child: Center(
          // Wrap everything in Center widget
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // Center vertically
            crossAxisAlignment:
                CrossAxisAlignment.center, // Center horizontally
            children: [
              // Counter section
              Text(
                '$_counter',
                style: TextStyle(
                  fontSize: screenWidth < 400 ? 64 : 80,
                  fontWeight: FontWeight.w300,
                  color: Colors.black,
                  height: 1,
                ),
                textAlign: TextAlign.center, // Center the text
              ),

              const SizedBox(height: 60), // Space between counter and buttons
              // Control buttons section
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Main circular increment button
                  AnimatedCircleButton(
                    animation: _incrementScale,
                    onTap: _increment,
                    icon: Icons.keyboard_arrow_up,
                    size: screenWidth < 400 ? 120 : 150,
                    iconSize: screenWidth < 400 ? 60 : 75,
                  ),
                  const SizedBox(height: 15),
                  // Decrement button
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
    );
  }
}
