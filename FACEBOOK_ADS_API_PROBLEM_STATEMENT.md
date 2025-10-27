# Facebook Marketing API Access Issue - Help Needed

**Date:** October 26, 2025  
**App Name:** Medwave  
**App ID:** 1579668440071828  
**Business:** MedWave Limited (ID: 133307248976718)

---

## 🎯 Problem Summary

I need to access the Facebook Marketing API / Insights API to read ad performance data (impressions, clicks, spend, etc.) from my own ad accounts for display in my admin dashboard. 

My app is fully configured and published LIVE, but I cannot generate a User Access Token with the required `ads_read` permission.

---

## ⚠️ Current Issue

When attempting to generate a User Access Token with `ads_read` and `business_management` permissions via the Graph API Explorer, I receive this error:

> **"Feature Unavailable - Facebook Login is currently unavailable for this app, since we are updating additional details for this app. Please try again later."**

When I successfully generate a User Token (without the Facebook Login dialog), the token has **NO SCOPES/PERMISSIONS** - it's completely empty, making it useless for API calls.

---

## ✅ What I Have Already Completed

### **1. Facebook App Setup** ✅
- App created and **published to LIVE mode** (not in development)
- App ID: 1579668440071828
- Privacy Policy URL: Configured and deployed
- Data Deletion URL: Configured and deployed
- App Icon: Uploaded
- Contact Email: Configured
- All basic settings complete

### **2. Business Setup** ✅
- Business Portfolio: MedWave Limited (Verified)
- Business ID: 133307248976718
- Business verification: Complete

### **3. Ad Accounts** ✅
- 4 ad accounts connected and authorized in Advanced settings:
  - `2269601786725768`
  - `221848657672558`
  - `704993548469322` (MW B2C Clients - Primary)
  - `220298027464902`
- I OWN all these ad accounts
- All accounts are active and have campaigns running

### **4. Use Case Configuration** ✅
- Use Case: "Create & manage app ads with Meta Ads Manager"
- Business portfolio: Connected
- Ad accounts: Connected (all 4)
- Website platform: `https://medx-ai.web.app` (configured)
- Setup status: Complete

### **5. System Users** ✅
- Created System Users: Conversions API System Users
- Assigned to Medwave app: Full control
- Assigned to ad accounts: Full control
- However, when trying to generate tokens for System Users, I get "No permissions available"

---

## 🔍 What I've Tried (All Failed)

1. **Graph API Explorer with permissions:**
   - Added `ads_read` and `business_management` permissions
   - Clicked "Generate Access Token"
   - Result: "Feature Unavailable" error

2. **Access Token Tool:**
   - Shows "You need to grant permissions to your app"
   - Generated token has NO scopes/permissions

3. **System User Token Generation:**
   - Tried generating token from Business Settings → System Users
   - Selected Medwave app
   - Result: "No permissions available" - unable to assign any permissions

4. **Use Case Customization:**
   - Checked if I could add Marketing API access to the use case
   - No options available to add additional permissions

5. **Looking for App Review:**
   - No "App Review" section visible in the app dashboard
   - Cannot find where to request Advanced Access for permissions

6. **Different browsers/incognito mode:**
   - Tried Chrome, incognito mode
   - Same error persists

---

## 📋 What I Need

### **Required Permission:**
- `ads_read` - To access the Insights API and read ad performance data

### **What I Want to Do:**
Make API calls like this to retrieve ad insights:

```bash
curl -G \
  -d "fields=spend,impressions,clicks,cpm,cpc,ctr" \
  -d "date_preset=last_30d" \
  -d "access_token=USER_ACCESS_TOKEN_WITH_ADS_READ" \
  "https://graph.facebook.com/v24.0/act_704993548469322/insights"
```

### **Use Case:**
Display ad performance metrics (spend, impressions, clicks, conversions) from my own ad accounts in a custom admin dashboard for my business.

---

## ❓ Specific Questions

1. **Why is Facebook Login showing "Feature Unavailable" even though my app is LIVE?**
   - Is there a waiting period after publishing?
   - Is there additional verification needed?

2. **How do I request Advanced Access for `ads_read` permission?**
   - There's no "App Review" section in my dashboard
   - The use case I selected doesn't provide Marketing API access

3. **Does the "Create & manage app ads with Meta Ads Manager" use case support reading ad data?**
   - The description says "Does not include access to Marketing API"
   - Should I use a different use case?
   - If so, which one?

4. **Can I access my own ad accounts with Development Access?**
   - According to documentation, Development Access allows 1 ad account
   - But I can't generate a token even for development

5. **Is there a specific onboarding process for Marketing API I'm missing?**
   - I've followed the documentation but might be missing a step
   - Is there a separate application/registration for Marketing API?

---

## 🔗 Relevant Documentation I've Read

- [Marketing API Overview](https://developers.facebook.com/docs/marketing-api)
- [Marketing API Get Started](https://developers.facebook.com/docs/marketing-api/get-started)
- [Insights API](https://developers.facebook.com/docs/marketing-api/insights)
- [Permissions Reference](https://developers.facebook.com/docs/permissions)
- [Marketing API Authorization](https://developers.facebook.com/docs/marketing-api/authorization)

---

## 💡 What Would Help

1. **Step-by-step guidance** on how to properly request `ads_read` permission for a LIVE app
2. **Confirmation** if there's a waiting period after publishing before permissions work
3. **Alternative approaches** if the current use case doesn't support what I need
4. **Direct link** to where I can request Advanced Access (if it exists)
5. **Contact** at Facebook Developer Support who can manually review my app configuration

---

## 🔑 App Information for Support

```
App Name: Medwave
App ID: 1579668440071828
Business ID: 133307248976718
Business Name: MedWave Limited
Primary Ad Account: act_704993548469322
App Status: LIVE (Published)
Use Case: Create & manage app ads with Meta Ads Manager
Permissions Needed: ads_read, business_management
API Version: v24.0
```

---

## 📸 Screenshots Available

I have screenshots showing:
- ✅ App published successfully
- ✅ Ad accounts configured in Advanced settings
- ✅ Use case setup complete
- ❌ "Feature Unavailable" error when generating token
- ❌ User token with empty scopes/permissions
- ❌ "No permissions available" when trying to generate System User token

---

## 🆘 Where I'm Asking for Help

- [ ] Facebook Developer Community Forums
- [ ] Facebook Developer Support (via support form)
- [ ] Stack Overflow
- [ ] Reddit r/FacebookDevelopers
- [ ] Meta Business Help Center

---

## 📞 How You Can Help

If you've successfully set up Marketing API access for a similar use case, please share:

1. What use case did you select?
2. How did you request `ads_read` permission?
3. Was there a waiting period after publishing?
4. Did you need to contact support, or was there a self-service option?
5. Any specific settings or configurations I might be missing?

---

## ⏱️ Timeline

- **App created:** October 26, 2025
- **App published to LIVE:** October 26, 2025 (today)
- **First token generation attempt:** October 26, 2025 (immediately after publishing)
- **Time elapsed since publishing:** Less than 24 hours

---

## 🙏 Thank You

Any guidance, suggestions, or direct help would be greatly appreciated! I've spent significant time on the setup and everything appears correct except for the permission grant mechanism.

---

**Contact:** If you need more information or screenshots, please let me know!



