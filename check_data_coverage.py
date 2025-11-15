"""
Check data coverage for October and November 2025 across all collections
"""
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime
from collections import defaultdict

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('/Users/mac/dev/medwave/medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()

print("=" * 100)
print("DATA COVERAGE CHECK: OCTOBER vs NOVEMBER 2025")
print("=" * 100)
print()

def check_collection(collection_name, date_field='createdAt', month_field='month'):
    """Check a collection for October and November data"""
    print(f"Checking collection: {collection_name}")
    print("-" * 100)
    
    # Get all documents
    docs = list(db.collection(collection_name).stream())
    
    if len(docs) == 0:
        print(f"  ⚠️  EMPTY COLLECTION - No documents found")
        print()
        return
    
    oct_count = 0
    nov_count = 0
    no_month_field = 0
    oct_dates = []
    nov_dates = []
    
    for doc in docs:
        data = doc.to_dict()
        
        # Check if month field exists
        if month_field in data:
            month = data.get(month_field)
            if month == 'October':
                oct_count += 1
                if date_field in data:
                    oct_dates.append(data[date_field])
            elif month == 'November':
                nov_count += 1
                if date_field in data:
                    nov_dates.append(data[date_field])
        else:
            # Try to determine from date field
            if date_field in data:
                date_str = data.get(date_field)
                if date_str:
                    try:
                        # Handle both ISO format and other formats
                        if isinstance(date_str, str):
                            if '2025-10' in date_str:
                                oct_count += 1
                                oct_dates.append(date_str)
                            elif '2025-11' in date_str:
                                nov_count += 1
                                nov_dates.append(date_str)
                            else:
                                no_month_field += 1
                        else:
                            no_month_field += 1
                    except:
                        no_month_field += 1
            else:
                no_month_field += 1
    
    # Summary
    total = len(docs)
    print(f"  Total documents: {total}")
    print(f"  October 2025:    {oct_count} ({oct_count/total*100:.1f}%)")
    print(f"  November 2025:   {nov_count} ({nov_count/total*100:.1f}%)")
    
    if no_month_field > 0:
        print(f"  Other/Unknown:   {no_month_field} ({no_month_field/total*100:.1f}%)")
    
    # Date ranges
    if oct_dates:
        oct_dates_sorted = sorted(oct_dates)
        print(f"  October range:   {oct_dates_sorted[0][:10]} to {oct_dates_sorted[-1][:10]}")
    
    if nov_dates:
        nov_dates_sorted = sorted(nov_dates)
        print(f"  November range:  {nov_dates_sorted[0][:10]} to {nov_dates_sorted[-1][:10]}")
    
    # Warning if October seems low
    if nov_count > 0 and oct_count < nov_count * 0.5:
        print(f"  ⚠️  WARNING: October count is significantly lower than November!")
        print(f"     This suggests October data may not be fully populated.")
    
    if oct_count == 0:
        print(f"  ❌ ERROR: NO OCTOBER DATA FOUND!")
    
    if nov_count == 0:
        print(f"  ❌ ERROR: NO NOVEMBER DATA FOUND!")
    
    print()
    return {
        'total': total,
        'october': oct_count,
        'november': nov_count,
        'other': no_month_field
    }

# Check each collection
print()
results = {}

print("1. FACEBOOK ADS COLLECTION")
print("=" * 100)
results['fb_ads'] = check_collection('fb_ads', date_field='fetchedAt', month_field='month')

print("2. GHL OPPORTUNITIES COLLECTION")
print("=" * 100)
results['ghl_opportunities'] = check_collection('ghl_opportunities', date_field='createdAt', month_field='month')

print("3. GHL DATA (FORM SUBMISSIONS) COLLECTION")
print("=" * 100)
results['ghl_data'] = check_collection('ghl_data', date_field='createdAt', month_field='month')

print("4. GHL CONTACTS COLLECTION")
print("=" * 100)
results['ghl_contacts'] = check_collection('ghl_contacts', date_field='dateAdded', month_field='month')

# Summary table
print()
print("=" * 100)
print("SUMMARY TABLE")
print("=" * 100)
print()
print(f"{'Collection':<30} {'Total':<10} {'October':<12} {'November':<12} {'Status'}")
print("-" * 100)

for collection, data in results.items():
    if data:
        status = "✅ OK"
        if data['october'] == 0:
            status = "❌ NO OCT DATA"
        elif data['november'] > 0 and data['october'] < data['november'] * 0.5:
            status = "⚠️  OCT LOOKS LOW"
        
        print(f"{collection:<30} {data['total']:<10} {data['october']:<12} {data['november']:<12} {status}")
    else:
        print(f"{collection:<30} {'EMPTY':<10} {'-':<12} {'-':<12} {'❌ EMPTY'}")

print()
print("=" * 100)
print("RECOMMENDATIONS")
print("=" * 100)
print()

for collection, data in results.items():
    if data and data['october'] == 0:
        print(f"❌ {collection}: Run the October collection script")
        if collection == 'fb_ads':
            print(f"   → cd /Users/mac/dev/medwave/fb_ads_collection && python3 facebook_Oct.py")
        elif collection == 'ghl_opportunities':
            print(f"   → cd /Users/mac/dev/medwave/ghl_opp_collection && python3 ghl_opportunities_Oct.py")
        elif collection == 'ghl_data':
            print(f"   → cd /Users/mac/dev/medwave/ghl_data_collection && python3 ghl_Oct.py")
        elif collection == 'ghl_contacts':
            print(f"   → cd /Users/mac/dev/medwave/ghl_contacts_collection && python3 ghl_contacts_Oct.py")
    elif data and data['november'] > 0 and data['october'] < data['november'] * 0.5:
        print(f"⚠️  {collection}: October data seems incomplete (only {data['october']} vs {data['november']} in Nov)")
        print(f"   Consider re-running the October collection script")

print()

