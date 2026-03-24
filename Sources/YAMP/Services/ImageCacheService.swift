import AppKit
import CryptoKit
import Foundation
import SwiftUI

actor ImageCacheService {
    static let shared = ImageCacheService()

    private let cacheDirectory: URL
    private let maxDiskBytes: Int = 200 * 1024 * 1024 // 200 MB
    private let ttl: TimeInterval = 7 * 24 * 60 * 60  // 7 days
    private var memoryCache = NSCache<NSString, NSImage>()

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = caches.appendingPathComponent("ru.korenskoy.zvuk-unofficial.images", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        memoryCache.countLimit = 300
    }

    func image(for url: URL) async -> NSImage? {
        let key = cacheKey(for: url)

        // Memory
        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }

        // Disk
        let filePath = cacheDirectory.appendingPathComponent(key)
        if let attrs = try? FileManager.default.attributesOfItem(atPath: filePath.path),
           let modified = attrs[.modificationDate] as? Date,
           Date().timeIntervalSince(modified) < ttl,
           let data = try? Data(contentsOf: filePath),
           let image = NSImage(data: data) {
            memoryCache.setObject(image, forKey: key as NSString)
            return image
        }

        // Network
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let image = NSImage(data: data) else {
            return nil
        }

        // Save
        memoryCache.setObject(image, forKey: key as NSString)
        try? data.write(to: filePath, options: .atomic)

        // Evict old files in background
        Task.detached(priority: .utility) {
            await self.evictIfNeeded()
        }

        return image
    }

    private func cacheKey(for url: URL) -> String {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func evictIfNeeded() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
        ) else { return }

        var totalSize: Int = 0
        var entries: [(url: URL, date: Date, size: Int)] = []

        for file in files {
            guard let values = try? file.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                  let date = values.contentModificationDate,
                  let size = values.fileSize else { continue }
            // Remove expired
            if Date().timeIntervalSince(date) > ttl {
                try? fm.removeItem(at: file)
                continue
            }
            totalSize += size
            entries.append((file, date, size))
        }

        guard totalSize > maxDiskBytes else { return }

        // Remove oldest first
        entries.sort { $0.date < $1.date }
        for entry in entries {
            try? fm.removeItem(at: entry.url)
            totalSize -= entry.size
            if totalSize <= maxDiskBytes / 2 { break }
        }
    }
}
