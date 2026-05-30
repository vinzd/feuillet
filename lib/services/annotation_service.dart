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
  static final AnnotationService instance = AnnotationService._();
  AnnotationService._();

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

  /// Get annotations for a specific layer and page
  Future<List<DrawingStroke>> getAnnotations(
    int layerId,
    int pageNumber,
  ) async {
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

    debugPrint(
      '[AnnotationService] saveAnnotation START layerId=$layerId page=$pageNumber type=${stroke.type} points=${stroke.points.length}',
    );
    final id = await _database.insertAnnotation(
      AnnotationsCompanion(
        layerId: drift.Value(layerId),
        pageNumber: drift.Value(pageNumber),
        type: drift.Value(stroke.type.toString()),
        data: drift.Value(data),
      ),
    );
    debugPrint('[AnnotationService] saveAnnotation DONE id=$id');
    return id;
  }

  /// Delete an annotation
  Future<void> deleteAnnotation(int annotationId) async {
    await _database.deleteAnnotation(annotationId);
  }

  /// Merge a source layer into a target layer (moves all annotations, deletes source)
  Future<void> mergeLayers(int sourceLayerId, int targetLayerId) async {
    await _database.moveAnnotationsToLayer(sourceLayerId, targetLayerId);
    await _database.deleteAnnotationLayer(sourceLayerId);
  }

  /// Recolor all strokes of a layer to a given color
  Future<void> recolorLayer(int layerId, Color color) async {
    final annotations = await _database.getAllAnnotationsForLayer(layerId);
    for (final annotation in annotations) {
      try {
        final data = jsonDecode(annotation.data) as Map<String, dynamic>;
        data['color'] = color.toARGB32();
        await _database.updateAnnotationData(annotation.id, jsonEncode(data));
      } catch (e) {
        debugPrint('Error recoloring annotation ${annotation.id}: $e');
      }
    }
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
        debugPrint(
          '[AnnotationService] getAllPageAnnotations layer=${layer.id} (visible=${layer.isVisible}) page=$pageNumber -> ${annotations.length} strokes',
        );
      } else {
        debugPrint(
          '[AnnotationService] getAllPageAnnotations layer=${layer.id} SKIPPED (not visible)',
        );
      }
    }

    debugPrint(
      '[AnnotationService] getAllPageAnnotations docId=$documentId page=$pageNumber TOTAL: ${result.map((k, v) => MapEntry(k, v.length))}',
    );
    return result;
  }
}
