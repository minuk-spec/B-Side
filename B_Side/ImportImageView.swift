import SwiftUI
import Vision
import AppKit
import PDFKit
import UniformTypeIdentifiers

struct ParsedWordEntry: Identifiable {
    let id = UUID()
    var term: String
    var meaning: String
    var selected: Bool = true
}

struct ImportImageView: View {
    let store: WordStore
    var onBack: () -> Void
    var onClose: () -> Void
    var onSuspendMonitor: (() -> Void)? = nil
    var onResumeMonitor: (() -> Void)? = nil

    @State private var entries: [ParsedWordEntry] = []
    @State private var isProcessing = false
    @State private var errorMessage: String? = nil
    @State private var isDragging = false
    @State private var phase: Phase = .pick
    @State private var batchPOSTagID: UUID? = nil

    enum Phase { case pick, result }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(.regularMaterial)
                .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
            VStack(spacing: 0) {
                header
                Divider().padding(.horizontal, 8)
                switch phase {
                case .pick:   pickView
                case .result: resultView
                }
            }
        }
        .frame(width: 300)
    }

    var header: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.plain)
            Text("사진으로 단어 추가")
                .font(.system(size: 13, weight: .semibold))
            Text("Beta")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.orange)
                .clipShape(Capsule())
            Spacer()
            Button("닫기") { onClose() }
                .buttonStyle(.plain).font(.system(size: 12)).foregroundColor(.secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    var pickView: some View {
        VStack(spacing: 14) {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isDragging ? Color.blue : Color.secondary.opacity(0.35),
                            style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isDragging ? Color.blue.opacity(0.05) : Color.clear)
                    )
                    .frame(height: 140)
                if isProcessing {
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("분석 중...").font(.system(size: 12)).foregroundColor(.secondary)
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary)
                        Text("이미지 또는 PDF 드래그 또는")
                            .font(.system(size: 12)).foregroundColor(.secondary)
                        Button("파일 선택") { selectImage() }
                            .buttonStyle(.borderedProminent).controlSize(.small)
                    }
                }
            }
            .onDrop(of: [.image, .pdf, .fileURL], isTargeted: $isDragging) { providers in
                loadFromProvider(providers.first)
                return true
            }

            if let err = errorMessage {
                Text(err)
                    .font(.system(size: 11)).foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            Text("2컬럼 형식(왼쪽: 단어 / 오른쪽: 뜻)이\n가장 잘 인식됩니다 · PDF 최대 20페이지")
                .font(.system(size: 11)).foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(height: 330)
    }

    var resultView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(entries.count)개 인식됨")
                    .font(.system(size: 12)).foregroundColor(.secondary)
                Spacer()
                Button("다시 선택") {
                    entries = []; phase = .pick; errorMessage = nil; batchPOSTagID = nil
                }
                .buttonStyle(.plain).font(.system(size: 12)).foregroundColor(.blue)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)

            if !store.posTags.isEmpty {
                Divider().padding(.horizontal, 8)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ImportPOSPill(label: "태그 없음", color: .secondary, isSelected: batchPOSTagID == nil) { batchPOSTagID = nil }
                        ForEach(store.posTags) { tag in
                            ImportPOSPill(
                                label: tag.name,
                                color: Color(hex: tag.colorHex) ?? .blue,
                                isSelected: batchPOSTagID == tag.id
                            ) { batchPOSTagID = tag.id }
                        }
                    }
                    .padding(.horizontal, 14)
                }
                .padding(.vertical, 7)
            }

            Divider().padding(.horizontal, 8)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach($entries) { $entry in
                        ImportWordRow(entry: $entry)
                    }
                }
            }
            .frame(height: 255)

            Divider().padding(.horizontal, 8)

            HStack {
                let n = entries.filter { $0.selected }.count
                Text("\(n)개 선택됨")
                    .font(.system(size: 11)).foregroundColor(.secondary)
                Spacer()
                Button("추가") { commit() }
                    .buttonStyle(.borderedProminent).controlSize(.small)
                    .disabled(n == 0)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
    }

    // MARK: - Actions

    func selectImage() {
        // 이벤트 모니터가 파일 패널 클릭을 팝오버 닫기로 처리하지 않도록 일시 중단
        onSuspendMonitor?()
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            self.onResumeMonitor?()
            guard response == .OK, let url = panel.url else { return }
            self.processURL(url)
        }
        // 팝오버가 status bar 레벨(25)에 있으므로 그보다 높게 설정
        panel.level = .popUpMenu
        panel.orderFrontRegardless()
    }

    func loadFromProvider(_ provider: NSItemProvider?) {
        guard let provider = provider else { return }
        if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
            provider.loadFileRepresentation(forTypeIdentifier: UTType.pdf.identifier) { url, _ in
                guard let url else { return }
                let tmp = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString + ".pdf")
                try? FileManager.default.copyItem(at: url, to: tmp)
                DispatchQueue.main.async { processPDFURL(tmp) }
            }
        } else {
            provider.loadDataRepresentation(forTypeIdentifier: "public.image") { data, _ in
                guard let data, let nsImage = NSImage(data: data) else { return }
                DispatchQueue.main.async { processNSImage(nsImage) }
            }
        }
    }

    func processURL(_ url: URL) {
        if url.pathExtension.lowercased() == "pdf" {
            processPDFURL(url)
        } else {
            guard let nsImage = NSImage(contentsOf: url) else {
                errorMessage = "이미지를 불러올 수 없습니다"; return
            }
            processNSImage(nsImage)
        }
    }

    func processPDFURL(_ url: URL) {
        guard let pdf = PDFDocument(url: url) else {
            errorMessage = "PDF를 불러올 수 없습니다"; return
        }
        isProcessing = true
        errorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async {
            var allEntries: [ParsedWordEntry] = []
            let pageCount = min(pdf.pageCount, 20)

            for i in 0..<pageCount {
                guard let page = pdf.page(at: i) else { continue }
                let pageRect = page.bounds(for: .mediaBox)
                let renderSize = CGSize(width: pageRect.width * 2, height: pageRect.height * 2)
                let nsImage = page.thumbnail(of: renderSize, for: .mediaBox)
                guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }

                let semaphore = DispatchSemaphore(value: 0)
                var pageEntries: [ParsedWordEntry] = []

                let request = VNRecognizeTextRequest { req, _ in
                    let obs = (req.results as? [VNRecognizedTextObservation]) ?? []
                    pageEntries = self.parseObservations(obs)
                    semaphore.signal()
                }
                request.recognitionLanguages = ["ja", "ko", "en-US"]
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
                semaphore.wait()
                allEntries.append(contentsOf: pageEntries)
            }

            DispatchQueue.main.async {
                isProcessing = false
                if allEntries.isEmpty {
                    errorMessage = "텍스트를 인식하지 못했습니다.\nPDF에 이미지 형태의 텍스트가 있는지 확인해보세요."
                } else {
                    entries = allEntries; phase = .result
                }
            }
        }
    }

    func processNSImage(_ nsImage: NSImage) {
        guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            errorMessage = "이미지 변환 실패"; return
        }
        isProcessing = true
        errorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async {
            let request = VNRecognizeTextRequest { req, err in
                DispatchQueue.main.async {
                    isProcessing = false
                    if let err {
                        errorMessage = "인식 실패: \(err.localizedDescription)"; return
                    }
                    let obs = (req.results as? [VNRecognizedTextObservation]) ?? []
                    let parsed = parseObservations(obs)
                    if parsed.isEmpty {
                        errorMessage = "텍스트를 인식하지 못했습니다.\n더 선명한 사진을 사용해보세요."
                    } else {
                        entries = parsed; phase = .result
                    }
                }
            }
            request.recognitionLanguages = ["ja", "ko", "en-US"]
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        }
    }

    func parseObservations(_ obs: [VNRecognizedTextObservation]) -> [ParsedWordEntry] {
        // Vision coords: origin bottom-left, normalized 0–1 → sort descending = top→bottom
        let items: [(text: String, box: CGRect)] = obs.compactMap { o in
            guard let c = o.topCandidates(1).first, c.confidence > 0.3 else { return nil }
            return (c.string, o.boundingBox)
        }.sorted { $0.box.minY > $1.box.minY }

        // Group into rows (items within 2.5% vertical distance share a row)
        var rows: [[(text: String, box: CGRect)]] = []
        for item in items {
            if let last = rows.last, abs(last[0].box.midY - item.box.midY) < 0.025 {
                rows[rows.count - 1].append(item)
            } else {
                rows.append([item])
            }
        }
        rows = rows.map { $0.sorted { $0.box.minX < $1.box.minX } }

        let multiColCount = rows.filter { $0.count >= 2 }.count
        var result: [ParsedWordEntry] = []

        if multiColCount > rows.count / 2 {
            // Multi-column layout: leftmost col = term, rightmost col = meaning
            for row in rows where row.count >= 2 {
                let term = row.first!.text
                let meaning = row.last!.text
                guard !term.isEmpty else { continue }
                result.append(ParsedWordEntry(term: term, meaning: meaning))
            }
        } else {
            // Single-column layout: alternate lines (even index = term, odd = meaning)
            var i = 0
            while i < rows.count {
                let term = rows[i].map { $0.text }.joined(separator: " ")
                let meaning = (i + 1 < rows.count) ? rows[i + 1].map { $0.text }.joined(separator: " ") : ""
                if !term.isEmpty {
                    result.append(ParsedWordEntry(term: term, meaning: meaning))
                }
                i += 2
            }
        }
        return result
    }

    func commit() {
        for e in entries where e.selected {
            store.addWord(term: e.term, meaning: e.meaning, example: "", exampleMeaning: "", posTagID: batchPOSTagID)
        }
        onBack()
    }
}

struct ImportPOSPill: View {
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
        }
        .buttonStyle(.plain)
    }
}

struct ImportWordRow: View {
    @Binding var entry: ParsedWordEntry
    var body: some View {
        HStack(spacing: 8) {
            Toggle("", isOn: $entry.selected).toggleStyle(.checkbox).labelsHidden()
            VStack(alignment: .leading, spacing: 2) {
                TextField("단어", text: $entry.term)
                    .font(.system(size: 13, weight: .medium)).textFieldStyle(.plain)
                TextField("뜻", text: $entry.meaning)
                    .font(.system(size: 11)).foregroundColor(.secondary).textFieldStyle(.plain)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 7)
        .background(entry.selected ? Color.blue.opacity(0.05) : Color.clear)
        .contentShape(Rectangle())
    }
}
