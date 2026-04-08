//
//  PlayMenuItem.swift
//  AzuraPlayer Mac
//

import Cocoa
import Combine

class PlayMenuItem: NSMenuItem {
    init() {
        super.init(title: "", action: nil, keyEquivalent: "")
        view = PlayItemView(menuItem: self)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

fileprivate class PlayItemView: NSView {
    private let songLabel    = NSTextField()
    private let stationLabel = NSTextField()
    private let coverImageView = NSImageView()
    private let statusIcon   = NSImageView()

    weak var menuItem: NSMenuItem?

    let player   = AudioPlayerService.shared
    let metadata = MetadataService.shared

    private var cancellables = Set<AnyCancellable>()

    init(menuItem: NSMenuItem) {
        self.menuItem = menuItem
        super.init(frame: NSRect(x: 0, y: 0, width: 360, height: 70))
        createView()

        AudioPlayerService.shared.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        AudioPlayerService.shared.$isBuffering
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshStatusIcon() }
            .store(in: &cancellables)

        AudioPlayerService.shared.$currentStation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        AudioPlayerService.shared.$lastStation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        MetadataService.shared.$currentTrack
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        MetadataService.shared.$isOnline
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshStatusIcon() }
            .store(in: &cancellables)

        refresh()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func createView() {
        autoresizingMask = [.height, .width]

        // Cover Image
        coverImageView.translatesAutoresizingMaskIntoConstraints = false
        coverImageView.imageScaling = .scaleProportionallyUpOrDown
        coverImageView.wantsLayer = true
        coverImageView.layer?.cornerRadius = 6
        coverImageView.layer?.masksToBounds = true
        addSubview(coverImageView)

        NSLayoutConstraint.activate([
            coverImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            coverImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            coverImageView.widthAnchor.constraint(equalToConstant: 48),
            coverImageView.heightAnchor.constraint(equalToConstant: 48)
        ])

        // Song Label
        songLabel.translatesAutoresizingMaskIntoConstraints = false
        songLabel.isBezeled = false
        songLabel.drawsBackground = false
        songLabel.isEditable = false
        songLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        songLabel.textColor = .labelColor
        songLabel.lineBreakMode = .byTruncatingTail
        addSubview(songLabel)

        NSLayoutConstraint.activate([
            songLabel.leadingAnchor.constraint(equalTo: coverImageView.trailingAnchor, constant: 12),
            songLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            songLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -50)
        ])

        // Station Label
        stationLabel.translatesAutoresizingMaskIntoConstraints = false
        stationLabel.isBezeled = false
        stationLabel.drawsBackground = false
        stationLabel.isEditable = false
        stationLabel.font = NSFont.systemFont(ofSize: 11)
        stationLabel.textColor = .secondaryLabelColor
        stationLabel.lineBreakMode = .byTruncatingTail
        addSubview(stationLabel)

        NSLayoutConstraint.activate([
            stationLabel.leadingAnchor.constraint(equalTo: songLabel.leadingAnchor),
            stationLabel.topAnchor.constraint(equalTo: songLabel.bottomAnchor, constant: 3),
            stationLabel.trailingAnchor.constraint(equalTo: songLabel.trailingAnchor)
        ])

        // Status Icon
        statusIcon.translatesAutoresizingMaskIntoConstraints = false
        statusIcon.imageScaling = .scaleProportionallyUpOrDown
        addSubview(statusIcon)

        NSLayoutConstraint.activate([
            statusIcon.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            statusIcon.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            statusIcon.widthAnchor.constraint(equalToConstant: 14),
            statusIcon.heightAnchor.constraint(equalToConstant: 14)
        ])
    }

    // MARK: - Mouse

    override func mouseUp(with event: NSEvent) {
        togglePlayback()
        menuItem?.menu?.cancelTracking()
    }

    override func rightMouseUp(with event: NSEvent) {
        player.stop()
        menuItem?.menu?.cancelTracking()
    }

    private func togglePlayback() {
        if player.isPlaying {
            player.stop()
        } else if let last = player.lastStation {
            player.play(station: last)
        }
    }

    // MARK: - Refresh

    private func refresh() {
        if player.isPlaying, let station = player.currentStation {
            showPlayingState(station: station)
        } else if let last = player.lastStation {
            showIdleState(station: last)
        } else {
            showEmptyState()
        }
    }

    private func showPlayingState(station: RadioStation) {
        songLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        songLabel.textColor = .labelColor

        if let track = metadata.currentTrack, !track.title.isEmpty {
            songLabel.stringValue = track.artist.isEmpty
                ? track.title
                : "\(track.artist) – \(track.title)"
        } else {
            songLabel.stringValue = station.displayName
        }

        stationLabel.stringValue = station.displayName
        stationLabel.isHidden = false

        // Reposition labels: top-aligned (two lines)
        updateLabelConstraints(centered: false)

        // Cover art
        loadCoverArt(for: station)

        refreshStatusIcon()
    }

    // Identische Logik wie iOS: buffering > online-check
    private func refreshStatusIcon() {
        guard player.isPlaying else {
            statusIcon.image = nil
            return
        }

        let problem = player.isBuffering || !metadata.isOnline
        let symbolName = problem ? "wifi.exclamationmark" : "wifi"
        statusIcon.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        statusIcon.image?.isTemplate = true
        statusIcon.contentTintColor = problem ? .systemOrange : .systemGreen
    }

    private func showIdleState(station: RadioStation) {
        songLabel.font = NSFont.systemFont(ofSize: 13)
        songLabel.textColor = .secondaryLabelColor
        songLabel.stringValue = station.displayName
        stationLabel.isHidden = true
        statusIcon.image = nil

        // Reposition label: vertically centered (single line)
        updateLabelConstraints(centered: true)

        // Station image or placeholder
        if let data = station.customImageData, let image = NSImage(data: data) {
            coverImageView.image = image
        } else {
            let placeholder = NSImage(systemSymbolName: "radio", accessibilityDescription: nil)
            placeholder?.isTemplate = true
            coverImageView.image = placeholder
            coverImageView.contentTintColor = .tertiaryLabelColor
        }
    }

    private func showEmptyState() {
        songLabel.font = NSFont.systemFont(ofSize: 13)
        songLabel.textColor = .secondaryLabelColor
        songLabel.stringValue = "Kein Sender aktiv"
        stationLabel.isHidden = true
        statusIcon.image = nil
        updateLabelConstraints(centered: true)

        let placeholder = NSImage(systemSymbolName: "radio", accessibilityDescription: nil)
        placeholder?.isTemplate = true
        coverImageView.image = placeholder
        coverImageView.contentTintColor = .tertiaryLabelColor
    }

    // MARK: - Cover Loading

    private func loadCoverArt(for station: RadioStation) {
        // 1. Song-spezifisches Cover — nur wenn vom User aktiviert
        if station.showSongArt,
           let artURLString = metadata.currentTrack?.art,
           !artURLString.isEmpty,
           let url = URL(string: artURLString) {
            fetch(url: url)
            return
        }

        // 2. Eigenes Senderbild (hochgeladen)
        if let data = station.customImageData, let image = NSImage(data: data) {
            coverImageView.image = image
            coverImageView.contentTintColor = nil
            return
        }

        // 3. Sendercover von der API
        if let artURLString = metadata.stationArtURL,
           !artURLString.isEmpty,
           let url = URL(string: artURLString) {
            fetch(url: url)
            return
        }

        // 4. Fallback-Placeholder
        coverImageView.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)
        coverImageView.contentTintColor = .secondaryLabelColor
    }

    private func fetch(url: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let image = NSImage(data: data) else { return }
            DispatchQueue.main.async {
                self?.coverImageView.image = image
                self?.coverImageView.contentTintColor = nil
            }
        }.resume()
    }

    // MARK: - Label positioning

    private var songCenterY: NSLayoutConstraint?
    private var songTop: NSLayoutConstraint?

    private func updateLabelConstraints(centered: Bool) {
        // Remove existing vertical song constraints
        constraints.filter {
            ($0.firstItem as? NSTextField) == songLabel &&
            ($0.firstAttribute == .centerY || $0.firstAttribute == .top)
        }.forEach { removeConstraint($0) }

        if centered {
            let c = songLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
            c.isActive = true
        } else {
            let c = songLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12)
            c.isActive = true
        }
    }
}
