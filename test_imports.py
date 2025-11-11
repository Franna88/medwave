#!/usr/bin/env python3
print("1. Starting...")

print("2. Importing firebase_admin...")
import firebase_admin
print("3. firebase_admin imported")

print("4. Importing credentials, firestore...")
from firebase_admin import credentials, firestore
print("5. credentials, firestore imported")

print("6. Initializing Firebase...")
if not firebase_admin._apps:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)
print("7. Firebase initialized")

print("8. Creating firestore client...")
db = firestore.client()
print("9. Firestore client created")

print("10. Testing query...")
months = list(db.collection('advertData').limit(1).stream())
print(f"11. Query successful! Found {len(months)} month(s)")

print("✅ All tests passed!")

