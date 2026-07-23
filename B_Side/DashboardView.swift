import SwiftUI

enum WordFilter: CaseIterable {
    case all, active, memorized
    var label: String {
        switch self { case .all: "전체"; case .active: "학습중"; case .memorized: "외웠음" }
    }
}

struct DashboardView: View {
    let store: WordStore
    var onAdd: () -> Void
    var onDelete: () -> Void
    var onCheck: () -> Void
    var onFocus: () -> Void
    var onSetting: () -> Void
    var onFolder: () -> Void
    var onImport: () -> Void
    var onClose: () -> Void
    var onQuit: (() -> Void)? = nil
    var onEdit: ((Word) -> Void)?
    var onAddToFolder: ((Word) -> Void)?
    var onDeleteWord: ((Word) -> Void)? = nil

    @State private var filter: WordFilter = .all
    @State private var searchText: String = ""
    @State private var selectedPOSID: UUID? = nil

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(.regularMaterial)
                .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
            VStack(spacing: 0) {
                HStack {
                    // 현재 폴더 표시
                    if let fid = store.activeFolderID,
                       let folder = store.folders.first(where: { $0.id == fid }) {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.fill").font(.system(size: 11)).foregroundColor(.blue)
                            Text(folder.name).font(.system(size: 13, weight: .semibold)).foregroundColor(.blue)
                        }
                    } else {
                        Text("단어목록").font(.system(size: 13, weight: .semibold))
                    }
                    Spacer()
                    HStack(spacing: 2) {
                        DashIconButton(systemName: "folder",            tooltip: "단어장")            { onFolder() }
                        DashIconButton(systemName: "plus",              tooltip: "단어 추가")          { onAdd() }
                        DashIconButton(systemName: "minus.circle",      tooltip: "일괄 삭제")          { onDelete() }
                        DashIconButton(systemName: "checkmark.circle",  tooltip: "외운 단어 체크")     { onCheck() }
                        DashIconButton(systemName: "scope",             tooltip: "집중 단어 선택")    { onFocus() }
                        DashIconButton(systemName: "photo",             tooltip: "사진으로 단어 추가") { onImport() }
                        DashIconButton(systemName: "gearshape",         tooltip: "설정")              { onSetting() }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)

                Divider().padding(.horizontal, 8)

                HStack(spacing: 0) {
                    ForEach(WordFilter.allCases, id: \.self) { tab in
                        Button(action: { filter = tab }) {
                            Text(tab.label)
                                .font(.system(size: 11, weight: filter == tab ? .semibold : .regular))
                                .foregroundColor(filter == tab ? .primary : .secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(filter == tab ? Color.primary.opacity(0.08) : Color.clear)
                        }
                        .buttonStyle(.plain)
                        if tab != WordFilter.allCases.last {
                            Divider().frame(height: 14)
                        }
                    }
                }
                .padding(.horizontal, 8).padding(.vertical, 4)

                Divider().padding(.horizontal, 8)

                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").font(.system(size: 11)).foregroundColor(.secondary)
                    TextField("검색", text: $searchText).textFieldStyle(.plain).font(.system(size: 12))
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill").font(.system(size: 11)).foregroundColor(.secondary)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Color.primary.opacity(0.05)).cornerRadius(7)
                .padding(.horizontal, 10).padding(.vertical, 5)

                Divider().padding(.horizontal, 8)

                if !store.posTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 5) {
                            DashPOSPill(label: "전체", color: .secondary, isSelected: selectedPOSID == nil) {
                                selectedPOSID = nil
                            }
                            ForEach(store.posTags) { tag in
                                DashPOSPill(
                                    label: tag.name,
                                    color: Color(hex: tag.colorHex) ?? .blue,
                                    isSelected: selectedPOSID == tag.id
                                ) { selectedPOSID = selectedPOSID == tag.id ? nil : tag.id }
                            }
                        }.padding(.horizontal, 10)
                    }.padding(.vertical, 6)
                    Divider().padding(.horizontal, 8)
                }

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(displayWords) { word in
                            WordRowView(
                                store: store, word: word,
                                onTap: { onEdit?(word) },
                                onFolderTap: { onAddToFolder?(word) },
                                onPlayFrom: { store.jumpTo(wordID: word.id) },
                                onDelete: onDeleteWord != nil ? { onDeleteWord!(word) } : nil
                            )
                        }
                    }
                }
                .frame(height: store.posTags.isEmpty ? 365 : 330)

                Divider().padding(.horizontal, 8)

                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        let total = baseWords.count
                        let mem   = baseWords.filter { $0.isMemorized }.count
                        Group {
                            switch filter {
                            case .all:
                                Text("전체 \(total)개 · \(mem)개 외움")
                            case .active:
                                Text("학습중 \(baseWords.filter { !$0.isMemorized }.count)개")
                            case .memorized:
                                Text("외운 \(mem)개")
                            }
                        }
                        .font(.system(size: 11)).foregroundColor(.secondary)
                        Text("오늘 \(store.todayViewedCount)개 학습")
                            .font(.system(size: 10)).foregroundColor(.secondary.opacity(0.65))
                    }
                    Spacer()
                    Button(action: { store.jumpToBeginning() }) {
                        HStack(spacing: 3) {
                            Image(systemName: "backward.end.fill").font(.system(size: 10))
                            Text("처음부터").font(.system(size: 12))
                        }
                    }
                    .buttonStyle(.plain).foregroundColor(.secondary)
                    Divider().frame(height: 12).padding(.horizontal, 4)
                    Button("닫기") { onClose() }
                        .buttonStyle(.plain).font(.system(size: 12)).foregroundColor(.secondary)
                    Divider().frame(height: 12).padding(.horizontal, 4)
                    Button(action: { onQuit?() }) {
                        HStack(spacing: 3) {
                            Image(systemName: "power")
                                .font(.system(size: 10, weight: .medium))
                            Text("종료")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("B-Side 종료")
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
            }
        }
        .frame(width: 300)
    }

    var baseWords: [Word] {
        if let fid = store.activeFolderID,
           let folder = store.folders.first(where: { $0.id == fid }) {
            return store.words.filter { folder.wordIDs.contains($0.id) }
        }
        return store.words
    }

    var displayWords: [Word] {
        var base: [Word]
        switch filter {
        case .all:       base = baseWords
        case .active:    base = baseWords.filter { !$0.isMemorized }
        case .memorized: base = baseWords.filter { $0.isMemorized }
        }
        if let posID = selectedPOSID {
            base = base.filter { $0.posTagID == posID }
        }
        guard !searchText.isEmpty else { return base }
        let q = searchText.lowercased()
        return base.filter { $0.term.lowercased().contains(q) || $0.meaning.lowercased().contains(q) }
    }
}

struct WordRowView: View {
    let store: WordStore
    let word: Word
    var onTap: () -> Void
    var onFolderTap: (() -> Void)? = nil
    var onPlayFrom: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            // Focus dot
            Circle()
                .fill(word.isFocused ? Color(red: 1.0, green: 0.6, blue: 0.1) : Color.clear)
                .frame(width: 6, height: 6)
                .overlay(Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(word.term)
                        .font(.system(size: 13, weight: word.isMemorized ? .regular : .medium))
                        .foregroundColor(word.isMemorized ? .secondary : (word.isFocused ? Color(red: 1.0, green: 0.6, blue: 0.1) : .primary))


                    // 품사 태그 (커스텀)
                    if let pid = word.posTagID,
                       let tag = store.posTags.first(where: { $0.id == pid }),
                       let color = Color(hex: tag.colorHex) {
                        Text(tag.name)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(color)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.12)))
                    }
                }
                if !word.meaning.isEmpty {
                    Text(word.meaning)
                        .font(.system(size: 11)).foregroundColor(.secondary).lineLimit(1)
                }
            }

            Spacer()

            if isHovered {
                HStack(spacing: 4) {
                    if onFolderTap != nil {
                        RowActionButton(systemName: "folder.badge.plus", tooltip: "단어장에 추가") { onFolderTap?() }
                    }
                    RowActionButton(systemName: "play.fill", tooltip: "여기서부터 재생") { onPlayFrom?() }
                    RowActionButton(systemName: "pencil", tooltip: "단어 수정") { onTap() }
                    if onDelete != nil {
                        RowActionButton(systemName: "trash", tooltip: "삭제", tintColor: .red) { onDelete?() }
                    }
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(isHovered ? Color.primary.opacity(0.05) : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}

struct RowActionButton: View {
    let systemName: String
    let tooltip: String
    var tintColor: Color = .blue
    let action: () -> Void
    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isPressed ? .white : (isHovered ? tintColor : .secondary))
                .frame(width: 24, height: 22)
                .background(RoundedRectangle(cornerRadius: 5)
                    .fill(isPressed ? tintColor : (isHovered ? tintColor.opacity(0.12) : Color.clear)))
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .onHover { isHovered = $0 }
        .simultaneousGesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in isPressed = true }
            .onEnded { _ in isPressed = false })
    }
}

struct DashPOSPill: View {
    let label: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 4).fill(isSelected ? color : color.opacity(0.12)))
        }.buttonStyle(.plain)
    }
}

struct DashIconButton: View {
    let systemName: String
    let tooltip: String
    let action: () -> Void
    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isPressed ? .white : (isHovered ? .primary : .secondary))
                .frame(width: 26, height: 24)
                .background(RoundedRectangle(cornerRadius: 5)
                    .fill(isPressed ? Color.blue : (isHovered ? Color.primary.opacity(0.1) : Color.clear)))
        }
        .buttonStyle(.plain).help(tooltip).onHover { isHovered = $0 }
        .simultaneousGesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in isPressed = true }.onEnded { _ in isPressed = false })
    }
}
