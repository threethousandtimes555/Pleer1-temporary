import SwiftUI
import UniformTypeIdentifiers

let accent = Color(red: 0.91, green: 0.81, blue: 0.42)

struct RootView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var player: Player
    @State private var showPlayer = false

    var body: some View {
        TabView {
            SearchView(showPlayer: $showPlayer)
                .tabItem { Label("Поиск", systemImage: "magnifyingglass") }
            LibraryView(showPlayer: $showPlayer)
                .tabItem { Label("Моё", systemImage: "heart") }
            SettingsView(showPlayer: $showPlayer)
                .tabItem { Label("Настройки", systemImage: "slider.horizontal.3") }
        }
        .tint(accent)
        .sheet(isPresented: $showPlayer) {
            PlayerView()
                .environmentObject(player)
                .environmentObject(store)
        }
        .overlay(alignment: .bottom) {
            if let m = store.toast {
                Text(m)
                    .font(.footnote)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 120)
                    .transition(.opacity)
            }
        }
        .animation(.default, value: store.toast)
    }
}

struct MiniPlayer: View {
    @EnvironmentObject var player: Player
    @Binding var show: Bool

    var body: some View {
        if let t = player.current {
            HStack(spacing: 12) {
                Cover(track: t, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(t.title).lineLimit(1).font(.subheadline.weight(.medium))
                    Text(t.artist).lineLimit(1).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Button { player.toggle() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").font(.title2)
                }
                .buttonStyle(.borderless)
                Button { player.advance() } label: {
                    Image(systemName: "forward.fill").font(.title3)
                }
                .buttonStyle(.borderless)
            }
            .padding(10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, 10)
            .padding(.bottom, 4)
            .contentShape(Rectangle())
            .onTapGesture { show = true }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("player.mini")
        }
    }
}

struct TrackRow: View {
    let track: Track
    let list: [Track]
    var removeLabel: String? = nil
    var onRemove: (() -> Void)? = nil

    @EnvironmentObject var store: Store
    @EnvironmentObject var player: Player
    @State private var renaming = false
    @State private var newTitle = ""
    @State private var newArtist = ""
    @State private var newPlaylist = false
    @State private var plName = ""

    var body: some View {
        HStack(spacing: 12) {
            Button {
                player.play(list, at: list.firstIndex(of: track) ?? 0)
            } label: {
                HStack(spacing: 12) {
                    Cover(track: track, size: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title).lineLimit(2)
                        Text(track.artist + (track.youtubeRadioID != nil ? " · YouTube-микс" : (track.youtubePlaylistID == nil ? (track.tag.isEmpty ? "" : " · " + track.tag) : " · YouTube-плейлист")))
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(
                track.tag == "YouTube" && track.youtubePlaylistID == nil && track.youtubeRadioID == nil
                    ? "search.result.youtube.track"
                    : "search.result.track"
            )

            if !track.isLocal && track.archive == nil && track.youtubePlaylistID == nil && track.youtubeRadioID == nil {
                Button { store.toggleFav(track) } label: {
                    Image(systemName: store.isFav(track) ? "heart.fill" : "heart").foregroundColor(accent)
                }
                .buttonStyle(.borderless)
            }

            Menu {
                if track.archive == nil {
                    Menu("В плейлист") {
                        ForEach(store.playlists) { p in
                            Button(p.name) { store.add(track, to: p.id) }
                        }
                        Button("Новый плейлист…") {
                            plName = ""
                            newPlaylist = true
                        }
                    }
                }
                if !track.isLocal && track.archive == nil && track.youtubePlaylistID == nil && track.youtubeRadioID == nil {
                    Button(store.isFav(track) ? "Убрать из избранного" : "В избранное") { store.toggleFav(track) }
                }
                if track.isLocal || store.isFav(track) || removeLabel != nil {
                    Button("Переименовать") {
                        newTitle = track.title
                        newArtist = track.artist
                        renaming = true
                    }
                }
                if let l = removeLabel, let r = onRemove {
                    Button(l, role: .destructive) { r() }
                }
            } label: {
                Image(systemName: "ellipsis").foregroundColor(.secondary).padding(.horizontal, 6)
            }
            .buttonStyle(.borderless)
        }
        .swipeActions(edge: .leading) {
            if !track.isLocal && track.archive == nil && track.youtubePlaylistID == nil && track.youtubeRadioID == nil {
                Button { store.toggleFav(track) } label: { Label("Лайк", systemImage: "heart") }
                    .tint(.pink)
            }
        }
        .alert("Переименовать", isPresented: $renaming) {
            TextField("Название", text: $newTitle)
            TextField("Исполнитель", text: $newArtist)
            Button("Сохранить") { store.rename(track, title: newTitle, artist: newArtist) }
            Button("Отмена", role: .cancel) {}
        }
        .alert("Новый плейлист", isPresented: $newPlaylist) {
            TextField("Название", text: $plName)
            Button("Создать") {
                if let id = store.createPlaylist(plName) { store.add(track, to: id) }
            }
            Button("Отмена", role: .cancel) {}
        }
    }
}

struct SearchView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var player: Player
    @StateObject private var model = SearchModel()
    @State private var q = ""
    @State private var filter = ""
    @Binding var showPlayer: Bool

    var shown: [Track] {
        return filter.isEmpty ? model.results : model.results.filter { $0.tag == filter }
    }

    var body: some View {
        NavigationStack {
            List {
                if !model.errors.isEmpty {
                    Section {
                        ForEach(model.errors, id: \.self) { e in
                            Text(e).font(.footnote).foregroundColor(.secondary)
                        }
                    }
                }
                ForEach(shown) { t in
                    TrackRow(track: t, list: shown)
                }
            }
            .listStyle(.plain)
            .overlay { if model.loading { ProgressView() } }
            .navigationTitle("Поиск")
            .searchable(text: $q, prompt: "Трек или исполнитель")
            .onSubmit(of: .search) {
                let text = q.trimmingCharacters(in: .whitespaces)
                if text.isEmpty { return }
                Task { await model.run(text, key: store.jamendoKey, host: store.funkHost) }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("Источник", selection: $filter) {
                            Text("Все").tag("")
                            ForEach(["YouTube", "Jamendo", "Audius", "ccMixter", "Funkwhale", "Archive"], id: \.self) { n in
                                Text(n).tag(n)
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { MiniPlayer(show: $showPlayer) }
        }
    }
}

struct LibraryView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var player: Player
    @Binding var showPlayer: Bool
    @State private var importing = false
    @State private var newPlaylist = false
    @State private var plName = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        Button("Играть всё") { player.play(store.library) }
                            .buttonStyle(.borderedProminent)
                        Button("Перемешать") { player.play(store.library.shuffled()) }
                            .buttonStyle(.bordered)
                    }
                    .listRowSeparator(.hidden)
                }
                Section("Плейлисты") {
                    ForEach(store.playlists) { p in
                        NavigationLink {
                            PlaylistView(id: p.id, showPlayer: $showPlayer)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(p.name)
                                Text("Треков: \(p.tracks.count)").font(.footnote).foregroundColor(.secondary)
                            }
                        }
                    }
                    Button("Новый плейлист") {
                        plName = ""
                        newPlaylist = true
                    }
                }
                Section("Вся музыка") {
                    let lib = store.library
                    if lib.isEmpty {
                        Text("Пока пусто. Нажми «+», чтобы добавить файлы, или поставь сердечко у трека в поиске. Из Telegram: открой аудио, «Поделиться», выбери «Плеер».")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    ForEach(lib) { t in
                        TrackRow(track: t, list: lib,
                                 removeLabel: t.isLocal ? "Удалить файл" : "Убрать из избранного") {
                            if t.isLocal { store.deleteFile(t) } else { store.toggleFav(t) }
                        }
                    }
                }
                Section("Недавние") {
                    let h = Array(store.history.prefix(10))
                    ForEach(h) { t in
                        TrackRow(track: t, list: h)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Моё")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { importing = true } label: { Image(systemName: "plus") }
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.audio], allowsMultipleSelection: true) { r in
                if case .success(let urls) = r {
                    store.importFiles(urls)
                }
            }
            .alert("Новый плейлист", isPresented: $newPlaylist) {
                TextField("Название", text: $plName)
                Button("Создать") { store.createPlaylist(plName) }
                Button("Отмена", role: .cancel) {}
            }
            .safeAreaInset(edge: .bottom) { MiniPlayer(show: $showPlayer) }
        }
    }
}

struct PlaylistView: View {
    let id: UUID
    @Binding var showPlayer: Bool
    @EnvironmentObject var store: Store
    @EnvironmentObject var player: Player
    @Environment(\.dismiss) private var dismiss
    @State private var renaming = false
    @State private var name = ""

    var pl: Playlist? { return store.playlists.first { $0.id == id } }

    var body: some View {
        List {
            if let p = pl {
                Section {
                    HStack(spacing: 12) {
                        Button("Играть") { player.play(p.tracks) }
                            .buttonStyle(.borderedProminent)
                        Button("Перемешать") { player.play(p.tracks.shuffled()) }
                            .buttonStyle(.bordered)
                    }
                    .listRowSeparator(.hidden)
                }
                if p.tracks.isEmpty {
                    Text("Пусто. Добавляй треки через меню «⋯» у любого трека.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                ForEach(p.tracks) { t in
                    TrackRow(track: t, list: p.tracks, removeLabel: "Убрать из плейлиста") {
                        store.removeFromPlaylist(t, id)
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(pl?.name ?? "")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Переименовать") {
                        name = pl?.name ?? ""
                        renaming = true
                    }
                    Button("Удалить плейлист", role: .destructive) {
                        store.deletePlaylist(id)
                        dismiss()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Переименовать плейлист", isPresented: $renaming) {
            TextField("Название", text: $name)
            Button("Сохранить") { store.renamePlaylist(id, name) }
            Button("Отмена", role: .cancel) {}
        }
        .safeAreaInset(edge: .bottom) { MiniPlayer(show: $showPlayer) }
    }
}

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var player: Player
    @Binding var showPlayer: Bool
    @State private var diagnosticsRevision = 0

    var body: some View {
        let journalSnapshot = YouTubeDiagnostics.exportText
        let journalLines = journalSnapshot.split(whereSeparator: \.isNewline).count
        NavigationStack {
            Form {
                Section("Jamendo (client_id)") {
                    TextField("Ключ", text: $store.jamendoKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section("Funkwhale (сервер)") {
                    TextField("open.audio", text: $store.funkHost)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section("Отладка YouTube") {
                    Text("Журнал хранится только на этом iPhone. В нём есть поисковые запросы, ответы YouTube и состояние аудиоплеера. Он не отправляется автоматически.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Button {
                        diagnosticsRevision += 1
                    } label: {
                        Label("Обновить журнал", systemImage: "arrow.clockwise")
                    }
                    Text("Снимок: \(journalLines) строк · \(journalSnapshot.count) символов")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ShareLink(item: journalSnapshot) {
                        Label("Поделиться журналом", systemImage: "square.and.arrow.up")
                    }
                    .disabled(journalSnapshot.isEmpty)
                    .id(diagnosticsRevision)
                    Button("Очистить журнал", role: .destructive) {
                        YouTubeDiagnostics.clear()
                        diagnosticsRevision += 1
                    }
                }
                Section {
                    Text("Файлы можно класть и через приложение «Файлы»: На iPhone, Плеер, Music. Они появятся в «Моё».")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Настройки")
            .safeAreaInset(edge: .bottom) { MiniPlayer(show: $showPlayer) }
        }
    }
}

struct SeekBar: View {
    @EnvironmentObject var clock: Clock
    @EnvironmentObject var player: Player
    @State private var seeking = false
    @State private var value = 0.0

    var body: some View {
        VStack(spacing: 2) {
            Slider(
                value: Binding(get: { seeking ? value : clock.position }, set: { value = $0 }),
                in: 0...max(clock.duration, 1),
                onEditingChanged: { e in
                    if e { value = clock.position }
                    seeking = e
                    if !e { player.seek(value) }
                }
            )
            .accessibilityIdentifier("player.seekbar")
            HStack {
                Text(fmt(seeking ? value : clock.position))
                    .accessibilityIdentifier("player.elapsed")
                Spacer()
                Text(fmt(clock.duration))
                    .accessibilityIdentifier("player.duration")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
}

struct PlayerBackdrop: View {
    let track: Track?

    var body: some View {
        Color.black
            .overlay {
                ZStack {
                    ArtView(track: track)
                        .scaleEffect(1.5)
                        .blur(radius: 60)
                        .opacity(0.5)
                    LinearGradient(colors: [Color.black.opacity(0.1), Color.black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
                }
            }
            .clipped()
            .ignoresSafeArea()
    }
}

struct PlayerView: View {
    @EnvironmentObject var player: Player
    @EnvironmentObject var store: Store
    @State private var showQueue = false

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width - 40, geo.size.height * 0.52)
            ZStack {
                PlayerBackdrop(track: player.current)
                if let t = player.current {
                    VStack(spacing: 14) {
                        Spacer(minLength: 6)
                        ArtView(track: t)
                            .frame(width: side, height: side)
                            .clipShape(RoundedRectangle(cornerRadius: 26))
                            .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 10)
                        Spacer(minLength: 4)
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(t.title).font(.title3.weight(.semibold)).lineLimit(2)
                                Text(t.artist).foregroundColor(.secondary).lineLimit(1)
                            }
                            Spacer()
                            if !t.isLocal {
                                Button { store.toggleFav(t) } label: {
                                    Image(systemName: store.isFav(t) ? "heart.fill" : "heart")
                                        .font(.title2)
                                        .foregroundColor(accent)
                                }
                            }
                        }
                        SeekBar()
                        HStack(spacing: 26) {
                            Button { player.cycleRepeat() } label: {
                                Image(systemName: player.repeatMode.icon)
                                    .foregroundColor(player.repeatMode == .off ? .secondary : accent)
                            }
                            Button { player.previous() } label: { Image(systemName: "backward.fill").font(.title) }
                            Button { player.toggle() } label: {
                                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill").font(.system(size: 66))
                            }
                            Button { player.advance() } label: { Image(systemName: "forward.fill").font(.title) }
                            Button { showQueue = true } label: { Image(systemName: "list.bullet") }
                        }
                        .font(.title2)
                        .foregroundColor(.primary)
                        HStack(spacing: 38) {
                            Menu {
                                ForEach(store.playlists) { p in
                                    Button(p.name) { store.add(t, to: p.id) }
                                }
                            } label: {
                                Image(systemName: "text.badge.plus")
                            }
                            Menu {
                                Picker("Таймер сна", selection: Binding(get: { player.sleepMinutes }, set: { player.setSleep($0) })) {
                                    Text("Выкл").tag(0)
                                    Text("15 минут").tag(15)
                                    Text("30 минут").tag(30)
                                    Text("60 минут").tag(60)
                                }
                            } label: {
                                Image(systemName: "moon.zzz").foregroundColor(player.sleepMinutes > 0 ? accent : .secondary)
                            }
                            Menu {
                                Picker("Скорость", selection: Binding(get: { player.speed }, set: { player.setSpeed($0) })) {
                                    Text("0.75×").tag(0.75)
                                    Text("1×").tag(1.0)
                                    Text("1.25×").tag(1.25)
                                    Text("1.5×").tag(1.5)
                                }
                            } label: {
                                Image(systemName: "speedometer").foregroundColor(player.speed != 1.0 ? accent : .secondary)
                            }
                        }
                        .font(.title3)
                        Spacer(minLength: 6)
                    }
                    .padding(.horizontal, 20)
                } else {
                    Text("Ничего не играет").foregroundColor(.secondary)
                }
            }
        }
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showQueue) {
            QueueView().environmentObject(player)
        }
    }
}

struct QueueView: View {
    @EnvironmentObject var player: Player

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(player.queue.enumerated()), id: \.offset) { i, t in
                    Button { player.jump(to: i) } label: {
                        HStack(spacing: 12) {
                            Cover(track: t, size: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t.title).lineLimit(1)
                                Text(t.artist).font(.footnote).foregroundColor(.secondary).lineLimit(1)
                            }
                            Spacer()
                            if i == player.index {
                                Image(systemName: "speaker.wave.2.fill").foregroundColor(accent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Очередь")
        }
    }
}
