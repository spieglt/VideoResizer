import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var selectedVideo: PhotosPickerItem?
    @State private var videoURL: URL?
    @State private var isProcessing = false
    @State private var processingProgress: Double = 0.0
    @State private var outputURL: URL?
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var reductionPercentage: Double = 50.0
    @State private var originalVideoInfo: VideoInfo?
    @State private var predictedFileSize: String = ""
    
    struct VideoInfo {
        let duration: Double
        let fileSize: Int64
        let resolution: CGSize
        let bitrate: Double
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                
                // Header
                VStack {
                    Image(systemName: "video.badge.waveform")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Video Resizer")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Select a video and choose how much to reduce its size")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top)
                
                Spacer()
                
                // Video Picker Button
                PhotosPicker(
                    selection: $selectedVideo,
                    matching: .videos,
                    photoLibrary: .shared()
                ) {
                    HStack {
                        Image(systemName: "video.circle.fill")
                            .font(.title2)
                        Text("Select Video from Camera Roll")
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .disabled(isProcessing)
                
                // Selected Video Info
                if let videoInfo = originalVideoInfo {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Original Video:")
                            .font(.headline)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Size: \(ByteCountFormatter.string(fromByteCount: videoInfo.fileSize, countStyle: .file))")
                                    .font(.caption)
                                Text("Resolution: \(Int(videoInfo.resolution.width))×\(Int(videoInfo.resolution.height))")
                                    .font(.caption)
                                Text("Duration: \(String(format: "%.1f", videoInfo.duration))s")
                                    .font(.caption)
                            }
                            Spacer()
                        }
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                
                // Size Reduction Slider
                if originalVideoInfo != nil {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Size Reduction")
                                .font(.headline)
                            Spacer()
                            Text("\(Int(reductionPercentage))%")
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                        
                        Slider(value: $reductionPercentage, in: 10...90, step: 5) {
                            Text("Reduction Percentage")
                        }
                        .accentColor(.blue)
                        
                        HStack {
                            Text("10%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("90%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Predicted file size
                        if !predictedFileSize.isEmpty {
                            HStack {
                                Text("Predicted new size:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(predictedFileSize)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.green)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .onChange(of: reductionPercentage) {
                        updatePredictedFileSize()
                    }
                }
                
                // Process Button
                if videoURL != nil && !isProcessing {
                    Button(action: processVideo) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.title2)
                            Text("Resize Video")
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                
                // Processing Progress
                if isProcessing {
                    VStack(spacing: 12) {
                        ProgressView(value: processingProgress, total: 1.0)
                            .progressViewStyle(LinearProgressViewStyle())
                            .scaleEffect(1.2)
                        
                        Text("Resizing video... \(Int(processingProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("Cancel") {
                            isProcessing = false
                            processingProgress = 0.0
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // Output Video Info
                if let outputURL = outputURL {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("✅ Video Resized Successfully!")
                            .font(.headline)
                            .foregroundColor(.green)
                        
                        if let fileSize = getFileSize(url: outputURL),
                           let originalSize = originalVideoInfo?.fileSize {
                            let actualReduction = (1.0 - Double(getFileSizeBytes(url: outputURL)) / Double(originalSize)) * 100
                            VStack(alignment: .leading, spacing: 4) {
                                Text("New Size: \(fileSize)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Actual Reduction: \(String(format: "%.1f", actualReduction))%")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                        
                        Button("Save to Photos") {
                            saveVideoToPhotos(url: outputURL)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationBarHidden(true)
        }
        .onChange(of: selectedVideo) {
            Task {
                await loadSelectedVideo()
            }
        }
        .alert("Video Resizer", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func loadSelectedVideo() async {
        guard let selectedVideo = selectedVideo else { return }
        
        do {
            if let data = try await selectedVideo.loadTransferable(type: Data.self) {
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("mov")
                
                try data.write(to: tempURL)
                
                await MainActor.run {
                    self.videoURL = tempURL
                    self.outputURL = nil
                    self.loadVideoInfo()
                }
            }
        } catch {
            await MainActor.run {
                alertMessage = "Failed to load video: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
    
    private func loadVideoInfo() {
        guard let videoURL = videoURL else { return }
        
        let asset = AVURLAsset(url: videoURL)
        
        Task {
            do {
                let duration = try await asset.load(.duration)
                let tracks = try await asset.loadTracks(withMediaType: .video)
                
                guard let videoTrack = tracks.first else { return }
                
                let naturalSize = try await videoTrack.load(.naturalSize)
                let preferredTransform = try await videoTrack.load(.preferredTransform)
                
                // Get the actual display size considering transform
                let size = naturalSize.applying(preferredTransform)
                let correctedSize = CGSize(width: abs(size.width), height: abs(size.height))
                
                // Estimate bitrate
                let fileSize = getFileSizeBytes(url: videoURL)
                let durationInSeconds = CMTimeGetSeconds(duration)
                let bitrate = Double(fileSize * 8) / durationInSeconds // bits per second
                
                let videoInfo = VideoInfo(
                    duration: durationInSeconds,
                    fileSize: fileSize,
                    resolution: correctedSize,
                    bitrate: bitrate
                )
                
                await MainActor.run {
                    self.originalVideoInfo = videoInfo
                    self.updatePredictedFileSize()
                }
            } catch {
                await MainActor.run {
                    alertMessage = "Failed to analyze video: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
    
    private func updatePredictedFileSize() {
        guard let videoInfo = originalVideoInfo else { return }
        
        // Calculate new dimensions based on reduction percentage
        let scaleFactor = sqrt((100.0 - reductionPercentage) / 100.0)
        let newWidth = videoInfo.resolution.width * scaleFactor
        let newHeight = videoInfo.resolution.height * scaleFactor
        let pixelReduction = (newWidth * newHeight) / (videoInfo.resolution.width * videoInfo.resolution.height)
        
        // Estimate new file size (this is approximate)
        let estimatedSize = Int64(Double(videoInfo.fileSize) * pixelReduction * 0.8) // 0.8 factor for compression efficiency
        predictedFileSize = ByteCountFormatter.string(fromByteCount: estimatedSize, countStyle: .file)
    }
    
    private func processVideo() {
        guard let inputURL = videoURL, let videoInfo = originalVideoInfo else { return }
        
        isProcessing = true
        processingProgress = 0.0
        
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("resized_\(UUID().uuidString)")
            .appendingPathExtension("mp4")
        
        // Calculate new size based on reduction percentage
        let scaleFactor = sqrt((100.0 - reductionPercentage) / 100.0)
        let newWidth = videoInfo.resolution.width * scaleFactor
        let newHeight = videoInfo.resolution.height * scaleFactor
        let targetSize = CGSize(width: newWidth, height: newHeight)
        
        Task {
            await resizeVideo(inputURL: inputURL, outputURL: outputURL, targetSize: targetSize) { progress in
                DispatchQueue.main.async {
                    self.processingProgress = progress
                }
            } completion: { success, error in
                DispatchQueue.main.async {
                    self.isProcessing = false
                    
                    if success {
                        self.outputURL = outputURL
                    } else {
                        self.alertMessage = error?.localizedDescription ?? "Failed to resize video"
                        self.showAlert = true
                    }
                }
            }
        }
    }
    
    private func resizeVideo(inputURL: URL, outputURL: URL, targetSize: CGSize,
                             progressHandler: @escaping (Double) -> Void,
                             completion: @escaping (Bool, Error?) -> Void) async {
        
        let asset = AVURLAsset(url: inputURL)
        
        do {
            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard let videoTrack = tracks.first else {
                completion(false, NSError(domain: "VideoError", code: 1,
                                        userInfo: [NSLocalizedDescriptionKey: "No video track found"]))
                return
            }
            
            // Create video composition
            let videoComposition = AVMutableVideoComposition()
            videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
            videoComposition.renderSize = targetSize
            
            // Get video properties
            let naturalSize = try await videoTrack.load(.naturalSize)
            let preferredTransform = try await videoTrack.load(.preferredTransform)
            
            // Calculate the display size after applying transform
            let transformedSize = naturalSize.applying(preferredTransform)
            let videoWidth = abs(transformedSize.width)
            let videoHeight = abs(transformedSize.height)
            
            // Calculate scale factors
            let scaleX = targetSize.width / videoWidth
            let scaleY = targetSize.height / videoHeight
            let scale = min(scaleX, scaleY) // Use uniform scaling to maintain aspect ratio
            
            // Create the final transform
            var finalTransform = preferredTransform
            
            // Apply scaling
            finalTransform = finalTransform.concatenating(CGAffineTransform(scaleX: scale, y: scale))
            
            // Center the video in the render size
            let scaledWidth = videoWidth * scale
            let scaledHeight = videoHeight * scale
            let translateX = (targetSize.width - scaledWidth) / 2
            let translateY = (targetSize.height - scaledHeight) / 2
            
            finalTransform = finalTransform.concatenating(CGAffineTransform(translationX: translateX, y: translateY))
            
            // Create layer instruction
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
            layerInstruction.setTransform(finalTransform, at: .zero)
            
            // Create composition instruction
            let instruction = AVMutableVideoCompositionInstruction()
            let duration = try await asset.load(.duration)
            instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
            instruction.layerInstructions = [layerInstruction]
            instruction.backgroundColor = UIColor.black.cgColor
            
            videoComposition.instructions = [instruction]
            
            // Use MediumQuality preset which allows custom video composition
            guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality) else {
                completion(false, NSError(domain: "VideoError", code: 3,
                                        userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"]))
                return
            }
            
            exporter.outputURL = outputURL
            exporter.outputFileType = AVFileType.mp4
            exporter.videoComposition = videoComposition
            exporter.shouldOptimizeForNetworkUse = true
            
            // Start a task to monitor progress
            let progressTask = Task {
                while !Task.isCancelled {
                    let progress = exporter.progress
                    await MainActor.run {
                        progressHandler(Double(progress))
                    }
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                }
            }
            
            // Export the video using modern async API
            do {
                try await exporter.export(to: outputURL, as: .mp4)
                progressTask.cancel()
                completion(true, nil)
            } catch {
                progressTask.cancel()
                print("Export failed: \(error)")
                completion(false, error)
            }
            
        } catch {
            completion(false, error)
        }
    }
    
    private func saveVideoToPhotos(url: URL) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                DispatchQueue.main.async {
                    self.alertMessage = "Photo library access denied"
                    self.showAlert = true
                }
                return
            }
            
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    if success {
                        self.alertMessage = "Video saved to Photos successfully!"
                    } else {
                        self.alertMessage = "Failed to save video: \(error?.localizedDescription ?? "Unknown error")"
                    }
                    self.showAlert = true
                }
            }
        }
    }
    
    private func getFileSize(url: URL) -> String? {
        let fileSize = getFileSizeBytes(url: url)
        return ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    private func getFileSizeBytes(url: URL) -> Int64 {
        do {
            let resources = try url.resourceValues(forKeys: [.fileSizeKey])
            return Int64(resources.fileSize ?? 0)
        } catch {
            print("Error getting file size: \(error)")
            return 0
        }
    }
}

struct VideoResizerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// For SwiftUI Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


// TODO:
// batch processing
// display progress indicator while video loads
