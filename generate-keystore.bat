@echo off
echo =========================================
echo FlatSync Release Keystore Generator
echo =========================================
echo.
echo This will create a keystore for signing your release APK/AAB
echo.

set /p STORE_PASSWORD="Enter keystore password (min 6 characters): "
set /p KEY_PASSWORD="Enter key password (min 6 characters): "
set /p NAME="Enter your name: "
set /p ORG="Enter your organization: "
set /p CITY="Enter your city: "
set /p STATE="Enter your state: "
set /p COUNTRY="Enter your country code (e.g., US, IN): "

keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload -dname "CN=%NAME%, OU=%ORG%, O=%ORG%, L=%CITY%, ST=%STATE%, C=%COUNTRY%" -storepass %STORE_PASSWORD% -keypass %KEY_PASSWORD%

echo storePassword=%STORE_PASSWORD% > key.properties
echo keyPassword=%KEY_PASSWORD% >> key.properties
echo keyAlias=upload >> key.properties
echo storeFile=upload-keystore.jks >> key.properties

echo.
echo =========================================
echo ✅ Keystore created successfully!
echo =========================================
echo.
echo Files created:
echo   - upload-keystore.jks (Keep this SAFE and PRIVATE!)
echo   - key.properties (Keep this SAFE and PRIVATE!)
echo.
echo ⚠️  IMPORTANT:
echo   1. Move upload-keystore.jks to android\app\
echo   2. Move key.properties to android\
echo   3. Add both files to .gitignore
echo   4. Backup these files securely
echo.
pause
