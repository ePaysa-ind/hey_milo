// File: lib/models/medication_model.dart
// Purpose: Both DB-compatible and UI-focused medication models
// Author: Milo App Development Team
// Last Updated: May 5, 2025

//import 'package:flutter/material.dart';

/// -------------------------------------------
/// DATABASE-COMPATIBLE MODEL (used in services)
/// -------------------------------------------
class Medication {
  final String id;
  final String name;
  final String dosage;
  final String? instructions;
  final int frequency;
  final List<String> daysOfWeek;
  final String? color;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Medication({
    required this.id,
    required this.name,
    required this.dosage,
    this.instructions,
    this.frequency = 1,
    required this.daysOfWeek,
    this.color,
    this.notes,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Medication.fromJson(Map<String, dynamic> json) {
    return Medication(
      id: json['id'],
      name: json['name'],
      dosage: json['dosage'],
      instructions: json['instructions'],
      frequency: json['frequency'] ?? 1,
      daysOfWeek: (json['days_of_week'] as String).split(','),
      color: json['color'],
      notes: json['notes'],
      isActive: json['is_active'] == 1,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'dosage': dosage,
      'instructions': instructions,
      'frequency': frequency,
      'days_of_week': daysOfWeek.join(','),
      'color': color,
      'notes': notes,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Medication copyWith({
    String? name,
    String? dosage,
    String? instructions,
    int? frequency,
    List<String>? daysOfWeek,
    String? color,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Medication(
      id: id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      instructions: instructions ?? this.instructions,
      frequency: frequency ?? this.frequency,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      color: color ?? this.color,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// ✅ Add this helper for service-layer updates
  Medication copyWithTimestamps({
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Medication(
      id: id,
      name: name,
      dosage: dosage,
      instructions: instructions,
      frequency: frequency,
      daysOfWeek: daysOfWeek,
      color: color,
      notes: notes,
      isActive: isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Medication && id == other.id);

  @override
  int get hashCode => id.hashCode;
}
