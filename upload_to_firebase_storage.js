// Firebase Storage Upload Script for APK Distribution
// Run with: node upload_to_firebase_storage.js

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin
const serviceAccount = require('./bhl-obe-firebase-adminsdk-fbsvc-0a91fc9874.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: 'medx-ai.appspot.com'
});

const bucket = admin.storage().bucket();

async function uploadAPK() {
  try {
    const apkPath = './MedWave-v1.2.7.apk';
    const destination = 'downloads/MedWave-v1.2.7.apk';
    
    console.log('🚀 Uploading APK to Firebase Storage...');
    
    // Upload file
    await bucket.upload(apkPath, {
      destination: destination,
      metadata: {
        metadata: {
          firebaseStorageDownloadTokens: 'public-download-token'
        }
      },
      public: true
    });
    
    console.log('✅ Upload successful!');
    
    // Get download URL
    const file = bucket.file(destination);
    const [url] = await file.getSignedUrl({
      action: 'read',
      expires: '03-09-2491' // Very far future date
    });
    
    console.log('📱 APK Download URL:');
    console.log(url);
    
    // Also create a simple public URL
    const publicUrl = `https://firebasestorage.googleapis.com/v0/b/medx-ai.appspot.com/o/downloads%2FMedWave-v1.2.7.apk?alt=media`;
    console.log('\n🌐 Direct Download URL:');
    console.log(publicUrl);
    
    // Update download page with the URL
    updateDownloadPage(publicUrl);
    
  } catch (error) {
    console.error('❌ Upload failed:', error);
  }
}

function updateDownloadPage(downloadUrl) {
  try {
    let html = fs.readFileSync('./apk_download.html', 'utf8');
    
    // Replace the download link
    html = html.replace(
      'href="./app-release.apk"',
      `href="${downloadUrl}"`
    );
    
    fs.writeFileSync('./apk_download_updated.html', html);
    console.log('✅ Download page updated: apk_download_updated.html');
    
  } catch (error) {
    console.error('❌ Failed to update download page:', error);
  }
}

// Run the upload
uploadAPK();


