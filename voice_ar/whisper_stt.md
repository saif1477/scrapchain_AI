# Offline STT — whisper.cpp integration

The Flutter app's primary STT is `speech_to_text` (on-device Google engine).
For fully-offline field use (no Play Services / no network), we bundle
whisper.cpp `tiny` (39 MB, ggml Q5_0 quantized ≈ 26 MB):

## Build (Android arm64)
```bash
git clone https://github.com/ggerganov/whisper.cpp
cd whisper.cpp
cmake -B build -DANDROID_ABI=arm64-v8a -DCMAKE_TOOLCHAIN_FILE=$NDK/build/cmake/android.toolchain.cmake
cmake --build build -j
# outputs libwhisper.so -> mobile/android/app/src/main/jniLibs/arm64-v8a/
```

## Dart FFI binding (mobile/lib/services/whisper_ffi.dart — production build)
```dart
final DynamicLibrary _lib = DynamicLibrary.open('libwhisper.so');
// whisper_init_from_file / whisper_full / whisper_full_get_segment_text
```

## Language models
`ggml-tiny.bin` handles hi/mr/ta/bn with language auto-detect. Latency on a
₹8,000 Android phone (SD680): ~1.9 s for a 4-second command clip — acceptable
for command-and-control voice UX.

## Command grammar
Post-STT, commands map to intents via the keyword table in
`mobile/lib/services/voice_service.dart` (scan / price / recycler / receipt),
which is robust to Whisper's transliteration variance.
