import Foundation

// MARK: - 커스텀 품사 태그
struct POSTag: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var colorHex: String  // e.g. "#4A90E2"
}

// MARK: - 단어장 폴더
struct WordFolder: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var wordIDs: [UUID] = []
}

// MARK: - 단어
struct Word: Identifiable, Codable, Equatable {
    var id = UUID()
    var term: String
    var meaning: String
    var example: String
    var exampleMeaning: String = ""
    var posTagID: UUID? = nil       // 커스텀 품사 태그 ID
    var isMemorized: Bool = false
    var isFocused: Bool = false
}

class WordStore {
    var words: [Word] = []
    var folders: [WordFolder] = []
    var posTags: [POSTag] = []      // 사용자 정의 품사
    var currentIndex: Int = 0
    // 재생 방법 — 상호 배타적 단일 선택
    enum PlayMode: String { case normal, shuffle, `repeat`, focus }
    var playMode: PlayMode = .normal
    var isShuffle:   Bool { playMode == .shuffle }
    var isRepeat:    Bool { playMode == .repeat }
    var isFocusMode: Bool { playMode == .focus }
    var isReverse:   Bool = false
    var autoInterval: Int = 15
    var activeFolderID: UUID? = nil {
        didSet { buildShuffleQueue() }
    }
    private var shuffledIndices: [Int] = []

    private let wordsKey  = "bord_words_v4"
    private let foldersKey = "bord_folders_v1"
    private let posKey    = "bord_pos_v1"

    var onChange: (() -> Void)?

    init() {
        load()
        if words.isEmpty {
            words = [
                Word(term: "Apple",     meaning: "사과",   example: "I ate apples.",         exampleMeaning: "나는 사과를 먹었다."),
                Word(term: "Run",       meaning: "달리다", example: "She runs every day.",    exampleMeaning: "그녀는 매일 달린다."),
                Word(term: "Beautiful", meaning: "아름다운", example: "It is beautiful.",     exampleMeaning: "그것은 아름답다.", isFocused: true),
            ]
        }
        if posTags.isEmpty {
            posTags = [
                POSTag(name: "명사",  colorHex: "#4A90E2"),
                POSTag(name: "동사",  colorHex: "#27AE60"),
                POSTag(name: "형용사", colorHex: "#E67E22"),
                POSTag(name: "부사",  colorHex: "#8E44AD"),
            ]
        }
        buildShuffleQueue()
    }

    // MARK: - Active words
    var activeWords: [Word] {
        let base: [Word]
        if let fid = activeFolderID,
           let folder = folders.first(where: { $0.id == fid }) {
            base = words.filter { folder.wordIDs.contains($0.id) }
        } else {
            base = words
        }
        return base.filter { !$0.isMemorized && (!isFocusMode || $0.isFocused) }
    }

    var currentWord: Word? {
        let active = activeWords
        guard !active.isEmpty else { return nil }
        return active[currentIndex % active.count]
    }

    func next(manual: Bool = false) {
        guard !isRepeat || manual else { return }
        let active = activeWords
        guard !active.isEmpty else { return }
        if isShuffle {
            if shuffledIndices.isEmpty { buildShuffleQueue() }
            if !shuffledIndices.isEmpty { currentIndex = shuffledIndices.removeFirst() }
        } else {
            currentIndex = (currentIndex + 1) % active.count
        }
        onChange?()
    }

    func previous() {
        let active = activeWords
        guard !active.isEmpty else { return }
        currentIndex = (currentIndex - 1 + active.count) % active.count
        onChange?()
    }

    func jumpToBeginning() {
        currentIndex = 0
        onChange?()
    }

    func jumpTo(wordID: UUID) {
        let active = activeWords
        if let idx = active.firstIndex(where: { $0.id == wordID }) {
            currentIndex = idx
            onChange?()
        }
    }

    // MARK: - Word CRUD
    func addWord(term: String, meaning: String, example: String, exampleMeaning: String, posTagID: UUID?) {
        words.append(Word(term: term, meaning: meaning, example: example, exampleMeaning: exampleMeaning, posTagID: posTagID))
        buildShuffleQueue(); save(); onChange?()
    }

    func updateWord(id: UUID, term: String, meaning: String, example: String, exampleMeaning: String, posTagID: UUID?) {
        if let i = words.firstIndex(where: { $0.id == id }) {
            words[i].term = term; words[i].meaning = meaning
            words[i].example = example; words[i].exampleMeaning = exampleMeaning
            words[i].posTagID = posTagID
            save(); onChange?()
        }
    }

    func deleteWords(ids: Set<UUID>) {
        words.removeAll { ids.contains($0.id) }
        for i in folders.indices { folders[i].wordIDs.removeAll { ids.contains($0) } }
        currentIndex = 0; buildShuffleQueue(); save(); onChange?()
    }

    func toggleMemorized(id: UUID) {
        if let i = words.firstIndex(where: { $0.id == id }) {
            words[i].isMemorized.toggle(); buildShuffleQueue(); save(); onChange?()
        }
    }

    func toggleFocused(id: UUID) {
        if let i = words.firstIndex(where: { $0.id == id }) {
            words[i].isFocused.toggle(); buildShuffleQueue(); save(); onChange?()
        }
    }

    // MARK: - POS Tag CRUD
    func addPOSTag(name: String, colorHex: String) {
        posTags.append(POSTag(name: name, colorHex: colorHex))
        save()
    }

    func updatePOSTag(id: UUID, name: String, colorHex: String) {
        if let i = posTags.firstIndex(where: { $0.id == id }) {
            posTags[i].name = name; posTags[i].colorHex = colorHex; save()
        }
    }

    func deletePOSTag(id: UUID) {
        posTags.removeAll { $0.id == id }
        for i in words.indices { if words[i].posTagID == id { words[i].posTagID = nil } }
        save()
    }

    func posTag(for word: Word) -> POSTag? {
        guard let pid = word.posTagID else { return nil }
        return posTags.first { $0.id == pid }
    }

    // MARK: - Folder
    func addFolder(name: String) { folders.append(WordFolder(name: name)); save(); onChange?() }
    func deleteFolder(id: UUID) {
        folders.removeAll { $0.id == id }
        if activeFolderID == id { activeFolderID = nil }
        save(); onChange?()
    }
    func renameFolder(id: UUID, name: String) {
        if let i = folders.firstIndex(where: { $0.id == id }) { folders[i].name = name; save(); onChange?() }
    }
    func toggleWordInFolder(wordID: UUID, folderID: UUID) {
        if let i = folders.firstIndex(where: { $0.id == folderID }) {
            if folders[i].wordIDs.contains(wordID) { folders[i].wordIDs.removeAll { $0 == wordID } }
            else { folders[i].wordIDs.append(wordID) }
            save(); onChange?()
        }
    }
    func wordIsInFolder(_ wordID: UUID, folderID: UUID) -> Bool {
        folders.first { $0.id == folderID }?.wordIDs.contains(wordID) ?? false
    }

    // MARK: - Backup (JSON 문자열을 클립보드에 복사 / 붙여넣기로 복원)
    struct BackupData: Codable {
        var words: [Word]
        var folders: [WordFolder]
        var posTags: [POSTag]
    }

    func exportToData() -> Data? {
        let backup = BackupData(words: words, folders: folders, posTags: posTags)
        return try? JSONEncoder().encode(backup)
    }

    func importFromData(_ data: Data) -> (success: Bool, count: Int, error: String) {
        if let backup = try? JSONDecoder().decode(BackupData.self, from: data) {
            words = backup.words; folders = backup.folders; posTags = backup.posTags
            currentIndex = 0; save(); onChange?()
            return (true, words.count, "")
        }
        // 구버전 호환
        if let oldWords = try? JSONDecoder().decode([Word].self, from: data) {
            words = oldWords; currentIndex = 0; save(); onChange?()
            return (true, words.count, "")
        }
        return (false, 0, "올바른 백업 파일이 아닙니다")
    }

    // MARK: - Persist
    func save() {
        if let d = try? JSONEncoder().encode(words)   { UserDefaults.standard.set(d, forKey: wordsKey) }
        if let d = try? JSONEncoder().encode(folders)  { UserDefaults.standard.set(d, forKey: foldersKey) }
        if let d = try? JSONEncoder().encode(posTags)  { UserDefaults.standard.set(d, forKey: posKey) }
        // persist settings
        UserDefaults.standard.set(autoInterval, forKey: "bord_interval")
        UserDefaults.standard.set(playMode.rawValue, forKey: "bord_playmode")
        UserDefaults.standard.set(isReverse, forKey: "bord_reverse")
    }

    private func load() {
        if let d = UserDefaults.standard.data(forKey: wordsKey),
           let v = try? JSONDecoder().decode([Word].self, from: d)       { words   = v }
        if let d = UserDefaults.standard.data(forKey: foldersKey),
           let v = try? JSONDecoder().decode([WordFolder].self, from: d) { folders = v }
        if let d = UserDefaults.standard.data(forKey: posKey),
           let v = try? JSONDecoder().decode([POSTag].self, from: d)     { posTags = v }
        // load settings
        let savedInterval = UserDefaults.standard.integer(forKey: "bord_interval")
        if savedInterval > 0 { autoInterval = savedInterval }
        if let raw = UserDefaults.standard.string(forKey: "bord_playmode"),
           let mode = PlayMode(rawValue: raw) { playMode = mode }
        isReverse = UserDefaults.standard.bool(forKey: "bord_reverse")
    }

    private func buildShuffleQueue() {
        shuffledIndices = Array(0..<activeWords.count).shuffled()
    }
}
