import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

enum CapabilityStatus { granted, denied, permanentlyDenied, unavailable }

class DeviceCapabilityResult {
  const DeviceCapabilityResult({
    required this.status,
    this.message,
    this.openSettings = false,
  });

  final CapabilityStatus status;
  final String? message;
  final bool openSettings;
}

class DeviceCapabilitiesService {
  const DeviceCapabilitiesService();

  Future<DeviceCapabilityResult> requestCameraAccess() async {
    final status = await Permission.camera.request();
    switch (status) {
      case PermissionStatus.granted:
        return const DeviceCapabilityResult(status: CapabilityStatus.granted);
      case PermissionStatus.permanentlyDenied:
        return const DeviceCapabilityResult(
          status: CapabilityStatus.permanentlyDenied,
          message: 'La cámara está deshabilitada. Puedes activarla desde Ajustes.',
          openSettings: true,
        );
      case PermissionStatus.denied:
      case PermissionStatus.restricted:
      case PermissionStatus.limited:
      case PermissionStatus.provisional:
        return const DeviceCapabilityResult(
          status: CapabilityStatus.denied,
          message: 'Necesitas permitir la cámara para adjuntar una foto.',
        );
    }
  }

  Future<DeviceCapabilityResult> requestPhotoLibraryAccess() async {
    final status = await Permission.photos.request();
    switch (status) {
      case PermissionStatus.granted:
        return const DeviceCapabilityResult(status: CapabilityStatus.granted);
      case PermissionStatus.permanentlyDenied:
        return const DeviceCapabilityResult(
          status: CapabilityStatus.permanentlyDenied,
          message: 'La galería está denegada permanentemente. Puedes habilitarla desde Ajustes.',
          openSettings: true,
        );
      case PermissionStatus.denied:
      case PermissionStatus.restricted:
      case PermissionStatus.limited:
      case PermissionStatus.provisional:
        return const DeviceCapabilityResult(
          status: CapabilityStatus.denied,
          message: 'No se pudo acceder a la galería. Puedes seguir usando la app sin imagen.',
        );
    }
  }

  Future<DeviceCapabilityResult> requestLocationAccess() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const DeviceCapabilityResult(
        status: CapabilityStatus.unavailable,
        message: 'La ubicación está desactivada. Puedes guardar la nota sin coordenadas.',
      );
    }

    final status = await Permission.locationWhenInUse.request();
    switch (status) {
      case PermissionStatus.granted:
        return const DeviceCapabilityResult(status: CapabilityStatus.granted);
      case PermissionStatus.permanentlyDenied:
        return const DeviceCapabilityResult(
          status: CapabilityStatus.permanentlyDenied,
          message: 'La ubicación fue denegada permanentemente. Puedes abrir Ajustes para cambiarlo.',
          openSettings: true,
        );
      case PermissionStatus.denied:
      case PermissionStatus.restricted:
      case PermissionStatus.limited:
      case PermissionStatus.provisional:
        return const DeviceCapabilityResult(
          status: CapabilityStatus.denied,
          message: 'Sin permiso de ubicación, la nota se guardará sin coordenadas.',
        );
    }
  }

  Future<XFile?> pickImageFromCamera() async {
    final result = await requestCameraAccess();
    if (result.status == CapabilityStatus.granted) {
      return ImagePicker().pickImage(source: ImageSource.camera);
    }
    return null;
  }

  Future<XFile?> pickImageFromGallery() async {
    final result = await requestPhotoLibraryAccess();
    if (result.status == CapabilityStatus.granted) {
      return ImagePicker().pickImage(source: ImageSource.gallery);
    }
    return null;
  }

  Future<Position?> getCurrentLocation() async {
    final result = await requestLocationAccess();
    if (result.status != CapabilityStatus.granted) return null;
    return Geolocator.getCurrentPosition();
  }
}
