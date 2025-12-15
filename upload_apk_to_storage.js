#!/usr/bin/env node

/**
 * Upload APK to Firebase Storage
 * 
 * This script uploads the MedWave Android APK to Firebase Storage
 * at the path: downloads/apks/MedWave-v1.2.7.apk
 * 
 * Usage: node upload_apk_to_storage.js
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin SDK
// Using the existing service account key
const serviceAccount = require('./bhl-obe-firebase-adminsdk-fbsvc-0a91fc9874.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: 'medx-ai.firebasestorage.app'
});

const bucket = admin.storage().bucket();

// APK file path
const apkPath = path.join(__dirname, 'MedWave-v1.2.7.apk');
const destinationPath = 'downloads/apks/MedWave-v1.2.7.apk';

console.log('🚀 Starting APK upload to Firebase Storage...');
console.log(`📁 Source: ${apkPath}`);
console.log(`📦 Destination: ${destinationPath}`);

// Check if file exists
if (!fs.existsSync(apkPath)) {
  console.error('❌ Error: APK file not found at', apkPath);
  console.error('Please ensure MedWave-v1.2.7.apk exists in the project root.');
  process.exit(1);
}

// Get file size
const stats = fs.statSync(apkPath);
const fileSizeMB = (stats.size / (1024 * 1024)).toFixed(2);
console.log(`📊 File size: ${fileSizeMB} MB`);

// Upload file
async function uploadAPK() {
  try {
    await bucket.upload(apkPath, {
      destination: destinationPath,
      metadata: {
        contentType: 'application/vnd.android.package-archive',
        metadata: {
          version: '1.2.7',
          buildNumber: '12',
          uploadedAt: new Date().toISOString(),
          description: 'MedWave Provider Android App - Beta Version'
        }
      },
      public: false, // Keep private, use signed URLs for download
    });

    console.log('✅ APK uploaded successfully!');
    console.log(`🔗 Storage path: gs://${bucket.name}/${destinationPath}`);
    console.log('');
    console.log('📋 Next steps:');
    console.log('1. Deploy the Cloud Function: firebase deploy --only functions');
    console.log('2. Test the download endpoint: https://us-central1-medx-ai.cloudfunctions.net/api/api/download/apk');
    console.log('3. Access the download page at: <your-domain>/download-app');
    console.log('');
    console.log('✨ Setup complete!');
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error uploading APK:', error.message);
    process.exit(1);
  }
}

uploadAPK();

