import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';

class FaceService {
  late final FaceDetector _faceDetector;

  FaceService() {
    final options = FaceDetectorOptions(
      enableContours: false,
      enableLandmarks: false,
      enableClassification: false,
      enableTracking: false,
    );

    _faceDetector = FaceDetector(options: options);
  }

  Future<bool> detectFaceFromCamera() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
      );

      if (image == null) return false;

      final inputImage = InputImage.fromFilePath(image.path);
      final faces = await _faceDetector.processImage(inputImage);

      return faces.isNotEmpty;
    } catch (e) {
      print('Face detection error: $e');
      return false;
    }
  }

  void dispose() {
    _faceDetector.close();
  }
}
