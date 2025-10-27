# Facebook App Setup Guide for MedWave

**Date:** October 26, 2025  
**App Name:** Medwave  
**App ID:** 1579668440071828  
**Status:** In Setup

---

## 📋 Overview

This guide will help you complete the Facebook App setup for MedWave. Based on your current Facebook Developer Console, you need to:

1. ✅ Add Privacy Policy URL
2. ✅ Configure Use Cases
3. ✅ Complete App Settings
4. ✅ Submit for Review (if needed)

---

## 🚀 Step-by-Step Setup

### **Step 1: Add Privacy Policy URL**

Your privacy policy is already created and ready to deploy!

#### **A. Deploy Privacy Policy (if not already done)**

```bash
cd /Users/mac/dev/medwave
firebase deploy --only hosting:downloads-medx-ai
```

#### **B. Your Privacy Policy URL**

Use one of these URLs:
- **Primary:** `https://privacy-medx-ai.web.app/privacy-policy.html`
- **Alternative:** `https://downloads-medx-ai.web.app/privacy-policy.html`

#### **C. Add to Facebook App**

1. In Facebook Developer Console, click **"Go to app settings"** (as shown in your screenshot)
2. Navigate to: **Settings** → **Basic**
3. Scroll to: **Privacy Policy URL**
4. Enter: `https://privacy-medx-ai.web.app/privacy-policy.html`
5. Click: **Save Changes**

---

### **Step 2: Configure Use Cases**

Based on your screenshot, you need to review the use case: **"Create & manage app ads with Meta Ads Manager"**

#### **What This Use Case Means**

This use case allows your app to:
- Create and manage advertising campaigns
- Track ad performance
- Access Meta Ads Manager API

#### **Do You Need This?**

**Answer these questions:**
- ❓ Will MedWave run Facebook/Instagram ads?
- ❓ Do you need to programmatically create ads from within your app?
- ❓ Do you need to track ad performance in your app?

**If YES:** Keep this use case and complete the setup  
**If NO:** You can remove this use case

#### **How to Configure**

1. Click on **"Create & manage app ads with Meta Ads Manager"** in your screenshot
2. Review the requirements:
   - Business verification (may be required)
   - App Review approval
   - Permissions needed
3. Complete any required steps
4. Click **Save**

---

### **Step 3: Complete Basic App Settings**

#### **A. App Settings Checklist**

Go to: **Settings** → **Basic**

Complete these fields:

```
✅ App Name: Medwave
✅ App ID: 1579668440071828
✅ Display Name: MedWave Provider
✅ Contact Email: [your-email@medwave.co.za]
✅ Privacy Policy URL: https://privacy-medx-ai.web.app/privacy-policy.html
✅ Terms of Service URL: (optional, but recommended)
✅ App Icon: Upload MedWave logo (1024x1024px)
✅ Category: Health & Fitness or Medical
✅ Business Use: Business
```

#### **B. App Domain**

Add your app domains:
```
medwave.co.za
medx-ai.web.app
downloads-medx-ai.web.app
privacy-medx-ai.web.app
```

---

### **Step 4: Configure App Platforms**

Depending on what you're integrating Facebook for, add your platforms:

#### **For Android App**

1. Go to: **Settings** → **Basic** → **Add Platform**
2. Select: **Android**
3. Fill in:
   ```
   Package Name: com.medwave.provider (or your actual package name)
   Class Name: MainActivity
   Key Hashes: [Generate from your keystore]
   ```

#### **For iOS App**

1. Go to: **Settings** → **Basic** → **Add Platform**
2. Select: **iOS**
3. Fill in:
   ```
   Bundle ID: com.medwave.provider (or your actual bundle ID)
   ```

#### **For Web App**

1. Go to: **Settings** → **Basic** → **Add Platform**
2. Select: **Website**
3. Fill in:
   ```
   Site URL: https://medx-ai.web.app
   ```

---

### **Step 5: App Review (If Required)**

If you need special permissions or features, you may need to submit for App Review.

#### **Common Permissions for Healthcare Apps**

- `email` - Get user's email address
- `public_profile` - Get basic profile info
- `user_friends` - Access friends list (if needed)

#### **How to Submit**

1. Go to: **App Review** → **Permissions and Features**
2. Select the permissions you need
3. Provide detailed explanations:
   - Why you need each permission
   - How you'll use the data
   - Screenshots of the feature
4. Submit for review

---

## 🔧 Integration Options

### **Option 1: Facebook Login**

If you want users to log in with Facebook:

#### **A. Enable Facebook Login**

1. Go to: **Products** → **Add Product**
2. Select: **Facebook Login**
3. Click: **Set Up**

#### **B. Configure OAuth Settings**

```
Valid OAuth Redirect URIs:
- https://medx-ai.web.app/auth/callback
- https://medx-ai.firebaseapp.com/__/auth/handler
- medwave://auth/callback (for mobile)
```

#### **C. Get App Credentials**

```
App ID: 1579668440071828
App Secret: [Found in Settings → Basic]
```

---

### **Option 2: Facebook Analytics**

If you want to track app events:

#### **A. Enable Facebook Analytics**

1. Go to: **Products** → **Add Product**
2. Select: **Facebook Analytics**
3. Click: **Set Up**

#### **B. Add SDK to Your App**

For Flutter:
```yaml
# pubspec.yaml
dependencies:
  facebook_app_events: ^0.19.2
```

---

### **Option 3: Facebook Ads**

If you want to run ads or track conversions:

#### **A. Create Facebook Pixel**

1. Go to: [Facebook Events Manager](https://business.facebook.com/events_manager2)
2. Create a new Pixel
3. Get Pixel ID

#### **B. Add Pixel to Website**

```html
<!-- Add to web/index.html -->
<script>
  !function(f,b,e,v,n,t,s)
  {if(f.fbq)return;n=f.fbq=function(){n.callMethod?
  n.callMethod.apply(n,arguments):n.queue.push(arguments)};
  if(!f._fbq)f._fbq=n;n.push=n;n.loaded=!0;n.version='2.0';
  n.queue=[];t=b.createElement(e);t.async=!0;
  t.src=v;s=b.getElementsByTagName(e)[0];
  s.parentNode.insertBefore(t,s)}(window, document,'script',
  'https://connect.facebook.net/en_US/fbevents.js');
  fbq('init', 'YOUR_PIXEL_ID');
  fbq('track', 'PageView');
</script>
```

---

## 📱 Mobile Integration (Flutter)

### **Add Facebook SDK to Flutter**

#### **1. Add Dependencies**

```yaml
# pubspec.yaml
dependencies:
  flutter_facebook_auth: ^6.0.4
  facebook_app_events: ^0.19.2
```

#### **2. Android Configuration**

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<manifest>
    <application>
        <!-- Add before </application> -->
        <meta-data 
            android:name="com.facebook.sdk.ApplicationId" 
            android:value="@string/facebook_app_id"/>
        
        <meta-data 
            android:name="com.facebook.sdk.ClientToken" 
            android:value="@string/facebook_client_token"/>
        
        <activity 
            android:name="com.facebook.FacebookActivity"
            android:configChanges="keyboard|keyboardHidden|screenLayout|screenSize|orientation"
            android:label="@string/app_name" />
    </application>
</manifest>
```

```xml
<!-- android/app/src/main/res/values/strings.xml -->
<resources>
    <string name="app_name">MedWave Provider</string>
    <string name="facebook_app_id">1579668440071828</string>
    <string name="facebook_client_token">YOUR_CLIENT_TOKEN</string>
</resources>
```

#### **3. iOS Configuration**

```xml
<!-- ios/Runner/Info.plist -->
<dict>
    <!-- Add these keys -->
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>fb1579668440071828</string>
            </array>
        </dict>
    </array>
    
    <key>FacebookAppID</key>
    <string>1579668440071828</string>
    
    <key>FacebookClientToken</key>
    <string>YOUR_CLIENT_TOKEN</string>
    
    <key>FacebookDisplayName</key>
    <string>MedWave Provider</string>
    
    <key>LSApplicationQueriesSchemes</key>
    <array>
        <string>fbapi</string>
        <string>fb-messenger-share-api</string>
    </array>
</dict>
```

#### **4. Flutter Code Example**

```dart
// lib/services/facebook_auth_service.dart
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

class FacebookAuthService {
  final FacebookAuth _facebookAuth = FacebookAuth.instance;

  Future<Map<String, dynamic>?> signInWithFacebook() async {
    try {
      // Trigger the sign-in flow
      final LoginResult result = await _facebookAuth.login(
        permissions: ['email', 'public_profile'],
      );

      // Check if login was successful
      if (result.status == LoginStatus.success) {
        // Get user data
        final userData = await _facebookAuth.getUserData();
        return userData;
      } else {
        print('Facebook login failed: ${result.status}');
        return null;
      }
    } catch (e) {
      print('Error during Facebook sign-in: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _facebookAuth.logOut();
  }
}
```

---

## 🔐 Security Best Practices

### **1. Store Credentials Securely**

**NEVER commit these to git:**
- App Secret
- Client Token
- Access Tokens

**Use environment variables or secure storage:**

```dart
// lib/config/facebook_config.dart
class FacebookConfig {
  static const String appId = '1579668440071828';
  // Load secret from secure storage, not hardcoded
  static String get appSecret => _loadFromSecureStorage();
}
```

### **2. Validate Tokens**

Always validate tokens server-side:

```javascript
// functions/validateFacebookToken.js
const axios = require('axios');

async function validateFacebookToken(accessToken) {
  const appId = process.env.FACEBOOK_APP_ID;
  const appSecret = process.env.FACEBOOK_APP_SECRET;
  
  const url = `https://graph.facebook.com/debug_token?input_token=${accessToken}&access_token=${appId}|${appSecret}`;
  
  const response = await axios.get(url);
  return response.data.data.is_valid;
}
```

### **3. Use HTTPS Only**

All OAuth redirect URIs must use HTTPS in production.

---

## ✅ Pre-Launch Checklist

Before going live, verify:

- [ ] Privacy Policy URL is accessible
- [ ] App icon uploaded (1024x1024px)
- [ ] All required app settings completed
- [ ] Platform configurations added (Android/iOS/Web)
- [ ] OAuth redirect URIs configured
- [ ] App domain verified
- [ ] Use cases reviewed and approved
- [ ] App Review submitted (if needed)
- [ ] Credentials stored securely
- [ ] Test login flow works
- [ ] Error handling implemented

---

## 🎯 Quick Action Items (For Your Current Screenshot)

Based on what I see in your screenshot, here's what you need to do RIGHT NOW:

### **Immediate Actions (5 minutes)**

1. **Add Privacy Policy URL:**
   - Click "Go to app settings"
   - Add: `https://privacy-medx-ai.web.app/privacy-policy.html`
   - Save

2. **Review Use Case:**
   - Click on "Create & manage app ads with Meta Ads Manager"
   - Decide if you need this feature
   - Complete or remove it

3. **Check Required Actions:**
   - Click on "Required actions" in the left sidebar
   - Complete any pending items

### **After Immediate Actions (10 minutes)**

4. **Complete Basic Settings:**
   - Add app icon
   - Add contact email
   - Add app description
   - Add category

5. **Add Platform:**
   - Add Android platform with package name
   - Add iOS platform with bundle ID (if applicable)

6. **Test Configuration:**
   - Verify privacy policy loads
   - Check all settings are saved

---

## 📞 Troubleshooting

### **Issue: Can't find Privacy Policy field**

**Solution:**
1. Go to **Settings** → **Basic**
2. Scroll down to find "Privacy Policy URL"
3. If not visible, check if app is in Development mode

### **Issue: Use case requires Business Verification**

**Solution:**
1. Go to [Meta Business Suite](https://business.facebook.com)
2. Complete business verification
3. This may take 1-3 business days

### **Issue: Can't save settings**

**Solution:**
- Check all required fields are filled
- Ensure URLs are valid and accessible
- Try refreshing the page

### **Issue: App Review taking too long**

**Solution:**
- Reviews typically take 1-3 business days
- Provide detailed explanations
- Include screenshots and videos
- Respond promptly to any questions

---

## 🔗 Useful Links

**Facebook Developer Console:**
- Your App: https://developers.facebook.com/apps/1579668440071828
- Dashboard: https://developers.facebook.com/apps/1579668440071828/dashboard
- Settings: https://developers.facebook.com/apps/1579668440071828/settings/basic

**Documentation:**
- Facebook Login: https://developers.facebook.com/docs/facebook-login
- App Review: https://developers.facebook.com/docs/app-review
- Best Practices: https://developers.facebook.com/docs/development/release/best-practices

**Support:**
- Developer Community: https://developers.facebook.com/community
- Bug Reports: https://developers.facebook.com/support/bugs

---

## 📝 Next Steps

1. **Complete immediate actions** (5 min)
2. **Deploy privacy policy** if not done (2 min)
3. **Add privacy policy URL to Facebook** (1 min)
4. **Configure use cases** (5 min)
5. **Complete basic settings** (10 min)
6. **Add platforms** (5 min)
7. **Test integration** (10 min)

**Total Time:** ~40 minutes

---

## 💡 Common Use Cases for MedWave

### **Scenario 1: Social Login**
If you want users to log in with Facebook:
- ✅ Enable Facebook Login product
- ✅ Request `email` and `public_profile` permissions
- ✅ Integrate with Firebase Auth

### **Scenario 2: Share to Facebook**
If you want users to share progress/achievements:
- ✅ Enable Facebook Share Dialog
- ✅ No special permissions needed
- ✅ Use Share API

### **Scenario 3: Marketing & Ads**
If you want to run Facebook ads:
- ✅ Create Facebook Pixel
- ✅ Add conversion tracking
- ✅ Enable Ads Manager use case

### **Scenario 4: Analytics Only**
If you just want to track app usage:
- ✅ Enable Facebook Analytics
- ✅ Add Facebook SDK
- ✅ Track custom events

**Which scenario applies to MedWave?** Let me know and I can provide more specific guidance!

---

**Last Updated:** October 26, 2025  
**Status:** Ready for Setup  
**Estimated Completion Time:** 40 minutes

