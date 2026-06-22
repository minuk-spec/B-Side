import AppKit

class StatusBarView: NSView {
    var onPrev: (() -> Void)?
    var onNext: (() -> Void)?
    var onWordClick: (() -> Void)?
    var onRightClick: (() -> Void)?

    private let leftBtn  = ArrowButton(title: "◀")
    private let rightBtn = ArrowButton(title: "▶")
    private let wordBtn  = WordButton()

    override init(frame: NSRect) {
        super.init(frame: frame)
        addSubview(leftBtn)
        addSubview(wordBtn)
        addSubview(rightBtn)
        leftBtn.onClick       = { [weak self] in self?.onPrev?() }
        rightBtn.onClick      = { [weak self] in self?.onNext?() }
        leftBtn.onRightClick  = { [weak self] in self?.onRightClick?() }
        rightBtn.onRightClick = { [weak self] in self?.onRightClick?() }
        wordBtn.onRightClick  = { [weak self] in self?.onRightClick?() }
        wordBtn.onClick       = { [weak self] in self?.onWordClick?() }
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        let h = bounds.height, aw: CGFloat = 24
        leftBtn.frame  = NSRect(x: 0,                 y: 0, width: aw,                    height: h)
        wordBtn.frame  = NSRect(x: aw,                y: 0, width: bounds.width - aw * 2, height: h)
        rightBtn.frame = NSRect(x: bounds.width - aw, y: 0, width: aw,                    height: h)
    }

    func setWord(_ term: String, isFocused: Bool) { wordBtn.setWord(term, isFocused: isFocused) }
    func setHoverText(_ text: String?)            { wordBtn.setHoverText(text) }
}

// MARK: - ArrowButton
class ArrowButton: NSView {
    var onClick: (() -> Void)?
    var onRightClick: (() -> Void)?
    private let glyph: String
    private var isHovered = false, isPressed = false

    init(title: String) {
        self.glyph = title; super.init(frame: .zero)
        wantsLayer = true; layer?.cornerRadius = 3
        addTrackingArea(NSTrackingArea(rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil))
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let alpha: CGFloat = isPressed ? 1.0 : (isHovered ? 0.95 : 0.65)
        let str = NSAttributedString(string: glyph, attributes: [
            .font: NSFont.systemFont(ofSize: 9, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(alpha)
        ])
        let sz = str.size()
        str.draw(at: NSPoint(x: (bounds.width-sz.width)/2, y: (bounds.height-sz.height)/2))
    }

    private func refresh() {
        layer?.backgroundColor = isPressed
            ? NSColor.white.withAlphaComponent(0.22).cgColor
            : (isHovered ? NSColor.white.withAlphaComponent(0.13).cgColor : NSColor.clear.cgColor)
        needsDisplay = true
    }

    override func mouseEntered(with event: NSEvent)  { isHovered = true;  refresh() }
    override func mouseExited(with event: NSEvent)   { isHovered = false; isPressed = false; refresh() }
    override func mouseDown(with event: NSEvent)     { isPressed = true;  refresh() }
    override func mouseUp(with event: NSEvent) {
        isPressed = false; refresh()
        if bounds.contains(convert(event.locationInWindow, from: nil)) { onClick?() }
    }
    override func rightMouseUp(with event: NSEvent)  { onRightClick?() }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

// MARK: - WordButton
class WordButton: NSView {
    var onClick: (() -> Void)?
    var onRightClick: (() -> Void)?

    private var term: String = ""
    private var isFocused: Bool = false
    private var hoverText: String? = nil
    private var isHovered = false, isPressed = false
    private var hoverOverlay: HoverOverlayWindow?

    override init(frame: NSRect) {
        super.init(frame: frame); wantsLayer = true; layer?.cornerRadius = 3
        addTrackingArea(NSTrackingArea(rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil))
    }
    required init?(coder: NSCoder) { fatalError() }

    func setWord(_ term: String, isFocused: Bool) { self.term = term; self.isFocused = isFocused; needsDisplay = true }
    func setHoverText(_ text: String?) { self.hoverText = text; if text == nil { dismissHover() } }

    override func draw(_ dirtyRect: NSRect) {
        let color: NSColor = isFocused
            ? NSColor(red: 1.0, green: 0.6, blue: 0.1, alpha: 1.0) : .labelColor
        let str = NSAttributedString(string: term, attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: color
        ])
        let sz = str.size()
        let ctx = NSGraphicsContext.current?.cgContext
        ctx?.saveGState(); ctx?.clip(to: bounds)
        str.draw(at: NSPoint(x: max((bounds.width-sz.width)/2, 0), y: (bounds.height-sz.height)/2))
        ctx?.restoreGState()
    }

    private func refresh() {
        layer?.backgroundColor = isPressed
            ? NSColor.white.withAlphaComponent(0.15).cgColor
            : (isHovered ? NSColor.white.withAlphaComponent(0.08).cgColor : NSColor.clear.cgColor)
    }

    private func showHover() {
        guard let text = hoverText, !text.isEmpty, let win = self.window else { return }
        dismissHover()
        let viewInScreen = win.convertToScreen(convert(bounds, to: nil))
        hoverOverlay = HoverOverlayWindow(text: text, anchorFrame: viewInScreen)
        hoverOverlay?.orderFront(nil)
    }

    private func dismissHover() { hoverOverlay?.close(); hoverOverlay = nil }

    override func mouseEntered(with event: NSEvent) { isHovered = true;  refresh(); showHover() }
    override func mouseExited(with event: NSEvent)  { isHovered = false; isPressed = false; refresh(); dismissHover() }
    override func mouseDown(with event: NSEvent)    { dismissHover(); isPressed = true; refresh() }
    override func mouseUp(with event: NSEvent) {
        isPressed = false; refresh()
        if bounds.contains(convert(event.locationInWindow, from: nil)) { onClick?() }
    }
    override func rightMouseUp(with event: NSEvent) { onRightClick?() }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

// MARK: - HoverOverlayWindow
class HoverOverlayWindow: NSWindow {
    init(text: String, anchorFrame: NSRect) {
        let font = NSFont.systemFont(ofSize: 13)
        // boundingRect 방식으로 정확한 텍스트 너비 계산 (Retina 대응)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let boundingRect = (text as NSString).boundingRect(
            with: NSSize(width: 9999, height: 40),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs
        )
        let textWidth = ceil(boundingRect.width) + 4  // 여유 4px 추가
        let pad: CGFloat = 16
        let w = min(textWidth + pad * 2, 320)
        let h: CGFloat = 34

        // 상단바가 있는 화면 기준으로 x 클리핑 (멀티 모니터 대응)
        let screen = NSScreen.screens.first(where: { $0.frame.contains(anchorFrame) }) ?? NSScreen.main
        let sf = screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let rawX = anchorFrame.midX - w / 2
        let clampedX = min(rawX, sf.maxX - w - 8)
        let x = max(clampedX, sf.minX + 8)
        let y = anchorFrame.minY - h - 4

        super.init(
            contentRect: NSRect(x: x, y: y, width: w, height: h),
            styleMask: .borderless, backing: .buffered, defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        ignoresMouseEvents = true
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 2)
        hasShadow = true
        isReleasedWhenClosed = false

        let bg = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))
        bg.wantsLayer = true
        bg.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        bg.layer?.cornerRadius = 7
        bg.layer?.borderWidth = 0.5
        bg.layer?.borderColor = NSColor.separatorColor.cgColor

        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = .labelColor
        label.backgroundColor = .clear
        label.isBordered = false
        label.lineBreakMode = .byClipping
        label.cell?.isScrollable = false
        let labelH = ceil(boundingRect.height)
        label.frame = NSRect(x: pad, y: (h - labelH) / 2,
                             width: w - pad * 2, height: labelH)
        bg.addSubview(label)
        contentView = bg
    }
}
