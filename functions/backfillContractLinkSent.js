/**
 * ONE-TIME BACKFILL: Set contractLinkSentAt on existing contracts so the
 * contract reminder Cloud Function sends reminders only for contracts whose
 * link was actually sent to the customer.
 *
 * Logic:
 * - Only contracts whose appointment has contractEmailSentAt (link was sent)
 * - Skip contracts that already have contractLinkSentAt or are superseded
 * - Per appointment, set contractLinkSentAt on exactly ONE contract: the
 *   "current" one (highest revisionNumber, then newest createdAt)
 *
 * Usage:
 *   cd functions && node backfillContractLinkSent.js
 * Dry run (no writes): $env:DRY_RUN="1"; node backfillContractLinkSent.js
 *
 * Credentials: set GOOGLE_APPLICATION_CREDENTIALS to your service account JSON path,
 * or place the key file in the project (see script for paths tried).
 */

const path = require('path');
const fs = require('fs');
const admin = require('firebase-admin');

const PROJECT_ID = 'medx-ai';
const KEY_FILENAMES = [
  'bhl-obe-firebase-adminsdk-fbsvc-68c34b6ad7.json',
  'medx-ai-firebase-adminsdk.json',
  'service-account.json',
];

function findServiceAccountPath() {
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    const p = process.env.GOOGLE_APPLICATION_CREDENTIALS;
    if (fs.existsSync(p)) return p;
  }
  const dirs = [
    path.join(__dirname, '..'),           // medwave project root
    path.join(__dirname, '.'),            // functions folder
    path.join(__dirname, '..', '..'),    // parent of medwave
  ];
  for (const dir of dirs) {
    for (const name of KEY_FILENAMES) {
      const full = path.join(dir, name);
      if (fs.existsSync(full)) return full;
    }
  }
  return null;
}

if (!admin.apps.length) {
  const keyPath = findServiceAccountPath();
  if (keyPath) {
    const serviceAccount = require(keyPath);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: PROJECT_ID,
    });
    console.log('   Using service account:', keyPath);
  } else {
    console.log('⚠️ No service account key found. Tried:');
    console.log('   - GOOGLE_APPLICATION_CREDENTIALS env var');
    console.log('   - Project root, functions folder, and parent folder for:', KEY_FILENAMES.join(', '));
    console.log('   Initializing with default credentials (will fail if not logged in)...\n');
    admin.initializeApp();
  }
}

const db = admin.firestore();
const DRY_RUN = process.env.DRY_RUN === '1' || process.env.DRY_RUN === 'true';

function toDate(v) {
  if (!v) return new Date(0);
  if (typeof v.toDate === 'function') return v.toDate();
  if (v instanceof Date) return v;
  return new Date(0);
}

async function run() {
  console.log('🔄 Backfill contractLinkSentAt (one-time script)');
  if (DRY_RUN) console.log('   DRY RUN – no writes will be made.\n');

  console.log('   Loading unsigned contracts (hasSigned=false, status in pending/viewed)...');
  const contractsSnap = await db
    .collection('contracts')
    .where('hasSigned', '==', false)
    .where('status', 'in', ['pending', 'viewed'])
    .get();

  const candidates = [];
  contractsSnap.docs.forEach((doc) => {
    const d = doc.data();
    if (d.contractLinkSentAt) return;
    if (d.supersededByContractId) return;
    candidates.push({
      id: doc.id,
      appointmentId: d.appointmentId,
      revisionNumber: d.revisionNumber ?? 0,
      createdAt: d.createdAt,
    });
  });

  console.log(`   Found ${candidates.length} candidate contracts (no contractLinkSentAt, not superseded).`);

  const appointmentIds = [...new Set(candidates.map((c) => c.appointmentId))];
  const appointmentMap = {};

  for (let i = 0; i < appointmentIds.length; i += 10) {
    const batch = appointmentIds.slice(i, i + 10);
    const refs = batch.map((id) => db.collection('appointments').doc(id));
    const snaps = await db.getAll(...refs);
    snaps.forEach((snap, j) => {
      if (snap.exists) appointmentMap[batch[j]] = snap.data();
    });
  }

  const withAppointment = candidates.filter((c) => {
    const appt = appointmentMap[c.appointmentId];
    return appt && appt.contractEmailSentAt;
  });

  console.log(`   ${withAppointment.length} of those have appointment with contractEmailSentAt.`);

  const byAppointment = {};
  withAppointment.forEach((c) => {
    if (!byAppointment[c.appointmentId]) byAppointment[c.appointmentId] = [];
    byAppointment[c.appointmentId].push(c);
  });

  const toUpdate = [];
  Object.entries(byAppointment).forEach(([appointmentId, contracts]) => {
    const sorted = [...contracts].sort((a, b) => {
      const r = (b.revisionNumber ?? 0) - (a.revisionNumber ?? 0);
      if (r !== 0) return r;
      return toDate(b.createdAt).getTime() - toDate(a.createdAt).getTime();
    });
    const appt = appointmentMap[appointmentId];
    toUpdate.push({
      contractId: sorted[0].id,
      contractLinkSentAt: appt.contractEmailSentAt,
    });
  });

  console.log(`   Will set contractLinkSentAt on ${toUpdate.length} contract(s) (one per appointment).\n`);

  if (toUpdate.length === 0) {
    console.log('✅ Nothing to update. Exiting.');
    process.exit(0);
    return;
  }

  if (DRY_RUN) {
    console.log('Sample of contract IDs that would be updated (first 5):');
    toUpdate.slice(0, 5).forEach((u, i) => console.log(`   ${i + 1}. ${u.contractId}`));
    console.log('\n✅ Dry run complete. Run without DRY_RUN=1 to apply.');
    process.exit(0);
    return;
  }

  const BATCH_SIZE = 500;
  let updated = 0;
  for (let i = 0; i < toUpdate.length; i += BATCH_SIZE) {
    const batch = db.batch();
    toUpdate.slice(i, i + BATCH_SIZE).forEach(({ contractId, contractLinkSentAt }) => {
      batch.update(db.collection('contracts').doc(contractId), {
        contractLinkSentAt,
      });
      updated++;
    });
    await batch.commit();
  }

  console.log(`✅ Backfill complete. Updated ${updated} contract(s).`);
  process.exit(0);
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
