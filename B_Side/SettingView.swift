import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingView: View {
    let store: WordStore
    var onBack: () -> Void
    var onClose: () -> Void
    var onShowTutorial: (() -> Void)? = nil
    var onSuspendMonitor: (() -> Void)? = nil
    var onResumeMonitor: (() -> Void)? = nil
    @State private var playOrder: WordStore.PlayOrder
    @State private var playFilter: WordStore.PlayFilter
    @State private var isReverse: Bool
    @State private var autoInterval: Int
    @State private var feedbackMessage: String? = nil
    @State private var showPOSManager = false
    @State private var updateState: Updater.State = .idle
    let intervalOptions = [5, 15, 30]

    init(store: WordStore, onBack: @escaping () -> Void, onClose: @escaping () -> Void,
         onShowTutorial: (() -> Void)? = nil, onSuspendMonitor: (() -> Void)? = nil, onResumeMonitor: (() -> Void)? = nil) {
        self.store = store; self.onBack = onBack; self.onClose = onClose
        self.onShowTutorial = onShowTutorial
        self.onSuspendMonitor = onSuspendMonitor
        self.onResumeMonitor = onResumeMonitor
        _playOrder    = State(initialValue: store.playOrder)
        _playFilter   = State(initialValue: store.playFilter)
        _isReverse    = State(initialValue: store.isReverse)
        _autoInterval = State(initialValue: store.autoInterval)
    }

    var body: some View {
        if showPOSManager {
            POSManagerView(store: store, onBack: { showPOSManager = false })
        } else {
            mainView
        }
    }

    var mainView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(.regularMaterial)
                .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
            VStack(spacing: 0) {
                PanelHeader(title: "설정", onBack: onBack)
                Divider().padding(.horizontal, 8)
                ScrollView {
                    VStack(spacing: 16) {
                        // 재생 순서
                        VStack(alignment: .leading, spacing: 10) {
                            Text("재생 순서").font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
                            VStack(spacing: 4) {
                                SettingOptionRow(systemName: "shuffle",                 label: "Shuffle",   isOn: playOrder == .shuffle)     { playOrder = playOrder == .shuffle     ? .none : .shuffle }
                                SettingOptionRow(systemName: "arrow.right.to.line.alt", label: "순서대로", isOn: playOrder == .sequential)  { playOrder = playOrder == .sequential  ? .none : .sequential }
                            }
                        }
                        Divider()
                        // 재생 범위
                        VStack(alignment: .leading, spacing: 10) {
                            Text("재생 범위").font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
                            VStack(spacing: 4) {
                                SettingOptionRow(systemName: "scope",            label: "집중 단어만",    isOn: playFilter == .focus)     { playFilter = playFilter == .focus     ? .all : .focus }
                                SettingOptionRow(systemName: "checkmark.circle", label: "외운 단어 복습", isOn: playFilter == .memorized) { playFilter = playFilter == .memorized ? .all : .memorized }
                            }
                        }
                        Divider()
                        // 표시 방식
                        VStack(alignment: .leading, spacing: 10) {
                            Text("표시 방식").font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
                            HStack(spacing: 10) {
                                Image(systemName: "arrow.left.arrow.right")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .frame(width: 16)
                                Text("Reverse").font(.system(size: 13))
                                Spacer()
                                Toggle("", isOn: $isReverse).toggleStyle(.switch).labelsHidden().scaleEffect(0.8)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 9)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
                        }
                        Divider()
                        // 재생 시간
                        VStack(alignment: .leading, spacing: 10) {
                            Text("단어 재생 시간").font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
                            HStack(spacing: 8) {
                                ForEach(intervalOptions, id: \.self) { sec in
                                    SettingToggleButton(
                                        systemName: "\(sec).circle", label: "\(sec)초",
                                        isOn: autoInterval == sec
                                    ) { autoInterval = sec }
                                }
                            }
                        }
                        Divider()
                        // 품사 관리
                        VStack(alignment: .leading, spacing: 10) {
                            Text("품사 태그 관리").font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
                            Button(action: { showPOSManager = true }) {
                                HStack {
                                    Image(systemName: "tag").font(.system(size: 13))
                                    Text("품사 태그 편집").font(.system(size: 13))
                                    Spacer()
                                    Text("\(store.posTags.count)개")
                                        .font(.system(size: 11)).foregroundColor(.secondary)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11)).foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 12).padding(.vertical, 9)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
                            }.buttonStyle(.plain)
                        }
                        Divider()
                        // 백업 — 파일 저장/불러오기
                        VStack(alignment: .leading, spacing: 10) {
                            Text("데이터 백업").font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
                            HStack(spacing: 8) {
                                BackupButton(icon: "square.and.arrow.up", label: "내보내기", color: .blue) { exportData() }
                                BackupButton(icon: "square.and.arrow.down", label: "불러오기", color: .green) { importData() }
                            }
                            if let msg = feedbackMessage {
                                Text(msg).font(.system(size: 11))
                                    .foregroundColor(msg.hasPrefix("✓") ? .green : .red)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Divider()
                        // 업데이트
                        VStack(alignment: .leading, spacing: 10) {
                            Text("업데이트").font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("현재 버전 \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                                        .font(.system(size: 12)).foregroundColor(.secondary)
                                    updateStatusText
                                }
                                Spacer()
                                updateActionButton
                            }
                            .padding(.horizontal, 12).padding(.vertical, 9)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
                        }
                        Divider()
                        // 튜토리얼
                        VStack(alignment: .leading, spacing: 10) {
                            Text("도움말").font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
                            Button(action: {
                                UserDefaults.standard.removeObject(forKey: "bord_tutorial_shown_v1")
                                onShowTutorial?()
                            }) {
                                HStack {
                                    Image(systemName: "hand.wave").font(.system(size: 13))
                                    Text("튜토리얼 다시 보기").font(.system(size: 13))
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11)).foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 12).padding(.vertical, 9)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
                            }.buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                }
                Divider().padding(.horizontal, 8)
                HStack {
                    Spacer()
                    SaveButton(enabled: true, action: save)
                }.padding(.horizontal, 16).padding(.vertical, 10)
            }
        }.frame(width: 300)
        .onAppear { syncUpdaterState() }
    }

    @ViewBuilder var updateStatusText: some View {
        switch updateState {
        case .idle:                  EmptyView()
        case .checking:              Text("확인 중...").font(.system(size: 11)).foregroundColor(.secondary)
        case .available(let v, _):   Text("v\(v) 업데이트 가능").font(.system(size: 11)).foregroundColor(.blue)
        case .downloading:           Text("다운로드 중...").font(.system(size: 11)).foregroundColor(.secondary)
        case .installing:            Text("설치 중... 앱이 재시작됩니다").font(.system(size: 11)).foregroundColor(.secondary)
        case .upToDate:              Text("최신 버전입니다").font(.system(size: 11)).foregroundColor(.green)
        case .error(let msg):        Text(msg).font(.system(size: 11)).foregroundColor(.red)
        }
    }

    @ViewBuilder var updateActionButton: some View {
        switch updateState {
        case .available(_, let downloadURL):
            Button("업데이트") {
                Updater.shared.downloadAndInstall(downloadURL: downloadURL)
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.blue))
        case .checking, .downloading, .installing:
            ProgressView().scaleEffect(0.7)
        default:
            Button("확인") {
                Updater.shared.onStateChange = { state in updateState = state }
                Updater.shared.checkForUpdate()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundColor(.blue)
        }
    }

    // 설정 화면이 열릴 때 이미 완료된 자동 체크 결과를 즉시 반영
    private func syncUpdaterState() {
        Updater.shared.onStateChange = { state in updateState = state }
        updateState = Updater.shared.state
    }

    func exportData() {
        guard let data = store.exportToData() else {
            showFeedback("✗ 데이터 변환 실패"); return
        }
        // Desktop에 저장 (샌드박스 없이 접근 가능)
        let desktop = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop")
        let url = desktop.appendingPathComponent("B-side_backup.json")
        do {
            try data.write(to: url, options: .atomic)
            showFeedback("✓ 바탕화면에 저장됨\nB-side_backup.json")
        } catch {
            // fallback: Documents
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let url2 = docs.appendingPathComponent("B-side_backup.json")
            do {
                try data.write(to: url2, options: .atomic)
                showFeedback("✓ 문서 폴더에 저장됨\nB-side_backup.json")
            } catch {
                showFeedback("✗ 저장 실패: 권한이 없습니다")
            }
        }
    }

    func importData() {
        onSuspendMonitor?()
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "백업 파일 선택"
        panel.level = .popUpMenu
        panel.orderFrontRegardless()
        let response = panel.runModal()
        onResumeMonitor?()
        guard response == .OK, let url = panel.url else { return }
        guard let data = try? Data(contentsOf: url) else {
            showFeedback("✗ 파일을 읽을 수 없습니다"); return
        }
        let result = store.importFromData(data)
        if result.success {
            showFeedback("✓ \(result.count)개 단어를 불러왔습니다")
        } else {
            showFeedback("✗ \(result.error)")
        }
    }

    func showFeedback(_ msg: String) {
        feedbackMessage = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { feedbackMessage = nil }
    }

    func save() {
        store.playOrder    = playOrder
        store.playFilter   = playFilter
        store.isReverse    = isReverse
        store.autoInterval = autoInterval
        store.save()
        onBack()
    }
}

// MARK: - 품사 태그 관리 화면
struct POSManagerView: View {
    let store: WordStore
    var onBack: () -> Void
    @State private var tags: [POSTag] = []
    @State private var newName = ""
    @State private var newColorHex = "#4A90E2"
    @State private var showingAdd = false

    let presetColors = ["#4A90E2","#27AE60","#E67E22","#8E44AD","#E74C3C","#16A085","#F39C12","#2C3E50"]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(.regularMaterial)
                .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
            VStack(spacing: 0) {
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 3) {
                            Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold))
                            Text("뒤로").font(.system(size: 12))
                        }.foregroundColor(.secondary).padding(.horizontal, 8).padding(.vertical, 4)
                    }.buttonStyle(.plain)
                    Spacer()
                    Text("품사 태그 편집").font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Button(action: { showingAdd.toggle() }) {
                        Image(systemName: "plus").font(.system(size: 13)).foregroundColor(.blue)
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 14).padding(.vertical, 11)
                Divider().padding(.horizontal, 8)

                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(tags) { tag in
                            POSTagEditRow(tag: tag, onUpdate: { name, hex in
                                store.updatePOSTag(id: tag.id, name: name, colorHex: hex)
                                tags = store.posTags
                            }, onDelete: {
                                store.deletePOSTag(id: tag.id)
                                tags = store.posTags
                            })
                        }
                    }.padding(.horizontal, 14).padding(.vertical, 10)
                }
                .frame(height: 410)

                if showingAdd {
                    Divider().padding(.horizontal, 8)
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("품사 이름 (예: 명사, noun...)", text: $newName)
                            .textFieldStyle(.plain).font(.system(size: 13))
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(Color.primary.opacity(0.05)).cornerRadius(7)

                        // 프리셋 컬러 팔레트
                        HStack(spacing: 6) {
                            ForEach(presetColors, id: \.self) { hex in
                                let col = Color(hex: hex) ?? .blue
                                Button(action: { newColorHex = hex }) {
                                    Circle().fill(col).frame(width: 22, height: 22)
                                        .overlay(Circle().stroke(newColorHex == hex ? Color.primary : Color.clear, lineWidth: 2))
                                }.buttonStyle(.plain)
                            }
                        }

                        // 미리보기 + 추가
                        HStack {
                            if !newName.isEmpty {
                                Text(newName)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Color(hex: newColorHex) ?? .blue)
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(RoundedRectangle(cornerRadius: 6)
                                        .fill((Color(hex: newColorHex) ?? .blue).opacity(0.1)))
                                    .overlay(RoundedRectangle(cornerRadius: 6)
                                        .stroke((Color(hex: newColorHex) ?? .blue).opacity(0.4), lineWidth: 1))
                            }
                            Spacer()
                            Button("추가") {
                                let n = newName.trimmingCharacters(in: .whitespaces)
                                guard !n.isEmpty else { return }
                                store.addPOSTag(name: n, colorHex: newColorHex)
                                tags = store.posTags
                                newName = ""; showingAdd = false
                            }
                            .buttonStyle(.plain).font(.system(size: 12, weight: .semibold)).foregroundColor(.blue)
                        }
                    }.padding(.horizontal, 14).padding(.vertical, 10)
                }
            }
        }
        .frame(width: 300)
        .onAppear { tags = store.posTags }
    }
}

struct POSTagEditRow: View {
    let tag: POSTag
    let onUpdate: (String, String) -> Void
    let onDelete: () -> Void
    @State private var isHovered = false
    @State private var isEditing = false
    @State private var editName = ""
    @State private var editHex = ""

    let presetColors = ["#4A90E2","#27AE60","#E67E22","#8E44AD","#E74C3C","#16A085","#F39C12","#2C3E50"]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle().fill(Color(hex: tag.colorHex) ?? .blue).frame(width: 10, height: 10)
                if isEditing {
                    TextField("이름", text: $editName)
                        .textFieldStyle(.plain).font(.system(size: 13))
                } else {
                    Text(tag.name).font(.system(size: 13))
                    Text(tag.colorHex).font(.system(size: 10)).foregroundColor(.secondary)
                }
                Spacer()
                if isHovered && !isEditing {
                    Button(action: {
                        editName = tag.name; editHex = tag.colorHex; isEditing = true
                    }) {
                        Image(systemName: "pencil").font(.system(size: 11)).foregroundColor(.secondary)
                    }.buttonStyle(.plain)
                    Button(action: onDelete) {
                        Image(systemName: "trash").font(.system(size: 11)).foregroundColor(.red)
                    }.buttonStyle(.plain)
                }
                if isEditing {
                    Button("저장") {
                        onUpdate(editName.trimmingCharacters(in: .whitespaces), editHex)
                        isEditing = false
                    }.buttonStyle(.plain).font(.system(size: 11, weight: .semibold)).foregroundColor(.blue)
                }
            }
            if isEditing {
                HStack(spacing: 6) {
                    ForEach(presetColors, id: \.self) { hex in
                        Button(action: { editHex = hex }) {
                            Circle().fill(Color(hex: hex) ?? .blue).frame(width: 20, height: 20)
                                .overlay(Circle().stroke(editHex == hex ? Color.primary : Color.clear, lineWidth: 2))
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8).fill(isHovered ? Color.primary.opacity(0.04) : Color.clear))
        .onHover { isHovered = $0 }
    }
}

// MARK: - Backup / Toggle Buttons
struct SettingOptionRow: View {
    let systemName: String; let label: String; let isOn: Bool; let action: () -> Void
    @State private var isHovered = false
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isOn ? .blue : .secondary)
                    .frame(width: 16)
                Text(label).font(.system(size: 13))
                Spacer()
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 8)
                .fill(isOn ? Color.blue.opacity(0.08) : (isHovered ? Color.primary.opacity(0.08) : Color.primary.opacity(0.05))))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .stroke(isOn ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain).onHover { isHovered = $0 }
    }
}


struct BackupButton: View {
    let icon: String; let label: String; let color: Color; let action: () -> Void
    @State private var isHovered = false; @State private var isPressed = false
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 13, weight: .medium))
                Text(label).font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isPressed ? .white : (isHovered ? color : color.opacity(0.8)))
            .frame(maxWidth: .infinity).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 8)
                .fill(isPressed ? color : (isHovered ? color.opacity(0.15) : color.opacity(0.08))))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(isPressed ? 0 : 0.3), lineWidth: 1))
        }
        .buttonStyle(.plain).onHover { isHovered = $0 }
        .simultaneousGesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in isPressed = true }.onEnded { _ in isPressed = false })
    }
}

struct SettingToggleButton: View {
    let systemName: String; let label: String; let isOn: Bool; let action: () -> Void
    @State private var isHovered = false
    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: systemName).font(.system(size: 16, weight: .medium)).foregroundColor(fg)
                Text(label).font(.system(size: 10, weight: .medium)).foregroundColor(fg)
            }
            .frame(width: 80, height: 52).background(bg).cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(border, lineWidth: 1.5))
            .scaleEffect(isHovered && !isOn ? 1.03 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isHovered)
        }
        .buttonStyle(.plain).onHover { isHovered = $0 }
    }
    var fg: Color { isOn ? .white : (isHovered ? .primary : .secondary) }
    var bg: Color { isOn ? .blue : (isHovered ? Color.primary.opacity(0.1) : Color.primary.opacity(0.05)) }
    var border: Color { isOn ? .blue : (isHovered ? Color.primary.opacity(0.2) : Color.clear) }
}
