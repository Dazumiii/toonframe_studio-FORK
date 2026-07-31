import 'package:flutter/material.dart';
import '../models/animation_project.dart';
import 'editor_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _newProject(BuildContext context) {
    final project = AnimationProject(name: 'Untitled Animation');
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditorScreen(project: project)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.movie_creation, size: 96, color: Colors.orangeAccent),
              const SizedBox(height: 16),
              const Text(
                'ToonFrame Studio',
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '2D Frame-by-Frame Animation',
                style: TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => _newProject(context),
                icon: const Icon(Icons.add),
                label: const Text('New Animation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
