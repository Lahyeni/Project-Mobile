import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

class ImageService {
  final ImagePicker _imagePicker = ImagePicker();

  Future<File?> takePhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (image != null) return File(image.path);
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('Erreur prise de photo: $e');
      return null;
    }
  }

  Future<File?> pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (image != null) return File(image.path);
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('Erreur sélection galerie: $e');
      return null;
    }
  }

  Uint8List base64ToImage(String base64String) {
    try {
      String cleanBase64 = base64String;
      if (base64String.contains(',')) {
        cleanBase64 = base64String.split(',').last;
      }
      return base64Decode(cleanBase64);
    } catch (e) {
      // ignore: avoid_print
      print('Erreur décodage base64: $e');
      throw Exception('Erreur décodage base64');
    }
  }

  Future<String> captureAndConvertToBase64({bool removeBackground = true}) async {
    try {
      final File? imageFile = await takePhoto();
      if (imageFile == null) {
        throw Exception('Aucune image capturée');
      }
      return await imageToBase64(imageFile, removeBackground: removeBackground);
    } catch (e) {
      // ignore: avoid_print
      print('Erreur capture et conversion: $e');
      throw Exception("Erreur lors de la capture et conversion de l'image");
    }
  }

  Future<String> pickAndConvertToBase64({bool removeBackground = true}) async {
    try {
      final File? imageFile = await pickImageFromGallery();
      if (imageFile == null) {
        throw Exception('Aucune image sélectionnée');
      }
      return await imageToBase64(imageFile, removeBackground: removeBackground);
    } catch (e) {
      // ignore: avoid_print
      print('Erreur sélection et conversion: $e');
      throw Exception("Erreur lors de la sélection et conversion de l'image");
    }
  }

  int getBase64Size(String base64String) {
    return (base64String.length * 3 / 4).ceil();
  }

  bool isSizeAcceptable(String base64String) {
    final int sizeInBytes = getBase64Size(base64String);
    return sizeInBytes < 1000000;
  }

  Future<Uint8List> compressImage(
      Uint8List imageBytes, {
        int maxSize = 800,
        int quality = 70,
      }) async {
    try {
      final img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) {
        throw Exception("Impossible de décoder l'image");
      }

      img.Image resizedImage = originalImage;
      if (originalImage.width > maxSize || originalImage.height > maxSize) {
        resizedImage = img.copyResize(
          originalImage,
          width: maxSize,
          height: maxSize,
        );
      }

      return Uint8List.fromList(
        img.encodeJpg(resizedImage, quality: quality),
      );
    } catch (e) {
      // ignore: avoid_print
      print('Erreur compression image: $e');
      throw Exception("Erreur lors de la compression de l'image");
    }
  }

  /// Optional helper: selfie segmentation -> transparent PNG bytes.
  /// Not used by the screens below, but kept from your original file.
  Future<Uint8List> applySelfieSegmentationFromFile(File imageFile) async {
    try {
      final Uint8List fileBytes = await imageFile.readAsBytes();
      final img.Image? decoded = img.decodeImage(fileBytes);
      if (decoded == null) {
        throw Exception("Cannot decode image");
      }

      final inputImage = InputImage.fromFilePath(imageFile.path);

      final segmenter = SelfieSegmenter(
        mode: SegmenterMode.single,
        enableRawSizeMask: false,
      );

      final SegmentationMask? mask = await segmenter.processImage(inputImage);
      await segmenter.close();

      if (mask == null) return fileBytes;

      final int maskWidth = mask.width;
      final int maskHeight = mask.height;
      final List<double> conf = mask.confidences;

      if (conf.length != maskWidth * maskHeight) {
        return fileBytes;
      }

      final img.Image out =
      img.Image(width: decoded.width, height: decoded.height);

      for (int y = 0; y < decoded.height; y++) {
        for (int x = 0; x < decoded.width; x++) {
          final int mx = (x * maskWidth / decoded.width)
              .floor()
              .clamp(0, maskWidth - 1);
          final int my = (y * maskHeight / decoded.height)
              .floor()
              .clamp(0, maskHeight - 1);

          final int mIndex = my * maskWidth + mx;
          final double alphaFactor = conf[mIndex];
          final int a = (alphaFactor * 255).clamp(0, 255).toInt();

          final p = decoded.getPixel(x, y);
          out.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), a);
        }
      }

      return Uint8List.fromList(img.encodePng(out));
    } catch (e) {
      // ignore: avoid_print
      print('Segmentation error: $e');
      return await imageFile.readAsBytes();
    }
  }

  /// Main function used by Marketplace & Spot flows.
  /// If [removeBackground] is false => returns original file as base64 (no ML Kit).
  Future<String> imageToBase64(
      File imageFile, {
        bool removeBackground = true,
      }) async {
    if (!removeBackground) {
      final raw = await imageFile.readAsBytes();
      return base64Encode(raw);
    }

    final options = SubjectSegmenterOptions(
      enableForegroundBitmap: true,
      enableForegroundConfidenceMask: false,
      enableMultipleSubjects: SubjectResultOptions(
        enableConfidenceMask: false,
        enableSubjectBitmap: false,
      ),
    );

    final segmenter = SubjectSegmenter(options: options);
    try {
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final result = await segmenter.processImage(inputImage);

      if (result.foregroundBitmap != null) {
        return base64Encode(result.foregroundBitmap!);
      }

      final raw = await imageFile.readAsBytes();
      return base64Encode(raw);
    } finally {
      await segmenter.close();
    }
  }
}
