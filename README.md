# Photo Map Explorer

A native macOS app that maps your geotagged photos. Open a folder of photos, see them on an interactive map, inspect their camera metadata, and identify objects in them with on-device AI.

## Features

### 📸 Photo Management
- Open any folder of photos (**⌘O**), drag a folder onto the window, or pick from **File → Open Recent**
- Supported formats: JPEG, PNG, HEIC/HEIF, TIFF, DNG, and RAW (ORF, CR2, CR3, NEF, ARW)
- The last folder reopens automatically at launch (configurable in Settings)
- Search photos by filename, detected object, camera, or coordinates (**⌘F**)
- Sidebar list with photo thumbnails; browse the collection as a map (**⌘1**) or a thumbnail grid (**⌘2**) — the choice persists across launches

### 🗺️ Interactive Mapping
- All geotagged photos appear on the map, with automatic clustering as you zoom out
- Click a cluster to zoom in; click a pin to jump to that photo's details
- The map fits itself to your photos when a folder loads

### 📍 Metadata
- GPS coordinates and altitude
- Camera make/model, lens, exposure summary (focal length, aperture, shutter, ISO), capture date, and pixel dimensions
- All metadata text is selectable and copyable

### 🤖 On-Device Object Detection
- Analyze one photo (**⇧⌘A**) or the whole folder (**⌥⌘A**, cancellable) using Apple's Vision framework
- Confidence threshold and result count are adjustable in **Settings (⌘,)**
- Everything runs locally — no photo ever leaves your Mac

### 🖥️ Mac Behaviours
- Full menu bar command set with keyboard shortcuts
- Native sidebar list with arrow-key navigation
- **Space** or **⌘Y** for Quick Look; double-click the detail image to Quick Look
- Drag photos out of the list (or the detail image) into Finder, Mail, or any other app
- Context menus on every photo: Analyze, Quick Look, Reveal in Finder, Open in Default App, Copy
- **⌥⌘C** copies the photo file, **⇧⌘C** copies its coordinates
- **⇧⌘R** reveals the selected photo in Finder
- **Esc** or **⇧⌘M** returns from a photo to the map
- Window title shows the folder (with proxy icon) and photo counts

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘O | Open Folder |
| ⌘F | Search |
| ⌘1 / ⌘2 | View as map / grid |
| Space / ⌘Y | Quick Look selected photo |
| ⇧⌘A | Analyze selected photo |
| ⌥⌘A | Analyze all photos |
| ⇧⌘R | Reveal in Finder |
| ⌥⌘C | Copy photo file |
| ⇧⌘C | Copy coordinates |
| Esc / ⇧⌘M | Back to all photos |
| ⌘, | Settings |

## Requirements

- **macOS:** 14.0 (Sonoma) or later
- **Building:** Xcode 15+

## Building

```bash
xcodebuild -project PhotoMapApp.xcodeproj -scheme PhotoMapApp -configuration Release build
```

Or open `PhotoMapApp.xcodeproj` in Xcode and press ⌘R.

## Creating Test Data

```bash
mkdir -p ~/TestPhotos && cd ~/TestPhotos
brew install imagemagick exiftool

magick -size 800x600 xc:blue test1.jpg
magick -size 800x600 xc:red test2.jpg

# Los Angeles
exiftool -GPSLatitude=34.0522 -GPSLatitudeRef=N \
         -GPSLongitude=118.2437 -GPSLongitudeRef=W \
         -GPSAltitude=50 test1.jpg

# San Francisco
exiftool -GPSLatitude=37.7749 -GPSLatitudeRef=N \
         -GPSLongitude=122.4194 -GPSLongitudeRef=W \
         -GPSAltitude=52 test2.jpg
```

Then in the app: **⌘O** → choose `~/TestPhotos`.

## Technical Details

- **UI:** SwiftUI with AppKit bridges (MapKit's `MKMapView` for clustering, `NSOpenPanel`, pasteboard, Quick Look)
- **Metadata:** ImageIO (`CGImageSource`) for EXIF, TIFF, and GPS dictionaries
- **AI:** Vision `VNClassifyImageRequest`, run off the main thread against a downsampled thumbnail
- **Persistence:** recent folders and detection preferences in `UserDefaults`

## License

Free to use and modify for personal use.
