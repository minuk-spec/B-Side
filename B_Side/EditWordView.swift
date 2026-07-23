import SwiftUI

struct EditWordView: View {
    let store: WordStore
    let word: Word
    var onBack: () -> Void
    var onClose: () -> Void

    @State private var term: String
    @State private var meaning: String
    @State private var example: String
    @State private var exampleMeaning: String
    @State private var selectedPOSID: UUID?
    @State private var selectedFolderIDs: Set<UUID>
    @State private var showAddPOS = false
    @State private var newPOSName = ""
    @State private var newPOSColorHex = "#4A90E2"
    @State private var posRefresh = UUID()
    @FocusState private var focused: Field?
    enum Field { case term, meaning, example, exampleMeaning }

    init(store: WordStore, word: Word, onBack: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.store = store; self.word = word; self.onBack = onBack; self.onClose = onClose
        _term              = State(initialValue: word.term)
        _meaning           = State(initialValue: word.meaning)
        _example           = State(initialValue: word.example)
        _exampleMeaning    = State(initialValue: word.exampleMeaning)
        _selectedPOSID     = State(initialValue: word.posTagID)
        _selectedFolderIDs = State(initialValue: Set(store.folders.filter { $0.wordIDs.contains(word.id) }.map { $0.id }))
    }

    var canSave: Bool { !term.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(.regularMaterial)
                .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
            VStack(spacing: 0) {
                PanelHeader(title: "단어 수정", onBack: onBack)
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
        store.updateWord(
            id: word.id,
            term: term.trimmingCharacters(in: .whitespaces),
            meaning: meaning.trimmingCharacters(in: .whitespaces),
            example: example.trimmingCharacters(in: .whitespaces),
            exampleMeaning: exampleMeaning.trimmingCharacters(in: .whitespaces),
            posTagID: selectedPOSID
        )
        for folder in store.folders {
            let shouldBeIn = selectedFolderIDs.contains(folder.id)
            let isIn = store.wordIsInFolder(word.id, folderID: folder.id)
            if shouldBeIn != isIn { store.toggleWordInFolder(wordID: word.id, folderID: folder.id) }
        }
        onBack()
    }
}
