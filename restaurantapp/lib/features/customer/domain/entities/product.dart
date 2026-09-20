import 'package:flutter/material.dart';

enum ProductCategory { burritos, tacos, bowls, sides, drinks }

extension ProductCategoryX on ProductCategory {
  String get label {
    switch (this) {
      case ProductCategory.burritos:
        return 'Burritos';
      case ProductCategory.tacos:
        return 'Tacos';
      case ProductCategory.bowls:
        return 'Bowls';
      case ProductCategory.sides:
        return 'Sides';
      case ProductCategory.drinks:
        return 'Drinks';
    }
  }

  IconData get icon {
    switch (this) {
      case ProductCategory.burritos:
        return Icons.lunch_dining;
      case ProductCategory.tacos:
        return Icons.local_pizza;
      case ProductCategory.bowls:
        return Icons.rice_bowl;
      case ProductCategory.sides:
        return Icons.fastfood;
      case ProductCategory.drinks:
        return Icons.local_drink;
    }
  }
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.icon,
    required this.accentColor,
    this.isAvailable = true,
    this.imagePath,
    this.description,
    this.ingredients,
    this.allergens,
  });

  final String id;
  final String name;
  final ProductCategory category;
  final double price;
  final IconData icon;
  final Color accentColor;
  final String? imagePath;
  final String? description;
  final List<String>? ingredients;
  final List<String>? allergens;
  final bool isAvailable;


  String get formattedPrice => '£${price.toStringAsFixed(2)}';

  Product copyWith({bool? isAvailable, String? imagePath}) => Product(
    id: id,
    name: name,
    category: category,
    price: price,
    icon: icon,
    accentColor: accentColor,
    isAvailable: isAvailable ?? this.isAvailable,
    imagePath: imagePath ?? this.imagePath,
    description: description,
    ingredients: ingredients,
    allergens: allergens,
  );
}
