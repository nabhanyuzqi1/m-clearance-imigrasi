## 16 KB page size readiness

- `flutter_pdfview` upgraded to `^1.4.3` (implements stable Android 16 KB page size support).
- Build with current toolchain (`AGP 8.9.1`, `flutter.ndkVersion`) which already aligns native libs on 16 KB boundaries.
- Verification steps for release artifacts:
  - Generate a release build (e.g. `flutter build appbundle`).
  - Run `zipalign -c -P 16 -v 4 build/app/outputs/bundle/release/app-release.aab`.
  - If you ship APKs, run the same command against the APK.
  - Check `adb shell getconf PAGE_SIZE` on a 16 KB emulator/device (Android 15+) and install/run the build.
- If `zipalign` reports an unaligned `.so`, ensure all third-party SDKs are updated to 16 KB compatible releases or contact the vendor for new binaries.
