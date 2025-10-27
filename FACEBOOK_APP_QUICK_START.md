# Facebook App Quick Start - MedWave

**App ID:** 1579668440071828  
**Package Name:** com.barefoot.medwave2  
**Date:** October 26, 2025

---

## 🚀 5-Minute Setup (Do This Now!)

Based on your screenshot, here's what you need to do immediately:

### **Step 1: Add Privacy Policy URL (2 minutes)**

1. Click **"Go to app settings"** in your Facebook Developer Console
2. Scroll to **"Privacy Policy URL"**
3. Enter: `https://privacy-medx-ai.web.app/privacy-policy.html`
4. Click **"Save Changes"**

> **Note:** If privacy policy is not deployed yet, run:
> ```bash
> cd /Users/mac/dev/medwave
> firebase deploy --only hosting:downloads-medx-ai
> ```

---

### **Step 2: Review Use Cases (3 minutes)**

You have one use case showing: **"Create & manage app ads with Meta Ads Manager"**

**Quick Decision:**

#### **Option A: You DON'T need Facebook Ads**
If MedWave won't run Facebook ads or track conversions:
1. Click on the use case
2. Click **"Remove"** or **"Skip"**
3. Continue to next step

#### **Option B: You DO need Facebook Ads**
If you plan to run Facebook/Instagram ads for MedWave:
1. Click on the use case
2. Complete the setup wizard
3. May require Business Verification (takes 1-3 days)

**Recommendation:** Unless you're actively planning Facebook ads, skip this for now.

---

## 📱 Complete Basic Settings (10 minutes)

### **Required Information**

Go to: **Settings** → **Basic**

```
App Display Name: MedWave Provider
Category: Health & Fitness
Contact Email: [your-email@medwave.co.za]
Privacy Policy URL: https://privacy-medx-ai.web.app/privacy-policy.html
App Icon: Upload images/medX_appIcon.png (resize to 1024x1024)
```

### **Add Android Platform**

1. Scroll to **"Add Platform"**
2. Select **"Android"**
3. Enter:
   ```
   Google Play Package Name: com.barefoot.medwave2
   Class Name: MainActivity
   Key Hashes: [See below to generate]
   ```

### **Generate Android Key Hash**

Run this command to get your key hash:

```bash
cd /Users/mac/dev/medwave/android

# For debug key
keytool -exportcert -alias androiddebugkey -keystore ~/.android/debug.keystore | openssl sha1 -binary | openssl base64

# For release key (use your actual keystore path)
keytool -exportcert -alias upload -keystore upload-keystore.jks | openssl sha1 -binary | openssl base64
```

**Default debug keystore password:** `android`

---

## 🔧 What Facebook Features Do You Need?

### **Option 1: Facebook Login** 
*Let users sign in with their Facebook account*

**When to use:**
- You want to simplify user registration
- You want to reduce password management
- You want social profile data

**Setup:**
1. Go to **Products** → **Add Product**
2. Select **"Facebook Login"**
3. Configure OAuth redirect URIs:
   ```
   https://medx-ai.firebaseapp.com/__/auth/handler
   https://medx-ai.web.app/auth/callback
   medwave://auth/callback
   ```

---

### **Option 2: Facebook Analytics**
*Track app usage and user behavior*

**When to use:**
- You want to understand user engagement
- You want to track feature usage
- You want demographic insights

**Setup:**
1. Go to **Products** → **Add Product**
2. Select **"Facebook Analytics"**
3. Add SDK to your app (see below)

---

### **Option 3: Facebook Share**
*Let users share content to Facebook*

**When to use:**
- Users want to share achievements
- You want viral growth
- You want social proof

**Setup:**
- No special permissions needed
- Use Flutter share_plus package (already in your pubspec.yaml!)

---

### **Option 4: Facebook Ads & Marketing**
*Run Facebook/Instagram ads and track conversions*

**When to use:**
- You're running paid advertising campaigns
- You want to track ad conversions
- You need remarketing capabilities

**Setup:**
1. Complete Business Verification
2. Create Facebook Pixel
3. Add conversion tracking

---

## 📝 My Recommendation for MedWave

Based on your healthcare app, I recommend:

### **Phase 1: Essential (Do Now)**
✅ Complete basic app settings  
✅ Add privacy policy URL  
✅ Add Android platform  
✅ Skip Facebook Ads use case (unless actively advertising)

### **Phase 2: Optional (Later)**
⏳ Facebook Login (if you want social login)  
⏳ Facebook Analytics (if you want usage tracking)  
⏳ Facebook Share (if users want to share progress)

### **Phase 3: Marketing (Future)**
⏸️ Facebook Ads (only if running paid campaigns)  
⏸️ Facebook Pixel (only if tracking conversions)

---

## 🎯 Your Immediate Action Plan

### **Right Now (5 minutes):**

1. ✅ Add privacy policy URL to Facebook App
2. ✅ Remove/Skip the "Ads Manager" use case (unless needed)
3. ✅ Check "Required actions" tab and complete any items

### **Within 24 Hours (15 minutes):**

4. ✅ Upload app icon (1024x1024px)
5. ✅ Add contact email
6. ✅ Add Android platform with package name
7. ✅ Generate and add key hash

### **This Week (if needed):**

8. ⏳ Decide if you need Facebook Login
9. ⏳ Decide if you need Facebook Analytics
10. ⏳ Implement chosen features

---

## 🔐 Security Notes

**NEVER commit to git:**
- App Secret (found in Settings → Basic)
- Access Tokens
- Client Tokens

**Store securely:**
```dart
// Create: lib/config/facebook_config.dart
class FacebookConfig {
  static const String appId = '1579668440071828';
  // Don't hardcode the secret - load from secure storage
}
```

Add to `.gitignore`:
```
lib/config/facebook_config.dart
```

---

## 📞 Quick Help

### **"I can't find Privacy Policy field"**
→ Go to Settings → Basic → Scroll down

### **"Use case requires verification"**
→ Skip it for now unless you need Facebook Ads

### **"Can't generate key hash"**
→ Make sure you have Java keytool and OpenSSL installed

### **"Do I need Facebook for my app?"**
→ Only if you want: Login, Analytics, Share, or Ads

### **"How do I know if setup is complete?"**
→ Check "Required actions" tab - should show no items

---

## 🔗 Quick Links

**Your App Dashboard:**
https://developers.facebook.com/apps/1579668440071828/dashboard

**Settings:**
https://developers.facebook.com/apps/1579668440071828/settings/basic

**App Review:**
https://developers.facebook.com/apps/1579668440071828/app-review

---

## ✅ Completion Checklist

- [ ] Privacy policy URL added
- [ ] Use cases reviewed (removed/completed)
- [ ] App icon uploaded (1024x1024px)
- [ ] Contact email added
- [ ] Category selected (Health & Fitness)
- [ ] Android platform added
- [ ] Package name: com.barefoot.medwave2
- [ ] Key hash generated and added
- [ ] No items in "Required actions"
- [ ] App status: Ready for development

---

## 💡 Common Questions

### **Q: Do I need to submit for App Review?**
**A:** Only if you need special permissions like `user_friends`, `email`, etc. Basic setup doesn't require review.

### **Q: Can I test without completing setup?**
**A:** Yes! You can test in Development Mode. Just add test users in Roles → Test Users.

### **Q: How long does Business Verification take?**
**A:** Usually 1-3 business days, but can take up to 2 weeks.

### **Q: What if I don't need Facebook features?**
**A:** You can create the app for future use and leave it in Development Mode. No rush to complete everything.

---

**Status:** Ready to complete setup  
**Estimated Time:** 15 minutes for basic setup  
**Next Review:** After basic setup is complete

---

## 🎬 Next Steps

1. **Complete the 5-minute setup above** ✅
2. **Decide which features you need** 🤔
3. **Read full guide if implementing features:** `FACEBOOK_APP_SETUP_GUIDE.md`
4. **Come back when ready to integrate** 👍

**You've got this! The basic setup is really quick.** 🚀

