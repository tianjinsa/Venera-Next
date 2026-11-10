# Build and Development

Default Chinese version: [build.zh.md](build.zh.md)

This guide is for developers building, testing, or maintaining VeneraNext from source. For installation and usage, see the root [README](../../README.md).

## Prerequisites

- Flutter `3.41.4`
- Dart `>=3.8.0 <4.0.0`
- JDK `17` for Android builds
- A Rust toolchain; Android builds require the corresponding Android targets
- Native tooling for the target platform, such as Android SDK / NDK, Xcode, Visual Studio, or Linux GTK/WebKit dependencies
- Windows local builds require Developer Mode because the `pdfrx` native assets used by PDF import create symbolic links during the build

Check the Flutter environment first:

```bash
flutter doctor -v
flutter --version
```

## Dependencies

Clone the repository and resolve dependencies from its lock file:

```bash
git clone https://github.com/CyrilPeng/venera-next.git
cd venera-next
flutter pub get --enforce-lockfile
```

Do not delete or regenerate `pubspec.lock` without understanding the dependency changes.

See [Dependency Governance](dependencies.en.md) for Git fork provenance, pinned commits, and upgrade requirements.

### Critical Version Pin

The project uses `rhttp 0.15.1` and must keep `flutter_rust_bridge 2.11.1`. With an incompatible version, a build may succeed while the resulting application cannot access the network and reports:

```text
flutter_rust_bridge has not been initialized
```

Check the pinned version in PowerShell:

```powershell
Select-String pubspec.lock -Pattern "flutter_rust_bridge" -Context 0,6
```

The result must include:

```yaml
version: "2.11.1"
```

## Quality Checks

Run at least the following before submitting code:

```bash
python .github/scripts/check_structure_imports.py
flutter analyze --no-pub
flutter test --no-pub
git diff --check
```

CI runs `flutter test --coverage`, publishes line coverage in the workflow summary, and uploads `coverage/lcov.info`. Coverage is currently a visible baseline rather than a repository-wide hard threshold. Changes to critical behavior still require focused tests.

Pull requests also run `依赖安全审查` and `PR 平台冒烟构建`. Dependency review blocks newly introduced dependencies with high or critical vulnerabilities. Affected paths select Android, Windows, Linux, macOS or iOS smoke builds. Android mobile and TV share one ARM64 runner; documentation-only changes skip platform jobs. Quality checks also run navigation, input, low-memory, and update regressions with the actual TV flavor. Dart formatting is checked only for Dart files changed by the current PR, so historical formatting differences do not block new contributions. The `main` branch requires code analysis, dependency review, and the platform smoke-build gate to pass, and direct force-pushes or branch deletion are disabled.

For release-related changes, also run:

```bash
python .github/scripts/release_version.py --check
```

## Android Build

Place local release signing files at:

```text
android/keystore.jks
android/key.properties
```

Example `android/key.properties`:

```properties
storePassword=your store password
keyPassword=your key password
keyAlias=your key alias
storeFile=../keystore.jks
```

Build the APK:

```bash
flutter pub get --enforce-lockfile
flutter build apk --release --flavor mobile
flutter build apk --release --flavor tv
```

Artifacts are written to `build/app/outputs/apk/mobile/release/` and `build/app/outputs/apk/tv/release/`. Explicitly pass `--flavor mobile` or `--flavor tv` for Android. Do not set a global `default-flavor`, which would interfere with the existing iOS/macOS Xcode schemes. Manual GitHub Actions builds can select mobile, TV or both; full releases still build both. See [Android TV Distribution](../distribution/android_tv.en.md) for its separate package, version-code offset, updates, and release checks.

Signing files and passwords are sensitive and must not be committed.

## Desktop and iOS Builds

With the native toolchain installed on the corresponding operating system, run:

```bash
flutter pub get --enforce-lockfile
flutter build windows
flutter build linux
flutter build macos
```

Use a no-codesign build to validate iOS first:

```bash
flutter pub get --enforce-lockfile
flutter build ios --release --no-codesign
```

For Windows installer, portable package, and winget manifest maintenance, see [Windows Distribution](../distribution/windows.en.md).

## GitHub Actions and Release Versions

Repository workflows handle continuous integration, manual builds, tag releases, and distribution metadata. The release version is maintained centrally in `release.json`:

```json
{
  "version": "1.2.3",
  "build": 123
}
```

Before a release, update `release.json`, then synchronize and validate related files:

```bash
python .github/scripts/release_version.py --write
python .github/scripts/release_version.py --check --tag v1.2.3
```

`pubspec.yaml`, the release tag, and the version section in `CHANGELOG.md` must match `release.json`. `alt_store.json` is not a version source. After a stable GitHub Release succeeds, workflows update it from release assets; RC prereleases do not update the AltStore source.

`代码分析` starts with lightweight version, structure and architecture checks, then selects tests from the complete PR diff or all commits in a push. Documentation and distribution metadata skip Flutter, emulator and Apple runners. Dart changes retain the full Flutter suite and coverage; native platform checks follow affected paths. Unknown inputs, unavailable diffs, manual builds and tags conservatively use the full scope. Dependency review still checks PR dependencies. PR smoke builds select affected platforms; Android mobile and TV share one runner and compile ARM64 only. Full builds reuse the same quality workflow before multi-platform compilation.

Development uses `codex/agent-center-tab`. Manual `构建` defaults to mobile ARM64 only; other platforms must be selected. `android_flavors` accepts `mobile`, `tv`, or `both`; `android_architecture` accepts `arm64` or `all` (ARM32, ARM64, x86_64, and universal APKs). Android flavors build sequentially, sharing Flutter, Gradle and native Rust outputs. Each flavor is independently verified and staged immediately, then uploaded in one `android_build` artifact. Android-only quality checks skip Apple runners. Full builds and all tag builds force both flavors and every architecture; release gates still require all eight APKs and both manifests.

Rust caches include source downloads and actual Cargo target directories, separated by OS, host architecture, target/profile, lockfiles, toolchain, build configuration and Rust source. Source changes can restore dependency caches with the same configuration; Cargo decides what to rebuild. Toolchain preparation retains usable installations and adds only missing toolchains or targets. Gradle task caching is enabled. Android needs 20 GiB free; sufficient space skips cleanup. Only hosted GitHub runners with insufficient space remove unrelated tools on demand, preserving the full tool cache, Android SDK and Flutter.

Manual runs of `构建`, `完整构建`, and `HarmonyOS Release HAP` offer a `skip_tests` checkbox, disabled by default. Reusable workflows receive the same option. It skips Python, Dart, Swift and Rust tests, Android Provider regressions, Windows native/startup tests, Linux AppImage smoke tests, and HarmonyOS host tests. Static analysis, version/dependency checks, compilation, and artifact integrity/signature checks still run. PRs and main-branch CI run tests for affected paths by default; automatic tag releases run the full suite.

Android release workflows require these repository Secrets:

- `ANDROID_KEYSTORE`: Base64 content of the keystore file
- `ANDROID_KEY_PROPERTIES`: text content of `key.properties`

`ANDROID_KEY_PROPERTIES` can use this format directly, without changing `storeFile`:

```properties
storeFile=keystore.jks
storePassword=<ANDROID_KEYSTORE_PASSWORD>
keyAlias=<ANDROID_KEY_ALIAS>
keyPassword=<ANDROID_KEY_PASSWORD>
```

Only the Android signing preparation step reads these Secrets. It writes the keystore and properties to `$RUNNER_TEMP/android-signing/`, with directory mode `700` and file mode `600`. Gradle reads these temporary files through `ANDROID_KEYSTORE_FILE` and `ANDROID_KEY_PROPERTIES_FILE`; the absolute temporary keystore path overrides `storeFile` in CI. No `android/app/keystore.jks` is needed in the repository. Missing Secrets or invalid Base64 fail the job; cleanup runs on success or failure, and signing files are never uploaded as artifacts. Local builds without these environment variables still read `android/key.properties` and its `storeFile` value.

After a stable release, the AltStore workflow reuses the fixed `automation/update-altstore` branch and creates a pull request. Configure `ALTSTORE_PR_TOKEN` with permission to push a branch and create pull requests in this repository; when it is not configured, the workflow falls back to `WINGET_PKGS_TOKEN`. A missing token or failed PR creation now fails the job instead of reporting success with only an orphan branch.

Issue classification and format checks run by default without an AI API. `.github/scripts/issue_policy.py` validates structured reports, category-specific evidence and classification/missing-information labels. New/edit/reopen and comment changes trigger rechecks; the same bot comment is updated. Bot events, PRs, closed Issues and historical formats are skipped. Required labels are created when absent; existing label colors and descriptions are preserved. See the [reporting guide](../user/issue_reporting.en.md).

Optional AI summaries are disabled by default and run only for complete opened/edited reports. After verifying `API_URL` and `API_KEY`, set `ENABLE_AI_ISSUE_CHECK` to `true`; `ISSUE_CHECK_MODEL` can override the model. Format and AI jobs have separate per-Issue queues; skipped bot jobs cannot replace pending human checks, and slow AI calls do not block later format checks. AI updates its marked comment using the body and reporter/maintainer supplements; failure does not affect the fixed rules. Suggestions require maintainer review and never close Issues. Issue text is not interpolated into shell commands, and automation does not download attachments.

Never put Secrets, signing files, or real passwords in code, logs, or documentation examples.

## Troubleshooting

### The Build Succeeds but the App Has No Network Access

First confirm that `flutter_rust_bridge` is still `2.11.1` and that dependencies were resolved from the current repository `pubspec.lock`. Do not blindly upgrade dependencies to address initialization failures.

### `flutter_rust_bridge has not been initialized`

This usually means dependency versions have drifted. Restore the repository `pubspec.lock`, confirm the required Flutter version, and run:

```bash
flutter pub get --enforce-lockfile
```

### `Unable to satisfy pubspec.yaml using pubspec.lock`

The Flutter/Dart version or package-source environment usually does not match. Check the Flutter version required by this guide and the output of `flutter doctor -v`; do not immediately delete the lock file.

### Slow Gradle Downloads

You may temporarily use a local Gradle wrapper mirror or configure a network proxy. Environment-specific URLs must not be committed. Before submitting changes, verify that `gradle-wrapper.properties` does not contain local mirror edits.
