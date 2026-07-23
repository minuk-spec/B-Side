import Foundation
import AppKit

class Updater {
    static let shared = Updater()

    private let currentVersion: String =
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"

    private let apiBase = "https://api.github.com/repos/minuk-spec/B-Side"

    enum State: Equatable {
        case idle
        case checking
        case available(version: String, downloadURL: String)
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

        let req = URLRequest(url: URL(string: "\(apiBase)/releases/latest")!)

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            guard let self else { return }
            if let error = error {
                self.state = .error("네트워크 오류: \(error.localizedDescription)")
                return
            }
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                self.state = .error("서버 오류 (\(http.statusCode))")
                return
            }
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
            guard let assets      = json["assets"] as? [[String: Any]],
                  let asset       = assets.first,
                  let downloadURL = asset["browser_download_url"] as? String else {
                self.state = .error("다운로드 파일 없음")
                return
            }
            self.state = .available(version: latest, downloadURL: downloadURL)
        }.resume()
    }

    func downloadAndInstall(downloadURL: String) {
        state = .downloading

        guard let url = URL(string: downloadURL) else {
            state = .error("잘못된 URL"); return
        }

        URLSession.shared.downloadTask(with: URLRequest(url: url)) { [weak self] tempURL, _, _ in
            guard let self else { return }
            guard let tempURL else { self.state = .error("다운로드 실패"); return }

            // 임시 파일을 안정적인 경로로 이동 (launchd 스크립트가 앱 종료 후 접근하므로)
            let stableDMG = URL(fileURLWithPath: NSTemporaryDirectory() + "B-Side-pending.dmg")
            try? FileManager.default.removeItem(at: stableDMG)
            guard (try? FileManager.default.moveItem(at: tempURL, to: stableDMG)) != nil else {
                self.state = .error("다운로드 실패"); return
            }

            self.state = .installing
            self.install(from: stableDMG)
        }.resume()
    }

    private func install(from dmgURL: URL) {
        let fm = FileManager.default

        let testFile = "/Applications/.bside_write_test"
        let canWrite = fm.createFile(atPath: testFile, contents: Data(), attributes: nil)
        if canWrite { try? fm.removeItem(atPath: testFile) }
        guard canWrite else {
            state = .error("설치 실패:\n/Applications 쓰기 권한 없음")
            return
        }

        let targetPath = "/Applications/B_Side.app"
        let mountPoint = NSTemporaryDirectory() + "bside_mount_\(Int.random(in: 100000...999999))"

        // 1. 마운트
        let mount = Process()
        mount.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        mount.arguments = ["attach", dmgURL.path, "-mountpoint", mountPoint,
                           "-nobrowse", "-noverify", "-quiet"]
        guard (try? mount.run()) != nil else { state = .error("마운트 실패"); return }
        mount.waitUntilExit()
        guard mount.terminationStatus == 0 else { state = .error("마운트 실패"); return }

        // 2. 구버전 제거 → 신버전 복사 → quarantine 해제
        let update = Process()
        update.executableURL = URL(fileURLWithPath: "/bin/bash")
        update.arguments = ["-c", """
            rm -rf '\(targetPath)' && \
            /usr/bin/ditto '\(mountPoint)/B_Side.app' '\(targetPath)' && \
            xattr -cr '\(targetPath)'
        """]
        guard (try? update.run()) != nil else {
            cleanup(mountPoint: mountPoint, dmg: dmgURL)
            state = .error("설치 실패")
            return
        }
        update.waitUntilExit()

        cleanup(mountPoint: mountPoint, dmg: dmgURL)

        guard update.terminationStatus == 0 else {
            state = .error("설치 실패")
            return
        }

        // 3. 새 앱 실행 → 현재 앱 종료
        DispatchQueue.main.async {
            NSWorkspace.shared.open(URL(fileURLWithPath: targetPath))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApp.terminate(nil)
            }
        }
    }

    private func cleanup(mountPoint: String, dmg: URL) {
        let detach = Process()
        detach.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        detach.arguments = ["detach", mountPoint, "-quiet"]
        try? detach.run()
        detach.waitUntilExit()
        try? FileManager.default.removeItem(atPath: mountPoint)
        try? FileManager.default.removeItem(at: dmg)
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
