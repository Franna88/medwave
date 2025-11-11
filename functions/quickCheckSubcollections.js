#!/usr/bin/env node
/**
 * Quick check for advertData subcollections
 */

const admin = require('firebase-admin');
const serviceAccount = require('../medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json');

// Initialize Firebase Admin
try {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
} catch (error) {
  // Already initialized
}

const db = admin.firestore();

async function quickCheck() {
  console.log('\n🔍 Checking advertData subcollections...\n');

  // Get a few random ads
  const advertsSnapshot = await db.collection('advertData').limit(10).get();
  
  console.log(`Found ${advertsSnapshot.size} ads to check\n`);

  for (const advertDoc of advertsSnapshot.docs) {
    const adId = advertDoc.id;
    const adData = advertDoc.data();
    
    console.log(`\nAd: ${adData.adName || adId}`);
    console.log(`   Campaign: ${adData.campaignName}`);
    
    // Check insights subcollection
    const insightsSnapshot = await db.collection('advertData')
      .doc(adId)
      .collection('insights')
      .get();
    
    console.log(`   insights/ subcollection: ${insightsSnapshot.size} documents`);
    
    // Check ghlData/weekly subcollection - CORRECT PATH
    const ghlWeeklySnapshot = await db.collection('advertData')
      .doc(adId)
      .collection('ghlData')
      .doc('weekly')
      .collection('weekly')
      .get();
    
    console.log(`   ghlData/weekly/weekly/ subcollection: ${ghlWeeklySnapshot.size} documents`);
    
    if (ghlWeeklySnapshot.size > 0) {
      const firstWeek = ghlWeeklySnapshot.docs[0];
      const weekData = firstWeek.data();
      console.log(`   Sample week (${firstWeek.id}):`);
      console.log(`      Leads: ${weekData.leads || 0}`);
      console.log(`      Booked: ${weekData.bookedAppointments || 0}`);
      console.log(`      Deposits: ${weekData.deposits || 0}`);
      console.log(`      Cash: R${weekData.cashAmount || 0}`);
    }
  }
  
  // Now let's find ALL ads with GHL data
  console.log('\n\n🔍 Searching for ALL ads with GHL data...\n');
  
  const allAdvertsSnapshot = await db.collection('advertData').get();
  console.log(`Total ads in collection: ${allAdvertsSnapshot.size}`);
  
  let adsWithGHL = 0;
  let totalWeeks = 0;
  const adsWithData = [];
  
  for (const advertDoc of allAdvertsSnapshot.docs) {
    const adId = advertDoc.id;
    const adData = advertDoc.data();
    
    const ghlWeeklySnapshot = await db.collection('advertData')
      .doc(adId)
      .collection('ghlData')
      .doc('weekly')
      .collection('weekly')
      .get();
    
    if (ghlWeeklySnapshot.size > 0) {
      adsWithGHL++;
      totalWeeks += ghlWeeklySnapshot.size;
      
      let totalLeads = 0;
      ghlWeeklySnapshot.docs.forEach(doc => {
        totalLeads += doc.data().leads || 0;
      });
      
      adsWithData.push({
        adId,
        adName: adData.adName,
        weeks: ghlWeeklySnapshot.size,
        leads: totalLeads
      });
    }
    
    if ((adsWithGHL) % 10 === 0 && adsWithGHL > 0) {
      console.log(`   Found ${adsWithGHL} ads with GHL data so far...`);
    }
  }
  
  console.log(`\n✅ Found ${adsWithGHL} ads with GHL data`);
  console.log(`✅ Total weekly documents: ${totalWeeks}`);
  
  if (adsWithData.length > 0) {
    console.log('\n📊 Top 10 Ads with GHL Data:');
    adsWithData.sort((a, b) => b.leads - a.leads).slice(0, 10).forEach((ad, i) => {
      console.log(`   ${i+1}. ${ad.adName || ad.adId}`);
      console.log(`      Weeks: ${ad.weeks}, Leads: ${ad.leads}`);
    });
  } else {
    console.log('\n⚠️  NO ADS HAVE GHL DATA IN SUBCOLLECTIONS!');
  }
  
  process.exit(0);
}

quickCheck().catch(error => {
  console.error('Error:', error);
  process.exit(1);
});

