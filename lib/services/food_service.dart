
import 'dart:convert';

import 'package:flutter/services.dart';

class FoodService {
  Stream<List<Map<String, dynamic>>> getFoods() async* {
    final jsonString = await rootBundle.loadString(
      'assets/data/foods.json',
    );

    final List<dynamic> decodedFoods = jsonDecode(jsonString);

    final foods = decodedFoods.map((food) {
      return Map<String, dynamic>.from(food);
    }).toList();

    yield foods;
  }
}
