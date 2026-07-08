import Foundation

private final class AppResourceBundleToken {}

enum AppResourceLocator {
    #if SWIFT_PACKAGE
    static let baseBundle = Bundle.module
    #else
    static let baseBundle = Bundle(for: AppResourceBundleToken.self)
    #endif

    private static let fallbackResourcesDirectoryName = "Resources"

    static func url(forResource resource: String, withExtension ext: String?, subdirectory: String? = nil) -> URL? {
        if let url = baseBundle.url(forResource: resource, withExtension: ext, subdirectory: subdirectory) {
            return url
        }

        let candidates = resourceRoots.compactMap { root in
            manualCandidateURL(root: root, resource: resource, ext: ext, subdirectory: subdirectory)
        }

        if let resolved = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
            return resolved
        }

        debugReportMissingResource(
            kind: "resource",
            identifier: [subdirectory, [resource, ext].compactMap { $0 }.joined(separator: ".")].compactMap { $0 }.joined(separator: "/"),
            searched: candidates
        )
        return nil
    }

    static func localizedBundle(for identifiers: [String]) -> Bundle? {
        for identifier in identifiers {
            if let path = baseBundle.path(forResource: identifier, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }

        var searched: [URL] = []
        for root in resourceRoots {
            for identifier in identifiers {
                let candidate = root.appendingPathComponent("\(identifier).lproj", isDirectory: true)
                searched.append(candidate)
                if FileManager.default.fileExists(atPath: candidate.path),
                   let bundle = Bundle(url: candidate) {
                    return bundle
                }
            }
        }

        debugReportMissingResource(
            kind: "localized bundle",
            identifier: identifiers.joined(separator: ", "),
            searched: searched
        )
        return nil
    }

    private static var resourceRoots: [URL] {
        let primary = (baseBundle.resourceURL ?? baseBundle.bundleURL).standardizedFileURL
        let nested = primary.appendingPathComponent(fallbackResourcesDirectoryName, isDirectory: true).standardizedFileURL
        var roots = [primary]
        if nested != primary, FileManager.default.fileExists(atPath: nested.path) {
            roots.append(nested)
        }
        return roots
    }

    private static func manualCandidateURL(root: URL, resource: String, ext: String?, subdirectory: String?) -> URL? {
        var url = root
        if let subdirectory, !subdirectory.isEmpty {
            for component in subdirectory.split(separator: "/") {
                url.appendPathComponent(String(component), isDirectory: true)
            }
        }
        let fileName = ext.map { "\(resource).\($0)" } ?? resource
        return url.appendingPathComponent(fileName, isDirectory: false)
    }

    private static func debugReportMissingResource(kind: String, identifier: String, searched: [URL]) {
        #if DEBUG
        let paths = searched.map(\.path).joined(separator: "\n  - ")
        let message = "[AppResourceLocator] Missing \(kind): \(identifier)\n  - \(paths)"
        assertionFailure(message)
        NSLog("%@", message)
        #endif
    }
}
