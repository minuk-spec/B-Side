import SwiftUI

// MARK: - AddWordView
struct AddWordView: View {
    let store: WordStore
    var onBack: () -> Void
    var onClose: () -> Void
    @State private var term = ""
    @State private var meaning = ""
    @State private var example = ""
    @State private var exampleMeaning = ""
    @State private var selectedPOSID: UUID? = nil
    @State private var selectedFolderIDs: Set<UUID> = []
    @State private var showAddPOS = false
    @State private var newPOSName = ""
    @State private var newPOSColorHex = "#4A90E2"
    @State private var posRefresh = UUID()
    @FocusState private var focused: Field?
    enum Field { case term, meaning, example, exampleMeaning }
    var canSave: Bool { !term.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(.regularMaterial)
                .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
            VStack(spacing: 0) {
                PanelHeader(title: "단어 추가", onBack: onBack)
                Divider().padding(.horizontal, 8)
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        InputField(placeholder: "단어", text: $term).focused($focused, equals: .term)
                        InputField(placeholder: "단어 의미", text: $meaning).focused($focused, equals: .meaning)
                        InputField(placeholder: "예문", text: $example).focused($focused, equals: .example)
                        InputField(placeholder: "예문 뜻", text: $exampleMeaning).focused($focused, equals: .exampleMeaning)

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("품사").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                                Spacer()
                                Button(action: { showAddPOS.toggle(); if !showAddPOS { newPOSName = "" } }) {
                                    Image(systemName: showAddPOS ? "xmark" : "plus")
                                        .font(.system(size: 10, weight: .medium)).foregroundColor(.secondary)
                                }.buttonStyle(.plain)
                            }
                            if !store.posTags.isEmpty {
                                POSTagSelector(store: store, selectedID: $selectedPOSID).id(posRefresh)
                            }
                            if showAddPOS {
                                HStack(spacing: 6) {
                                    TextField("품사 이름", text: $newPOSName)
                                        .textFieldStyle(.plain).font(.system(size: 12))
                                        .padding(.horizontal, 8).padding(.vertical, 5)
                                        .background(Color.primary.opacity(0.05)).cornerRadius(6)
                                    ForEach(["#4A90E2","#27AE60","#E67E22","#8E44AD"], id: \.self) { hex in
                                        Button(action: { newPOSColorHex = hex }) {
                                            Circle().fill(Color(hex: hex) ?? .blue).frame(width: 18, height: 18)
                                                .overlay(Circle().stroke(newPOSColorHex == hex ? Color.primary : .clear, lineWidth: 1.5))
                                        }.buttonStyle(.plain)
                                    }
                                    Button("추가") {
                                        let n = newPOSName.trimmingCharacters(in: .whitespaces)
                                        guard !n.isEmpty else { return }
                                        store.addPOSTag(name: n, colorHex: newPOSColorHex)
                                        selectedPOSID = store.posTags.last?.id
                                        newPOSName = ""; showAddPOS = false; posRefresh = UUID()
                                    }.buttonStyle(.plain).font(.system(size: 12, weight: .semibold)).foregroundColor(.blue)
                                }
                            }
                        }

                        // 폴더 선택
                        if !store.folders.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("단어장").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                                VStack(spacing: 0) {
                                    ForEach(store.folders) { folder in
                                        let isSelected = selectedFolderIDs.contains(folder.id)
                                        HStack(spacing: 8) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(isSelected ? Color.blue : Color.clear)
                                                    .frame(width: 15, height: 15)
                                                RoundedRectangle(cornerRadius: 4)
                                                    .stroke(isSelected ? Color.blue : Color.secondary.opacity(0.4), lineWidth: 1.5)
                                                    .frame(width: 15, height: 15)
                                                if isSelected {
                                                    Image(systemName: "checkmark")
                                                        .font(.system(size: 9, weight: .bold))
                                                        .foregroundColor(.white)
                                                }
                                            }
                                            Image(systemName: "folder")
                                                .font(.system(size: 11))
                                                .foregroundColor(isSelected ? .blue : .secondary)
                                            Text(folder.name)
                                                .font(.system(size: 13))
                                                .foregroundColor(isSelected ? .blue : .primary)
                                            Spacer()
                                            Text("\(folder.wordIDs.count)개")
                                                .font(.system(size: 11)).foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal, 10).padding(.vertical, 7)
                                        .background(isSelected ? Color.blue.opacity(0.06) : Color.clear)
                                        .cornerRadius(7)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            if isSelected { selectedFolderIDs.remove(folder.id) }
                                            else { selectedFolderIDs.insert(folder.id) }
                                        }
                                    }
                                }
                                .background(Color.primary.opacity(0.04))
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.08), lineWidth: 1))
                            }
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                }
                .frame(height: 390)
                Divider().padding(.horizontal, 8)
                HStack {
                    Spacer()
                    SaveButton(enabled: canSave, action: save)
                }.padding(.horizontal, 16).padding(.vertical, 10)
            }
        }
        .frame(width: 300)
        .onAppear { focused = .term }
    }

    func save() {
        guard canSave else { return }
        store.addWord(
            term: term.trimmingCharacters(in: .whitespaces),
            meaning: meaning.trimmingCharacters(in: .whitespaces),
            example: example.trimmingCharacters(in: .whitespaces),
            exampleMeaning: exampleMeaning.trimmingCharacters(in: .whitespaces),
            posTagID: selectedPOSID
        )
        // 선택한 폴더에 추가
        if let newWord = store.words.last {
            for folderID in selectedFolderIDs {
                store.toggleWordInFolder(wordID: newWord.id, folderID: folderID)
            }
        }
        onBack()
    }
}

// MARK: - POS Tag Selector (커스텀 태그)
struct POSTagSelector: View {
    let store: WordStore
    @Binding var selectedID: UUID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(store.posTags) { tag in
                    let isSelected = selectedID == tag.id
                    let color = Color(hex: tag.colorHex) ?? .blue
                    Button(action: { selectedID = isSelected ? nil : tag.id }) {
                        Text(tag.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(isSelected ? .white : color)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(RoundedRectangle(cornerRadius: 6)
                                .fill(isSelected ? color : color.opacity(0.1)))
                            .overlay(RoundedRectangle(cornerRadius: 6)
                                .stroke(color.opacity(isSelected ? 0 : 0.4), lineWidth: 1))
                    }.buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Shared UI Components
struct InputField: View {
    let placeholder: String
    @Binding var text: String
    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain).font(.system(size: 13))
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(Color.primary.opacity(0.05)).cornerRadius(7)
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.primary.opacity(0.1), lineWidth: 1))
    }
}

struct PanelHeader: View {
    let title: String
    var onBack: () -> Void
    @State private var isHovered = false
    @State private var isPressed = false
    var body: some View {
        HStack(spacing: 0) {
            Button(action: onBack) {
                HStack(spacing: 3) {
                    Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold))
                    Text("뒤로").font(.system(size: 12))
                }
                .foregroundColor(isPressed ? .white : (isHovered ? .primary : .secondary))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6)
                    .fill(isPressed ? Color.blue : (isHovered ? Color.primary.opacity(0.1) : Color.clear)))
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }
            .simultaneousGesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }.onEnded { _ in isPressed = false })
            Spacer()
            Text(title).font(.system(size: 13, weight: .semibold))
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }
}

struct SaveButton: View {
    let enabled: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "checkmark").font(.system(size: 11, weight: .semibold))
                Text("저장").font(.system(size: 12, weight: .semibold))
            }.foregroundColor(enabled ? .blue : .secondary)
        }.buttonStyle(.plain).disabled(!enabled)
    }
}

// MARK: - Color hex extension
extension Color {
    init?(hex: String) {
        let h = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        self.init(
            red:   Double((val >> 16) & 0xFF) / 255,
            green: Double((val >>  8) & 0xFF) / 255,
            blue:  Double( val        & 0xFF) / 255
        )
    }
}
