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

    @State private var filter: WordFilter = .all

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
                        DashIconButton(systemName: "minus",             tooltip: "단어 삭제")          { onDelete() }
                        DashIconButton(systemName: "checkmark.circle",  tooltip: "외운 단어 체크")     { onCheck() }
                        DashIconButton(systemName: "scope",             tooltip: "모르는 단어 선택")   { onFocus() }
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

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(displayWords) { word in
                            WordRowView(store: store, word: word, onTap: { onEdit?(word) }, onFolderTap: { onAddToFolder?(word) }, onPlayFrom: { store.jumpTo(wordID: word.id) })
                        }
                    }
                }
                .frame(height: 390)

                Divider().padding(.horizontal, 8)

                HStack {
                    Text("전체 \(store.words.count)개")
                        .font(.system(size: 11)).foregroundColor(.secondary)
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

    var displayWords: [Word] {
        let base: [Word]
        if let fid = store.activeFolderID,
           let folder = store.folders.first(where: { $0.id == fid }) {
            base = store.words.filter { folder.wordIDs.contains($0.id) }
        } else {
            base = store.words
        }
        switch filter {
        case .all:       return base
        case .active:    return base.filter { !$0.isMemorized }
        case .memorized: return base.filter { $0.isMemorized }
        }
    }
}

struct WordRowView: View {
    let store: WordStore
    let word: Word
    var onTap: () -> Void
    var onFolderTap: (() -> Void)? = nil
    var onPlayFrom: (() -> Void)? = nil
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
                        .strikethrough(word.isMemorized)

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
    let action: () -> Void
    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isPressed ? .white : (isHovered ? .primary : .secondary))
                .frame(width: 24, height: 22)
                .background(RoundedRectangle(cornerRadius: 5)
                    .fill(isPressed ? Color.blue : (isHovered ? Color.primary.opacity(0.1) : Color.clear)))
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .onHover { isHovered = $0 }
        .simultaneousGesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in isPressed = true }
            .onEnded { _ in isPressed = false })
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
