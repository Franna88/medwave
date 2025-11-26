# README — Custom Facebook Ads Form (capture UTMs & FB IDs)

Create a Flutter web form that reads URL query parameters (UTMs + `fbclid` + FB ad ids) and saves them with the lead to your own backend database. Marketing will append the UTM query string to the ad links (you don’t need to modify ads). Do *not* forward leads to GHL.

---

## Purpose

This repo/docs show a clear, repeatable workflow for:

1. Building a Flutter web form that reads and preserves incoming query parameters.
2. Persisting leads and their tracking data (UTMs, `fbclid`, `ad_id`, `adset_id`, `campaign_id`) to your own backend and database.
3. Testing and QA so marketing can safely append UTM strings later.

This doc assumes the marketing team will add the full query string to the ad URLs after the form exists.

---

## Quick architecture overview

* **Facebook ad** → link with query params appended by Marketing → **Flutter web form** (reads params & user input) → **POST** to **your backend API** → **Database** (leads table)

No 3rd-party forwarding — everything stored in your system.

---

## What Marketing needs to provide (required keys)

When marketing creates ad links they must append (example keys):

* `utm_source` (e.g. `facebook`)
* `utm_medium` (e.g. `cpc`)
* `utm_campaign` (campaign name)
* `utm_campaign_id` (campaign id)
* `utm_adset` (ad set name)
* `utm_adset_id` (ad set id)
* `utm_ad` (ad name)
* `utm_ad_id` (ad id)
* `fbclid` (facebook click id — optional but recommended)

**Example marketing link** (they will add exact values):

```
https://app.example.com/lead-form?utm_source=facebook&utm_medium=cpc&utm_campaign=BlackFri&utm_campaign_id=12345&utm_adset=Retarget&utm_adset_id=2222&utm_ad=HeroImage&utm_ad_id=3333&fbclid={fbclid}
```

> Marketing should use Facebook macros for dynamic values (`{{campaign.id}}`, etc.) when creating the creative.

---

## Step-by-step implementation guide (developer)

### 1) Create the Flutter web form page

**Goal:** Render form fields + capture query params from the browser URL and persist them in the form state.

**File:** `frontend/lib/pages/lead_form.dart`

**Essential behavior:**

* On load, read `Uri.base.queryParameters`.
* Map the expected keys into a `tracking` map.
* Keep tracking values in hidden fields or as part of the form state.
* When user submits, include `tracking` keys in the submission JSON.

**Minimal example (Flutter - key lines only):**

```dart
// frontend/lib/pages/lead_form.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class LeadFormPage extends StatefulWidget {
  @override
  _LeadFormPageState createState() => _LeadFormPageState();
}

class _LeadFormPageState extends State<LeadFormPage> {
  final _formKey = GlobalKey<FormState>();
  String name = '';
  String email = '';
  Map<String, String?> tracking = {};

  @override
  void initState() {
    super.initState();
    final params = Uri.base.queryParameters; // read query params
    tracking = {
      'utm_source': params['utm_source'],
      'utm_medium': params['utm_medium'],
      'utm_campaign': params['utm_campaign'],
      'utm_campaign_id': params['utm_campaign_id'],
      'utm_adset': params['utm_adset'],
      'utm_adset_id': params['utm_adset_id'],
      'utm_ad': params['utm_ad'],
      'utm_ad_id': params['utm_ad_id'],
      'fbclid': params['fbclid'],
    };
  }

  Future<void> submitLead() async {
    final payload = {
      'name': name,
      'email': email,
      'tracking': tracking,
    };

    final res = await http.post(
      Uri.parse('https://api.example.com/leads'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (res.statusCode == 201) {
      // success
    } else {
      // handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(onSaved: (v) => name = v ?? ''),
            TextFormField(onSaved: (v) => email = v ?? ''),
            ElevatedButton(
              onPressed: () {
                _formKey.currentState!.save();
                submitLead();
              },
              child: Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
```

> Keep tracking fields readonly and hidden from users in the UI, but store them in state and send them in the POST.

### 2) Backend API — receive and save leads

**Goal:** Accept `POST /leads` with user data + `tracking` map. Save to DB.

**File:** `backend/src/server.js` (Node + Express example)

**Minimal example (Node.js + Express + PostgreSQL):**

```js
// backend/src/server.js
const express = require('express');
const bodyParser = require('body-parser');
const { Pool } = require('pg');
const app = express();
app.use(bodyParser.json());

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

app.post('/leads', async (req, res) => {
  const { name, email, tracking } = req.body;
  try {
    const insert = `INSERT INTO leads (name, email, tracking, created_at) VALUES ($1, $2, $3, now()) RETURNING id`;
    const result = await pool.query(insert, [name, email, tracking]);
    res.status(201).json({ id: result.rows[0].id });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'server_error' });
  }
});

app.listen(process.env.PORT || 3000);
```

**Notes:**

* We store the whole `tracking` object as JSON (Postgres `jsonb` recommended).
* Validate all required fields before insert (not shown for brevity).

### 3) Database schema

**File:** `backend/db/migrations/001_create_leads.sql`

```sql
CREATE TABLE leads (
  id serial PRIMARY KEY,
  name varchar(255),
  email varchar(255),
  phone varchar(50),
  tracking jsonb,
  created_at timestamptz DEFAULT now()
);
```

`tracking` JSON should contain UTM keys and any Facebook IDs.

### 4) Admin dashboard — how to show tracking

* Show tracking JSON fields as columns in your admin table (or expand row to see JSON).
* Important columns: `utm_source`, `utm_campaign`, `utm_campaign_id`, `utm_ad_id`, `fbclid`, `created_at`.
* Provide filters: `utm_campaign_id`, `utm_ad_id`, date range.

### 5) Testing checklist (must do before handing to Marketing)

1. Build & deploy the Flutter page.
2. Create a test link with a sample query string. Example:

```
https://app.example.com/lead-form?utm_source=facebook&utm_medium=cpc&utm_campaign=test123&utm_campaign_id=999&utm_adset=adsetA&utm_adset_id=888&utm_ad=testAd&utm_ad_id=777&fbclid=testfbclid
```

3. Open link in browser — verify the form loads and `Uri.base.queryParameters` contains the values.
4. Submit the form. Confirm backend receives the POST with a `tracking` object.
5. Confirm DB row contains the `tracking` JSON and expected values.
6. Verify admin dashboard displays tracking values and filters/sorts properly.

### 6) Edge cases & hardening

* **User removes params**: store a `source` default (e.g. `organic`) if `utm_source` absent.
* **Repeated visits**: If you want multi-touch attribution, store raw URL and `referrer` in DB.
* **Bots / malformed params**: validate string lengths and acceptable characters.
* **Offline capture**: If user loses connection, cache form locally and retry submission.

### 7) Privacy & consent

* Show explicit consent checkbox (GDPR/CCPA). Save consent flags with the lead.
* Don’t store personal data longer than required.

### 8) Example payload (what backend receives)

```json
POST /leads
Content-Type: application/json

{
  "name": "Jane Doe",
  "email": "jane@example.com",
  "tracking": {
    "utm_source": "facebook",
    "utm_medium": "cpc",
    "utm_campaign": "BlackFri",
    "utm_campaign_id": "12345",
    "utm_adset": "Retarget",
    "utm_adset_id": "2222",
    "utm_ad": "HeroImage",
    "utm_ad_id": "3333",
    "fbclid": "XYZ123"
  }
}
```

### 9) Troubleshooting common issues

* **UTMs missing in DB:** Marketing didn’t append the query string — confirm exact sample link and test.
* **fbclid present but ad ids missing:** Facebook will provide `fbclid` on clicks; dynamic macros for ids must be used in Ads Manager.
* **Redirects remove params:** Ensure the ad link lands directly on the form page; avoid intermediate redirects that strip query params.

---

## Hand-off notes for Marketing (short)

* You only need to append the query parameters to the ad destination URL when you create the ad. Example template:

```
https://app.example.com/lead-form?utm_source=facebook&utm_medium=cpc&utm_campaign={{campaign.name}}&utm_campaign_id={{campaign.id}}&utm_adset={{adset.name}}&utm_adset_id={{adset.id}}&utm_ad={{ad.name}}&utm_ad_id={{ad.id}}&fbclid={{fbclid}}
```

* Test by replacing macros with sample values and clicking the link — confirm lead appears in admin with the tracking values.

---

## Checklist before launch

* [ ] Frontend deployed to production domain.
* [ ] Backend `POST /leads` deployed and secured (CORS configured and rate limits).
* [ ] DB migration applied.
* [ ] Admin dashboard shows tracking values.
* [ ] Privacy/consent checkbox implemented.
* [ ] Marketing has sample link and knows exact keys to use.
* [ ] QA tests completed using the testing checklist above.

---

## Appendix — useful tips

* Use `jsonb` in Postgres for `tracking` so you can `->>` extract keys in queries.
* Consider capturing `navigator.userAgent` and `document.referrer` for extra attribution context.
* For analytics, you can optionally send the `fbclid` + utms to your analytics provider later, but **do not** rely on third-party forwarding for the canonical lead record.

---

**Next steps I can help with:**

**a.** Generate the full, production-ready Flutter web form (complete file) that extracts query params and handles validation + consent.
**b.** Generate the backend endpoint code (Node.js Express + Postgres) including validation and unit tests.

---

## New Architectural Improvements & Enforcement Guidelines (Inspired by PandaDoc + FormFlow)

To support long-term scalability, multi-form support, dynamic rendering, and robust tracking, the following standards **must be enforced** during development.

### 1. Dynamic Form Rendering (Schema-Driven)

All lead-capture forms must be defined using a **JSON schema** stored in the backend. Flutter should **not** hardcode fields. The frontend must:

* Fetch schema with `GET /forms/:id`
* Render fields dynamically based on type, rules, labels, placeholders
* Support hidden fields for tracking data
* Use validation rules defined in the schema

**Why:** Allows the marketing team to create/modify forms without developer intervention.

### 2. Published Form URLs (PandaDoc-Style)

Each form created in the Admin Dashboard must generate a shareable link:

```
https://yourdomain.com/forms/{formId}
```

This link serves as the destination URL for ads. All UTM tags will be appended to this base URL.

### 3. First-Load Tracking Preservation

On initial load, the Flutter app must read:

* UTM parameters
* fbclid
* Ad / AdSet / Campaign IDs
* Referrer

These values must be stored in state and included in the final submission. They must **not be re-read after the first step**, preventing data loss.

### 4. Submission as a Single Lead Object

Every form submission must generate **one unified record** that contains:

* `answers` (all form field inputs)
* `tracking` (UTMs, facebook IDs, fbclid)
* `metadata` (ip, user-agent, timestamps)

Submissions must be stored in the `submissions` table.

### 5. Admin Dashboard Requirements

Admin dashboard must:

* List all forms
* Allow creation and editing of form schemas
* Show submission/lead table for each form
* Allow filtering by:

  * campaign id
  * ad id
  * date range

Must also support viewing the **full submission JSON** for debugging.

### 6. Database Enforcement

Two tables minimum:

**forms**

```
id
schema (jsonb)
created_at
updated_at
```

**submissions**

```
id
form_id
answers (jsonb)
tracking (jsonb)
metadata (jsonb)
created_at
```

Tracking and answer structure must be consistently formatted across all forms.

### 7. No-Redirect Policy

To prevent losing UTM parameters:

* The form URL must be the **direct landing page** for ads
* No intermediate redirects or router transitions before capturing UTMs

### 8. Security & Validation

At a minimum:

* Validate all required fields from schema
* Sanitize strings
* Enforce rate limiting on `/forms/:id/submissions`
* Enforce CORS only for known frontends

### 9. Marketing Team Workflow Enforcement

Marketing must:

* Append required UTM keys to the form URL
* Only modify the query string, **not** the formId in the URL
* Test links using the QA procedure before activating ads

### 10. QA Testing Requirements

Before launch, every new form requires:

1. Render test using a formId
2. Open URL with sample UTM parameters
3. Submit form
4. Verify:

   * Submission stored correctly
   * Tracking values match URL
   * Admin displays submission

QA must sign off before marketing begins using the form.

### 11. Extensibility Requirements

System must be designed to support:

* Multi-step forms (FormFlow wizard)
* Conditional logic (optional future requirement)
* File uploads (optional future requirement)
* A/B test forms (optional future requirement)

### 12. Documentation Requirements

Every form schema must contain:

* version number
* change history
* ownership (who created it)

This ensures maintainability and debugging clarity.
