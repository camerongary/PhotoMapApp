import SwiftUI
import MapKit
import Vision
import ImageIO
import CoreLocation

@main
struct PhotoMapAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = PhotoViewModel()
    @State private var selectedPhoto: PhotoMetadata?
    @State private var showingFilePicker = false
    @State private var isAnalyzingAll = false
    @State private var searchText = ""
    
    var filteredPhotos: [PhotoMetadata] {
        if searchText.isEmpty {
            return viewModel.photos
        }
        return viewModel.photos.filter { photo in
            // Search by filename
            if photo.filename.localizedCaseInsensitiveContains(searchText) {
                return true
            }
            // Search by detected objects
            if let detections = photo.detections {
                return detections.contains { detection in
                    detection.localizedCaseInsensitiveContains(searchText)
                }
            }
            // Search by coordinates
            if let location = photo.location {
                let coordString = "\(String(format: "%.4f", location.latitude)), \(String(format: "%.4f", location.longitude))"
                if coordString.contains(searchText) {
                    return true
                }
            }
            return false
        }
    }
    
    var body: some View {
        NavigationSplitView {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Button(action: { showingFilePicker = true }) {
                        Label("Select Folder", systemImage: "folder.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    
                    Button(action: analyzeAll) {
                        Label("Analyze All", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .disabled(viewModel.photos.isEmpty || isAnalyzingAll)
                }
                
                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search photos, objects, or location...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 8)
                
                List(filteredPhotos, id: \.fileURL) { photo in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(photo.filename)
                                    .font(.headline)
                                    .lineLimit(1)
                                
                                if let location = photo.location {
                                    Text("📍 \(String(format: "%.4f, %.4f", location.latitude, location.longitude))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let detections = photo.detections, !detections.isEmpty {
                                    HStack(spacing: 4) {
                                        ForEach(detections.prefix(2), id: \.self) { detection in
                                            Text(detection.split(separator: " ").first.map(String.init) ?? detection)
                                                .font(.caption2)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.blue.opacity(0.2))
                                                .foregroundColor(.blue)
                                                .cornerRadius(4)
                                        }
                                        if let detections = photo.detections, detections.count > 2 {
                                            Text("+\(detections.count - 2)")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            if let detections = photo.detections, !detections.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("\(detections.count)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedPhoto = photo
                    }
                }
                .listStyle(.sidebar)
                
                HStack {
                    if isAnalyzingAll {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Analyzing...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        let count = filteredPhotos.count
                        Text(count == 1 ? "1 photo" : "\(count) photos")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
            .padding(12)
        } detail: {
            if let photo = selectedPhoto {
                PhotoDetailView(photo: photo, viewModel: viewModel)
            } else {
                VStack {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Select a photo to view details")
                        .foregroundColor(.secondary)
                }
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.folder],
            onCompletion: { result in
                switch result {
                case .success(let url):
                    viewModel.loadPhotos(from: url)
                case .failure(let error):
                    print("File selection error: \(error)")
                }
            }
        )
    }
    
    private func analyzeAll() {
        isAnalyzingAll = true
        Task {
            await viewModel.analyzeAllPhotos()
            isAnalyzingAll = false
        }
    }
}

struct PhotoDetailView: View {
    let photo: PhotoMetadata
    @ObservedObject var viewModel: PhotoViewModel
    @State private var detections: [String] = []
    @State private var isAnalyzing = false
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text(photo.filename)
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let location = photo.location {
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                        VStack(alignment: .leading) {
                            Text("Latitude: \(String(format: "%.4f", location.latitude))")
                            Text("Longitude: \(String(format: "%.4f", location.longitude))")
                            if let altitude = location.altitude {
                                Text("Altitude: \(String(format: "%.1f m", altitude))")
                            }
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(8)
                }
            }
            
            if !viewModel.validLocations.isEmpty {
                MapView(locations: viewModel.validLocations, selectedLocation: photo.location)
                    .frame(height: 300)
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Objects Detected")
                    .font(.headline)
                
                if isAnalyzing {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if let photoDetections = photo.detections, !photoDetections.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(photoDetections, id: \.self) { detection in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(detection)
                                Spacer()
                            }
                        }
                    }
                } else {
                    Button(action: analyzePhoto) {
                        Text("Analyze Photo")
                            .frame(maxWidth: .infinity)
                            .padding(8)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    }
                }
            }
            .padding(12)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
            
            Spacer()
        }
        .padding(16)
    }
    
    private func analyzePhoto() {
        isAnalyzing = true
        Task {
            detections = await viewModel.detectObjects(in: photo)
            isAnalyzing = false
        }
    }
}

struct MapView: NSViewRepresentable {
    let locations: [LocationData]
    let selectedLocation: LocationData?
    
    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        updateMapView(mapView)
        return mapView
    }
    
    func updateNSView(_ nsView: MKMapView, context: Context) {
        updateMapView(nsView)
    }
    
    private func updateMapView(_ mapView: MKMapView) {
        mapView.removeAnnotations(mapView.annotations)
        
        for location in locations {
            let annotation = MKPointAnnotation()
            annotation.coordinate = location.coordinate
            annotation.title = "Photo"
            mapView.addAnnotation(annotation)
        }
        
        if !locations.isEmpty {
            let validLocations = locations.filter { !($0.latitude.isNaN || $0.longitude.isNaN) }
            if !validLocations.isEmpty {
                let rect = MKMapRect.from(validLocations.map { $0.coordinate })
                mapView.setVisibleMapRect(rect, edgePadding: NSEdgeInsets(top: 40, left: 40, bottom: 40, right: 40), animated: true)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard annotation is MKPointAnnotation else { return nil }
            let identifier = "pin"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            if annotationView == nil {
                annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            } else {
                annotationView?.annotation = annotation
            }
            return annotationView
        }
    }
}

@MainActor
class PhotoViewModel: NSObject, ObservableObject {
    @Published var photos: [PhotoMetadata] = []
    @Published var validLocations: [LocationData] = []
    
    func loadPhotos(from folderURL: URL) {
        guard folderURL.startAccessingSecurityScopedResource() else {
            print("Access denied")
            return
        }
        defer { folderURL.stopAccessingSecurityScopedResource() }
        
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil) else {
            print("Cannot read folder")
            return
        }
        
        var loadedPhotos: [PhotoMetadata] = []
        var allLocations: [LocationData] = []
        
        for file in files {
            guard file.startAccessingSecurityScopedResource() else { continue }
            defer { file.stopAccessingSecurityScopedResource() }
            
            let type = file.pathExtension.lowercased()
            guard ["jpg", "jpeg", "png", "heic", "raw", "orf", "cr2", "nef"].contains(type) else { continue }
            
            if let metadata = extractMetadata(from: file) {
                loadedPhotos.append(metadata)
                if let location = metadata.location {
                    allLocations.append(location)
                }
            }
        }
        
        self.photos = loadedPhotos.sorted { $0.filename < $1.filename }
        self.validLocations = allLocations
    }
    
    func extractMetadata(from fileURL: URL) -> PhotoMetadata? {
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else { return nil }
        
        guard let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return PhotoMetadata(filename: fileURL.lastPathComponent, fileURL: fileURL, location: nil, detections: nil)
        }
        
        var location: LocationData? = nil
        if let gpsData = metadata["{GPS}"] as? [String: Any] {
            location = LocationData.extractFromGPS(gpsData)
        }
        
        return PhotoMetadata(filename: fileURL.lastPathComponent, fileURL: fileURL, location: location, detections: nil)
    }
    
    func detectObjects(in photo: PhotoMetadata) async -> [String] {
        guard let cgImage = loadCGImage(from: photo.fileURL) else { return [] }
        
        return await withCheckedContinuation { continuation in
            let classificationRequest = VNClassifyImageRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([classificationRequest])
                
                let observations = classificationRequest.results as? [VNClassificationObservation] ?? []
                let detections = observations
                    .prefix(5)
                    .compactMap { observation -> String? in
                        let confidence = observation.confidence
                        guard confidence > 0.3 else { return nil }
                        let label = observation.identifier
                        return ObjectDetection(label: label, confidence: Double(confidence)).displayString
                    }
                    .sorted()
                
                continuation.resume(returning: detections)
            } catch {
                continuation.resume(returning: [])
            }
        }
    }
    
    func analyzeAllPhotos() async {
        for index in photos.indices {
            let detections = await detectObjects(in: photos[index])
            photos[index].detections = detections
        }
    }
    
    private func loadCGImage(from url: URL) -> CGImage? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
    }
}

struct PhotoMetadata {
    let filename: String
    let fileURL: URL
    let location: LocationData?
    var detections: [String]?
}

struct LocationData {
    let latitude: Double
    let longitude: Double
    let altitude: Double?
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    func distance(to other: LocationData) -> Double {
        let lat1 = latitude * .pi / 180
        let lon1 = longitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let lon2 = other.longitude * .pi / 180
        
        let dLat = lat2 - lat1
        let dLon = lon2 - lon1
        
        let a = sin(dLat/2) * sin(dLat/2) +
                cos(lat1) * cos(lat2) * sin(dLon/2) * sin(dLon/2)
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        
        let earthRadius = 6371000.0
        return earthRadius * c
    }
    
    static func extractFromGPS(_ gpsData: [String: Any]) -> LocationData? {
        guard let latitude = gpsData["Latitude"] as? Double,
              let longitude = gpsData["Longitude"] as? Double else {
            return nil
        }
        
        let altitude = gpsData["Altitude"] as? Double
        let latRef = gpsData["LatitudeRef"] as? String
        let lonRef = gpsData["LongitudeRef"] as? String
        
        let finalLatitude = (latRef == "S") ? -latitude : latitude
        let finalLongitude = (lonRef == "W") ? -longitude : longitude
        
        return LocationData(
            latitude: finalLatitude,
            longitude: finalLongitude,
            altitude: altitude
        )
    }
}

struct ObjectDetection {
    let label: String
    let confidence: Double
    
    var displayString: String {
        "\(label) (\(String(format: "%.0f%%", confidence * 100)))"
    }
}

extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

extension MKMapRect {
    static func from(_ coordinates: [CLLocationCoordinate2D]) -> MKMapRect {
        guard !coordinates.isEmpty else { return .null }
        
        var mapRect = MKMapRect.null
        for coordinate in coordinates {
            let point = MKMapPoint(coordinate)
            let rect = MKMapRect(x: point.x, y: point.y, width: 1, height: 1)
            mapRect = mapRect.union(rect)
        }
        
        return mapRect
    }
}
