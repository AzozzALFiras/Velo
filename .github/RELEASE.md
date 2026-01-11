# Release Process

## Automated Releases

Velo uses GitHub Actions for automated releases. When you push a version tag, the workflow automatically:

1. ✅ Builds the Release configuration
2. 📦 Creates a DMG installer
3. 🔐 Generates SHA-256 checksums
4. 🚀 Publishes a GitHub Release with auto-generated notes

## Creating a Release

### 1. Update Version
Update the version in `Velo/Info.plist`:
```xml
<key>CFBundleShortVersionString</key>
<string>1.0.0</string>
```

### 2. Commit Changes
```bash
git add .
git commit -m "chore: bump version to 1.0.0"
git push origin main
```

### 3. Create and Push Tag
```bash
git tag v1.0.0
git push origin v1.0.0
```

### 4. Wait for Workflow
The GitHub Actions workflow will automatically:
- Build the app
- Create `Velo-1.0.0.dmg`
- Generate checksums
- Create a draft release

### 5. Edit Release (Optional)
Go to GitHub Releases and edit the auto-generated release to:
- Add screenshots
- Highlight key features
- Add upgrade instructions

## Manual Release

If you need to create a release manually:

```bash
# Build
xcodebuild -scheme Velo -configuration Release -archivePath build/Velo.xcarchive archive

# Export
xcodebuild -exportArchive -archivePath build/Velo.xcarchive -exportPath build/Release -exportOptionsPlist exportOptions.plist

# Create DMG
create-dmg \
  --volname "Velo" \
  --window-pos 200 120 \
  --window-size 800 450 \
  --icon-size 100 \
  --icon "Velo.app" 200 190 \
  --hide-extension "Velo.app" \
  --app-drop-link 600 185 \
  "Velo-1.0.0.dmg" \
  "build/Release/Velo.app"

# Checksum
shasum -a 256 Velo-1.0.0.dmg > checksums.txt
```

## Version Naming

Follow [Semantic Versioning](https://semver.org/):
- **v1.0.0** - Major release (breaking changes)
- **v1.1.0** - Minor release (new features)
- **v1.0.1** - Patch release (bug fixes)

## Pre-release

For beta versions, use:
```bash
git tag v1.0.0-beta.1
git push origin v1.0.0-beta.1
```

The workflow will mark it as a pre-release automatically.
