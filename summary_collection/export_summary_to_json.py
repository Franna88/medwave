#!/usr/bin/env python3
"""
Export the entire `summary` collection to a single JSON file.

The output file is intended as a safety backup before running summary migrations.
It will contain a plain mapping of:

{
  "<campaignId>": { ... full summary document ... },
  ...
}

Usage:
  python3 export_summary_to_json.py
"""

import os
import sys
import json
from datetime import datetime

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


def export_summary_to_json(output_dir: str) -> str:
    """
    Read all documents from `summary` and write them to a JSON file.

    Returns the path to the created JSON file.
    """
    db = init_firestore()

    print("=" * 80)
    print("EXPORT SUMMARY COLLECTION TO JSON")
    print("=" * 80)

    print("\nFetching documents from `summary` collection...")
    docs = db.collection("summary").stream()

    summary_data = {}
    total_campaigns = 0
    total_weeks = 0
    total_ads = 0

    for doc in docs:
        total_campaigns += 1
        data = doc.to_dict() or {}
        summary_data[doc.id] = data

        weeks = data.get("weeks", {}) or {}
        total_weeks += len(weeks)

        for week in weeks.values():
            ads = week.get("ads", {}) or {}
            total_ads += len(ads)

    print(f"\n✅ Loaded {total_campaigns} campaigns from `summary`")
    print(f"✅ Total weeks: {total_weeks}")
    print(f"✅ Total ads (across all weeks): {total_ads}")

    if not summary_data:
        print("\n⚠️  No documents found in `summary`. Nothing to export.")
        return ""

    # Ensure output directory exists
    os.makedirs(output_dir, exist_ok=True)

    timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
    filename = f"summary_backup_{timestamp}.json"
    output_path = os.path.join(output_dir, filename)

    print(f"\nWriting backup to: {output_path}")

    # Use indent for readability but avoid extremely large files by not sorting keys
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(summary_data, f, ensure_ascii=False, indent=2)

    print("\n✅ Export complete")
    print(f"   Backup file: {output_path}")
    print("=" * 80)

    return output_path


def main():
    """
    Main entry point.

    Optional argument: output directory (default: summary_collection/backups)
      python3 export_summary_to_json.py ./summary_collection/backups
    """
    if len(sys.argv) > 1:
        output_dir = sys.argv[1]
    else:
        # Default backup directory within the repo
        output_dir = os.path.join(
            os.path.dirname(__file__),
            "backups",
        )

    export_summary_to_json(output_dir)


if __name__ == "__main__":
    main()




