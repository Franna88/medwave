# Quick Instructions to See Unknown Campaign Details

## What I Just Did
I added **client-side logging** to your Flutter app that will print details about the "Unknown Campaign" whenever you view the Advertisement Performance screen.

## How to See the Results RIGHT NOW

### Option 1: Hot Reload (Fastest - 1 second)
1. Go to your terminal where Flutter is running
2. Press the **`r`** key (lowercase r)
3. Wait for the hot reload to complete
4. The app will refresh and show the Unknown Campaign details in the terminal

### Option 2: Hot Restart (5 seconds)
1. Go to your terminal where Flutter is running  
2. Press the **`R`** key (uppercase R)
3. Wait for the hot restart to complete

### Option 3: Refresh the Browser (10 seconds)
1. Simply refresh your Chrome browser where the app is running
2. Navigate back to the Advertisement Performance screen

## What You'll See

Once you reload, look in your Flutter terminal for output like this:

```
🔍 UNKNOWN CAMPAIGN FOUND IN FLUTTER:
  Campaign Data: {campaignName: Unknown Campaign, ...}
  Total Opportunities: 52
  Booked Appointments: 6
  Campaign Source: (empty or specific value)
  Campaign Medium: (empty or specific value)
  Number of Ads: 1
    - Ad: Some Ad Name (52 opportunities)
  ---
```

This will tell you:
- How many opportunities are in "Unknown Campaign" (should be 52)
- What source/medium they have (if any)
- The actual ad names associated with these leads

## Next Steps After You See the Data

Once you see what the "Unknown Campaign" actually represents, we can:
1. **Categorize it properly** - If it's a specific source (like "phone calls" or "referrals")
2. **Fix tracking** - If it should have proper UTM parameters
3. **Filter it** - If you want to exclude non-ad leads from this report
4. **Rename it** - Give it a more descriptive name based on what it actually is

## Quick Action
Just press **`r`** in your Flutter terminal now and watch for the output!

