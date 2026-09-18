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
    this.imagePath,
  });

  final String id;
  final String name;
  final ProductCategory category;
  final double price;
  final IconData icon;
  final Color accentColor;
  final String? imagePath;

  String get formattedPrice => '£${price.toStringAsFixed(2)}';
}
