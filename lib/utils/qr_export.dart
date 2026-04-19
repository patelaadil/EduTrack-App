export 'qr_export_stub.dart'
    if (dart.library.html) 'qr_export_web.dart'
    if (dart.library.io) 'qr_export_mobile.dart';
