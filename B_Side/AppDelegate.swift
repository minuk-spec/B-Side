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
    }

    func updateTitle() {
        let word = store.currentWord
        let displayText = store.isReverse ? (word?.meaning ?? "B-Side") : (word?.term ?? "B-Side")
        let hoverText   = store.isReverse ? word?.term : word?.meaning
        statusBarView?.setWord(displayText, isFocused: word?.isFocused ?? false)
        statusBarView?.setHoverText(hoverText)
    }

    func startAutoTimer() {
        autoTimer?.invalidate()
        autoTimer = nil
        // always read from store directly — store.autoInterval is updated on save
        let seconds = store.autoInterval > 0 ? store.autoInterval : 15
        autoTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(seconds), repeats: true) { [weak self] _ in
            self?.store.next()
        }
        RunLoop.main.add(autoTimer!, forMode: .common)
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
        let hostingVC = NSHostingController(rootView: TapView(word: word, isReverse: store.isReverse, onToggleMemorized: { [weak self] in
            self?.store.toggleMemorized(id: word.id)
            self?.closePopover()
        }))
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
            onCheck: { [weak self] in
                guard let s = self else { return }
                s.replacePopover(view: AnyView(CheckMemorizedView(store: s.store, onBack: { s.showDashboard() }, onClose: { s.closePopover() })), width: 300, height: 390)
            },
            onFocus: { [weak self] in
                guard let s = self else { return }
                s.replacePopover(view: AnyView(CheckFocusView(store: s.store, onBack: { s.showDashboard() }, onClose: { s.closePopover() })), width: 300, height: 390)
            },
            onSetting: { [weak self] in
                guard let s = self else { return }
                s.replacePopover(view: AnyView(SettingView(
                    store: s.store,
                    onBack: { s.startAutoTimer(); s.showDashboard() },
                    onClose: { s.closePopover(); s.startAutoTimer() },
                    onShowTutorial: { s.showTutorial() }
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
            }
        )
        let p = makePopover(view: AnyView(view), width: 300, height: 390)
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
