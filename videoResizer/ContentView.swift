import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var selectedVideos: [PhotosPickerItem] = []
    @State private var videoItems: [VideoItem] = []
    @State private var isLoadingVideos = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var reductionPercentage: Double = 50.0
    @State private var predictedTotalSize: String = ""
    @State private var showAbout = false
    
    // Track temporary files for cleanup
    @State private var temporaryFiles: Set<URL> = []
    
    struct VideoItem: Identifiable {
        let id = UUID()
        let url: URL
        let info: VideoInfo
        var isProcessing: Bool = false
        var processingProgress: Double = 0.0
        var outputURL: URL?
    }
    
    struct VideoInfo {
        let duration: Double
        let fileSize: Int64
        let resolution: CGSize
        let bitrate: Double
        let filename: String
        let fps: Float
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                
                // Header
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            showAbout = true
                        }) {
                            Image(systemName: "info.circle")
                                .font(.title3)
                                .foregroundColor(.blue)
                        }
                        .padding(.trailing)
                    }
                    
                    Image(systemName: "video.badge.waveform")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Video Resizer")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Select videos and choose how much to reduce their size")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top)
                
                // Video Picker Button
                PhotosPicker(
                    selection: $selectedVideos,
                    // maxSelectionCount: 10,
                    matching: .videos,
                    photoLibrary: .shared()
                ) {
                    HStack {
                        Image(systemName: "video.circle.fill")
                            .font(.title2)
                        Text("Select Videos from Camera Roll")
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .disabled(isLoadingVideos || videoItems.contains(where: { $0.isProcessing }))
                
                // Loading indicator
                if isLoadingVideos {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading videos...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Selected Videos Info
                        if !videoItems.isEmpty && !isLoadingVideos {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Selected Videos (\(videoItems.count)):")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                ForEach(videoItems) { item in
                                    VideoItemView(item: item)
                                }
                                
                                // Total size info
                                let totalSize = videoItems.reduce(0) { $0 + $1.info.fileSize }
                                HStack {
                                    Text("Total Size:")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal)
                                .padding(.top, 4)
                            }
                        }
                        
                        // Size Reduction Slider
                        if !videoItems.isEmpty && !isLoadingVideos {
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
                                
                                // Predicted total size
                                if !predictedTotalSize.isEmpty {
                                    HStack {
                                        Text("Predicted total size:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text(predictedTotalSize)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.green)
                                    }
                                    .padding(.top, 4)
                                    
                                    // Show new resolution preview
                                    if let firstVideo = videoItems.first {
                                        let scaleFactor = sqrt((100.0 - reductionPercentage) / 100.0)
                                        let newWidth = Int(firstVideo.info.resolution.width * scaleFactor)
                                        let newHeight = Int(firstVideo.info.resolution.height * scaleFactor)
                                        
                                        HStack {
                                            Text(videoItems.count == 1 ? "New resolution:" : "Example resolution:")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            Text("\(newWidth)×\(newHeight)")
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundColor(.blue)
                                        }
                                    }
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
                        if !videoItems.isEmpty && !isLoadingVideos && !videoItems.contains(where: { $0.isProcessing }) {
                            Button(action: processAllVideos) {
                                HStack {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.title2)
                                    Text(videoItems.count == 1 ? "Resize Video" : "Resize All Videos")
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
                        
                        // Completed videos section
                        let completedVideos = videoItems.filter { $0.outputURL != nil }
                        if !completedVideos.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("✅ Completed (\(completedVideos.count)):")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                ForEach(completedVideos) { item in
                                    CompletedVideoView(item: item, originalSize: item.info.fileSize)
                                }
                                
                                Button(completedVideos.count == 1 ? "Save to Photos" : "Save All to Photos") {
                                    saveAllVideosToPhotos()
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                            .padding(.vertical)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onChange(of: selectedVideos) {
            Task {
                await loadSelectedVideos()
            }
        }
        .onAppear {
            cleanupTemporaryDirectory()
        }
        .onDisappear {
            cleanupTemporaryFiles()
        }
        .alert("Video Resizer", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
    }
    
    private func loadSelectedVideos() async {
        guard !selectedVideos.isEmpty else { return }
        
        await MainActor.run {
            isLoadingVideos = true
            videoItems.removeAll()
        }
        
        var loadedItems: [VideoItem] = []
        
        for selectedVideo in selectedVideos {
            do {
                if let data = try await selectedVideo.loadTransferable(type: Data.self) {
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension("mov")
                    
                    try data.write(to: tempURL)
                    
                    Task { @MainActor in
                        temporaryFiles.insert(tempURL)
                    }
                    
                    if let videoInfo = await loadVideoInfo(url: tempURL) {
                        let item = VideoItem(url: tempURL, info: videoInfo)
                        loadedItems.append(item)
                    }
                }
            } catch {
                print("Failed to load video: \(error.localizedDescription)")
            }
        }
        
        await MainActor.run {
            self.videoItems = loadedItems
            self.isLoadingVideos = false
            self.updatePredictedFileSize()
        }
    }
    
    private func loadVideoInfo(url: URL) async -> VideoInfo? {
        let asset = AVURLAsset(url: url)
        
        do {
            let duration = try await asset.load(.duration)
            let tracks = try await asset.loadTracks(withMediaType: .video)
            
            guard let videoTrack = tracks.first else { return nil }
            
            let naturalSize = try await videoTrack.load(.naturalSize)
            let preferredTransform = try await videoTrack.load(.preferredTransform)
            let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
            
            // Get the actual display size considering transform
            let size = naturalSize.applying(preferredTransform)
            let correctedSize = CGSize(width: abs(size.width), height: abs(size.height))
            
            // Estimate bitrate
            let fileSize = getFileSizeBytes(url: url)
            let durationInSeconds = CMTimeGetSeconds(duration)
            let bitrate = Double(fileSize * 8) / durationInSeconds // bits per second
            
            return VideoInfo(
                duration: durationInSeconds,
                fileSize: fileSize,
                resolution: correctedSize,
                bitrate: bitrate,
                filename: url.lastPathComponent,
                fps: nominalFrameRate
            )
        } catch {
            print("Failed to analyze video: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func updatePredictedFileSize() {
        guard !videoItems.isEmpty else { return }
        
        let scaleFactor = sqrt((100.0 - reductionPercentage) / 100.0)
        
        var totalEstimatedSize: Int64 = 0
        for item in videoItems {
            let newWidth = item.info.resolution.width * scaleFactor
            let newHeight = item.info.resolution.height * scaleFactor
            let pixelReduction = (newWidth * newHeight) / (item.info.resolution.width * item.info.resolution.height)
            
            let estimatedSize = Int64(Double(item.info.fileSize) * pixelReduction * 0.8)
            totalEstimatedSize += estimatedSize
        }
        
        predictedTotalSize = ByteCountFormatter.string(fromByteCount: totalEstimatedSize, countStyle: .file)
    }
    
    private func processAllVideos() {
        Task {
            let scaleFactor = sqrt((100.0 - reductionPercentage) / 100.0)
            
            for index in videoItems.indices {
                await MainActor.run {
                    videoItems[index].isProcessing = true
                    videoItems[index].processingProgress = 0.0
                }
                
                let item = videoItems[index]
                let newWidth = item.info.resolution.width * scaleFactor
                let newHeight = item.info.resolution.height * scaleFactor
                let targetSize = CGSize(width: newWidth, height: newHeight)
                
                let outputURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("resized_\(UUID().uuidString)")
                    .appendingPathExtension("mp4")

                Task { @MainActor in
                    temporaryFiles.insert(outputURL)
                }
                
                await resizeVideo(inputURL: item.url, outputURL: outputURL, targetSize: targetSize, fps: item.info.fps) { progress in
                    Task { @MainActor in
                        videoItems[index].processingProgress = progress
                    }
                } completion: { success, error in
                    Task { @MainActor in
                        videoItems[index].isProcessing = false
                        
                        if success {
                            videoItems[index].outputURL = outputURL
                            // Delete the original input video after successful resize
                            deleteTemporaryFile(item.url)
                        } else {
                            alertMessage = "Failed to resize \(item.info.filename): \(error?.localizedDescription ?? "Unknown error")"
                            showAlert = true
                        }
                    }
                }
            }
        }
    }
    
    private func resizeVideo(inputURL: URL, outputURL: URL, targetSize: CGSize, fps: Float,
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
            // Use the original frame rate instead of hardcoding 30 fps
            videoComposition.frameDuration = CMTime(value: 1, timescale: Int32(fps))
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
            let scale = min(scaleX, scaleY)
            
            // Create the final transform
            var finalTransform = preferredTransform
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
    
    private func saveAllVideosToPhotos() {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                DispatchQueue.main.async {
                    self.alertMessage = "Photo library access denied"
                    self.showAlert = true
                }
                return
            }
            
            var successCount = 0
            var errorCount = 0
            let group = DispatchGroup()
            
            for item in videoItems {
                guard let outputURL = item.outputURL else { continue }
                
                group.enter()
                PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL)
                } completionHandler: { success, error in
                    if success {
                        successCount += 1
                    } else {
                        errorCount += 1
                    }
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                if errorCount == 0 {
                    self.alertMessage = "All \(successCount) videos saved to Photos successfully!"
                    // Clean up resized videos after saving
                    for item in self.videoItems {
                        if let outputURL = item.outputURL {
                            self.deleteTemporaryFile(outputURL)
                        }
                    }
                } else {
                    self.alertMessage = "Saved \(successCount) videos. Failed to save \(errorCount) videos."
                }
                self.showAlert = true
            }
        }
    }
    
    private func deleteTemporaryFile(_ url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            temporaryFiles.remove(url)
        } catch {
            print("Failed to delete temporary file: \(error.localizedDescription)")
        }
    }
    
    private func cleanupTemporaryFiles() {
        for url in temporaryFiles {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryFiles.removeAll()
    }
    
    private func cleanupTemporaryDirectory() {
        let tempDir = FileManager.default.temporaryDirectory
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: tempDir,
                includingPropertiesForKeys: nil,
                options: []
            )
            
            for url in contents {
                // Only delete video files that our app created
                let ext = url.pathExtension.lowercased()
                if ext == "mov" || ext == "mp4" || ext == "m4v" {
                    try? FileManager.default.removeItem(at: url)
                }
            }
        } catch {
            print("Failed to cleanup temporary directory: \(error.localizedDescription)")
        }
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

struct AboutView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    VStack {
                        Image(systemName: "video.badge.waveform")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                            .padding(.bottom, 8)
                        
                        Text("Video Resizer")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Version 1.1")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("About")
                            .font(.headline)
                        
                        Text("Video Resizer decreases the resolution and file size of videos. Useful for freeing up storage space and meeting upload limitations. Copyright 2025, Theron Spiegl. theron@spiegl.dev, https://github.com/spieglt/videoresizer")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Divider()
                        
                        Text("Features")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            FeatureRow(icon: "video.fill", text: "Process multiple videos at once")
                            FeatureRow(icon: "slider.horizontal.3", text: "Adjust reduction percentage (10-90%)")
                            FeatureRow(icon: "eye.fill", text: "Preview predicted file sizes")
                            FeatureRow(icon: "chart.bar.fill", text: "See actual size reduction results")
                            FeatureRow(icon: "square.and.arrow.down", text: "Save directly to Photos")
                            FeatureRow(icon: "play.fill", text: "Maintains video quality and orientation")
                        }
                        
                        Divider()
                        
                        Text("How to Use")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("1. Select one or more videos from your camera roll")
                            Text("2. Adjust the size reduction percentage using the slider")
                            Text("3. Preview the predicted file sizes")
                            Text("4. Tap 'Resize Video(s)' to process")
                            Text("5. Save the resized videos back to your Photos")
                        }
                        .font(.body)
                        .foregroundColor(.secondary)
                        
                        Divider()
                        
                        Text("Tips")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("• Higher reduction percentages = smaller file sizes but may reduce quality")
                            Text("• 50% reduction is a good balance for most videos")
                            Text("• The app maintains aspect ratio and video orientation")
                            Text("• Original videos are never modified")
                        }
                        .font(.body)
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(text)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

struct VideoItemView: View {
    let item: ContentView.VideoItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.info.filename)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Text("Size: \(ByteCountFormatter.string(fromByteCount: item.info.fileSize, countStyle: .file))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("Resolution: \(Int(item.info.resolution.width))×\(Int(item.info.resolution.height))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("FPS: \(String(format: "%.0f", item.info.fps))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if item.isProcessing {
                    VStack(spacing: 4) {
                        ProgressView(value: item.processingProgress, total: 1.0)
                            .frame(width: 60)
                        Text("\(Int(item.processingProgress * 100))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

struct CompletedVideoView: View {
    let item: ContentView.VideoItem
    let originalSize: Int64
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.info.filename)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
            
            if let outputURL = item.outputURL {
                let newSize = getFileSizeBytes(url: outputURL)
                let reduction = (1.0 - Double(newSize) / Double(originalSize)) * 100
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Original: \(ByteCountFormatter.string(fromByteCount: originalSize, countStyle: .file))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("New: \(ByteCountFormatter.string(fromByteCount: newSize, countStyle: .file))")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                    
                    Text("↓ \(String(format: "%.1f", reduction))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
    }
    
    private func getFileSizeBytes(url: URL) -> Int64 {
        do {
            let resources = try url.resourceValues(forKeys: [.fileSizeKey])
            return Int64(resources.fileSize ?? 0)
        } catch {
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
