# Deposit & Final Payment Reminder Email System

This document describes the planned (and reference) system for **automated reminder emails** when customers click **"No"** on the initial deposit request or final payment request email. Use it to verify requirements, timing, and that both flows (deposit and final payment) are covered.

---

## Overview

- **Two parallel flows:** one for **deposit** (appointment), one for **final payment** (order).
- **Trigger:** Customer clicks **"No"** on the first email (e.g. "Have you made the deposit?" / "Have you paid the remaining balance?").
- **Behaviour:** Automated sequence of up to 3 follow-up emails, spaced 2 days apart, with optional **opt-out** ("Stop sending these reminders") in each email.

---

## 1. Deposit reminder flow (appointment)

### 1.1 When the first email is sent

- When the appointment moves to **deposit_requested** (e.g. after contract is signed).
- One email: "Have you made the deposit?" with **Yes** / **No** links to `/deposit-confirmation`.

### 1.2 When customer clicks **"No"**

- Record that they have not yet paid; they become eligible for the **automated reminder sequence**.
- No manual follow-up required; a **scheduled Cloud Function** sends the next emails.

### 1.3 Automated reminder sequence (if No)

| Step | When | Content |
|------|------|--------|
| **Email 1** | 2 days after the **first** deposit email | Same as first email: "Have you made the deposit?" (Yes/No). |
| **Email 2** | 2 days after Email 1 | Shipped & locked at warehouse: "Confirm if deposit was made" (Yes/No). |
| **Email 3** | 2 days after Email 2 | Price increase warning: "Confirm if deposit was made" (Yes/No). |

- After Email 3, no further automatic reminders (unless you extend the design).
- Each reminder email can include **opt-out** links: "Yes, keep reminders" / "No, stop reminders".

### 1.4 Data (appointment document)

- **Existing:** `depositConfirmationSentAt`, `depositConfirmationToken`, `depositConfirmationStatus`.
- **To add (for automation + opt-out):**
  - `depositReminderSentCount` (0–3) – how many reminder emails sent.
  - `lastDepositReminderSentAt` – timestamp of last reminder.
  - `receiveDepositReminderEmails` (boolean) – if `false`, do not send more reminders (user opted out).

### 1.5 Logic

- **Eligible for reminder:** Appointment in stage `deposit_requested`, `depositConfirmationStatus` still pending (or equivalent), `receiveDepositReminderEmails !== false`, and enough time elapsed since first email / last reminder (2-day spacing).
- **Scheduled function:** e.g. `scheduleDepositReminders` (runs daily, finds eligible appointments, sends next reminder in sequence).
- **Opt-out endpoint:** e.g. `setDepositReminderPreference` – GET with `appointmentId` + `token` + `preference=yes|no`; updates `receiveDepositReminderEmails`.

### 1.6 Templates

| Email | When | Template ID | Notes |
|-------|------|-------------|--------|
| First (initial) | When moving to deposit_requested | `template_6vqr5ib` | Current deposit request (`_depositCustomerTemplateId` in `emailjs_service.dart`). |
| Reminder 1 | 2 days after first | **Same as first** – `template_6vqr5ib` | No new template; reuse first deposit request. |
| Reminder 2 | 2 days after reminder 1 | `template_i5hg6ik` | Shipped & Locked at warehouse (`_depositReminder2TemplateId`). |
| Reminder 3 | 2 days after reminder 2 | TBD | Price increase; reuse or add template later. |

All need **Yes/No** links (deposit confirmation) and optionally **opt-out** links (reminder preference).

---

## 2. Final payment reminder flow (order)

### 2.1 When the first email is sent

- When the customer **views the invoice** (public invoice link).
- One email: "Have you paid the remaining balance?" with **Yes** / **No** links (payment confirmation).

### 2.2 When customer clicks **"No"**

- Record that they have not yet paid; they become eligible for the **automated reminder sequence**.
- A **scheduled Cloud Function** sends the next emails.

### 2.3 Automated reminder sequence (if No)

| Step | When | Content |
|------|------|--------|
| **Email 1** | 2 days after the **first** payment email | Same as first: "Have you paid the remaining balance?" (Yes/No). |
| **Email 2** | 2 days after Email 1 | Your chosen wording (e.g. order locked / shipping soon) – confirm if payment was made (Yes/No). |
| **Email 3** | 2 days after Email 2 | Final reminder / urgency – confirm if payment was made (Yes/No). |

- After Email 3, no further automatic reminders unless extended.
- Each reminder can include **opt-out** links for payment reminders.

### 2.4 Data (order document)

- **Existing:** `paymentConfirmationSentAt`, `paymentConfirmationToken`.
- **To add:**
  - `paymentReminderSentCount` (0–3).
  - `lastPaymentReminderSentAt`.
  - `receivePaymentReminderEmails` (boolean).

### 2.5 Logic

- **Eligible for reminder:** Order has had first payment email sent (`paymentConfirmationSentAt` set), payment not yet confirmed, `receivePaymentReminderEmails !== false`, and 2-day spacing satisfied.
- **Scheduled function:** e.g. `schedulePaymentReminders`.
- **Opt-out endpoint:** e.g. `setPaymentReminderPreference` – updates `receivePaymentReminderEmails` on the order (with order ID + token validation).

### 2.6 Templates

- **Email 1:** Same as first payment request (or dedicated).
- **Email 2 & 3:** Your chosen wording for “remind to pay remaining balance” and “final reminder”.
- All need Yes/No (payment confirmation) and optionally opt-out (reminder preference) links.

---

## 3. Checklist – am I missing anything?

### 3.1 Product / UX

- [ ] **Timing:** Email 1 = 2 days after **first email** (not 2 days after clicking No). Confirm this is correct.
- [ ] **Max reminders:** Cap at 3 reminders (Email 1, 2, 3) for both deposit and final payment.
- [ ] **Opt-out:** Every reminder email includes “Yes, keep reminders” / “No, stop reminders” and links to the correct preference endpoint.
- [ ] **Final payment Email 2 & 3:** Exact wording and tone agreed (e.g. “order locked”, “shipping soon”, “final reminder”).

### 3.2 Data model

- [ ] **Appointment:** `depositReminderSentCount`, `lastDepositReminderSentAt`, `receiveDepositReminderEmails` added and used everywhere relevant.
- [ ] **Order:** `paymentReminderSentCount`, `lastPaymentReminderSentAt`, `receivePaymentReminderEmails` added and used.
- [ ] **“No” click:** Backend that handles deposit/payment “No” sets the appointment/order into “eligible for reminders” (and does not set opt-out).

### 3.3 Cloud / backend

- [ ] **Deposit:** Scheduled function `scheduleDepositReminders` (daily), HTTP function `setDepositReminderPreference` (with appointment token validation).
- [ ] **Final payment:** Scheduled function `schedulePaymentReminders` (daily), HTTP function `setPaymentReminderPreference` (with order token validation).
- [ ] **Firestore indexes:** Composite indexes for the new queries (e.g. stage + dates + flags) for both appointment and order.

### 3.4 Email / templates

- [ ] **Deposit:** 3 templates (or 3 variants): Email 1 (same as first), Email 2 (shipped & locked), Email 3 (price increase). All with Yes/No + opt-out links.
- [ ] **Final payment:** 3 templates (or 3 variants): Email 1 (same as first), Email 2, Email 3. All with Yes/No + opt-out links.
- [ ] **Template params:** Each template receives the correct URLs (confirmation Yes/No + reminder preference Yes/No) and any dynamic text (amounts, dates).

### 3.5 Security & config

- [ ] **Tokens:** Deposit and payment flows use secure tokens (e.g. stored on appointment/order) for both confirmation links and reminder-preference links. No one can opt out or confirm for another customer.
- [ ] **Config:** Firebase/Cloud config (or params) for template IDs, EmailJS credentials, and any base URLs for the new endpoints.

### 3.6 Edge cases

- [ ] **Already confirmed:** If customer confirms deposit (or payment) after Email 1 or 2, do not send further reminders.
- [ ] **Opt-out:** If `receiveDepositReminderEmails` or `receivePaymentReminderEmails` is `false`, scheduled function skips that appointment/order.
- [ ] **Stage/status changes:** If appointment moves out of `deposit_requested` or order is cancelled, reminders stop.

---

## 4. Reference: contract reminder (existing)

For comparison, the **contract signing reminder** system (already implemented):

- **Entity:** Contract (`contracts`).
- **Fields:** `reminderSentCount` (0–5), `lastReminderSentAt`, `receiveReminderEmails`.
- **Schedule:** First reminder 1 day after contract creation, then daily (Mon–Fri) up to 5 reminders.
- **Opt-out:** `setContractReminderPreference` HTTP endpoint; emails include `reminder_opt_in_url` and `reminder_opt_out_url`.

Deposit and final payment flows mirror this pattern but with **2-day spacing** and **3 reminders** each, and separate entities (appointment vs order).

---

## 5. Summary table

| Item | Deposit (appointment) | Final payment (order) |
|------|------------------------|------------------------|
| First email | When moving to deposit_requested | When customer views invoice |
| If No | Start 3-email reminder sequence | Start 3-email reminder sequence |
| Email 1 | 2 days after first – same as first | 2 days after first – same as first |
| Email 2 | 2 days after Email 1 – shipped & locked | 2 days after Email 1 – your wording |
| Email 3 | 2 days after Email 2 – price increase | 2 days after Email 2 – final reminder |
| Count fields | `depositReminderSentCount` | `paymentReminderSentCount` |
| Opt-out field | `receiveDepositReminderEmails` | `receivePaymentReminderEmails` |
| Scheduler | `scheduleDepositReminders` | `schedulePaymentReminders` |
| Preference endpoint | `setDepositReminderPreference` | `setPaymentReminderPreference` |

Use this README to verify you are not missing anything before or during implementation.
