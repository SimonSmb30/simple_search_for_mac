import AppKit

struct AppItem: Identifiable {
    let id: URL
    let name: String
    var url: URL { id }
}

final class AppIndex {
    private(set) var apps: [AppItem] = []

    init() { reload() }

    func reload() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let roots = ["/Applications", "/System/Applications", "/System/Cryptexes/App/System/Applications", "\(home)/Applications"]
        var found: [URL: AppItem] = [:]
        for root in roots {
            guard let e = FileManager.default.enumerator(
                at: URL(fileURLWithPath: root),
                includingPropertiesForKeys: nil,
                options: [.skipsPackageDescendants, .skipsHiddenFiles]) else { continue }
            for case let url as URL in e {
                guard url.pathExtension == "app" else { continue }
                let name = url.deletingPathExtension().lastPathComponent
                found[url] = AppItem(id: url, name: name)
            }
        }
        var seen = Set<String>()
        apps = found.values.filter { seen.insert($0.name).inserted }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func search(_ query: String) -> [AppItem] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty { return apps }
        var scored: [(AppItem, Int)] = []
        for app in apps {
            if let s = score(app.name.lowercased(), q) { scored.append((app, s)) }
        }
        return scored.sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.name.count < $1.0.name.count }.map { $0.0 }
    }

    private func score(_ name: String, _ q: String) -> Int? {
        if name.hasPrefix(q) { return 300 }
        if name.split(separator: " ").dropFirst().contains(where: { $0.hasPrefix(q) }) { return 200 }
        if name.contains(q) { return 100 }
        var it = name.makeIterator()
        for ch in q {
            var ok = false
            while let c = it.next() { if c == ch { ok = true; break } }
            if !ok { return nil }
        }
        return 50
    }
}
