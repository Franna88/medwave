#!/usr/bin/env node
/**
 * Find ads with actual data
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

async function findAdsWithData() {
  console.log('\n🔍 Searching for ads with data...\n');

  const advertsSnapshot = await db.collection('advertData').get();
  console.log(`Total ads: ${advertsSnapshot.size}\n`);

  const adsWithData = [];
  let checkedCount = 0;

  for (const advertDoc of advertsSnapshot.docs) {
    const adId = advertDoc.id;
    const adData = advertDoc.data();
    
    // Check ghlData/weekly subcollection
    const ghlWeeklySnapshot = await db.collection('advertData')
      .doc(adId)
      .collection('ghlData')
      .doc('weekly')
      .collection('weekly')
      .get();
    
    if (ghlWeeklySnapshot.size > 0) {
      let totalLeads = 0;
      let totalCash = 0;
      const weeks = [];
      
      ghlWeeklySnapshot.docs.forEach(weekDoc => {
        const weekData = weekDoc.data();
        totalLeads += weekData.leads || 0;
        totalCash += weekData.cashAmount || 0;
        weeks.push({
          weekId: weekDoc.id,
          leads: weekData.leads || 0,
          booked: weekData.bookedAppointments || 0,
          deposits: weekData.deposits || 0,
          cash: weekData.cashAmount || 0
        });
      });
      
      adsWithData.push({
        adId,
        adName: adData.adName,
        campaignName: adData.campaignName,
        weekCount: ghlWeeklySnapshot.size,
        totalLeads,
        totalCash,
        weeks: weeks.sort((a, b) => a.weekId.localeCompare(b.weekId))
      });
      
      console.log(`✅ Found ad with data: ${adData.adName || adId}`);
      console.log(`   Campaign: ${adData.campaignName}`);
      console.log(`   Weeks: ${ghlWeeklySnapshot.size}, Leads: ${totalLeads}, Cash: R${totalCash}`);
    }
    
    checkedCount++;
    if (checkedCount % 100 === 0) {
      console.log(`   Checked ${checkedCount}/${advertsSnapshot.size} ads...`);
    }
  }
  
  console.log(`\n\n📊 RESULTS:`);
  console.log(`   Total ads with GHL data: ${adsWithData.length}`);
  console.log(`   Total weeks across all ads: ${adsWithData.reduce((sum, ad) => sum + ad.weekCount, 0)}`);
  console.log(`   Total leads: ${adsWithData.reduce((sum, ad) => sum + ad.totalLeads, 0)}`);
  console.log(`   Total cash: R${adsWithData.reduce((sum, ad) => sum + ad.totalCash, 0).toFixed(2)}`);
  
  if (adsWithData.length > 0) {
    console.log(`\n\n📋 TOP 10 ADS BY LEADS:\n`);
    adsWithData.sort((a, b) => b.totalLeads - a.totalLeads).slice(0, 10).forEach((ad, i) => {
      console.log(`${i+1}. ${ad.adName || ad.adId}`);
      console.log(`   Campaign: ${ad.campaignName}`);
      console.log(`   Leads: ${ad.totalLeads}, Cash: R${ad.totalCash}, Weeks: ${ad.weekCount}`);
      console.log(`   Week breakdown:`);
      ad.weeks.forEach(week => {
        console.log(`      ${week.weekId}: ${week.leads} leads, ${week.booked} booked, ${week.deposits} deposits, R${week.cash}`);
      });
      console.log('');
    });
  }
  
  process.exit(0);
}

findAdsWithData().catch(error => {
  console.error('Error:', error);
  process.exit(1);
});

