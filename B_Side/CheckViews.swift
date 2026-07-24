import SwiftUI

struct CheckMemorizedView: View {
    let store: WordStore
    var onBack: () -> Void
    var onClose: () -> Void
    @State private var memorizedIDs: Set<UUID>

    init(store: WordStore, onBack: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.store = store; self.onBack = onBack; self.onClose = onClose
        _memorizedIDs = State(initialValue: Set(store.words.filter { $0.isMemorized }.map { $0.id }))
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(.regularMaterial)
                .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
            VStack(spacing: 0) {
                PanelHeader(title: "외운 단어", onBack: onBack)
                Divider().padding(.horizontal, 8)
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(store.words) { word in
                            CheckableRow(label: word.term, isChecked: memorizedIDs.contains(word.id), accentColor: .green) {
                                if memorizedIDs.contains(word.id) { memorizedIDs.remove(word.id) }
                                else { memorizedIDs.insert(word.id) }
                            }
                        }
                    }
                }.frame(height: 390)
                Divider().padding(.horizontal, 8)
                HStack {
                    Text("체크한 단어는 재생에서 제외됩니다").font(.system(size: 10)).foregroundColor(.secondary)
                    Spacer()
                    SaveButton(enabled: true, action: save)
                }.padding(.horizontal, 16).padding(.vertical, 10)
            }
        }.frame(width: 300)
    }

    func save() {
        for word in store.words {
            let should = memorizedIDs.contains(word.id)
            if word.isMemorized != should { store.toggleMemorized(id: word.id) }
        }
        onBack()
    }
}

