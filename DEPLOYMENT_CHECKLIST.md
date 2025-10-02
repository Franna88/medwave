# 🚀 MedWave APK Deployment Checklist

## Pre-Build Checklist
- [ ] Update version number in `pubspec.yaml`
- [ ] Test app thoroughly on device/emulator
- [ ] Verify Firebase configuration is correct
- [ ] Check all features work offline/online
- [ ] Review and update app permissions
- [ ] Ensure release keystore is available
- [ ] Update app description/metadata if needed

## Build Process
- [ ] Run `./build_and_deploy.sh` script OR manual steps below:
  - [ ] `flutter clean`
  - [ ] `flutter pub get`
  - [ ] `flutter build apk --release`
- [ ] Verify APK builds successfully
- [ ] Check APK size is reasonable (current: ~67MB)
- [ ] Test install on clean device

## Security & Verification
- [ ] Generate SHA-256 checksum
- [ ] Update verification.txt with new checksum
- [ ] Test APK on multiple Android versions
- [ ] Verify app signature is correct
- [ ] Scan APK for security issues (optional)

## Documentation Updates
- [ ] Update download page (`apk_download.html`)
  - [ ] New version number
  - [ ] New file size
  - [ ] New build date
  - [ ] New SHA-256 checksum
- [ ] Update CHANGELOG.md with release notes
- [ ] Update user installation guide if needed
- [ ] Review and update troubleshooting section

## Hosting & Distribution
- [ ] Choose hosting platform:
  - [ ] GitHub Releases (recommended)
  - [ ] Firebase Hosting
  - [ ] Cloud storage (Google Drive, Dropbox)
  - [ ] Custom web server
- [ ] Upload APK file
- [ ] Upload download page
- [ ] Upload verification files
- [ ] Test download link works
- [ ] Test installation from download link

## Post-Deployment
- [ ] Send download link to beta testers
- [ ] Monitor for installation issues
- [ ] Collect user feedback
- [ ] Document any issues found
- [ ] Plan next release if needed

## Communication
- [ ] Notify users via:
  - [ ] Email announcement
  - [ ] In-app notification (if previous version supports it)
  - [ ] Support documentation update
  - [ ] Training materials update
- [ ] Update support team with new version info
- [ ] Prepare FAQ for common issues

## Rollback Plan
- [ ] Keep previous version APK available
- [ ] Document how to revert if issues arise
- [ ] Have rollback communication ready
- [ ] Monitor user feedback for first 24-48 hours

## Hosting Platform Specific Steps

### GitHub Releases
1. [ ] Create new release tag (e.g., v1.2.7)
2. [ ] Upload APK as release asset
3. [ ] Copy download page content to release description
4. [ ] Publish release
5. [ ] Update download links

### Firebase Hosting
1. [ ] Place files in `public/` directory
2. [ ] Run `firebase deploy --only hosting`
3. [ ] Test deployed URLs
4. [ ] Update DNS if needed

### Cloud Storage
1. [ ] Upload to shared folder
2. [ ] Set public permissions
3. [ ] Get public download links
4. [ ] Test download works from various networks

## Version Management

### Current Version: 1.2.7+9
- [ ] APK built: ✅
- [ ] Size: 66.8MB
- [ ] SHA-256: 49643b89a2b59edb5ce83fb25feb7aa231c6d8db37d3c213bdd57c1311719874
- [ ] Signed: ✅
- [ ] Tested: ⏳

### Next Version Planning
- [ ] Identify features for next release
- [ ] Set target release date
- [ ] Update project roadmap
- [ ] Schedule testing phases

## Emergency Procedures

### If APK is Compromised
1. [ ] Immediately remove download links
2. [ ] Notify all users via emergency communication
3. [ ] Investigate security breach
4. [ ] Build new signed APK with different signature if needed
5. [ ] Implement additional security measures

### If Hosting Goes Down
1. [ ] Have backup hosting ready
2. [ ] Update download links quickly
3. [ ] Communicate with users about temporary issues
4. [ ] Monitor backup hosting performance

---

**Date Completed:** ___________  
**Deployed By:** ___________  
**Version:** ___________  
**Notes:** ___________
