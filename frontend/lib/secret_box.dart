import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// Encrypts small secrets, such as the API key, so that only the current
/// Windows user on this computer can read them back (Windows DPAPI). Copying
/// the database to another account or machine does not reveal the secret.
abstract class SecretBox {
  String seal(String secret);

  /// Returns null when [sealed] cannot be opened, for example after the
  /// database was copied from another computer.
  String? open(String sealed);
}

/// The Windows implementation, backed by `CryptProtectData`.
class DpapiSecretBox implements SecretBox {
  static final _crypt32 = DynamicLibrary.open('crypt32.dll');
  static final _kernel32 = DynamicLibrary.open('kernel32.dll');

  static final _protect = _crypt32.lookupFunction<_CryptNative, _CryptDart>(
    'CryptProtectData',
  );
  static final _unprotect = _crypt32.lookupFunction<_CryptNative, _CryptDart>(
    'CryptUnprotectData',
  );
  static final _localFree = _kernel32
      .lookupFunction<Pointer Function(Pointer), Pointer Function(Pointer)>(
        'LocalFree',
      );

  /// Never show a Windows prompt; fail instead.
  static const _uiForbidden = 0x1;

  @override
  String seal(String secret) =>
      base64Encode(_run(_protect, utf8.encode(secret))!);

  @override
  String? open(String sealed) {
    final Uint8List bytes;
    try {
      bytes = base64Decode(sealed);
    } on FormatException {
      return null;
    }
    final plain = _run(_unprotect, bytes);
    return plain == null ? null : utf8.decode(plain, allowMalformed: true);
  }

  Uint8List? _run(_CryptDart function, List<int> input) {
    return using((arena) {
      final data = arena<Uint8>(input.isEmpty ? 1 : input.length);
      data.asTypedList(input.length).setAll(0, input);
      final blobIn = arena<_DataBlob>()
        ..ref.cbData = input.length
        ..ref.pbData = data;
      final blobOut = arena<_DataBlob>();
      final ok = function(
        blobIn,
        nullptr,
        nullptr,
        nullptr,
        nullptr,
        _uiForbidden,
        blobOut,
      );
      if (ok == 0) return null;
      final result = Uint8List.fromList(
        blobOut.ref.pbData.asTypedList(blobOut.ref.cbData),
      );
      _localFree(blobOut.ref.pbData);
      return result;
    });
  }
}

/// Keeps secrets in memory as given; for tests and non-Windows runs.
class PlainSecretBox implements SecretBox {
  @override
  String seal(String secret) => secret;

  @override
  String? open(String sealed) => sealed;
}

SecretBox platformSecretBox() =>
    Platform.isWindows ? DpapiSecretBox() : PlainSecretBox();

final class _DataBlob extends Struct {
  @Uint32()
  external int cbData;

  external Pointer<Uint8> pbData;
}

// Both functions share one shape; the second argument is an input
// description for CryptProtectData and an output for CryptUnprotectData,
// and both are passed as null here.
typedef _CryptNative = Int32 Function(
  Pointer<_DataBlob> dataIn,
  Pointer description,
  Pointer<_DataBlob> entropy,
  Pointer reserved,
  Pointer prompt,
  Uint32 flags,
  Pointer<_DataBlob> dataOut,
);
typedef _CryptDart = int Function(
  Pointer<_DataBlob> dataIn,
  Pointer description,
  Pointer<_DataBlob> entropy,
  Pointer reserved,
  Pointer prompt,
  int flags,
  Pointer<_DataBlob> dataOut,
);
