import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

enum ExpenseCategory {
  food,
  shopping,
  travel,
  utilities,
  entertainment,
  others,
}

extension ExpenseCategoryExtension on ExpenseCategory {
  String get displayName {
    switch (this) {
      case ExpenseCategory.food:
        return 'Food';
      case ExpenseCategory.shopping:
        return 'Shopping';
      case ExpenseCategory.travel:
        return 'Travel';
      case ExpenseCategory.utilities:
        return 'Utilities';
      case ExpenseCategory.entertainment:
        return 'Entertainment';
      case ExpenseCategory.others:
        return 'Others';
    }
  }

  IconData get icon {
    switch (this) {
      case ExpenseCategory.food:
        return Icons.restaurant;
      case ExpenseCategory.shopping:
        return Icons.shopping_bag;
      case ExpenseCategory.travel:
        return Icons.flight;
      case ExpenseCategory.utilities:
        return Icons.lightbulb;
      case ExpenseCategory.entertainment:
        return Icons.movie;
      case ExpenseCategory.others:
        return Icons.more_horiz;
    }
  }

  Color get color {
    switch (this) {
      case ExpenseCategory.food:
        return const Color(0xFFE53935);
      case ExpenseCategory.shopping:
        return const Color(0xFF1E88E5);
      case ExpenseCategory.travel:
        return const Color(0xFF43A047);
      case ExpenseCategory.utilities:
        return const Color(0xFFFB8C00);
      case ExpenseCategory.entertainment:
        return const Color(0xFF8E24AA);
      case ExpenseCategory.others:
        return const Color(0xFF757575);
    }
  }

  Color get lightColor {
    switch (this) {
      case ExpenseCategory.food:
        return const Color(0xFFFFCDD2);
      case ExpenseCategory.shopping:
        return const Color(0xFFBBDEFB);
      case ExpenseCategory.travel:
        return const Color(0xFFC8E6C9);
      case ExpenseCategory.utilities:
        return const Color(0xFFFFE0B2);
      case ExpenseCategory.entertainment:
        return const Color(0xFFE1BEE7);
      case ExpenseCategory.others:
        return const Color(0xFFEEEEEE);
    }
  }

  String get description {
    switch (this) {
      case ExpenseCategory.food:
        return 'Restaurants, groceries, and food delivery';
      case ExpenseCategory.shopping:
        return 'Clothing, electronics, and retail purchases';
      case ExpenseCategory.travel:
        return 'Flights, hotels, and transportation';
      case ExpenseCategory.utilities:
        return 'Electricity, water, internet, and phone bills';
      case ExpenseCategory.entertainment:
        return 'Movies, games, events, and hobbies';
      case ExpenseCategory.others:
        return 'Miscellaneous expenses not covered elsewhere';
    }
  }

  static ExpenseCategory fromString(String value) {
    final normalizedValue = value.toLowerCase().trim();

    switch (normalizedValue) {
      case 'food':
        return ExpenseCategory.food;
      case 'shopping':
        return ExpenseCategory.shopping;
      case 'travel':
        return ExpenseCategory.travel;
      case 'utilities':
        return ExpenseCategory.utilities;
      case 'entertainment':
        return ExpenseCategory.entertainment;
      case 'others':
      case 'other':
        return ExpenseCategory.others;
      default:
        if (normalizedValue.contains('food') ||
            normalizedValue.contains('restaurant') ||
            normalizedValue.contains('grocer')) {
          return ExpenseCategory.food;
        }
        if (normalizedValue.contains('shop') ||
            normalizedValue.contains('retail') ||
            normalizedValue.contains('cloth')) {
          return ExpenseCategory.shopping;
        }
        if (normalizedValue.contains('travel') ||
            normalizedValue.contains('flight') ||
            normalizedValue.contains('hotel') ||
            normalizedValue.contains('transport')) {
          return ExpenseCategory.travel;
        }
        if (normalizedValue.contains('util') ||
            normalizedValue.contains('bill') ||
            normalizedValue.contains('electric') ||
            normalizedValue.contains('water') ||
            normalizedValue.contains('internet')) {
          return ExpenseCategory.utilities;
        }
        if (normalizedValue.contains('entertain') ||
            normalizedValue.contains('movie') ||
            normalizedValue.contains('game') ||
            normalizedValue.contains('hobby')) {
          return ExpenseCategory.entertainment;
        }

        return ExpenseCategory.others;
    }
  }

  static List<ExpenseCategory> get allValues => ExpenseCategory.values;

  int get index => ExpenseCategory.values.indexOf(this);

  static ExpenseCategory? fromIndex(int index) {
    if (index >= 0 && index < ExpenseCategory.values.length) {
      return ExpenseCategory.values[index];
    }
    return null;
  }

  String get serializeValue => name;
}

class ExpenseCategoryAdapter extends TypeAdapter<ExpenseCategory> {
  @override
  final int typeId = 1;

  @override
  ExpenseCategory read(BinaryReader reader) {
    final index = reader.readByte();
    return ExpenseCategory.values[index];
  }

  @override
  void write(BinaryWriter writer, ExpenseCategory obj) {
    writer.writeByte(obj.index);
  }
}
