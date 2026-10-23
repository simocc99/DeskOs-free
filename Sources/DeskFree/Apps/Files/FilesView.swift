import SwiftUI

struct FilesWindowView: View {
    let window: DeskWindow
    @ObservedObject private var model: FilesModel
    @ObservedObject private var linked = LinkedFolders.shared

    init(window: DeskWindow) {
        self.window = window
        _model = ObservedObject(wrappedValue: DeskSession.shared.models.model(for: window.id) { FilesModel() })
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                toolbar
                Divider()
                HStack(spacing: 0) {
                    if geo.size.width >= 520 {
                        sidebar.frame(width: 172)
                        Divider()
                    }
                    content
                }
                Divider()
                statusBar
            }
            .overlay { dialogOverlay }
        }
        .onAppear { model.reload() }
    }

    // MARK: Toolbar

    private var toolbar: some View {
        HStack(spacing: 4) {
            barButton("chevron.left", enabled: model.canGoBack) { model.goBack() }
            barButton("chevron.right", enabled: model.canGoForward) { model.goForward() }
            barButton("arrow.up", enabled: model.canGoUp) { model.goUp() }

            Text(model.relativePath)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.head)
                .padding(.leading, 6)

            Spacer(minLength: 6)

            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass").font(.system(size: 11)).foregroundStyle(.secondary)
                TextField("Search", text: $model.search)
                    .font(.system(size: 13))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .frame(width: 90)
            }
            .padding(.horizontal, 8)
            .frame(height: 26)
            .background(Color(uiColor: .systemGray5), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            if model.isTrash {
                Button("Empty") { model.emptyTrash() }
                    .font(.system(size: 13))
                    .buttonStyle(.borderless)
            }

            barButton(model.viewMode == .grid ? "list.bullet" : "square.grid.2x2", enabled: true) {
                model.viewMode = model.viewMode == .grid ? .list : .grid
            }

            Menu {
                Button {
                    model.dialogText = ""
                    model.dialog = .newFolder
                } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
                Button {
                    model.importFiles()
                } label: {
                    Label("Import Files…", systemImage: "square.and.arrow.down")
                }
                Button {
                    model.linkFolder()
                } label: {
                    Label("Link Folder…", systemImage: "link.badge.plus")
                }
                Button {
                    model.reload()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 30, height: 30)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 42)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    private func barButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? Color.primary : Color.secondary.opacity(0.5))
        .disabled(!enabled)
    }

    // MARK: Sidebar

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                sectionTitle("Favorites")
                placeRow("Recents", symbol: "clock", place: .recents)
                actionRow("Applications", symbol: "square.grid.2x2") { DeskSession.shared.toggleLaunchpad() }
                placeRow("Desktop", symbol: "menubar.dock.rectangle", place: .desktop)
                placeRow("Documents", symbol: "doc", place: .documents)
                placeRow("Downloads", symbol: "arrow.down.circle", place: .downloads)

                sectionTitle("Locations")
                ForEach(linked.folders) { folder in
                    placeRow(folder.name, symbol: "externaldrive", place: .linked(folder.id))
                        .contextMenu {
                            Button(role: .destructive) { linked.remove(folder) } label: {
                                Label("Unlink Folder", systemImage: "link.badge.minus")
                            }
                        }
                }
                actionRow("Link Folder…", symbol: "link.badge.plus") { model.linkFolder() }
                actionRow("Import Files…", symbol: "square.and.arrow.down") { model.importFiles() }

                Divider().padding(.vertical, 6)
                placeRow("Trash", symbol: "trash", place: .trash)
            }
            .padding(.bottom, 8)
        }
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.6))
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 2)
    }

    private func placeRow(_ title: String, symbol: String, place: FilesPlace) -> some View {
        sidebarButton(title, symbol: symbol, active: model.place == place) { model.show(place) }
    }

    private func actionRow(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        sidebarButton(title, symbol: symbol, active: false, action: action)
    }

    private func sidebarButton(_ title: String, symbol: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 13))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(active ? Color.accentColor.opacity(0.2) : Color.clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        let items = model.visibleItems
        if items.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "tray")
                    .font(.system(size: 34))
                    .foregroundStyle(.secondary)
                Text(model.search.isEmpty ? "This folder is empty" : "No results")
                    .foregroundStyle(.secondary)
                if model.search.isEmpty {
                    Button("Import Files…") { model.importFiles() }
                        .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.viewMode == .grid {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 6)], spacing: 6) {
                    ForEach(items) { item in
                        tile(item)
                    }
                }
                .padding(10)
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(items) { item in
                        row(item)
                    }
                }
            }
        }
    }

    private func tile(_ item: FileItem) -> some View {
        let selected = model.selectedURL == item.url
        return VStack(spacing: 4) {
            FileThumbnail(item: item, size: 60)
            Text(item.name)
                .font(.system(size: 12))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(6)
        .background(selected ? Color.accentColor.opacity(0.25) : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { model.open(item) }
        .onTapGesture { model.selectedURL = item.url }
        .contextMenu { menu(for: item) }
    }

    private func row(_ item: FileItem) -> some View {
        let selected = model.selectedURL == item.url
        return HStack(spacing: 10) {
            FileThumbnail(item: item, size: 28)
            Text(item.name)
                .font(.system(size: 14))
                .lineLimit(1)
            Spacer()
            Text(item.sizeText)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
            Text(item.modified.formatted(date: .abbreviated, time: .omitted))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 96, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(selected ? Color.accentColor.opacity(0.25) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { model.open(item) }
        .onTapGesture { model.selectedURL = item.url }
        .contextMenu { menu(for: item) }
    }

    @ViewBuilder
    private func menu(for item: FileItem) -> some View {
        Button { model.open(item) } label: { Label("Open", systemImage: "arrow.up.forward.app") }
        Button {
            model.dialogText = item.name
            model.dialog = .rename(item)
        } label: { Label("Rename", systemImage: "pencil") }
        Button { model.duplicate(item) } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
        if !item.isDirectory {
            Button { model.share(item) } label: { Label("Share", systemImage: "square.and.arrow.up") }
        }
        Button(role: .destructive) { model.dialog = .delete(item) } label: { Label("Delete", systemImage: "trash") }
    }

    // MARK: Status bar

    private var statusBar: some View {
        HStack(spacing: 8) {
            if let item = model.selectedItem {
                Text("\(item.name) · \(item.sizeText)")
                    .lineLimit(1)
                Spacer()
                Button("Open") { model.open(item) }
                Button("Rename") {
                    model.dialogText = item.name
                    model.dialog = .rename(item)
                }
                Button("Delete", role: .destructive) { model.dialog = .delete(item) }
            } else {
                Text(model.errorMessage ?? "\(model.visibleItems.count) items")
                    .foregroundStyle(model.errorMessage == nil ? Color.secondary : Color.red)
                Spacer()
            }
        }
        .font(.system(size: 12))
        .buttonStyle(.borderless)
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    // MARK: Dialog

    @ViewBuilder
    private var dialogOverlay: some View {
        if let dialog = model.dialog {
            ZStack {
                Color.black.opacity(0.3)
                    .contentShape(Rectangle())
                    .onTapGesture { model.dialog = nil }
                VStack(spacing: 12) {
                    switch dialog {
                    case .newFolder:
                        Text("New Folder").font(.headline)
                        nameField
                        dialogButtons(confirm: "Create") {
                            model.createFolder(named: model.dialogText)
                        }
                    case .rename(let item):
                        Text("Rename").font(.headline)
                        nameField
                        dialogButtons(confirm: "Rename") {
                            model.rename(item, to: model.dialogText)
                        }
                    case .delete(let item):
                        Text(model.isTrash ? "Delete “\(item.name)”?" : "Move “\(item.name)” to the Trash?")
                            .font(.headline).multilineTextAlignment(.center)
                        Text(model.isTrash ? "This can't be undone." : "You can empty the Trash from the sidebar.")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                        dialogButtons(confirm: model.isTrash ? "Delete" : "Move to Trash", destructive: true) {
                            model.delete(item)
                        }
                    }
                }
                .padding(18)
                .frame(width: 280)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(radius: 20)
            }
        }
    }

    private var nameField: some View {
        TextField("Name", text: $model.dialogText)
            .textFieldStyle(.roundedBorder)
            .autocorrectionDisabled()
    }

    private func dialogButtons(confirm: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Button("Cancel") { model.dialog = nil }
                .buttonStyle(.bordered)
            Button(confirm, role: destructive ? .destructive : nil) {
                action()
                model.dialog = nil
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

struct FileThumbnail: View {
    let item: FileItem
    let size: CGFloat

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: item.isDirectory ? "folder.fill" : SpotlightEngine.symbol(forFile: item.url))
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.15)
                    .foregroundStyle(item.isDirectory ? Color.accentColor : Color.secondary)
            }
        }
        .frame(width: size, height: size)
        .task(id: item) {
            image = await ThumbnailCache.shared.thumbnail(for: item, size: size)
        }
    }
}
