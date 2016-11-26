# CameraOCRSample

This sample project for Camera OCR app using TesseractOCRiOS.

## How to build

You need to retrieve TesseractOCRiOS using CocoaPods. You can install it as following:

```bash
cd [project folder where you may download this project into]
pod install
```

After install TesseractOCRiOS, you open XCode by 'CameraOCRSample.xcworkspace'.

## For using Xcode 7

If you use Xcode 7, you may see the build error (link error) as following:

```
ld: '/Users/[userName]/Library/Developer/Xcode/DerivedData/... .../libjsbindings iOS.a(Value.o)' does not contain bitcode. You must rebuild it with bitcode enabled (Xcode setting ENABLE_BITCODE), obtain an updated library from the vendor, or disable bitcode for this target. for architecture armv7
clang: error: linker command failed with exit code 1 (use -v to see invocation)
```

Please change configuration "Enable Bitcode" with "NO" and rebuild it.
