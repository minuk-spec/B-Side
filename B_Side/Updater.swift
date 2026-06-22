import Foundation
import AppKit

class Updater {
    static let shared = Updater()

    private let currentVersion: String =
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"

    private let apiBase = "https://api.github.com/repos/minuk-spec/B-Side"
    private let token   = "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"

    enum State: Equatable {
        case idle
        case checking
        case available(version: String, assetID: Int)
        case downloading
        case installing
        case upToDate
        case error(String)
    }

    private(set) var state: State = .idle {
        didSet { DispatchQueue.main.async { self.onStateChange?(self.state) } }
    }
    var onStateChange: ((State) -> Void)?

    func checkForUpdate() {
        guard state != .checking else { return }
        state = .checking

        var req = URLRequest(url: URL(string: "\(apiBase)/releases/latest")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let self else { return }
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag  = json["tag_name"] as? String else {
                self.state = .error("서버 응답 실패")
                return
            }
            let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            guard self.isNewer(latest, than: self.currentVersion) else {
                self.state = .upToDate
                return
            }
            guard let assets  = json["assets"] as? [[String: Any]],
                  let asset   = assets.first,
                  let assetID = asset["id"] as? Int else {
                self.state = .error("다운로드 파일 없음")
                return
            }
            self.state = .available(version: latest, assetID: assetID)
        }.resume()
    }

    func downloadAndInstall(assetID: Int) {
        state = .downloading

        var req = URLRequest(url: URL(string: "\(apiBase)/releases/assets/\(assetID)")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/octet-stream", forHTTPHeaderField: "Accept")

        URLSession.shared.downloadTask(with: req) { [weak self] tempURL, _, _ in
            guard let self else { return }
            guard let tempURL else { self.state = .error("다운로드 실패"); return }
            self.state = .installing
            self.install(from: tempURL)
        }.resume()
    }

    private func install(from zipURL: URL) {
        let fm      = FileManager.default
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("BSideUpdate_\(UUID().uuidString)")

        do {
            try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

            let unzip = Process()
            unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            unzip.arguments     = ["-q", zipURL.path, "-d", tempDir.path]
            try unzip.run(); unzip.waitUntilExit()

            let newApp = tempDir.appendingPathComponent("B_Side.app")
            guard fm.fileExists(atPath: newApp.path) else {
                state = .error("앱 파일 없음"); return
            }

            let currentPath = Bundle.main.bundleURL.path
            let parentDir   = (currentPath as NSString).deletingLastPathComponent
            let targetPath  = (parentDir as NSString).appendingPathComponent("B_Side.app")

            let scriptPath = tempDir.appendingPathComponent("update.sh").path
            let script = """
            #!/bin/bash
            sleep 1
            rm -rf "\(targetPath)"
            cp -R "\(newApp.path)" "\(targetPath)"
            xattr -cr "\(targetPath)"
            open "\(targetPath)"
            rm -rf "\(tempDir.path)"
            """
            try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            try fm.setAttributes([.posixPermissions: NSNumber(value: 0o755)], ofItemAtPath: scriptPath)

            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/bash")
            proc.arguments     = [scriptPath]
            try proc.run()

            DispatchQueue.main.async { NSApp.terminate(nil) }
        } catch {
            state = .error("설치 실패")
        }
    }

    private func isNewer(_ v1: String, than v2: String) -> Bool {
        let p1 = v1.split(separator: ".").compactMap { Int($0) }
        let p2 = v2.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(p1.count, p2.count) {
            let n1 = i < p1.count ? p1[i] : 0
            let n2 = i < p2.count ? p2[i] : 0
            if n1 != n2 { return n1 > n2 }
        }
        return false
    }
}
