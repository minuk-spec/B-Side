import SwiftUI

struct DeleteWordView: View {
    let store: WordStore
    var onBack: () -> Void
    var onClose: () -> Void
    @State private var selectedIDs: Set<UUID> = []

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(.regularMaterial)
                .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
            VStack(spacing: 0) {
                PanelHeader(title: "단어 삭제", onBack: onBack)
                Divider().padding(.horizontal, 8)
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(store.words) { word in
                            CheckableRow(label: word.term, isChecked: selectedIDs.contains(word.id), accentColor: .red) {
                                if selectedIDs.contains(word.id) { selectedIDs.remove(word.id) }
                                else { selectedIDs.insert(word.id) }
                            }
                        }
                    }
                }.frame(height: 390)
                Divider().padding(.horizontal, 8)
                HStack {
                    Button(selectedIDs.count == store.words.count ? "전체해제" : "전체선택") {
                        if selectedIDs.count == store.words.count { selectedIDs.removeAll() }
                        else { selectedIDs = Set(store.words.map { $0.id }) }
                    }.buttonStyle(.plain).font(.system(size: 12)).foregroundColor(.secondary)
                    Spacer()
                    Button(action: deleteSelected) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash").font(.system(size: 11))
                            Text("삭제").font(.system(size: 12, weight: .semibold))
                        }.foregroundColor(selectedIDs.isEmpty ? .secondary : .red)
                    }.buttonStyle(.plain).disabled(selectedIDs.isEmpty)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
            }
        }.frame(width: 300)
    }

    func deleteSelected() {
        guard !selectedIDs.isEmpty else { return }
        store.deleteWords(ids: selectedIDs)
        onBack()
    }
}

struct CheckableRow: View {
    let label: String
    let isChecked: Bool
    var accentColor: Color = .blue
    let onToggle: () -> Void
    @State private var isHovered = false
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 4).fill(isChecked ? accentColor : Color.clear).frame(width: 16, height: 16)
                RoundedRectangle(cornerRadius: 4).stroke(isChecked ? accentColor : Color.secondary.opacity(0.4), lineWidth: 1.5).frame(width: 16, height: 16)
                if isChecked { Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundColor(.white) }
            }
            Text(label)
                .font(.system(size: 13, weight: isChecked ? .medium : .regular))
                .foregroundColor(isChecked ? accentColor : .primary)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 9)
        .background(isHovered ? Color.primary.opacity(0.04) : Color.clear)
        .contentShape(Rectangle()).onTapGesture { onToggle() }.onHover { isHovered = $0 }
    }
}
