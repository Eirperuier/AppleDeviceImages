import Foundation

/// Fetches device images, remembering each one so a device is only looked up once.
actor ImageLoader {
    static let shared = ImageLoader()

    private struct Key: Hashable {
        let device: AppleDevice
        let size: AppleDeviceImageSize
        let scale: Int
    }

    private var cache: [Key: (url: URL, data: Data)] = [:]
    private var inFlight: [Key: Task<(url: URL, data: Data), Error>] = [:]

    func image(for device: AppleDevice, size: AppleDeviceImageSize, scale: Int) async throws -> (url: URL, data: Data) {
        let key = Key(device: device, size: size, scale: scale)
        if let cached = cache[key] { return cached }
        if let task = inFlight[key] { return try await task.value }
        let task = Task { try await Self.find(device.imageURLCandidates(size: size, scale: scale), device: device) }
        inFlight[key] = task
        defer { inFlight[key] = nil }
        let found = try await task.value
        cache[key] = found
        return found
    }

    private static func find(_ candidates: [URL], device: AppleDevice) async throws -> (url: URL, data: Data) {
        for url in candidates {
            try Task.checkCancellation()
            if let data = try await fetch(url) { return (url, data) }
        }
        throw AppleDeviceImageError.notFound(device)
    }

    /// The PNG at `url`, or nil when the CDN has none there: the account CDN answers 404 (403 to clients it
    /// doesn't recognize), Find My redirects to apple.com.
    private static func fetch(_ url: URL) async throws -> Data? {
        let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url), delegate: NoRedirects.shared)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              http.mimeType?.hasPrefix("image/") ?? false else { return nil }
        return data
    }
}

private final class NoRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    static let shared = NoRedirects()

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest) async -> URLRequest? {
        nil
    }
}
