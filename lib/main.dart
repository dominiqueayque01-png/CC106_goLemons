import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; 
import 'firebase_options.dart'; 
import 'new_entry_sheet.dart';
import 'home_view.dart'; 
import 'calendar_view.dart';
import 'insights_view.dart';
import 'profile_view.dart';
import 'login_view.dart';
import 'package:firebase_storage/firebase_storage.dart';


void main() async {
  // 🍋 FIX: Ensure Flutter is initialized BEFORE Firebase and runApp!
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const GoLemonsApp());
}

// 1. The Root of your Application
class GoLemonsApp extends StatelessWidget {
  const GoLemonsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'goLemons',
      theme: ThemeData(
        primaryColor: Colors.yellow[700],
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.yellow),
      ),
      home: const LoginView(), 
    );
  }
}

// 2. The Main Navigation Controller
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  
  // 🍋 CAROUSEL UPGRADE: We create a controller to drive the sliding animation
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    // Initialize the controller to start on the correct tab
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    // Clean up memory when the app is closed
    _pageController.dispose();
    super.dispose();
  }

  // 🍋 Handles the smooth slide when a bottom tab is tapped
  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300), 
      curve: Curves.easeInOutCubic, 
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 🍋 CAROUSEL UPGRADE: The PageView replaces the static screen list
      body: PageView(
        controller: _pageController,
        // Prevents the user from swiping with their finger (forces them to use the bottom buttons)
        physics: const NeverScrollableScrollPhysics(), 
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: const [
          HomeView(), 
          CalendarView(),
          InsightsView(),
          ProfileView(),
        ],
      ),
      
      // 4. The "Squeeze" Button (Floating Action Button) - Untouched!
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color.fromRGBO(253, 216, 53, 1),
        shape: const CircleBorder(), 
        onPressed: () async {
          final didSave = await showModalBottomSheet(
            context: context,
            isScrollControlled: true, 
            backgroundColor: Colors.transparent, 
            builder: (context) => const NewEntrySheet(),
          );

          if (didSave == true) {
            setState(() {}); 
          }
        },
        child: const Icon(Icons.add, color: Color.fromARGB(255, 107, 96, 18), size: 32),
      ),
      
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      
      // 5. The Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped, // 🍋 Connected to our new animation function!
        type: BottomNavigationBarType.fixed, 
        selectedItemColor: Colors.yellow[800],
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month_outlined), label: 'Calendar'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), label: 'Insights'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}