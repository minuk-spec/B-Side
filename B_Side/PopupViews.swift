import SwiftUI

struct TapView: View {
    let word: Word
    var isReverse: Bool = false
    var onToggleMemorized: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isReverse ? word.term : word.meaning)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
            if isReverse {
                Text(word.meaning)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !word.example.isEmpty {
                Divider()
                Text(word.example)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !word.exampleMeaning.isEmpty {
                Text(word.exampleMeaning)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if onToggleMemorized != nil {
                Divider()
                HStack {
                    Spacer()
                    Button(action: { onToggleMemorized?() }) {
                        HStack(spacing: 5) {
                            Image(systemName: word.isMemorized ? "checkmark.circle.fill" : "checkmark.circle")
                                .font(.system(size: 12))
                            Text(word.isMemorized ? "외웠음 취소" : "외웠어요")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(word.isMemorized ? .green : .secondary)
                    }.buttonStyle(.plain)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .frame(width: 260, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10).fill(.regularMaterial)
                .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 5)
        )
    }
}
