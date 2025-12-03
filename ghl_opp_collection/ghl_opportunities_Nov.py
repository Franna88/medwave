#!/usr/bin/env python3
"""
GHL Opportunities Collection - November 2025  
+ Lead Auto-Creation (for opportunities created from 2025-11-28T07:18:26.555Z onwards)

Full merged script including original functionality + new "create Lead" logic.
"""

import requests
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timedelta, timezone
import time
import json
import os

# Initialize Firebase
try:
    # Get the directory where this script is located
    script_dir = os.path.dirname(os.path.abspath(__file__))
    cred_path = os.path.join(script_dir, 'medx-ai-firebase-adminsdk-fbsvc-d88a6aa1a7.json')
    cred = credentials.Certificate(cred_path)
    firebase_admin.initialize_app(cred)
    print('✅ Firebase initialized successfully\n')
except Exception as e:
    print(f'⚠️  Firebase already initialized or error: {e}\n')
    pass

db = firestore.client()

# GHL API Configuration
GHL_API_KEY = 'pit-22f8af95-3244-41e7-9a52-22c87b166f5a'
GHL_LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw'
GHL_BASE_URL = 'https://services.leadconnectorhq.com'
GHL_API_VERSION = '2021-07-28'

# Pipeline IDs (Only Andries and Davide)
ANDRIES_PIPELINE_ID = 'XeAGJWRnUGJ5tuhXam2g'
DAVIDE_PIPELINE_ID = 'AUduOJBB2lxlsEaNmlJz'

# Date range will be calculated dynamically (yesterday and today in SA timezone)

# Stage mappings (UNCHANGED — full original dictionary)
STAGE_MAPPINGS = {
    'andries': {
        "9861ef30-81b6-49dc-ba4b-061ef194dcf9": "Booked Appointments",
        "00567f7d-293b-4438-8172-76531a225b76": "Call Completed",
        "0c0295b4-de16-41c1-94a2-e10ba396b55f": "No Show",
        "e1fc9820-f8b2-47b2-94d1-e245735cb2af": "Reschedule",
        "4bb7f632-aafc-4583-acd1-4e2875b590e3": "Follow Up Day 1",
        "a948f859-581e-48cf-b4d1-9ddd153bcdb5": "Follow Up Day 2",
        "dfa4be3d-d313-40b5-9ce9-6fac713d75c0": "Follow Up Day 3",
        "c2c86962-4d3e-42de-892e-b413e32f4f81": "Follow Up Day 4",
        "895d3cdd-b7a3-489d-9431-cc2b3d96b3fa": "Follow Up Day 5",
        "7b5cbe61-76ff-4776-9144-c71942daeaed": "Follow Up Day 6",
        "22c12a3a-a131-458c-b5a4-132ce568e105": "Follow Up Day 7",
        "b008f699-0ebf-43f6-9dc4-14efd430be48": "Follow Up Day 8",
        "e73275e7-7527-497e-b449-91ee245b5bf9": "Follow Up Day 9",
        "3eae3984-2343-43d8-96a4-6502e7f37af7": "Follow Up Day 10",
        "6e763bab-3ffb-4f5b-902f-a3dba5cc39c8": "Follow Up Day 11",
        "98afdd3c-2865-4015-a24c-692ac7daa220": "Follow Up Day 12",
        "0aa7f895-557d-4f53-a3d8-29b4f9805238": "Follow Up Day 13",
        "77c46b81-5a95-40ee-a7a9-36a5d5fdf7ae": "Follow Up Day 14",
        "190ec8c7-7673-4d8d-8ab4-b4cd6952f926": "Follow Up Day 15",
        "c861b50f-b0cc-4ee2-b8e7-03d81b32f53b": "Follow Up Day 16",
        "b4dbc120-12e2-4215-b4fa-3f51be8591cb": "Follow Up Day 17",
        "405640a0-2ba6-4025-828d-212347aede66": "Follow Up Day 18",
        "0700f5c9-0b70-420c-b52b-4107e30a850c": "Follow Up Day 19",
        "8ff3ec64-2058-422a-a52f-8a1ce9451a8f": "Follow Up Day 20",
        "4df5b2d3-b6fb-478c-96b4-a8c565c69940": "9. Long Term Leads (Twice Per Week)",
        "f82c7a4f-aceb-4657-9007-76c1c92641d2": "10. Andries Upfront Disqualified",
        "52a076ca-851f-43fc-a57d-309403a4b208": "Deposit Received",
        "3a8ead84-92b0-4796-aaf8-6594c3217a2c": "Cash Collected",
        "0b3e496e-cb24-4fdb-8d4f-7c5c84e94aae": "12. DND Leads👎",
        "89c988f9-f8af-4b3d-8109-66984a81d1f7": "13. USA Sales Calls Completed"
    },
    'davide': {
        "003d5559-d057-4e9b-8a77-525acecfb6c8": "Booked Appointments",
        "f38bbbc9-93e2-4e74-8238-f8bb456aaa92": "Call Completed",
        "90057d46-3e3a-4e6a-8134-e823c2a9cbea": "No Show/Cancelled/Disqualified",
        "246be3bc-ecc8-4981-ab33-d08842b5fdf9": "Follow Up Day 1",
        "6765b763-f44b-4f20-bb19-7df3b22dbf3f": "Follow Up Day 2",
        "099fa206-a8a1-4a1b-96bb-d03779846148": "Follow Up Day 3",
        "11876e11-62c6-4b3c-bc24-042515209273": "Follow Up Day 4",
        "3d5e8c67-c469-404c-adf5-dce22cc09dba": "Follow Up Day 5",
        "d30da05d-995d-406f-8ccc-974290eb4aa8": "Follow Up Day 6",
        "b545d3e1-8a20-4f1d-98b7-d1d58d7a4aaf": "Follow Up Day 7",
        "4048b4c4-91c4-49e0-9238-e39963739b38": "(DD) FU - Long Term",
        "13d54d18-d1e7-476b-aad8-cb4767b8b979": "Deposit Received",
        "3c89afba-9797-4b0f-947c-ba00b60468c6": "Cash Collected",
        "bf84e424-6e90-46a7-886f-a90eed27bbe6": "(DD) Leads",
        "c9c5cdfb-23c4-45d1-bd66-b11cbe33b449": "Lost"
    }
}

# ---------------------------------------
# NEW HELPERS FOR LEADS
# ---------------------------------------

# SA timezone is UTC+2
SA_UTC_OFFSET = timedelta(hours=2)

def get_sa_time(utc_dt=None):
    """Convert UTC datetime to SA time (UTC+2)."""
    if utc_dt is None:
        utc_dt = datetime.now(timezone.utc)
    return utc_dt + SA_UTC_OFFSET

def is_after_cutoff_time(iso_str):
    """Check if GHL createdAt is after 2025-11-28T07:18:26.555Z."""
    try:
        dt = datetime.fromisoformat(iso_str.replace("Z", "+00:00"))
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        
        # Cutoff time: 2025-11-28T07:18:26.555Z (last entry in leads collection)
        cutoff_time = datetime(2025, 11, 28, 7, 18, 26, 555000, tzinfo=timezone.utc)
        
        return dt > cutoff_time
    except:
        return False

def split_name(full_name):
    if not full_name:
        return ("", "")
    parts = full_name.strip().split()
    if len(parts) == 1:
        return (parts[0], "")
    return (parts[0], " ".join(parts[1:]))

def extract_utm(attributions):
    """Extract UTM parameters from GHL attributions array.
    
    GHL attributions have UTM fields directly on the attribution object.
    Returns a dict with Lead model UTM field names.
    """
    if not attributions or not isinstance(attributions, list):
        return {
            "utmSource": None,
            "utmMedium": None,
            "utmCampaign": None,
            "utmCampaignId": None,
            "utmAdset": None,
            "utmAdsetId": None,
            "utmAd": None,
            "utmAdId": None,
            "fbclid": None
        }
    
    # Get the last attribution (most recent) - check for isLast flag first
    last_attr = None
    for attr in attributions:
        if attr.get("isLast"):
            last_attr = attr
            break
    
    # If no isLast found, use the last item in array
    if not last_attr and attributions:
        last_attr = attributions[-1]
    
    if not last_attr:
        return {
            "utmSource": None,
            "utmMedium": None,
            "utmCampaign": None,
            "utmCampaignId": None,
            "utmAdset": None,
            "utmAdsetId": None,
            "utmAd": None,
            "utmAdId": None,
            "fbclid": None
        }
    
    # Extract UTM fields directly from attribution object
    # Map GHL attribution fields to Lead model fields
    return {
        "utmSource": last_attr.get("utmSource"),
        "utmMedium": last_attr.get("utmMedium"),
        "utmCampaign": last_attr.get("utmCampaign"),
        "utmCampaignId": last_attr.get("utmCampaignId"),
        "utmAdset": last_attr.get("utmMedium"),  # Ad set name is in utmMedium
        "utmAdsetId": last_attr.get("utmAdSetId") or last_attr.get("fbc_id") or last_attr.get("fbcId"),
        "utmAd": last_attr.get("utmContent"),  # Ad name is in utmContent
        "utmAdId": last_attr.get("utmAdId") or last_attr.get("h_ad_id") or last_attr.get("hAdId") or last_attr.get("adId"),
        "fbclid": last_attr.get("fbclid")
    }

# ---------------------------------------------------------------
# ORIGINAL FUNCTIONS (UNCHANGED)
# ---------------------------------------------------------------

def get_ghl_headers():
    return {
        'Authorization': f'Bearer {GHL_API_KEY}',
        'Version': GHL_API_VERSION,
        'Content-Type': 'application/json'
    }

def get_stage_name(pipeline_id, stage_id):
    if pipeline_id == ANDRIES_PIPELINE_ID:
        return STAGE_MAPPINGS['andries'].get(stage_id, 'Unknown Stage')
    elif pipeline_id == DAVIDE_PIPELINE_ID:
        return STAGE_MAPPINGS['davide'].get(stage_id, 'Unknown Stage')
    return 'Unknown Stage'

# ---------------------------------------------------------------
# MAIN SCRIPT (FULL ORIGINAL + NEW LEAD LOGIC)
# ---------------------------------------------------------------

def fetch_all_november_opportunities():
    # Calculate date range: From last entry (2025-11-28T07:18:26.555Z) to now
    # Start time: 2025-11-28T07:18:26.555Z (last entry in leads collection)
    START_DATE = "2025-11-28T07:18:26.555Z"
    
    # End time: Current time
    now_utc = datetime.now(timezone.utc)
    END_DATE = now_utc.strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3] + 'Z'
    
    print("="*80)
    print("GHL OPPORTUNITIES COLLECTION - FROM LAST ENTRY TO NOW")
    print("="*80 + "\n")

    print(f"📅 Date Range: {START_DATE} to {END_DATE}")
    print(f"🎯 Location ID: {GHL_LOCATION_ID}")
    print(f"📊 API Version: {GHL_API_VERSION}")
    print(f"👥 Pipelines: Andries & Davide ONLY\n")

    # ---------------------------
    # STEP 1: FETCH OPPORTUNITIES
    # ---------------------------
    print("="*80)
    print("STEP 1: FETCHING ALL OPPORTUNITIES FROM GHL")
    print("="*80 + "\n")

    url = f"{GHL_BASE_URL}/opportunities/search"
    all_opportunities = []

    params = {"location_id": GHL_LOCATION_ID, "limit": 100, "page": 1}
    page = 1

    while True:
        print(f"📄 Fetching page {page}...")
        params["page"] = page

        try:
            response = requests.get(url, headers=get_ghl_headers(), params=params, timeout=30)

            if response.status_code == 429:
                print("⚠️ Rate limit hit, waiting 60 seconds...")
                time.sleep(60)
                continue

            response.raise_for_status()
            data = response.json()
            opportunities = data.get("opportunities", [])

            if not opportunities:
                print("   ✅ No more opportunities found\n")
                break

            all_opportunities.extend(opportunities)
            print(f"   Found {len(opportunities)} opportunities on this page")

            meta = data.get("meta", {})
            total = meta.get("total", 0)
            if page * 100 >= total:
                print(f"   ✅ Reached last page (Total: {total})\n")
                break

            page += 1
            time.sleep(0.5)

        except Exception as e:
            print(f"❌ Error fetching opportunities: {e}")
            break

    print(f"✅ Total opportunities fetched: {len(all_opportunities)}\n")

    # ---------------------
    # STEP 2: FILTER FROM LAST ENTRY TO NOW
    # ---------------------
    print("="*80)
    print("STEP 2: FILTERING FOR OPPORTUNITIES AFTER LAST ENTRY")
    print("="*80 + "\n")

    recent_opportunities = []
    for o in all_opportunities:
        created = o.get("createdAt", "")
        if created and START_DATE < created <= END_DATE:
            recent_opportunities.append(o)

    print(f"✅ Opportunities after last entry: {len(recent_opportunities)}\n")

    # -------------------------------
    # STEP 3: FILTER PIPELINES
    # -------------------------------
    print("="*80)
    print("STEP 3: FILTERING FOR ANDRIES & DAVIDE PIPELINES")
    print("="*80 + "\n")

    andries_davide_opportunities = [
        o for o in recent_opportunities
        if o.get("pipelineId") in (ANDRIES_PIPELINE_ID, DAVIDE_PIPELINE_ID)
    ]

    print(f"📊 Total to store: {len(andries_davide_opportunities)}\n")

    # -------------------------------
    # STEP 4: STORE IN FIRESTORE
    # -------------------------------
    print("="*80)
    print('STEP 4: STORING IN FIRESTORE COLLECTION "ghl_opportunities"')
    print("="*80 + "\n")

    stored_count = 0

    for opp in andries_davide_opportunities:
        try:
            contact_id = opp.get("contactId")
            if not contact_id:
                print("⚠️ Skipped: no contactId")
                continue

            opportunity_id = opp.get("id")
            name = opp.get("name", "")
            monetary_value = opp.get("monetaryValue", 0)
            pipeline_id = opp.get("pipelineId")
            stage_id = opp.get("pipelineStageId")
            status = opp.get("status", "")
            created_at = opp.get("createdAt", "")
            updated_at = opp.get("updatedAt", "")
            source = opp.get("source", "")
            attributions = opp.get("attributions", [])
            contact = opp.get("contact", {})

            contact_name = contact.get("name", name)
            contact_email = contact.get("email", "")
            contact_phone = contact.get("phone", "")

            stage_name = get_stage_name(pipeline_id, stage_id)

            # --- STORE GHL OPPORTUNITY (unchanged)
            doc_data = {
                "opportunityId": opportunity_id,
                "contactId": contact_id,
                "name": name,
                "contactName": contact_name,
                "contactEmail": contact_email,
                "contactPhone": contact_phone,
                "monetaryValue": monetary_value,
                "pipelineId": pipeline_id,
                "pipelineStageId": stage_id,
                "stageName": stage_name,
                "status": status,
                "source": source,
                "createdAt": created_at,
                "updatedAt": updated_at,
                "attributions": attributions,
                "fullOpportunity": opp,
                "fetchedAt": datetime.now().isoformat(),
                "dateRange": {"start": START_DATE, "end": END_DATE}
            }

            db.collection("ghl_opportunities").document(contact_id).set(doc_data)
            stored_count += 1
            print(f"✅ Stored Opportunity {stored_count}: {name[:30]}")

            # -------------------------------------------------------------------
            # NEW: CREATE LEAD if createdAt is after cutoff time (2025-11-28T07:18:26.555Z)
            # -------------------------------------------------------------------
            if is_after_cutoff_time(created_at):

                print(f"➡️ Creating LEAD for contactId {contact_id} (created after cutoff time)")

                # Split name
                first_name, last_name = split_name(contact_name)

                # Extract UTM from attributions
                utm = extract_utm(attributions)

                # Get timestamps as ISO strings
                # Use opportunity createdAt if available, otherwise use current time
                try:
                    if created_at:
                        # Use the opportunity's createdAt time
                        created_timestamp_str = created_at
                    else:
                        # Use current time in ISO format
                        created_timestamp_str = datetime.now(timezone.utc).isoformat()
                except:
                    created_timestamp_str = datetime.now(timezone.utc).isoformat()

                # Current time as ISO string
                now_timestamp_str = datetime.now(timezone.utc).isoformat()

                # Create stage history entry
                stage_history = [{
                    "stage": "new_lead",
                    "enteredAt": now_timestamp_str,
                    "exitedAt": None,
                    "note": None
                }]

                lead_data = {
                    "id": contact_id,
                    "firstName": first_name,
                    "lastName": last_name,
                    "email": contact_email,
                    "phone": contact_phone,
                    "source": source or "ghl",
                    "channelId": "new_leads",
                    "currentStage": "new_lead",
                    "createdAt": created_timestamp_str,
                    "updatedAt": now_timestamp_str,
                    "stageEnteredAt": now_timestamp_str,
                    "stageHistory": stage_history,
                    "notes": [],
                    "createdBy": "ghl_opportunities",
                    "createdByName": "GHL Opportunities",
                    "ghlOpportunityId": opportunity_id,
                    # UTM fields as individual top-level fields
                    "utmSource": utm["utmSource"],
                    "utmMedium": utm["utmMedium"],
                    "utmCampaign": utm["utmCampaign"],
                    "utmCampaignId": utm["utmCampaignId"],
                    "utmAdset": utm["utmAdset"],
                    "utmAdsetId": utm["utmAdsetId"],
                    "utmAd": utm["utmAd"],
                    "utmAdId": utm["utmAdId"],
                    "fbclid": utm["fbclid"]
                }

                db.collection("leads").document(contact_id).set(lead_data)
                print(f"   ➕ Lead created: {first_name} {last_name}")

            # -------------------------------------------------------------------

        except Exception as e:
            print(f"❌ Error storing opportunity or creating lead: {e}")

    # SUMMARY
    print("\n" + "="*80)
    print("COMPLETE")
    print("="*80)
    print(f"Stored opportunities: {stored_count}\n")


if __name__ == "__main__":
    fetch_all_november_opportunities()
