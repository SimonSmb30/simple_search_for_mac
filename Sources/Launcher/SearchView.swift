import SwiftUI
import AppKit

let rowHeight: CGFloat = 44
let fieldHeight: CGFloat = 60
let maxRows = 8

final class SearchModel: ObservableObject {
    @Published var query = "" { didSet { results = query.isEmpty ? [] : index.search(query); selection = 0 } }
    @Published var results: [AppItem] = []
    @Published var selection = 0
    @Published var focusToken = 0
    var onClose: () -> Void = {}
    let index = AppIndex()

    func reset() {
        index.reload()
        query = ""
        results = []
        selection = 0
        focusToken += 1
    }

    func move(_ delta: Int) {
        guard !results.isEmpty else { return }
        selection = (selection + delta + results.count) % results.count
    }

    func launchSelected() {
        guard results.indices.contains(selection) else { return }
        let url = results[selection].url
        onClose()
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    var panelHeight: CGFloat {
        let rows = min(results.count, maxRows)
        return fieldHeight + (rows > 0 ? CGFloat(rows) * rowHeight + 20 : 0)
    }
}

struct SearchView: View {
    @ObservedObject var model: SearchModel
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(.secondary)
                TextField("Simple Search", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 24, weight: .light))
                    .focused($focused)
            }
            .padding(.horizontal, 24)
            .frame(height: fieldHeight)

            if !model.results.isEmpty {
                Divider().opacity(0.5)
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(model.results.enumerated()), id: \.element.id) { i, app in
                                Row(app: app, selected: i == model.selection)
                                    .id(i)
                                    .onTapGesture { model.selection = i; model.launchSelected() }
                            }
                        }
                        .padding(10)
                    }
                    .onChange(of: model.selection) { s in
                        withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(s) }
                    }
                }
            }
        }
        .frame(width: 680, height: model.panelHeight, alignment: .top)
        .onAppear { focused = true }
        .onChange(of: model.focusToken) { _ in focused = true }
    }
}

struct Row: View {
    let app: AppItem
    let selected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
                .resizable().frame(width: 30, height: 30)
            Text(app.name).font(.system(size: 15))
                .foregroundStyle(selected ? Color.white : Color.primary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .frame(height: rowHeight)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(selected ? Color.accentColor : .clear))
        .contentShape(Rectangle())
    }
}
