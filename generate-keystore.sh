#!/bin/bash

# Android Release Keystore Generation Script
# Run this script to create your release keystore

echo "========================================="
echo "FlatSync Release Keystore Generator"
echo "========================================="
echo ""
echo "This will create a keystore for signing your release APK/AAB"
echo ""

# Prompt for keystore details
read -p "Enter keystore password (min 6 characters): " STORE_PASSWORD
read -p "Enter key password (min 6 characters): " KEY_PASSWORD
read -p "Enter your name: " NAME
read -p "Enter your organization: " ORG
read -p "Enter your city: " CITY
read -p "Enter your state: " STATE
read -p "Enter your country code (e.g., US, IN): " COUNTRY

# Generate keystore
keytool -genkey -v \
  -keystore upload-keystore.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload \
  -dname "CN=$NAME, OU=$ORG, O=$ORG, L=$CITY, ST=$STATE, C=$COUNTRY" \
  -storepass "$STORE_PASSWORD" \
  -keypass "$KEY_PASSWORD"

# Create key.properties file
cat > key.properties << EOF
storePassword=$STORE_PASSWORD
keyPassword=$KEY_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
EOF

echo ""
echo "========================================="
echo "✅ Keystore created successfully!"
echo "========================================="
echo ""
echo "Files created:"
echo "  - upload-keystore.jks (Keep this SAFE and PRIVATE!)"
echo "  - key.properties (Keep this SAFE and PRIVATE!)"
echo ""
echo "⚠️  IMPORTANT:"
echo "  1. Move upload-keystore.jks to android/app/"
echo "  2. Move key.properties to android/"
echo "  3. Add both files to .gitignore"
echo "  4. Backup these files securely"
echo ""
