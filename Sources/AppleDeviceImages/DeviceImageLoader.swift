import Foundation

/// Finds and downloads Apple product images, remembering which URL served each request.
public actor DeviceImageLoader {
    public static let shared = DeviceImageLoader()

    private let session: URLSession
    private var resolved: [DeviceImageRequest: URL] = [:]

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// The first candidate URL that serves an image, and the image's PNG data.
    public func image(for request: DeviceImageRequest) async throws -> (url: URL, data: Data) {
        if let url = resolved[request], let data = try await fetch(url) {
            return (url, data)
        }
        for url in request.candidateURLs {
            try Task.checkCancellation()
            if let data = try await fetch(url) {
                resolved[request] = url
                return (url, data)
            }
        }
        throw DeviceImageError.notFound(request)
    }

    /// The PNG data at `url`, or nil when the CDN has no image there: the account CDN answers 403,
    /// Find My redirects to apple.com.
    private func fetch(_ url: URL) async throws -> Data? {
        let (data, response) = try await session.data(for: URLRequest(url: url), delegate: NoRedirects.shared)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              http.mimeType?.hasPrefix("image/") ?? false else { return nil }
        return data
    }
}

public enum DeviceImageError: Error, Sendable {
    case notFound(DeviceImageRequest)
}

private final class NoRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    static let shared = NoRedirects()

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest) async -> URLRequest? {
        nil
    }
}
