#!/usr/bin/env python3
"""
Backfill `adSetId` into summary.weeks[weekId].ads[adId] entries.

This script is intended as a one-time migration to make ad set-level
summary queries accurate (e.g. SummaryService.getAdIdsWithActivityInDateRange).

Safety:
  1. Run `export_summary_to_json.py` first to create a JSON backup.
  2. Start with a DRY RUN to see how many ads would be updated:
       python3 backfill_summary_adsetid.py --dry-run
  3. When satisfied and backup exists, run:
       python3 backfill_summary_adsetid.py --confirm-backup

Flags:
  --dry-run         : Do not write any changes, just print statistics.
  --confirm-backup  : Required for real writes (asserts you've taken a backup).
"""

import os
import sys
from typing import Dict, Any, Tuple

import firebase_admin
from firebase_admin import credentials, firestore

# NOTE: Update this path if your service account JSON lives elsewhere.
FIREBASE_CRED_PATH = os.path.join(
    os.path.dirname(__file__),
    "medx-ai-firebase-adminsdk-fbsvc-d88a6aa1a7.json"
)


def init_firestore():
    """Initialise Firebase Admin and return a Firestore client."""
    if not firebase_admin._apps:
        cred = credentials.Certificate(FIREBASE_CRED_PATH)
        firebase_admin.initialize_app(cred)
    return firestore.client()


def load_fb_ads_adset_map(db) -> Dict[str, str]:
    """
    Load all fb_ads documents and build a mapping:
      { adId: adSetId }

    We prefer adDetails.adsetId but fall back to insightsDaily/adset_id
    if needed, mirroring logic in rebuild_summary_from_firebase.py.
    """
    print("\n" + "=" * 80)
    print("STEP 1: LOADING fb_ads ADSET MAP")
    print("=" * 80)

    fb_ads_ref = db.collection("fb_ads")
    docs = fb_ads_ref.stream()

    ad_to_adset: Dict[str, str] = {}
    total_ads = 0
    adset_found = 0

    for doc in docs:
        total_ads += 1
        data = doc.to_dict() or {}
        ad_id = doc.id

        ad_details = data.get("adDetails", {}) or {}
        insights = data.get("insightsDaily", []) or []

        adset_id = ad_details.get("adSetId") or ad_details.get("adsetId")
        if not adset_id and insights:
            first_insight = insights[0]
            adset_id = (
                first_insight.get("adset_id")
                or first_insight.get("adSetId")
                or first_insight.get("adsetId")
            )

        if adset_id:
            ad_to_adset[ad_id] = str(adset_id)
            adset_found += 1

    print(f"\n✅ Scanned {total_ads} fb_ads documents")
    print(f"✅ Found adSetId for {adset_found} ads")
    print(f"⚠️  Missing adSetId for {total_ads - adset_found} ads")

    return ad_to_adset


def backfill_adsetid_in_summary(db, ad_to_adset: Dict[str, str], dry_run: bool) -> Tuple[int, int, int]:
    """
    For each summary document, walk its weeks.ads and set adSetId when possible.

    Returns (campaigns_processed, ads_seen, ads_updated).
    """
    print("\n" + "=" * 80)
    print("STEP 2: BACKFILL adSetId INTO SUMMARY")
    print("=" * 80)

    summary_ref = db.collection("summary")
    docs = summary_ref.stream()

    campaigns_processed = 0
    ads_seen = 0
    ads_updated = 0

    for doc in docs:
        campaign_id = doc.id
        campaign_data = doc.to_dict() or {}
        weeks = campaign_data.get("weeks", {}) or {}

        if not weeks:
            continue

        campaigns_processed += 1
        campaign_ads_seen = 0
        campaign_ads_updated = 0

        print(f"\nCampaign {campaign_id}: {campaign_data.get('campaignName', '')}")

        # Work on a shallow copy of weeks; weekData and ads maps will be mutated in-place.
        weeks_changed = False

        for week_id, week_data in weeks.items():
            ads = (week_data or {}).get("ads", {}) or {}
            if not ads:
                continue

            for ad_id, ad_entry in ads.items():
                campaign_ads_seen += 1
                ads_seen += 1

                ad_entry = ad_entry or {}
                existing = ad_entry.get("adSetId")
                if existing:
                    # Already has adSetId, leave as-is.
                    continue

                adset_id = ad_to_adset.get(ad_id)
                if not adset_id:
                    # No mapping available from fb_ads.
                    continue

                # Set adSetId in-place.
                ad_entry["adSetId"] = adset_id
                ads[ad_id] = ad_entry
                campaign_ads_updated += 1
                ads_updated += 1
                weeks_changed = True

        if campaign_ads_seen == 0:
            print("  ⚠️  No ads found in weeks; skipping")
            continue

        print(
            f"  Ads inspected: {campaign_ads_seen}, "
            f"updated with adSetId: {campaign_ads_updated}"
        )

        if weeks_changed and not dry_run:
            # Single update per campaign document to minimise writes.
            summary_ref.document(campaign_id).update({"weeks": weeks})
            print("  ✅ Updated summary document with new adSetId values")
        elif weeks_changed and dry_run:
            print("  ✅ Would update summary document (dry run)")

    print("\n" + "=" * 80)
    print("BACKFILL COMPLETE")
    print("=" * 80)
    print(f"Campaigns processed: {campaigns_processed}")
    print(f"Ads inspected: {ads_seen}")
    print(f"Ads updated with adSetId: {ads_updated}")

    return campaigns_processed, ads_seen, ads_updated


def main():
    dry_run = "--dry-run" in sys.argv
    confirm_backup = "--confirm-backup" in sys.argv

    print("=" * 80)
    print("BACKFILL SUMMARY ADSETID MIGRATION")
    print("=" * 80)
    print(f"Dry run: {dry_run}")

    if not dry_run and not confirm_backup:
        print(
            "\n❌ Safety check failed: you must pass --confirm-backup "
            "to run this migration for real.\n"
            "   Example:\n"
            "     python3 backfill_summary_adsetid.py --confirm-backup\n"
            "   (Make sure you've run export_summary_to_json.py first.)"
        )
        sys.exit(1)

    db = init_firestore()

    # Step 1: build adId -> adSetId map from fb_ads
    ad_to_adset = load_fb_ads_adset_map(db)

    # Step 2: backfill into summary.weeks[...].ads[...]
    backfill_adsetid_in_summary(db, ad_to_adset, dry_run=dry_run)

    if dry_run:
        print("\n⚠️  DRY RUN ONLY - no changes were written to Firestore.")
    else:
        print("\n✅ Migration finished and changes were written to Firestore.")


if __name__ == "__main__":
    main()




