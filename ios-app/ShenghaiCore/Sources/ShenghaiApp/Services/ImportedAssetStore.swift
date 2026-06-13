import Foundation
import CryptoKit

struct StoredScoreAsset: Sendable {
    var relativePath: String
    var fileURL: URL
    var checksum: String
}

final class ImportedAssetStore {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func copyImportedScore(from sourceURL: URL) throws -> StoredScoreAsset {
        let data = try Data(contentsOf: sourceURL)
        let preferredName = sourceURL.deletingPathExtension().lastPathComponent
        let fileExtension = sourceURL.pathExtension
        return try writeScoreData(data, preferredName: preferredName, fileExtension: fileExtension)
    }

    func writeScoreData(_ data: Data, preferredName: String, fileExtension: String) throws -> StoredScoreAsset {
        let checksum = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
        let sanitizedBase = sanitizedFileName(preferredName)
        let sanitizedExtension = fileExtension.isEmpty ? "musicxml" : fileExtension.lowercased()
        let relativePath = "scores/\(checksum.prefix(12))-\(sanitizedBase).\(sanitizedExtension)"
        let destinationURL = try resolveWriteURL(relativePath: relativePath)

        if !fileManager.fileExists(atPath: destinationURL.path) {
            try data.write(to: destinationURL, options: .atomic)
        }

        return StoredScoreAsset(relativePath: relativePath, fileURL: destinationURL, checksum: checksum)
    }

    func resolveReadURL(relativePath: String) throws -> URL {
        try baseDirectoryURL().appending(path: relativePath)
    }

    private func resolveWriteURL(relativePath: String) throws -> URL {
        let baseURL = try baseDirectoryURL()
        let destinationURL = baseURL.appending(path: relativePath)
        let folderURL = destinationURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        return destinationURL
    }

    private func baseDirectoryURL() throws -> URL {
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let baseURL = appSupport.appending(path: "Shenghai")
        try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
        return baseURL
    }

    private func sanitizedFileName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty ? "shenghai-score" : trimmed
        let pieces = fallback
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        return pieces.isEmpty ? "shenghai-score" : pieces.joined(separator: "-").lowercased()
    }
}
