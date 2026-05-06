# Photo Map Explorer

A beautiful macOS application that maps your geotagged photos, displays their locations on an interactive map, extracts metadata, and uses on-device AI to identify objects in your photos.

## Features

### 📸 Photo Management
- Load photos from any folder on your Mac
- Support for multiple formats: JPEG, PNG, HEIC, RAW, ORF (Olympus), and DNG
- View photos in an organized list with GPS status indicators
- Quick metadata display for each photo

### 🗺️ Interactive Mapping
- Display all geotagged photos on an interactive map
- Automatic clustering of nearby photos (groups photos within 1km)
- Toggle clustering on/off with "Group Nearby" button
- Map automatically fits to show all photo locations
- Zoom in/out to explore specific areas

### 📍 GPS & Location Data
- Extract GPS coordinates from photo metadata
- Display latitude, longitude, and elevation for each photo
- Track highest and lowest elevation across all photos
- View location details in the map info panel

### 🤖 AI-Powered Object Detection
- Analyze photos using Apple's on-device Vision framework
- Detect objects in photos with confidence scores
- Color-coded confidence indicators (green/yellow/orange)
- All processing happens locally on your Mac (no internet required)

### 📋 Metadata Display
- View complete camera information:
  - Camera make and model
  - Lens information
  - Focal length, ISO, aperture, shutter speed
  - Capture date and time
  - And more!
- Supports extended metadata extraction with exiftool integration

### 🎨 Beautiful Interface
- Clean, modern SwiftUI design
- Split-view layout with photo list and map
- Smooth navigation between photos and details
- Custom app icon

---

## System Requirements

- **macOS:** 13.0 or later
- **Xcode:** 15.0 or later (for building)
- **Swift:** 5.9+
- **Hardware:** Any modern Mac (Intel or Apple Silicon)

## Installation & Setup

### Step 1: Create a New Xcode Project

1. Open Xcode
2. File → New → Project
3. Choose **macOS → App**
4. Fill in the form:
   - **Product Name:** `PhotoMapApp`
   - **Team:** None (or your team)
   - **Organization Identifier:** `com.youname` (e.g., `com.camerongary`)
   - **Interface:** SwiftUI
   - **Language:** Swift
5. Click **Create** and choose where to save

### Step 2: Replace the Code

1. In Xcode, open the main Swift file (usually in the left sidebar)
2. Select all the code (⌘A)
3. Delete it
4. Download `PhotoMapApp-FINAL-WORKING.swift`
5. Copy all the code from that file (⌘A → ⌘C)
6. Paste into Xcode (⌘V)

### Step 3: Add the App Icon (Optional)

1. Download `AppIcon.svg`
2. In Xcode:
   - Click the **PhotoMapApp** project
   - Click the **PhotoMapApp** target
   - Go to **App Icons and Launch Screen**
   - Drag `AppIcon.svg` into the AppIcon area
   - Xcode will automatically generate all required sizes

### Step 4: Fix Code Signing (if needed)

If you get a "CodeSign failed" error:

1. Click **PhotoMapApp** target
2. Click **Signing & Capabilities** tab
3. Uncheck **"Automatically manage signing"**
4. Set **Signing Certificate** to **"Sign to Run Locally"**

If the error persists:

1. Close Xcode
2. Run in Terminal:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/PhotoMapApp*
   ```
3. Reopen Xcode and try building again

### Step 5: Build & Run

1. Press **⌘B** to build (wait for "Build complete!")
2. Press **⌘R** to run
3. The app will launch in a new window

---

## How to Use

### Loading Photos

1. **Click "Select Photo Folder"** button in the top-left
2. **Browse** to a folder containing your photos
3. **Select the folder** and click "Open"
4. The app will:
   - Load all photos in that folder
   - Display them in the left sidebar
   - Show the count of photos and GPS-tagged photos
   - Display highest/lowest elevation

### Viewing Photos

**In the List (Left Sidebar):**
- Photos are listed with their filenames
- Red map pin icon + coordinates = photo has GPS data
- Orange warning = no GPS data embedded
- **Click a photo** to view its full details and metadata

**In the Detail View:**
- **Photo thumbnail** at the top
- **Location data** with exact GPS coordinates and elevation
- **Camera metadata** (make, model, lens, ISO, aperture, etc.)
- **"Back to Map" button** to return to the map view
- **"Analyze" button** to detect objects in the photo

### Exploring the Map

1. The **right panel** shows an interactive map
2. **Red markers** = individual photos
3. **Orange markers** = clusters of nearby photos (hover to see count)
4. **Toggle "Group Nearby"** to cluster/uncluster photos
5. **Zoom in/out** with scroll wheel or trackpad
6. **Pan** by clicking and dragging
7. **Map Info** box shows:
   - Total number of photos
   - Number of clusters
   - Selected photo details

### Analyzing Photos for Objects

1. **Click a photo** in the list or open its detail view
2. Click the **"Analyze"** button
3. **Wait** for the analysis to complete (shows progress indicator)
4. See **detected objects** with confidence scores:
   - Green bar = high confidence (>80%)
   - Yellow bar = medium confidence (>60%)
   - Orange bar = lower confidence (<60%)
5. **Results reset** automatically when you switch to another photo

### Viewing Metadata

Each photo detail view shows:
- **Filename** - the original filename
- **Location Data** - GPS coordinates, elevation
- **Camera Metadata** - Make, model, lens, ISO, aperture, shutter speed, date/time
- **Detected Objects** - results from AI analysis

---

## Optional: Installing exiftool for Enhanced ORF Support

For better metadata extraction from Olympus RAW files (.orf), install exiftool:

```bash
brew install exiftool
```

The app will automatically detect and use it if available. Without it, the app falls back to standard EXIF extraction.

---

## Creating Test Data

To test the app with sample photos:

```bash
# Create a test folder
mkdir -p ~/TestPhotos
cd ~/TestPhotos

# Create test images (requires ImageMagick)
brew install imagemagick
magick -size 800x600 xc:blue test1.jpg
magick -size 800x600 xc:red test2.jpg

# Add GPS metadata (requires exiftool)
brew install exiftool

# Add GPS to test1.jpg (Los Angeles)
exiftool -GPSLatitude=34.0522 -GPSLatitudeRef=N \
          -GPSLongitude=118.2437 -GPSLongitudeRef=W \
          -GPSAltitude=50 test1.jpg

# Add GPS to test2.jpg (San Francisco)
exiftool -GPSLatitude=37.7749 -GPSLatitudeRef=N \
          -GPSLongitude=122.4194 -GPSLongitudeRef=W \
          -GPSAltitude=52 test2.jpg
```

Then in the app: **Select Photo Folder** → Choose `~/TestPhotos` → See your test photos on the map!

---

## Supported Photo Formats

| Format | Extension | Notes |
|--------|-----------|-------|
| JPEG | .jpg, .jpeg | Widely supported |
| PNG | .png | Widely supported |
| HEIC | .heic | Apple's modern format |
| RAW | .raw | Generic raw format |
| **Olympus RAW** | **.orf** | **Best with exiftool installed** |
| DNG | .dng | Adobe's raw format |

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| **⌘B** | Build the app |
| **⌘R** | Run the app |
| **⌘Q** | Quit the app |
| **⌘,** | Open Preferences |

---

## Troubleshooting

### "CodeSign failed" Error

**Solution:**
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/PhotoMapApp*
```
Then reopen Xcode and rebuild.

### Photos Not Loading

1. Check that the folder contains supported formats (.jpg, .png, .heic, .orf, etc.)
2. Ensure you have read permissions for the folder
3. Try with the test folder (`~/TestPhotos`) first

### No GPS Data Showing

1. Some photos may not have GPS embedded
2. Use Preview.app to check: Right-click photo → Get Info → see if GPS is listed
3. Create test photos with GPS data (see "Creating Test Data" above)

### Object Detection Not Working

1. Ensure the photo format is supported (JPEG, PNG, HEIC, etc.)
2. Try with different photos - some may not have detectable objects
3. Works best with clear, well-lit photos

### App Doesn't Appear in Applications Folder

The app runs in development mode from Xcode. To create a production app:
1. In Xcode: Product → Archive
2. Follow the archiving wizard
3. Export to Applications

---

## Technical Details

### Architecture

- **Language:** Swift
- **UI Framework:** SwiftUI
- **Maps:** MapKit
- **AI/ML:** Vision framework (on-device)
- **Metadata:** EXIF extraction + exiftool integration
- **File System:** Foundation framework

### Data Processing

- All GPS coordinates are parsed from EXIF data
- Elevation data extracted from GPS EXIF tags
- Object detection runs locally using Apple's Vision framework
- No data is sent to any servers - everything stays on your Mac

### Performance

- Handles 50-100 photos smoothly
- Larger collections (500+) may need pagination (future enhancement)
- Object detection takes 1-3 seconds per photo depending on image size

---

## Tips & Best Practices

### For Best Results

1. **Use high-quality photos** - Object detection works better with clear images
2. **Enable location services** on your camera - Ensures GPS data is embedded
3. **Try different folders** - Start with a small set of 5-10 photos to test
4. **Use recent photos** - Modern cameras embed more complete metadata

### Organization

1. Keep geotagged photos in separate folders by trip or date
2. Use consistent naming conventions for easy browsing
3. Check GPS data before importing with Preview.app

---

## Credits

Built with:
- Apple's MapKit for interactive mapping
- Vision framework for on-device AI object detection
- SwiftUI for the beautiful user interface
- exiftool (optional) for enhanced metadata extraction

---

## License

This app is free to use and modify for personal use.

---

## Questions or Issues?

If you encounter any problems:

1. Check the Troubleshooting section above
2. Verify all System Requirements are met
3. Try rebuilding with a clean derived data folder
4. Check that you're using the latest code

---

**Enjoy mapping your photos!** 📸🗺️✨
