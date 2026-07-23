import SwiftUI

// MARK: - 단어장 폴더 관리 메인 뷰
struct FolderListView: View {
    let store: WordStore
    var onBack: () -> Void
    var onSelectFolder: (UUID?) -> Void
    @State private var newFolderName = ""
    @State private var showingAdd = false
    @State private var editingFolder: WordFolder? = nil
    @State private var editName = ""
    @State private var refresh = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(.regularMaterial)
                .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
            VStack(spacing: 0) {
                ZStack {
                    Text("단어장").font(.system(size: 13, weight: .semibold))
                    HStack {
                        Button(action: onBack) {
                            HStack(spacing: 3) {
                                Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold))
                                Text("뒤로").font(.system(size: 12))
                            }
                            .foregroundColor(.secondary).padding(.horizontal, 8).padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.clear))
                        }.buttonStyle(.plain)
                        Spacer()
                        Button(action: { showingAdd = true }) {
                            Image(systemName: "plus").font(.system(size: 13, weight: .medium))
                                .foregroundColor(.blue)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 11)

                Divider().padding(.horizontal, 8)

                ScrollView {
                    VStack(spacing: 0) {
                        // 전체 보기
                        FolderRow(
                            name: "전체 단어",
                            count: store.words.count,
                            isSelected: store.activeFolderID == nil,
                            systemIcon: "tray.full",
                            showDelete: false,
                            onTap: {
                                store.activeFolderID = nil
                                onSelectFolder(nil)
                            },
                            onDelete: {},
                            onRename: { _ in }
                        )
                        ForEach(store.folders) { folder in
                            FolderRow(
                                name: folder.name,
                                count: folder.wordIDs.count,
                                isSelected: store.activeFolderID == folder.id,
                                systemIcon: "folder",
                                showDelete: true,
                                onTap: {
                                    store.activeFolderID = folder.id
                                    onSelectFolder(folder.id)
                                },
                                onDelete: {
                                    store.deleteFolder(id: folder.id)
                                    refresh.toggle()
                                },
                                onRename: { name in
                                    store.renameFolder(id: folder.id, name: name)
                                    refresh.toggle()
                                }
                            )
                        }
                    }
                }
                .frame(height: 390)
                .id(refresh)

                if showingAdd {
                    Divider().padding(.horizontal, 8)
                    HStack(spacing: 8) {
                        TextField("단어장 이름", text: $newFolderName)
                            .textFieldStyle(.plain).font(.system(size: 13))
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(Color.primary.opacity(0.05)).cornerRadius(7)
                        Button("추가") {
                            let name = newFolderName.trimmingCharacters(in: .whitespaces)
                            if !name.isEmpty {
                                store.addFolder(name: name)
                                newFolderName = ""
                                showingAdd = false
                                refresh.toggle()
                            }
                        }
                        .buttonStyle(.plain).font(.system(size: 12, weight: .semibold)).foregroundColor(.blue)
                    }.padding(.horizontal, 14).padding(.vertical, 10)
                }
            }
        }.frame(width: 300)
    }
}

struct FolderRow: View {
    let name: String
    let count: Int
    let isSelected: Bool
    let systemIcon: String
    var tintColor: Color = .blue
    let showDelete: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    let onRename: (String) -> Void

    @State private var isHovered = false
    @State private var isEditing = false
    @State private var editText = ""

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isSelected ? "\(systemIcon).fill" : systemIcon)
                .font(.system(size: 13))
                .foregroundColor(isSelected ? tintColor : .secondary)
                .frame(width: 18)

            if isEditing {
                TextField("", text: $editText, onCommit: {
                    let t = editText.trimmingCharacters(in: .whitespaces)
                    if !t.isEmpty { onRename(t) }
                    isEditing = false
                })
                .textFieldStyle(.plain).font(.system(size: 13))
            } else {
                Text(name)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? tintColor : .primary)
            }

            Spacer()
            Text("\(count)")
                .font(.system(size: 11)).foregroundColor(.secondary)

            if isHovered && showDelete {
                HStack(spacing: 4) {
                    Button(action: {
                        editText = name
                        isEditing = true
                    }) {
                        Image(systemName: "pencil").font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }.buttonStyle(.plain)

                    Button(action: onDelete) {
                        Image(systemName: "trash").font(.system(size: 10))
                            .foregroundColor(.red)
                    }.buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 9)
        .background(isHovered || isSelected ? Color.primary.opacity(0.05) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { if !isEditing { onTap() } }
        .onHover { isHovered = $0 }
    }
}

// MARK: - 단어를 폴더에 추가하는 뷰
struct AddToFolderView: View {
    let store: WordStore
    let word: Word
    var onBack: () -> Void
    @State private var refresh = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(.regularMaterial)
                .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
            VStack(spacing: 0) {
                PanelHeader(title: "단어장에 추가", onBack: onBack)
                Divider().padding(.horizontal, 8)

                if store.folders.isEmpty {
                    VStack(spacing: 8) {
                        Spacer()
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 28)).foregroundColor(.secondary)
                        Text("단어장을 먼저 만들어주세요")
                            .font(.system(size: 13)).foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 390)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(store.folders) { folder in
                                let inFolder = store.wordIsInFolder(word.id, folderID: folder.id)
                                HStack(spacing: 10) {
                                    Image(systemName: inFolder ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 15))
                                        .foregroundColor(inFolder ? .blue : .secondary)
                                    Text(folder.name).font(.system(size: 13))
                                    Spacer()
                                    Text("\(folder.wordIDs.count)개")
                                        .font(.system(size: 11)).foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 10)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    store.toggleWordInFolder(wordID: word.id, folderID: folder.id)
                                    refresh.toggle()
                                }
                            }
                        }
                    }
                    .frame(height: 390)
                    .id(refresh)
                }

                Divider().padding(.horizontal, 8)
                HStack {
                    Spacer()
                    Button("완료") { onBack() }
                        .buttonStyle(.plain).font(.system(size: 12, weight: .semibold)).foregroundColor(.blue)
                }.padding(.horizontal, 16).padding(.vertical, 10)
            }
        }.frame(width: 300)
    }
}
