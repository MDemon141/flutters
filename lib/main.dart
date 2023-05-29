import 'package:flutter/material.dart';
import 'package:food_ui/home_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  List ctg = [
    "Foods",
    "Drinks",
    "Snacks",
    "Sauces",
    "Desserts",
  ];
  List Titles = [
    "Veggie tomato mix",
    "Mix Veg Salad",
    "Chickpea Salad",
    "Chilli Salad",
  ];
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeScreen(),
    );
  }
}
