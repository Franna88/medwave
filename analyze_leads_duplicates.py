#!/usr/bin/env python3
"""
Analyze Facebook Leads CSV for duplicates
"""

import pandas as pd
from collections import defaultdict
import sys

def analyze_duplicates(csv_file):
    """Analyze the leads CSV file for duplicates"""
    
    print(f"Analyzing: {csv_file}\n")
    print("=" * 80)
    
    # Read the CSV file with tab delimiter
    # Try different encodings
    encodings = ['utf-8', 'utf-16', 'utf-16-le', 'utf-16-be', 'latin-1', 'iso-8859-1']
    df = None
    for encoding in encodings:
        try:
            df = pd.read_csv(csv_file, sep='\t', encoding=encoding)
            print(f"Successfully read file with encoding: {encoding}\n")
            break
        except UnicodeDecodeError:
            continue
        except Exception as e:
            print(f"Failed with {encoding}: {e}")
            continue
    
    if df is None:
        raise ValueError("Could not read file with any supported encoding")
    
    print(f"Total leads: {len(df)}\n")
    
    # 1. Check for duplicate IDs (should be unique)
    print("1. DUPLICATE IDs (lead IDs should be unique)")
    print("-" * 80)
    duplicate_ids = df[df.duplicated(subset=['id'], keep=False)]
    if len(duplicate_ids) > 0:
        print(f"Found {len(duplicate_ids)} records with duplicate IDs:")
        for id_val in duplicate_ids['id'].unique():
            print(f"  - ID: {id_val}")
        print()
    else:
        print("✓ No duplicate IDs found\n")
    
    # 2. Check for duplicate emails
    print("2. DUPLICATE EMAILS")
    print("-" * 80)
    # Filter out empty emails
    df_with_email = df[df['email'].notna() & (df['email'] != '')]
    duplicate_emails = df_with_email[df_with_email.duplicated(subset=['email'], keep=False)]
    if len(duplicate_emails) > 0:
        print(f"Found {len(duplicate_emails)} records with duplicate emails:")
        email_groups = duplicate_emails.groupby('email')
        for email, group in email_groups:
            print(f"\n  Email: {email}")
            print(f"  Count: {len(group)}")
            for _, row in group.iterrows():
                print(f"    - ID: {row['id']}, Name: {row['first_name']} {row['last_name']}, Date: {row['created_time']}")
        print()
    else:
        print("✓ No duplicate emails found\n")
    
    # 3. Check for duplicate phone numbers
    print("3. DUPLICATE PHONE NUMBERS")
    print("-" * 80)
    # Filter out empty phone numbers
    df_with_phone = df[df['phone_number'].notna() & (df['phone_number'] != '')]
    duplicate_phones = df_with_phone[df_with_phone.duplicated(subset=['phone_number'], keep=False)]
    if len(duplicate_phones) > 0:
        print(f"Found {len(duplicate_phones)} records with duplicate phone numbers:")
        phone_groups = duplicate_phones.groupby('phone_number')
        for phone, group in phone_groups:
            print(f"\n  Phone: {phone}")
            print(f"  Count: {len(group)}")
            for _, row in group.iterrows():
                print(f"    - ID: {row['id']}, Name: {row['first_name']} {row['last_name']}, Email: {row['email']}, Date: {row['created_time']}")
        print()
    else:
        print("✓ No duplicate phone numbers found\n")
    
    # 4. Check for duplicate email AND phone (same person)
    print("4. DUPLICATE EMAIL + PHONE (Same Person)")
    print("-" * 80)
    df_with_both = df[(df['email'].notna() & (df['email'] != '')) & 
                      (df['phone_number'].notna() & (df['phone_number'] != ''))]
    duplicate_both = df_with_both[df_with_both.duplicated(subset=['email', 'phone_number'], keep=False)]
    if len(duplicate_both) > 0:
        print(f"Found {len(duplicate_both)} records with duplicate email+phone combinations:")
        both_groups = duplicate_both.groupby(['email', 'phone_number'])
        for (email, phone), group in both_groups:
            print(f"\n  Email: {email}, Phone: {phone}")
            print(f"  Count: {len(group)}")
            for _, row in group.iterrows():
                print(f"    - ID: {row['id']}, Name: {row['first_name']} {row['last_name']}, Date: {row['created_time']}")
        print()
    else:
        print("✓ No duplicate email+phone combinations found\n")
    
    # 5. Check for similar names with same phone or email (potential duplicates)
    print("5. SIMILAR NAMES WITH SAME CONTACT INFO")
    print("-" * 80)
    # Create full name column
    df['full_name'] = df['first_name'].str.lower().str.strip() + ' ' + df['last_name'].str.lower().str.strip()
    
    # Group by phone or email and check for different names
    potential_duplicates = []
    
    # Check by phone
    for phone, group in df_with_phone.groupby('phone_number'):
        if len(group) > 1:
            names = group['full_name'].unique()
            if len(names) > 1:
                potential_duplicates.append({
                    'type': 'phone',
                    'value': phone,
                    'records': group
                })
    
    # Check by email
    for email, group in df_with_email.groupby('email'):
        if len(group) > 1:
            names = group['full_name'].unique()
            if len(names) > 1:
                potential_duplicates.append({
                    'type': 'email',
                    'value': email,
                    'records': group
                })
    
    if potential_duplicates:
        print(f"Found {len(potential_duplicates)} cases of same contact info with different names:")
        for dup in potential_duplicates:
            print(f"\n  Same {dup['type']}: {dup['value']}")
            print(f"  Different names found:")
            for _, row in dup['records'].iterrows():
                print(f"    - ID: {row['id']}, Name: {row['first_name']} {row['last_name']}, Date: {row['created_time']}")
        print()
    else:
        print("✓ No mismatched names found\n")
    
    # 6. Summary statistics
    print("6. SUMMARY STATISTICS")
    print("-" * 80)
    print(f"Total leads: {len(df)}")
    print(f"Unique emails: {df['email'].nunique()}")
    print(f"Unique phone numbers: {df['phone_number'].nunique()}")
    print(f"Unique campaigns: {df['campaign_name'].nunique()}")
    print(f"Unique ad sets: {df['adset_name'].nunique()}")
    print(f"Unique ads: {df['ad_name'].nunique()}")
    print(f"\nPlatform distribution:")
    print(df['platform'].value_counts())
    print(f"\nLead status distribution:")
    print(df['lead_status'].value_counts())
    print("\n" + "=" * 80)


if __name__ == "__main__":
    csv_file = "/Users/mac/Downloads/Obesity - DDM_Leads_2025-10-16_2025-10-27.csv"
    
    if len(sys.argv) > 1:
        csv_file = sys.argv[1]
    
    try:
        analyze_duplicates(csv_file)
    except Exception as e:
        print(f"Error analyzing file: {e}")
        import traceback
        traceback.print_exc()

