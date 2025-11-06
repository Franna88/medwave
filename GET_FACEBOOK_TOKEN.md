# How to Get a New Facebook Access Token

## Step 1: Open Facebook Graph API Explorer

1. Go to: **https://developers.facebook.com/tools/explorer/**
2. You should be logged in with your Facebook account that has access to the MedWave ad account

## Step 2: Select Your App

1. In the top-right corner, click on the **"Meta App"** dropdown
2. Find and select your app (look for "MedWave" or the app connected to ad account `act_220298027464902`)
3. If you don't see your app, you may need to create one or get access

## Step 3: Generate User Access Token

1. Click on **"Generate Access Token"** button (top right area)
2. A permissions dialog will appear

## Step 4: Select Required Permissions

You need these permissions:
- ✅ **ads_read** - Read ads data
- ✅ **ads_management** - Manage ads
- ✅ **read_insights** - Read ad insights/metrics

To add them:
1. Click **"Add a Permission"**
2. Search for each permission above
3. Check the box next to each one
4. Click **"Generate Access Token"**

## Step 5: Copy the Token

1. After generating, you'll see a long token in the **"Access Token"** field
2. It looks like: `EAAc9pw8rgA0BPzX...` (very long string)
3. Click the **copy icon** or select all and copy it
4. **IMPORTANT**: This token will expire in 1-2 hours by default

## Step 6: (Optional) Get a Long-Lived Token

For a token that lasts 60 days instead of 1 hour:

1. After copying your token, go to: **https://developers.facebook.com/tools/debug/accesstoken/**
2. Paste your token
3. Click **"Debug"**
4. Click **"Extend Access Token"** button at the bottom
5. Copy the new extended token

## Step 7: Verify Token Works

Test it with this command (replace YOUR_TOKEN):

```bash
curl "https://graph.facebook.com/v24.0/act_220298027464902/campaigns?fields=id,name&access_token=YOUR_TOKEN"
```

You should see a JSON response with campaign data. If you see an error, the token is invalid.

## Common Issues

### "Invalid OAuth access token"
- Token has expired
- Generate a new one following steps above

### "Permissions error"
- You didn't select all required permissions
- Regenerate token and make sure to add: ads_read, ads_management, read_insights

### "Ad account access denied"
- Your Facebook account doesn't have access to the ad account
- Contact the ad account admin to grant you access

### "App not found"
- You need to create or get access to the Facebook app
- Or ask someone who has admin access to generate the token for you

## Next Steps

Once you have the token:
1. Copy it
2. Follow instructions in DEPLOYMENT_NEXT_STEPS.md
3. Update the token in the code
4. Redeploy Cloud Functions

