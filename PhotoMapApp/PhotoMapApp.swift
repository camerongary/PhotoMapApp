import SwiftUI
import MapKit
import Vision
import ImageIO
import CoreLocation
import QuickLook
import UniformTypeIdentifiers

// MARK: - App

@main
struct PhotoMapAppApp: App {
    @StateObject private var library = PhotoLibrary()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(library)
        }
        .commands {
            PhotoMapCommands(library: library)
        }

        Settings {
            SettingsView()
        }
    }
}

// MARK: - Settings

enum Pref {
    static let confidenceThreshold = "confidenceThreshold"
    static let maxDetections = "maxDetections"
    static let reopenLastFolder = "reopenLastFolder"
    static let recentFolders = "recentFolders"
    static let browseMode = "browseMode"
    static let sortOrder = "sortOrder"
}

struct SettingsView: View {
    @AppStorage(Pref.confidenceThreshold) private var confidenceThreshold = 0.3
    @AppStorage(Pref.maxDetections) private var maxDetections = 5
    @AppStorage(Pref.reopenLastFolder) private var reopenLastFolder = true

    var body: some View {
        Form {
            Section("Object Detection") {
                Slider(value: $confidenceThreshold, in: 0.1...0.9, step: 0.05) {
                    Text("Minimum Confidence")
                } minimumValueLabel: {
                    Text("10%")
                } maximumValueLabel: {
                    Text("90%")
                }
                LabeledContent("Minimum Confidence", value: confidenceThreshold.formatted(.percent.precision(.fractionLength(0))))
                Stepper("Results per Photo: \(maxDetections)", value: $maxDetections, in: 1...10)
            }
            Section("General") {
                Toggle("Reopen last folder at launch", isOn: $reopenLastFolder)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
        .fixedSize()
    }
}

// MARK: - Menu Commands

struct PhotoMapCommands: Commands {
    @ObservedObject var library: PhotoLibrary

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Open Folder…") {
                library.openFolderPanel()
            }
            .keyboardShortcut("o")

            Menu("Open Recent") {
                ForEach(library.recentFolders, id: \.self) { url in
                    Button(url.lastPathComponent) {
                        library.loadPhotos(from: url)
                    }
                }
                if !library.recentFolders.isEmpty {
                    Divider()
                    Button("Clear Menu") {
                        library.clearRecentFolders()
                    }
                }
            }
        }

        CommandGroup(after: .pasteboard) {
            Divider()
            Button(library.selectionIDs.count > 1 ? "Copy Photo Files" : "Copy Photo File") {
                library.copySelectedFiles()
            }
            .keyboardShortcut("c", modifiers: [.command, .option])
            .disabled(library.selectionIDs.isEmpty)

            Button("Copy Coordinates") {
                library.copySelectedCoordinates()
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(library.singleSelectedPhoto?.location == nil)
        }

        CommandGroup(before: .toolbar) {
            Button("View as Map") {
                library.show(.map)
            }
            .keyboardShortcut("1")

            Button("View as Grid") {
                library.show(.grid)
            }
            .keyboardShortcut("2")

            Divider()

            Picker("Sort By", selection: $library.sortOrder) {
                Text("Name").tag(PhotoSort.name)
                Text("Date Taken").tag(PhotoSort.dateTaken)
            }

            Divider()
        }

        CommandMenu("Photo") {
            Button(library.selectionIDs.count > 1 ? "Analyze Photos" : "Analyze Photo") {
                library.analyzeSelected()
            }
            .keyboardShortcut("a", modifiers: [.command, .shift])
            .disabled(library.selectionIDs.isEmpty)

            Button("Analyze All Photos") {
                library.analyzeAll()
            }
            .keyboardShortcut("a", modifiers: [.command, .option])
            .disabled(library.photos.isEmpty || library.isAnalyzingAll)

            Divider()

            Button("Quick Look") {
                library.quickLookSelected()
            }
            .keyboardShortcut("y")
            .disabled(library.selectionIDs.isEmpty)

            Button("Reveal in Finder") {
                library.revealSelectedInFinder()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(library.selectionIDs.isEmpty)

            Button("Open in Default App") {
                library.openSelectedInDefaultApp()
            }
            .disabled(library.selectionIDs.isEmpty)

            Divider()

            Button("Move to Trash") {
                library.trashSelection()
            }
            .keyboardShortcut(.delete)
            .disabled(library.selectionIDs.isEmpty)

            Divider()

            Button("Show All Photos") {
                library.selectionIDs = []
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
            .disabled(library.selectionIDs.isEmpty)
        }
    }
}

// MARK: - Content

struct ContentView: View {
    @EnvironmentObject var library: PhotoLibrary
    @State private var searchText = ""

    private var filteredPhotos: [PhotoMetadata] {
        guard !searchText.isEmpty else { return library.photos }
        return library.photos.filter { $0.matches(searchText) }
    }

    private var subtitle: String {
        guard !library.photos.isEmpty else { return "" }
        let located = library.locatedPhotos.count
        return "\(library.photos.count) photos · \(located) with location"
    }

    var body: some View {
        splitView
            .searchable(text: $searchText, placement: .sidebar, prompt: "Name, object, or place")
            .navigationTitle(library.folderURL?.lastPathComponent ?? "Photo Map")
            .navigationSubtitle(subtitle)
            .background(WindowDocumentURL(url: library.folderURL))
            .quickLookPreview($library.quickLookItem)
            .toolbar { toolbarContent }
            .alert("Something Went Wrong", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(library.errorMessage ?? "")
            }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                handleDrop(providers)
            }
    }

    private var splitView: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 240, ideal: 300)
        } detail: {
            if let photo = library.singleSelectedPhoto {
                PhotoDetailView(photo: photo)
            } else if library.browseMode == .grid {
                GridPane(photos: filteredPhotos)
            } else {
                MapPane()
            }
        }
    }

    private var browseModeBinding: Binding<BrowseMode> {
        Binding(
            get: { library.browseMode },
            set: { library.show($0) }
        )
    }

    // MARK: Sidebar

    @ViewBuilder
    private var sidebar: some View {
        if library.photos.isEmpty {
            ContentUnavailableView {
                Label("No Photos", systemImage: "photo.on.rectangle.angled")
            } description: {
                Text("Open a folder of photos to map them.")
            } actions: {
                Button("Open Folder…") { library.openFolderPanel() }
            }
        } else if filteredPhotos.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            List(selection: $library.selectionIDs) {
                ForEach(filteredPhotos) { photo in
                    PhotoRow(photo: photo)
                        .contextMenu { PhotoContextMenuItems(photo: photo) }
                        .onDrag { NSItemProvider(contentsOf: photo.fileURL) ?? NSItemProvider() }
                }
            }
            .onCopyCommand {
                library.selectedPhotos.compactMap { NSItemProvider(contentsOf: $0.fileURL) }
            }
            .onDeleteCommand {
                library.trashSelection()
            }
            .onKeyPress(.space) {
                library.quickLookSelected()
                return .handled
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                statusBar
            }
        }
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            if library.isAnalyzingAll {
                ProgressView(value: Double(library.analysisCompleted), total: Double(max(library.photos.count, 1)))
                    .controlSize(.small)
                    .frame(width: 80)
                Text("Analyzing \(library.analysisCompleted) of \(library.photos.count)…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if library.selectionIDs.count > 1 {
                Text("\(library.selectionIDs.count) of \(library.photos.count) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if !searchText.isEmpty {
                Text("\(filteredPhotos.count) of \(library.photos.count) photos")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(library.photos.count == 1 ? "1 photo" : "\(library.photos.count) photos")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.bar)
        .overlay(Divider(), alignment: .top)
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem {
            Picker("View", selection: browseModeBinding) {
                Label("Map", systemImage: "map").tag(BrowseMode.map)
                Label("Grid", systemImage: "square.grid.2x2").tag(BrowseMode.grid)
            }
            .pickerStyle(.segmented)
            .help("Browse photos on a map (⌘1) or in a grid (⌘2)")
        }

        ToolbarItemGroup {
            Button {
                library.openFolderPanel()
            } label: {
                Label("Open Folder", systemImage: "folder")
            }
            .help("Open a folder of photos (⌘O)")

            if library.isAnalyzingAll {
                Button {
                    library.cancelAnalysis()
                } label: {
                    Label("Stop Analysis", systemImage: "stop.circle")
                }
                .help("Stop analyzing photos")
            } else {
                Button {
                    library.analyzeAll()
                } label: {
                    Label("Analyze All", systemImage: "sparkles")
                }
                .help("Detect objects in every photo (⌥⌘A)")
                .disabled(library.photos.isEmpty)
            }

            if let photo = library.singleSelectedPhoto {
                Button {
                    library.quickLookSelected()
                } label: {
                    Label("Quick Look", systemImage: "eye")
                }
                .help("Preview with Quick Look (Space)")

                Button {
                    library.revealSelectedInFinder()
                } label: {
                    Label("Reveal in Finder", systemImage: "questionmark.folder")
                }
                .help("Show this photo in the Finder (⇧⌘R)")

                ShareLink(item: photo.fileURL) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .help("Share this photo")

                Button {
                    library.selectionIDs = []
                } label: {
                    Label("All Photos", systemImage: library.browseMode == .grid ? "square.grid.2x2" : "map")
                }
                .help("Return to all photos (⇧⌘M)")
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { library.errorMessage != nil },
            set: { if !$0 { library.errorMessage = nil } }
        )
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            Task { @MainActor in
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
                    library.loadPhotos(from: isDirectory.boolValue ? url : url.deletingLastPathComponent())
                }
            }
        }
        return true
    }
}

/// Sets the window's represented file (proxy icon in the title bar) to the loaded folder.
struct WindowDocumentURL: NSViewRepresentable {
    let url: URL?

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            nsView.window?.representedURL = url
        }
    }
}

// MARK: - Shared Photo Actions

struct PhotoContextMenuItems: View {
    @EnvironmentObject var library: PhotoLibrary
    let photo: PhotoMetadata

    private var targets: [PhotoMetadata] {
        library.contextTargets(for: photo)
    }

    private var plural: Bool { targets.count > 1 }

    var body: some View {
        Button(plural ? "Analyze Photos" : "Analyze Photo") {
            targets.forEach { library.analyze($0) }
        }
        Button("Quick Look") { library.quickLookItem = photo.fileURL }
        Divider()
        Button("Reveal in Finder") { library.reveal(targets) }
        Button("Open in Default App") { library.openInDefaultApp(targets) }
        ShareLink(items: targets.map(\.fileURL)) {
            Text(plural ? "Share Photos…" : "Share…")
        }
        Divider()
        Button(plural ? "Copy Photo Files" : "Copy Photo File") { library.copyFiles(targets) }
        if !plural, photo.location != nil {
            Button("Copy Coordinates") { library.copyCoordinates(photo) }
        }
        Divider()
        Button("Move to Trash") { library.trash(targets) }
    }
}

// MARK: - Thumbnails

actor ThumbnailStore {
    static let shared = ThumbnailStore()
    private let cache = NSCache<NSString, NSImage>()

    init() {
        cache.countLimit = 600
    }

    func thumbnail(for url: URL, maxPixel: Int) -> NSImage? {
        let key = "\(url.path)#\(maxPixel)" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        let image = NSImage(cgImage: cgImage, size: .zero)
        cache.setObject(image, forKey: key)
        return image
    }
}

/// A square thumbnail that sizes to its container and loads asynchronously.
struct SquareThumbnail: View {
    let url: URL
    let maxPixel: Int
    @State private var image: NSImage?

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Rectangle().fill(.quaternary)
                        Image(systemName: "photo")
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .clipped()
            .accessibilityHidden(true)
            .task(id: url) {
                image = await ThumbnailStore.shared.thumbnail(for: url, maxPixel: maxPixel)
            }
    }
}

// MARK: - Photo Row

struct PhotoRow: View {
    let photo: PhotoMetadata

    var body: some View {
        HStack(spacing: 8) {
            SquareThumbnail(url: photo.fileURL, maxPixel: 96)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 3) {
                Text(photo.filename)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if let location = photo.location {
                        Image(systemName: "mappin.and.ellipse")
                        Text(location.coordinateString)
                    } else {
                        Image(systemName: "location.slash")
                        Text("No location")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let detections = photo.detections, !detections.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(detections.prefix(2), id: \.self) { detection in
                            Text(detection.label)
                                .font(.caption2)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(.tint.opacity(0.15), in: Capsule())
                                .foregroundStyle(.tint)
                        }
                        if detections.count > 2 {
                            Text("+\(detections.count - 2)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Grid Pane

struct GridPane: View {
    @EnvironmentObject var library: PhotoLibrary
    let photos: [PhotoMetadata]

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 14)]

    var body: some View {
        if photos.isEmpty {
            ContentUnavailableView {
                Label("No Photos", systemImage: "square.grid.2x2")
            } description: {
                Text("Open a folder of photos to browse them here.")
            } actions: {
                Button("Open Folder…") { library.openFolderPanel() }
            }
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(photos) { photo in
                        PhotoGridCell(photo: photo, isSelected: library.selectionIDs.contains(photo.id))
                            .onTapGesture {
                                if NSEvent.modifierFlags.contains(.command) {
                                    library.toggleSelection(photo.id)
                                } else {
                                    library.selectionIDs = [photo.id]
                                }
                            }
                            .contextMenu { PhotoContextMenuItems(photo: photo) }
                            .onDrag { NSItemProvider(contentsOf: photo.fileURL) ?? NSItemProvider() }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(photo.filename)
                            .accessibilityAddTraits(photo.location != nil ? [.isButton, .isImage] : [.isButton])
                    }
                }
                .padding(16)
            }
        }
    }
}

struct PhotoGridCell: View {
    let photo: PhotoMetadata
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            SquareThumbnail(url: photo.fileURL, maxPixel: 480)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.accentColor, lineWidth: 3)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if photo.location != nil {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 16))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .red)
                            .shadow(radius: 2)
                            .padding(6)
                    }
                }

            Text(photo.filename)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Map Pane

struct MapPane: View {
    @EnvironmentObject var library: PhotoLibrary

    var body: some View {
        if library.locatedPhotos.isEmpty {
            ContentUnavailableView {
                Label("No Photo Locations", systemImage: "mappin.slash")
            } description: {
                Text(library.photos.isEmpty
                     ? "Open a folder of geotagged photos to see them on the map."
                     : "None of the loaded photos contain GPS data.")
            } actions: {
                if library.photos.isEmpty {
                    Button("Open Folder…") { library.openFolderPanel() }
                }
            }
        } else {
            PhotoMapView(photos: library.locatedPhotos, selectionIDs: $library.selectionIDs)
        }
    }
}

// MARK: - Photo Detail

struct PhotoDetailView: View {
    @EnvironmentObject var library: PhotoLibrary
    let photo: PhotoMetadata
    @State private var photoImage: NSImage?

    var body: some View {
        VStack(spacing: 0) {
            imageSection
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let location = photo.location {
                        locationSection(location)
                    }
                    if photo.hasCameraInfo {
                        cameraSection
                    }
                    detectionSection
                }
                .padding(16)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationSubtitle(photo.filename)
        .onExitCommand {
            library.selectionIDs = []
        }
        .task(id: photo.id) {
            photoImage = nil
            let url = photo.fileURL
            photoImage = await Task.detached(priority: .userInitiated) {
                NSImage(contentsOf: url)
            }.value
        }
    }

    @ViewBuilder
    private var imageSection: some View {
        Group {
            if let photoImage {
                Image(nsImage: photoImage)
                    .resizable()
                    .scaledToFit()
                    .onDrag { NSItemProvider(contentsOf: photo.fileURL) ?? NSItemProvider() }
                    .onTapGesture(count: 2) {
                        library.quickLookItem = photo.fileURL
                    }
                    .help("Double-click to Quick Look; drag to copy the file elsewhere")
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 380)
        .padding(12)
    }

    private func locationSection(_ location: LocationData) -> some View {
        GroupBox("Location") {
            VStack(alignment: .leading, spacing: 6) {
                LabeledContent("Latitude", value: String(format: "%.5f", location.latitude))
                LabeledContent("Longitude", value: String(format: "%.5f", location.longitude))
                if let altitude = location.altitude {
                    LabeledContent("Altitude", value: String(format: "%.1f m", altitude))
                }
                PhotoMapView(photos: [photo], selectionIDs: .constant([]))
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .padding(.top, 4)
            }
            .textSelection(.enabled)
            .padding(4)
        }
    }

    private var cameraSection: some View {
        GroupBox("Camera") {
            VStack(alignment: .leading, spacing: 6) {
                if let camera = photo.camera {
                    LabeledContent("Camera", value: camera)
                }
                if let lens = photo.lens {
                    LabeledContent("Lens", value: lens)
                }
                if let exposure = photo.exposureSummary {
                    LabeledContent("Exposure", value: exposure)
                }
                if let date = photo.dateTaken {
                    LabeledContent("Taken", value: date.formatted(date: .abbreviated, time: .shortened))
                }
                if let dimensions = photo.pixelDimensions {
                    LabeledContent("Dimensions", value: dimensions)
                }
            }
            .textSelection(.enabled)
            .padding(4)
        }
    }

    private var detectionSection: some View {
        GroupBox("Objects Detected") {
            VStack(alignment: .leading, spacing: 6) {
                if library.analyzingIDs.contains(photo.id) {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                } else if let detections = photo.detections {
                    if detections.isEmpty {
                        Text("Nothing recognized above the confidence threshold.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(detections, id: \.self) { detection in
                            HStack {
                                Text(detection.label)
                                Spacer()
                                Text(detection.confidence.formatted(.percent.precision(.fractionLength(0))))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                        .textSelection(.enabled)
                    }
                } else {
                    Button("Analyze Photo") {
                        library.analyze(photo)
                    }
                }
            }
            .padding(4)
        }
    }
}

// MARK: - Map View

final class PhotoAnnotation: NSObject, MKAnnotation {
    let photoID: URL
    let coordinate: CLLocationCoordinate2D
    let title: String?

    init(photoID: URL, title: String, coordinate: CLLocationCoordinate2D) {
        self.photoID = photoID
        self.title = title
        self.coordinate = coordinate
    }
}

struct PhotoMapView: NSViewRepresentable {
    let photos: [PhotoMetadata]
    @Binding var selectionIDs: Set<URL>

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        context.coordinator.apply(photos, to: mapView)
        return mapView
    }

    func updateNSView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.apply(photos, to: mapView)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: PhotoMapView
        private var currentIDs: Set<URL> = []

        init(_ parent: PhotoMapView) {
            self.parent = parent
        }

        func apply(_ photos: [PhotoMetadata], to mapView: MKMapView) {
            let located = photos.filter { $0.location != nil }
            let ids = Set(located.map(\.id))
            guard ids != currentIDs else { return }
            currentIDs = ids

            mapView.removeAnnotations(mapView.annotations)
            let annotations = located.map { photo in
                PhotoAnnotation(photoID: photo.id, title: photo.filename, coordinate: photo.location!.coordinate)
            }
            mapView.addAnnotations(annotations)

            guard !annotations.isEmpty else { return }
            if annotations.count == 1 {
                let region = MKCoordinateRegion(
                    center: annotations[0].coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
                mapView.setRegion(region, animated: false)
            } else {
                let rect = MKMapRect.from(annotations.map(\.coordinate))
                mapView.setVisibleMapRect(
                    rect,
                    edgePadding: NSEdgeInsets(top: 40, left: 40, bottom: 40, right: 40),
                    animated: false
                )
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let photoAnnotation = annotation as? PhotoAnnotation else { return nil }
            let identifier = "photo"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: photoAnnotation, reuseIdentifier: identifier)
            view.annotation = photoAnnotation
            view.clusteringIdentifier = "photo"
            view.canShowCallout = true
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let cluster = view.annotation as? MKClusterAnnotation {
                mapView.deselectAnnotation(cluster, animated: false)
                mapView.showAnnotations(cluster.memberAnnotations, animated: true)
            } else if let annotation = view.annotation as? PhotoAnnotation {
                let id = annotation.photoID
                DispatchQueue.main.async {
                    self.parent.selectionIDs = [id]
                }
            }
        }
    }
}

// MARK: - Library Model

enum BrowseMode: String {
    case map
    case grid
}

enum PhotoSort: String {
    case name
    case dateTaken
}

@MainActor
final class PhotoLibrary: ObservableObject {
    @Published var photos: [PhotoMetadata] = []
    @Published var selectionIDs: Set<URL> = []
    @Published var browseMode: BrowseMode {
        didSet { UserDefaults.standard.set(browseMode.rawValue, forKey: Pref.browseMode) }
    }
    @Published var sortOrder: PhotoSort {
        didSet {
            UserDefaults.standard.set(sortOrder.rawValue, forKey: Pref.sortOrder)
            photos = sorted(photos)
        }
    }
    @Published var folderURL: URL?
    @Published var recentFolders: [URL] = []
    @Published var isAnalyzingAll = false
    @Published var analysisCompleted = 0
    @Published var analyzingIDs: Set<URL> = []
    @Published var errorMessage: String?
    @Published var quickLookItem: URL?

    private var analysisTask: Task<Void, Never>?
    private static let maxRecentFolders = 10

    /// All currently selected photos, in list order.
    var selectedPhotos: [PhotoMetadata] {
        photos.filter { selectionIDs.contains($0.id) }
    }

    /// The selected photo when exactly one is selected — drives the detail view.
    var singleSelectedPhoto: PhotoMetadata? {
        selectionIDs.count == 1 ? selectedPhotos.first : nil
    }

    var locatedPhotos: [PhotoMetadata] {
        photos.filter { $0.location != nil }
    }

    func toggleSelection(_ id: URL) {
        if selectionIDs.contains(id) {
            selectionIDs.remove(id)
        } else {
            selectionIDs.insert(id)
        }
    }

    /// Context-menu convention: acting on a selected item targets the whole
    /// selection; acting on an unselected item targets just that item.
    func contextTargets(for photo: PhotoMetadata) -> [PhotoMetadata] {
        selectionIDs.contains(photo.id) && selectionIDs.count > 1 ? selectedPhotos : [photo]
    }

    func sorted(_ list: [PhotoMetadata]) -> [PhotoMetadata] {
        switch sortOrder {
        case .name:
            return list.sorted { $0.filename.localizedStandardCompare($1.filename) == .orderedAscending }
        case .dateTaken:
            return list.sorted { ($0.dateTaken ?? .distantPast) < ($1.dateTaken ?? .distantPast) }
        }
    }

    /// Switches the overview between map and grid, returning to it if a photo is open.
    func show(_ mode: BrowseMode) {
        browseMode = mode
        selectionIDs = []
    }

    init() {
        browseMode = BrowseMode(rawValue: UserDefaults.standard.string(forKey: Pref.browseMode) ?? "") ?? .map
        sortOrder = PhotoSort(rawValue: UserDefaults.standard.string(forKey: Pref.sortOrder) ?? "") ?? .name
        UserDefaults.standard.register(defaults: [
            Pref.confidenceThreshold: 0.3,
            Pref.maxDetections: 5,
            Pref.reopenLastFolder: true,
        ])
        recentFolders = Self.loadRecentFolders()
        if UserDefaults.standard.bool(forKey: Pref.reopenLastFolder),
           let lastFolder = recentFolders.first,
           FileManager.default.fileExists(atPath: lastFolder.path) {
            loadPhotos(from: lastFolder)
        }
    }

    // MARK: Loading

    func openFolderPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder of photos to map"
        panel.prompt = "Open"
        if panel.runModal() == .OK, let url = panel.url {
            loadPhotos(from: url)
        }
    }

    func loadPhotos(from url: URL) {
        cancelAnalysis()
        Task {
            do {
                let loaded = try await PhotoScanner.scan(url)
                photos = sorted(loaded)
                folderURL = url
                selectionIDs = []
                addRecentFolder(url)
                if loaded.isEmpty {
                    errorMessage = "No supported photos were found in “\(url.lastPathComponent)”."
                }
            } catch {
                errorMessage = "Couldn’t read “\(url.lastPathComponent)”: \(error.localizedDescription)"
            }
        }
    }

    // MARK: Recents

    private static func loadRecentFolders() -> [URL] {
        let paths = UserDefaults.standard.stringArray(forKey: Pref.recentFolders) ?? []
        return paths.map { URL(fileURLWithPath: $0) }
    }

    private func addRecentFolder(_ url: URL) {
        var recents = recentFolders.filter { $0.path != url.path }
        recents.insert(url, at: 0)
        recentFolders = Array(recents.prefix(Self.maxRecentFolders))
        UserDefaults.standard.set(recentFolders.map(\.path), forKey: Pref.recentFolders)
    }

    func clearRecentFolders() {
        recentFolders = []
        UserDefaults.standard.removeObject(forKey: Pref.recentFolders)
    }

    // MARK: Analysis

    func analyze(_ photo: PhotoMetadata) {
        guard !analyzingIDs.contains(photo.id) else { return }
        analyzingIDs.insert(photo.id)
        Task {
            let detections = await ObjectClassifier.classify(url: photo.fileURL)
            analyzingIDs.remove(photo.id)
            if let index = photos.firstIndex(where: { $0.id == photo.id }) {
                photos[index].detections = detections
            }
        }
    }

    func analyzeSelected() {
        for photo in selectedPhotos {
            analyze(photo)
        }
    }

    func analyzeAll() {
        guard !photos.isEmpty, !isAnalyzingAll else { return }
        isAnalyzingAll = true
        analysisCompleted = 0
        analysisTask = Task {
            for photo in photos {
                if Task.isCancelled { break }
                let detections = await ObjectClassifier.classify(url: photo.fileURL)
                if let index = photos.firstIndex(where: { $0.id == photo.id }) {
                    photos[index].detections = detections
                }
                analysisCompleted += 1
            }
            isAnalyzingAll = false
        }
    }

    func cancelAnalysis() {
        analysisTask?.cancel()
        analysisTask = nil
        isAnalyzingAll = false
    }

    // MARK: Actions on selection

    func quickLookSelected() {
        quickLookItem = selectedPhotos.first?.fileURL
    }

    func revealSelectedInFinder() {
        reveal(selectedPhotos)
    }

    func reveal(_ targets: [PhotoMetadata]) {
        guard !targets.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(targets.map(\.fileURL))
    }

    func openSelectedInDefaultApp() {
        openInDefaultApp(selectedPhotos)
    }

    func openInDefaultApp(_ targets: [PhotoMetadata]) {
        for photo in targets {
            NSWorkspace.shared.open(photo.fileURL)
        }
    }

    func copySelectedFiles() {
        copyFiles(selectedPhotos)
    }

    func copyFiles(_ targets: [PhotoMetadata]) {
        guard !targets.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(targets.map { $0.fileURL as NSURL })
    }

    func copySelectedCoordinates() {
        if let photo = singleSelectedPhoto {
            copyCoordinates(photo)
        }
    }

    func trashSelection() {
        trash(selectedPhotos)
    }

    func trash(_ targets: [PhotoMetadata]) {
        guard !targets.isEmpty else { return }
        var trashedIDs: Set<URL> = []
        for photo in targets {
            do {
                try FileManager.default.trashItem(at: photo.fileURL, resultingItemURL: nil)
                trashedIDs.insert(photo.id)
            } catch {
                errorMessage = "Couldn’t move “\(photo.filename)” to the Trash: \(error.localizedDescription)"
                break
            }
        }
        photos.removeAll { trashedIDs.contains($0.id) }
        selectionIDs.subtract(trashedIDs)
    }

    func copyCoordinates(_ photo: PhotoMetadata) {
        guard let location = photo.location else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(location.coordinateString, forType: .string)
    }
}

// MARK: - Folder Scanning

enum PhotoScanner {
    static let supportedExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "tif", "tiff", "raw", "orf", "cr2", "cr3", "nef", "arw", "dng",
    ]

    nonisolated static func scan(_ folderURL: URL) async throws -> [PhotoMetadata] {
        let accessing = folderURL.startAccessingSecurityScopedResource()
        defer {
            if accessing { folderURL.stopAccessingSecurityScopedResource() }
        }

        let files = try FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        return files
            .filter { supportedExtensions.contains($0.pathExtension.lowercased()) }
            .compactMap { extractMetadata(from: $0) }
            .sorted { $0.filename.localizedStandardCompare($1.filename) == .orderedAscending }
    }

    nonisolated static func extractMetadata(from fileURL: URL) -> PhotoMetadata? {
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else { return nil }
        var photo = PhotoMetadata(filename: fileURL.lastPathComponent, fileURL: fileURL)

        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return photo
        }

        if let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
            photo.location = LocationData.extractFromGPS(gps)
        }

        if let width = properties[kCGImagePropertyPixelWidth as String] as? Int,
           let height = properties[kCGImagePropertyPixelHeight as String] as? Int {
            photo.pixelDimensions = "\(width) × \(height)"
        }

        let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
        let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any]

        let make = tiff?[kCGImagePropertyTIFFMake as String] as? String
        let model = tiff?[kCGImagePropertyTIFFModel as String] as? String
        photo.camera = [make, model]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .nilIfEmpty

        photo.lens = (exif?[kCGImagePropertyExifLensModel as String] as? String)?.nilIfEmpty
        photo.exposureSummary = exposureSummary(from: exif)
        photo.dateTaken = dateTaken(from: exif)

        return photo
    }

    private nonisolated static func exposureSummary(from exif: [String: Any]?) -> String? {
        guard let exif else { return nil }
        var parts: [String] = []
        if let focal = exif[kCGImagePropertyExifFocalLength as String] as? Double {
            parts.append("\(Int(focal.rounded())) mm")
        }
        if let fNumber = exif[kCGImagePropertyExifFNumber as String] as? Double {
            parts.append(String(format: "ƒ/%.1f", fNumber))
        }
        if let exposure = exif[kCGImagePropertyExifExposureTime as String] as? Double, exposure > 0 {
            if exposure < 1 {
                parts.append("1/\(Int((1 / exposure).rounded())) s")
            } else {
                parts.append(String(format: "%.1f s", exposure))
            }
        }
        if let isoValues = exif[kCGImagePropertyExifISOSpeedRatings as String] as? [Int], let iso = isoValues.first {
            parts.append("ISO \(iso)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private nonisolated static func dateTaken(from exif: [String: Any]?) -> Date? {
        guard let dateString = exif?[kCGImagePropertyExifDateTimeOriginal as String] as? String else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: dateString)
    }
}

// MARK: - Object Classification

enum ObjectClassifier {
    nonisolated static func classify(url: URL) async -> [Detection] {
        let threshold = UserDefaults.standard.double(forKey: Pref.confidenceThreshold)
        let maxResults = UserDefaults.standard.integer(forKey: Pref.maxDetections)

        return await Task.detached(priority: .userInitiated) { () -> [Detection] in
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return [] }
            let thumbnailOptions: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1024,
            ]
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary)
                ?? CGImageSourceCreateImageAtIndex(source, 0, nil) else { return [] }

            let request = VNClassifyImageRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                return []
            }

            return (request.results ?? [])
                .filter { $0.confidence >= Float(threshold) }
                .sorted { $0.confidence > $1.confidence }
                .prefix(max(maxResults, 1))
                .map { Detection(label: $0.identifier, confidence: Double($0.confidence)) }
        }.value
    }
}

// MARK: - Models

struct PhotoMetadata: Identifiable, Hashable {
    let filename: String
    let fileURL: URL
    var location: LocationData?
    var detections: [Detection]?
    var camera: String?
    var lens: String?
    var exposureSummary: String?
    var dateTaken: Date?
    var pixelDimensions: String?

    var id: URL { fileURL }

    var hasCameraInfo: Bool {
        camera != nil || lens != nil || exposureSummary != nil || dateTaken != nil || pixelDimensions != nil
    }

    func matches(_ query: String) -> Bool {
        if filename.localizedCaseInsensitiveContains(query) { return true }
        if let camera, camera.localizedCaseInsensitiveContains(query) { return true }
        if let lens, lens.localizedCaseInsensitiveContains(query) { return true }
        if let detections, detections.contains(where: { $0.label.localizedCaseInsensitiveContains(query) }) {
            return true
        }
        if let location, location.coordinateString.contains(query) { return true }
        return false
    }
}

struct Detection: Hashable {
    let label: String
    let confidence: Double
}

struct LocationData: Hashable {
    let latitude: Double
    let longitude: Double
    let altitude: Double?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var coordinateString: String {
        String(format: "%.4f, %.4f", latitude, longitude)
    }

    static func extractFromGPS(_ gpsData: [String: Any]) -> LocationData? {
        guard let latitude = gpsData[kCGImagePropertyGPSLatitude as String] as? Double,
              let longitude = gpsData[kCGImagePropertyGPSLongitude as String] as? Double else {
            return nil
        }

        let altitude = gpsData[kCGImagePropertyGPSAltitude as String] as? Double
        let latRef = gpsData[kCGImagePropertyGPSLatitudeRef as String] as? String
        let lonRef = gpsData[kCGImagePropertyGPSLongitudeRef as String] as? String

        return LocationData(
            latitude: latRef == "S" ? -latitude : latitude,
            longitude: lonRef == "W" ? -longitude : longitude,
            altitude: altitude
        )
    }
}

// MARK: - Helpers

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

extension MKMapRect {
    static func from(_ coordinates: [CLLocationCoordinate2D]) -> MKMapRect {
        coordinates.reduce(MKMapRect.null) { rect, coordinate in
            let point = MKMapPoint(coordinate)
            return rect.union(MKMapRect(x: point.x, y: point.y, width: 1, height: 1))
        }
    }
}
