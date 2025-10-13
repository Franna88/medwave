# Privacy Policy Deployment Guide

## 📁 Files Created

1. ✅ `web/privacy-policy.html` - Beautiful, mobile-responsive HTML version
2. ✅ `PRIVACY_POLICY_WEB.md` - Updated markdown version (October 13, 2025)
3. ✅ `firebase.json` - Updated with privacy policy hosting configuration

---

## 🚀 Quick Deployment (Recommended)

### **Step 1: Deploy to Firebase Hosting**

```bash
# Navigate to project directory
cd /Users/mac/dev/medwave

# Deploy privacy policy site
firebase deploy --only hosting:privacy-medx-ai
```

### **Step 2: Get Your Privacy Policy URL**

After deployment, your privacy policy will be available at:

```
https://privacy-medx-ai.web.app/privacy-policy.html
```

Or if you have a custom domain configured:
```
https://privacy.medwave.co.za/privacy-policy.html
```

### **Step 3: Add URL to Google Play Console**

1. Go to: [Google Play Console](https://play.google.com/console)
2. Navigate to: **Store presence** → **Main store listing**
3. Scroll to: **Privacy Policy** field
4. Enter: `https://privacy-medx-ai.web.app/privacy-policy.html`
5. Click: **Save**

---

## 📋 Complete Deployment Steps

### **1. Deploy Privacy Policy**

```bash
cd /Users/mac/dev/medwave
firebase deploy --only hosting:privacy-medx-ai
```

**Expected Output:**
```
✔  Deploy complete!

Project Console: https://console.firebase.google.com/project/medx-ai/overview
Hosting URL: https://privacy-medx-ai.web.app
```

### **2. Test the URL**

Open in browser:
```
https://privacy-medx-ai.web.app/privacy-policy.html
```

**Verify:**
- ✅ Page loads correctly
- ✅ All sections are visible
- ✅ Mobile responsive (test on phone)
- ✅ "Last Updated: October 13, 2025" is shown
- ✅ "Health App Features Declaration" section is present

### **3. Update Google Play Console**

#### **A. Add Privacy Policy URL**
```
Play Console → Store presence → Main store listing
→ Privacy Policy: https://privacy-medx-ai.web.app/privacy-policy.html
→ Save
```

#### **B. Update Health Apps Declaration**
```
Play Console → Policy and programs → App content → Health apps declaration
→ Check these 7 categories:
   ✅ Clinical decision support
   ✅ Healthcare services and management
   ✅ Medical reference and education
   ✅ Diseases and conditions management (ADD THIS)
   ✅ Medication and treatment management (ADD THIS)
   ✅ Physical therapy and rehabilitation (ADD THIS)
   ✅ Nutrition and weight management
→ Save
```

#### **C. Resubmit App**
```
Play Console → Publishing overview → Send for review
```

---

## 🌐 Alternative: Use Existing Downloads Site

If you want to use your existing downloads site instead:

### **Option A: Copy to Downloads Site**

```bash
# Copy privacy policy to downloads_public
cp web/privacy-policy.html downloads_public/

# Deploy downloads site
firebase deploy --only hosting:downloads-medx-ai
```

**URL will be:**
```
https://downloads-medx-ai.web.app/privacy-policy.html
```

---

## 🔧 Custom Domain Setup (Optional)

If you want a custom domain like `privacy.medwave.co.za`:

### **Step 1: Add Custom Domain in Firebase**

```bash
# Go to Firebase Console
https://console.firebase.google.com/project/medx-ai/hosting/sites

# Click on "privacy-medx-ai" site
# Click "Add custom domain"
# Enter: privacy.medwave.co.za
# Follow DNS setup instructions
```

### **Step 2: Update DNS Records**

Add these records to your domain registrar:

```
Type: A
Name: privacy
Value: [Firebase IP provided]

Type: TXT
Name: privacy
Value: [Verification code provided]
```

### **Step 3: Wait for SSL Certificate**

Firebase will automatically provision an SSL certificate (takes 24-48 hours).

---

## ✅ Verification Checklist

Before submitting to Google Play:

- [ ] Privacy policy HTML file exists at `web/privacy-policy.html`
- [ ] Firebase hosting is deployed: `firebase deploy --only hosting:privacy-medx-ai`
- [ ] Privacy policy URL is accessible in browser
- [ ] Privacy policy shows "Last Updated: October 13, 2025"
- [ ] Privacy policy includes "Health App Features Declaration" section
- [ ] All 7 health categories are listed in privacy policy
- [ ] Privacy policy URL added to Google Play Console
- [ ] Health Apps Declaration updated with all 7 categories
- [ ] App resubmitted for review

---

## 🎯 Quick Commands Reference

```bash
# Deploy privacy policy
firebase deploy --only hosting:privacy-medx-ai

# Deploy all hosting sites
firebase deploy --only hosting

# Test locally (optional)
firebase serve --only hosting:privacy-medx-ai
# Then open: http://localhost:5000/privacy-policy.html
```

---

## 📞 Troubleshooting

### **Issue: Firebase command not found**

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login
```

### **Issue: Deployment fails**

```bash
# Check if logged in
firebase login --reauth

# Check project
firebase projects:list

# Use correct project
firebase use medx-ai
```

### **Issue: 404 Not Found**

- Check file exists: `ls web/privacy-policy.html`
- Check firebase.json has correct "public": "web"
- Redeploy: `firebase deploy --only hosting:privacy-medx-ai`

### **Issue: Old version showing**

- Clear browser cache (Cmd+Shift+R on Mac, Ctrl+Shift+R on Windows)
- Wait 5 minutes for CDN to update
- Try incognito/private browsing mode

---

## 📊 Expected Timeline

| Step | Time | Status |
|------|------|--------|
| Deploy to Firebase | 2 min | ⏳ TO DO |
| Verify URL works | 1 min | ⏳ TO DO |
| Update Play Console | 5 min | ⏳ TO DO |
| **Google Review** | **3-7 days** | ⏳ PENDING |

---

## 🔗 Important URLs

**Firebase Console:**
- Project: https://console.firebase.google.com/project/medx-ai
- Hosting: https://console.firebase.google.com/project/medx-ai/hosting/sites

**Google Play Console:**
- App: https://play.google.com/console
- Health Declaration: https://play.google.com/console/u/0/developers/7120487348918867014/app/4973326309285902798/policy-center/issues

**Your Privacy Policy (after deployment):**
- https://privacy-medx-ai.web.app/privacy-policy.html

---

## 📝 Next Steps Summary

1. **Deploy** (2 min):
   ```bash
   cd /Users/mac/dev/medwave
   firebase deploy --only hosting:privacy-medx-ai
   ```

2. **Get URL** (1 min):
   - Copy: `https://privacy-medx-ai.web.app/privacy-policy.html`

3. **Update Play Console** (5 min):
   - Add privacy policy URL
   - Update health declaration (add 3 missing categories)
   - Resubmit app

4. **Wait for Review** (3-7 days):
   - Google will review your app
   - You'll receive email notification

---

**Last Updated:** October 13, 2025  
**Status:** Ready for Deployment
