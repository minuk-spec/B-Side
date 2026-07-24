import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    var statusItem: NSStatusItem!
    let store = WordStore()
    var autoTimer: Timer?
    var popover: NSPopover?
    var statusBarView: StatusBarView?
    var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if relocateToApplicationsIfNeeded() { return }

        NSApp.setActivationPolicy(.accessory)
        store.onChange = { [weak self] in
            DispatchQueue.main.async { self?.updateTitle() }
        }

        statusItem = NSStatusBar.system.statusItem(withLength: 180)

        if let button = statusItem.button {
            button.title = ""
            button.attributedTitle = NSAttributedString(string: "")
            button.action = nil
            button.target = nil

            let sbView = StatusBarView(frame: NSRect(x: 0, y: 0, width: 180, height: 22))
            sbView.onPrev      = { [weak self] in self?.store.previous() }
            sbView.onNext      = { [weak self] in self?.store.next(manual: true) }
            sbView.onWordClick = { [weak self] in
                guard let self = self else { return }
                if let p = self.popover, p.isShown { p.close(); self.popover = nil }
                else { self.showTapPopover() }
            }
            sbView.onRightClick = { [weak self] in
                guard let self = self else { return }
                self.closePopover()
                self.showDashboard()
            }
            button.addSubview(sbView)
            statusBarView = sbView
        }

        updateTitle()
        startAutoTimer()

        // 최초 실행 시 튜토리얼 표시
        let tutorialKey = "bord_tutorial_shown_v1"
        if !UserDefaults.standard.bool(forKey: tutorialKey) {
            UserDefaults.standard.set(true, forKey: tutorialKey)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showTutorial()
            }
        }

        // 실행 후 3초 뒤 업데이트 자동 확인
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            Updater.shared.checkForUpdate()
        }
    }

    // /Applications 밖에서 실행된 경우 조용히 이동 후 재시작
    @discardableResult
    func relocateToApplicationsIfNeeded() -> Bool {
        let src = Bundle.main.bundleURL.path
        guard !src.hasPrefix("/Applications") else { return false }

        let target = "/Applications/B_Side.app"
        let scriptPath = NSTemporaryDirectory() + "bside_relocate.sh"
        let script = """
        #!/bin/bash
        sleep 1
        rm -rf "\(target)"
        /usr/bin/ditto "\(src)" "\(target)"
        /usr/bin/xattr -cr "\(target)"
        open "\(target)"
        rm -f "\(scriptPath)"
        """
        do {
            try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.posixPermissions: NSNumber(value: 0o755)], ofItemAtPath: scriptPath)
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/bash")
            p.arguments = [scriptPath]
            try p.run()
            NSApp.terminate(nil)
        } catch {
            return false
        }
        return true
    }

    func updateTitle() {
        let word = store.currentWord
        let displayText = store.isReverse ? (word?.meaning ?? "B-Side") : (word?.term ?? "B-Side")
        let hoverText   = store.isReverse ? word?.term : word?.meaning
        statusBarView?.setWord(displayText)
        statusBarView?.setHoverText(hoverText)
        store.recordCurrentWordView()
    }

    func startAutoTimer() {
        autoTimer?.invalidate()
        autoTimer = nil
        let seconds = store.autoInterval > 0 ? store.autoInterval : 15
        let timer = Timer(timeInterval: TimeInterval(seconds), repeats: true) { [weak self] _ in
            self?.store.next(manual: false)
        }
        RunLoop.main.add(timer, forMode: .common)
        autoTimer = timer
    }

    func showTutorial() {
        guard let button = statusItem?.button else { return }
        closePopover()
        let view = TutorialView(onClose: { [weak self] in self?.closePopover() })
        let p = makePopover(view: AnyView(view), width: 300, height: 390)
        p.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover = p
        startEventMonitor()
    }

    func showTapPopover() {
        statusBarView?.setHoverText(nil)
        guard let word = store.currentWord, let button = statusItem?.button else { return }
        let hostingVC = NSHostingController(rootView: TapView(
            word: word,
            isReverse: store.isReverse,
            onToggleMemorized: { [weak self] in
                self?.store.toggleMemorized(id: word.id)
                self?.closePopover()
            }
        ))
        hostingVC.sizingOptions = .preferredContentSize
        let p = NSPopover()
        p.contentViewController = hostingVC
        p.behavior = .applicationDefined
        p.animates = true
        p.delegate = self
        p.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover = p
        startEventMonitor()
    }

    func popoverDidClose(_ notification: Notification) {
        updateTitle()
    }

    func closePopover() {
        popover?.close()
        popover = nil
        if let m = eventMonitor { NSEvent.removeMonitor(m); eventMonitor = nil }
    }

    func startEventMonitor() {
        if let m = eventMonitor { NSEvent.removeMonitor(m); eventMonitor = nil }
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
    }

    func showDashboard() {
        guard let button = statusItem?.button else { return }
        closePopover()
        let view = DashboardView(
            store: store,
            onAdd: { [weak self] in
                guard let s = self else { return }
                s.replacePopover(view: AnyView(AddWordView(store: s.store, onBack: { s.showDashboard() }, onClose: { s.closePopover() })), width: 300, height: 390)
            },
            onDelete: { [weak self] in
                guard let s = self else { return }
                s.replacePopover(view: AnyView(DeleteWordView(store: s.store, onBack: { s.showDashboard() }, onClose: { s.closePopover() })), width: 300, height: 390)
            },
            onSetting: { [weak self] in
                guard let s = self else { return }
                s.replacePopover(view: AnyView(SettingView(
                    store: s.store,
                    onBack: { s.startAutoTimer(); s.showDashboard() },
                    onClose: { s.closePopover(); s.startAutoTimer() },
                    onShowTutorial: { s.showTutorial() },
                    onSuspendMonitor: { if let m = s.eventMonitor { NSEvent.removeMonitor(m); s.eventMonitor = nil } },
                    onResumeMonitor: { s.startEventMonitor() }
                )), width: 300, height: 410)
            },
            onFolder: { [weak self] in
                guard let s = self else { return }
                s.replacePopover(view: AnyView(FolderListView(store: s.store, onBack: { s.showDashboard() }, onSelectFolder: { _ in s.showDashboard() })), width: 300, height: 390)
            },
            onImport: { [weak self] in
                guard let s = self else { return }
                s.replacePopover(view: AnyView(ImportImageView(
                    store: s.store,
                    onBack: { s.showDashboard() },
                    onClose: { s.closePopover() },
                    onSuspendMonitor: { [weak s] in
                        if let m = s?.eventMonitor { NSEvent.removeMonitor(m); s?.eventMonitor = nil }
                    },
                    onResumeMonitor: { [weak s] in s?.startEventMonitor() }
                )), width: 300, height: 390)
            },
            onClose: { [weak self] in self?.closePopover() },
            onQuit: { NSApp.terminate(nil) },
            onEdit: { [weak self] word in
                guard let s = self else { return }
                s.replacePopover(view: AnyView(EditWordView(store: s.store, word: word, onBack: { s.showDashboard() }, onClose: { s.closePopover() })), width: 300, height: 390)
            },
            onAddToFolder: { [weak self] word in
                guard let s = self else { return }
                s.replacePopover(view: AnyView(AddToFolderView(store: s.store, word: word, onBack: { s.showDashboard() })), width: 300, height: 390)
            },
            onDeleteWord: { [weak self] word in
                guard let s = self else { return }
                s.store.deleteWords(ids: [word.id])
                s.showDashboard()
            }
        )
        let p = makePopover(view: AnyView(view), width: 300, height: 420)
        p.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover = p
        startEventMonitor()
    }

    func makePopover(view: AnyView, width: CGFloat, height: CGFloat, minHeight: CGFloat = 390) -> NSPopover {
        let p = NSPopover()
        let hostingVC = NSHostingController(rootView: view)
        p.contentViewController = hostingVC
        p.contentSize = NSSize(width: width, height: max(height, minHeight))
        p.behavior = .applicationDefined
        p.animates = true
        return p
    }

    func replacePopover(view: AnyView, width: CGFloat, height: CGFloat, minHeight: CGFloat = 390) {
        popover?.close()
        popover = nil
        guard let button = statusItem?.button else { return }
        let p = makePopover(view: view, width: width, height: height, minHeight: minHeight)
        p.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover = p
        startEventMonitor()
    }
}
