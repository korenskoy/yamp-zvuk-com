import SwiftUI

struct LogPanelView: View {
    @Environment(LogStore.self) private var logStore
    @State private var selectedEntry: LogStore.Entry?

    var body: some View {
        @Bindable var store = logStore

        VStack(spacing: 0) {
            Divider()

            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        store.isVisible.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: store.isVisible ? "chevron.down" : "chevron.up")
                            .font(.caption2)
                        Text("Сетевые запросы")
                            .font(.caption)
                        Text("(\(logStore.entries.count))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                if store.isVisible {
                    Button("Очистить") {
                        logStore.clear()
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(.bar)

            if store.isVisible {
                logList
            }
        }
        .sheet(item: $selectedEntry) { entry in
            ResponseDetailView(entry: entry, logStore: logStore)
        }
    }

    private var logList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(logStore.entries) { entry in
                        logRow(entry)
                            .id(entry.id)
                    }
                }
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .frame(height: 160)
            .background(.black.opacity(0.85))
            .onChange(of: logStore.entries.count) {
                if let last = logStore.entries.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    @ViewBuilder
    private func logRow(_ entry: LogStore.Entry) -> some View {
        LogRowView(entry: entry, logStore: logStore, selectedEntry: $selectedEntry)
    }
}

private struct LogRowView: View {
    let entry: LogStore.Entry
    let logStore: LogStore
    @Binding var selectedEntry: LogStore.Entry?
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(logStore.formattedTime(entry.timestamp))
                    .foregroundStyle(.gray)

                Text(entry.method)
                    .foregroundStyle(.cyan)
                    .frame(width: 36, alignment: .leading)

                statusBadge(entry)

                Text(durationText(entry.duration))
                    .foregroundStyle(.gray)
                    .frame(width: 60, alignment: .trailing)

                Text(entry.shortURL)
                    .foregroundStyle(entry.isError ? .red : .white)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if let error = entry.error {
                    Text("– \(error)")
                        .foregroundStyle(.red)
                        .lineLimit(1)
                }

                Spacer()

                Text(sizeText(entry.bytesReceived))
                    .foregroundStyle(.gray)

                apiBadge(entry.apiSource)
            }

            if let preview = entry.preview {
                Text(preview)
                    .foregroundStyle(.gray.opacity(0.6))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.leading, 20)
            }
        }
        .padding(.vertical, 2)
        .background(isHovered ? Color.white.opacity(0.08) : .clear)
        .cornerRadius(2)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture {
            if entry.hasDetails {
                selectedEntry = entry
            }
        }
    }

    private func statusBadge(_ entry: LogStore.Entry) -> some View {
        Group {
            if let code = entry.statusCode {
                Text("\(code)")
                    .foregroundStyle(code >= 400 ? .red : .green)
            } else {
                Text("ERR")
                    .foregroundStyle(.red)
            }
        }
        .frame(width: 32, alignment: .leading)
    }

    private func durationText(_ duration: TimeInterval) -> String {
        if duration < 1 {
            return String(format: "%.0fms", duration * 1000)
        }
        return String(format: "%.1fs", duration)
    }

    private func apiBadge(_ source: LogStore.APISource) -> some View {
        Text(source.rawValue)
            .font(.system(.caption2, design: .monospaced))
            .foregroundStyle(source == .lastfm ? Color(red: 0xBF/255, green: 0x30/255, blue: 0x21/255) : Color(red: 0x05/255, green: 0xDF/255, blue: 0x65/255))
            .frame(width: 44, alignment: .trailing)
    }

    private func sizeText(_ bytes: Int) -> String {
        if bytes == 0 { return "" }
        if bytes < 1024 { return "\(bytes)B" }
        return String(format: "%.1fKB", Double(bytes) / 1024)
    }
}

// MARK: - Response Detail

private struct ResponseDetailView: View {
    enum Tab { case request, response }

    let entry: LogStore.Entry
    let logStore: LogStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: Tab = .response
    @State private var formattedRequest = ""
    @State private var formattedResponse = ""

    private var currentText: String {
        selectedTab == .request ? formattedRequest : formattedResponse
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(entry.method)
                            .foregroundStyle(.cyan)
                        if let code = entry.statusCode {
                            Text("\(code)")
                                .foregroundStyle(code >= 400 ? .red : .green)
                        }
                        Text(durationText(entry.duration))
                            .foregroundStyle(.secondary)
                        Text(sizeText(entry.bytesReceived))
                            .foregroundStyle(.secondary)
                    }
                    .font(.system(.body, design: .monospaced))

                    Text(entry.url)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button("Копировать") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(currentText, forType: .string)
                    }

                    Button("Закрыть") {
                        dismiss()
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                }
            }
            .padding()

            if entry.requestBody != nil && entry.responseBody != nil {
                Picker("", selection: $selectedTab) {
                    Text("Запрос").tag(Tab.request)
                    Text("Ответ").tag(Tab.response)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 4)
            }

            Divider()

            FastTextView(text: currentText)
        }
        .frame(minWidth: 700, minHeight: 450)
        .task {
            let reqRaw = entry.requestBody ?? ""
            let resRaw = entry.responseBody ?? ""
            let (req, res) = await Task.detached {
                (prettyJSON(reqRaw), prettyJSON(resRaw))
            }.value
            formattedRequest = req
            formattedResponse = res

            if entry.requestBody != nil && entry.responseBody == nil {
                selectedTab = .request
            }
        }
    }

    private func durationText(_ duration: TimeInterval) -> String {
        if duration < 1 {
            return String(format: "%.0fms", duration * 1000)
        }
        return String(format: "%.1fs", duration)
    }

    private func sizeText(_ bytes: Int) -> String {
        if bytes == 0 { return "" }
        if bytes < 1024 { return "\(bytes)B" }
        return String(format: "%.1fKB", Double(bytes) / 1024)
    }
}

private func prettyJSON(_ raw: String) -> String {
    guard let data = raw.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data),
          let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
          let result = String(data: pretty, encoding: .utf8)
    else {
        return raw
    }
    return result
}

private struct FastTextView: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .black
        textView.textColor = .white
        textView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.scrollerStyle = .overlay
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! NSTextView
        if textView.string != text {
            textView.string = text
        }
    }
}
