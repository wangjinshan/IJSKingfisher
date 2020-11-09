
import Foundation

public protocol ImageDownloaderDelegate: AnyObject {
    func imageDownloader(_ downloader: ImageDownloader, willDownloadImageForURL url: URL, with request: URLRequest?)
    func imageDownloader(_ downloader: ImageDownloader, didFinishDownloadingImageForURL url: URL, with response: URLResponse?, error: Error?)
    func imageDownloader(_ downloader: ImageDownloader, didDownload data: Data, for url: URL) -> Data?
    func imageDownloader( _ downloader: ImageDownloader, didDownload image: KFCrossPlatformImage, for url: URL, with response: URLResponse?)
    func isValidStatusCode(_ code: Int, for downloader: ImageDownloader) -> Bool
}

extension ImageDownloaderDelegate {
    public func imageDownloader(_ downloader: ImageDownloader, willDownloadImageForURL url: URL, with request: URLRequest?) {}

    public func imageDownloader(_ downloader: ImageDownloader, didFinishDownloadingImageForURL url: URL, with response: URLResponse?, error: Error?) {}

    public func imageDownloader(_ downloader: ImageDownloader, didDownload image: KFCrossPlatformImage, for url: URL, with response: URLResponse?) {}

    public func isValidStatusCode(_ code: Int, for downloader: ImageDownloader) -> Bool {
        return (200..<400).contains(code)
    }

    public func imageDownloader(_ downloader: ImageDownloader, didDownload data: Data, for url: URL) -> Data? {
        return data
    }
}
