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
    @FocusState private var focused: Field?
    enum Field { case term, meaning, example, exampleMeaning }

    init(store: WordStore, word: Word, onBack: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.store = store; self.word = word; self.onBack = onBack; self.onClose = onClose
        _term           = State(initialValue: word.term)
        _meaning        = State(initialValue: word.meaning)
        _example        = State(initialValue: word.example)
        _exampleMeaning = State(initialValue: word.exampleMeaning)
        _selectedPOSID  = State(initialValue: word.posTagID)
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
                        if !store.posTags.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("품사").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                                POSTagSelector(store: store, selectedID: $selectedPOSID)
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
        onBack()
    }
}
