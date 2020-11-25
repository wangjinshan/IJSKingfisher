
import UIKit

class FileManagerDemo {

    let manager =  FileManager()

    init() { }

    public func createFilePath(name: String) -> URL? {
        let url: URL?
        do {
           url = try manager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        } catch {
            url = nil
        }
        print("-----------------\(String(describing: url?.appendingPathComponent(name)))")
        return url?.appendingPathComponent(name)
    }

    public func writeData(name: Data, path: URL?) {
        if let url = path {
            do {
//                let temp = try String(contentsOf: url, encoding: .utf8)
//                if manager.fileExists(atPath: temp) {
//                    print("--------------")
//                }
                try name.write(to: url, options: [])
            } catch {
                print("写文件失败")
            }
        }
    }
}

