@echo off
echo ========================================
echo Building APK with Simple Icon
echo ========================================
echo.

echo [1/4] Generating launcher icons...
flutter pub run flutter_launcher_icons
if %errorlevel% neq 0 (
    echo ERROR: Failed to generate icons
    pause
    exit /b 1
)
echo.

echo [2/4] Cleaning project...
flutter clean
if %errorlevel% neq 0 (
    echo ERROR: Failed to clean project
    pause
    exit /b 1
)
echo.

echo [3/4] Getting dependencies...
flutter pub get
if %errorlevel% neq 0 (
    echo ERROR: Failed to get dependencies
    pause
    exit /b 1
)
echo.

echo [4/4] Building APK...
flutter build apk --release
if %errorlevel% neq 0 (
    echo ERROR: Failed to build APK
    pause
    exit /b 1
)
echo.

echo ========================================
echo SUCCESS! APK built successfully!
echo Location: build\app\outputs\flutter-apk\app-release.apk
echo ========================================
pause

