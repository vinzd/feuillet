import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import '../models/database.dart';
import 'database_service.dart';

/// Types of annotations
enum AnnotationType {
  pen,
  highlighter,
  eraser,
  text;

  @override
  String toString() => name;
}

/// Represents a drawing stroke
class DrawingStroke {
  final List<Offset> points;
  final Color color;
  final double thickness;
  final AnnotationType type;

  DrawingStroke({
    required this.points,
    required this.color,
    required this.thickness,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
        'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
        'color': color.toARGB32(),
        'thickness': thickness,
        'type': type.toString(),
      };

  factory DrawingStroke.fromJson(Map<String, dynamic> json) {
    return DrawingStroke(
      points: (json['points'] as List)
          .map((p) => Offset(p['x'] as double, p['y'] as double))
          .toList(),
      color: Color(json['color'] as int),
      thickness: json['thickness'] as double,
      type: AnnotationType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => AnnotationType.pen,
      ),
    );
  }
}

/// Service to manage annotations
class AnnotationService {
  final AppDatabase _database = DatabaseService.instance.database;

  /// Get all layers for a document
  Future<List<AnnotationLayer>> getLayers(int documentId) async {
    return await _database.getAnnotationLayers(documentId);
  }

  /// Create a new layer
  Future<int> createLayer(int documentId, String name) async {
    // Get current layer count to set order
    final layers = await getLayers(documentId);
    final orderIndex = layers.length;

    return await _database.insertAnnotationLayer(
      AnnotationLayersCompanion(
        documentId: drift.Value(documentId),
        name: drift.Value(name),
        orderIndex: drift.Value(orderIndex),
        isVisible: const drift.Value(true),
      ),
    );
  }

  /// Delete a layer and all its annotations
  Future<void> deleteLayer(int layerId) async {
    await _database.deleteAnnotationLayer(layerId);
  }

  /// Toggle layer visibility
  Future<void> toggleLayerVisibility(AnnotationLayer layer) async {
    final updated = layer.copyWith(isVisible: !layer.isVisible);
    await _database.updateAnnotationLayer(updated);
  }

  /// Rename a layer
  Future<void> renameLayer(AnnotationLayer layer, String newName) async {
    final updated = layer.copyWith(name: newName);
    await _database.updateAnnotationLayer(updated);
  }

  /// Reorder layers
  Future<void> reorderLayers(int documentId, List<int> layerIds) async {
    for (int i = 0; i < layerIds.length; i++) {
      final layers = await getLayers(documentId);
      final layer = layers.firstWhere((l) => l.id == layerIds[i]);
      final updated = layer.copyWith(orderIndex: i);
      await _database.updateAnnotationLayer(updated);
    }
  }

  /// Get annotations for a specific layer and page
  Future<List<DrawingStroke>> getAnnotations(
      int layerId, int pageNumber) async {
    final annotations = await _database.getAnnotations(layerId, pageNumber);

    return annotations
        .map((annotation) {
          try {
            final data = jsonDecode(annotation.data) as Map<String, dynamic>;
            return DrawingStroke.fromJson(data);
          } catch (e) {
            debugPrint('Error decoding annotation: $e');
            return null;
          }
        })
        .whereType<DrawingStroke>()
        .toList();
  }

  /// Save an annotation
  Future<int> saveAnnotation({
    required int layerId,
    required int pageNumber,
    required DrawingStroke stroke,
  }) async {
    final data = jsonEncode(stroke.toJson());

    return await _database.insertAnnotation(
      AnnotationsCompanion(
        layerId: drift.Value(layerId),
        pageNumber: drift.Value(pageNumber),
        type: drift.Value(stroke.type.toString()),
        data: drift.Value(data),
      ),
    );
  }

  /// Delete an annotation
  Future<void> deleteAnnotation(int annotationId) async {
    await _database.deleteAnnotation(annotationId);
  }

  /// Get all annotations for all layers on a specific page
  Future<Map<int, List<DrawingStroke>>> getAllPageAnnotations(
    int documentId,
    int pageNumber,
  ) async {
    final layers = await getLayers(documentId);
    final result = <int, List<DrawingStroke>>{};

    for (final layer in layers) {
      if (layer.isVisible) {
        final annotations = await getAnnotations(layer.id, pageNumber);
        if (annotations.isNotEmpty) {
          result[layer.id] = annotations;
        }
      }
    }

    return result;
  }

  /// Clear all annotations on a page for a specific layer
  Future<void> clearPageAnnotations(int layerId, int pageNumber) async {
    final annotations = await _database.getAnnotations(layerId, pageNumber);
    for (final annotation in annotations) {
      await _database.deleteAnnotation(annotation.id);
    }
  }
}
