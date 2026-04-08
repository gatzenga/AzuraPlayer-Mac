import AVFoundation
import MediaPlayer
import Combine
import AppKit

class AudioPlayerService: ObservableObject {
    static let shared = AudioPlayerService()

    @Published var isPlaying: Bool = false
    @Published var isBuffering: Bool = false
    @Published var currentStation: RadioStation?
    @Published var lastStation: RadioStation?

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var statusObserver: NSKeyValueObservation?
    private var timeControlObserver: NSKeyValueObservation?
    private var reconnectTimer: Timer?
    private var reconnectAttempts = 0
    private var metadataTimer: Timer?
    private var currentArtwork: MPMediaItemArtwork?
    private var lastDisplayedArtURL: String?

    private init() {
        setupRemoteControls()
    }

    // MARK: - Playback

    func play(station: RadioStation) {
        reconnectAttempts = 0
        lastDisplayedArtURL = nil
        currentArtwork = nil
        startStream(station: station)
    }

    private func startStream(station: RadioStation) {
        guard let url = URL(string: station.streamURL) else { return }

        stopReconnectTimer()
        stopMetadataTimer()

        currentStation = station
        isBuffering = true

        player?.pause()
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: playerItem)
        player = nil
        playerItem = nil
        statusObserver?.invalidate()
        timeControlObserver?.invalidate()

        playerItem = AVPlayerItem(url: url)
        playerItem?.preferredForwardBufferDuration = 12
        player = AVPlayer(playerItem: playerItem)
        player?.automaticallyWaitsToMinimizeStalling = true

        statusObserver = playerItem?.observe(\.status, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                if item.status == .readyToPlay {
                    self?.player?.play()
                } else if item.status == .failed {
                    self?.scheduleReconnect()
                }
            }
        }

        timeControlObserver = player?.observe(\.timeControlStatus, options: [.new]) { [weak self] avPlayer, _ in
            DispatchQueue.main.async {
                guard self?.isPlaying == true else { return }
                switch avPlayer.timeControlStatus {
                case .playing:
                    self?.isBuffering = false
                    self?.playerItem?.preferredForwardBufferDuration = 8
                case .waitingToPlayAtSpecifiedRate:
                    self?.isBuffering = true
                case .paused:
                    break
                @unknown default:
                    break
                }
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemFailedToPlay),
            name: .AVPlayerItemFailedToPlayToEndTime,
            object: playerItem
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playbackStalled),
            name: .AVPlayerItemPlaybackStalled,
            object: playerItem
        )

        isPlaying = true

        MetadataService.shared.startPolling(apiURL: station.apiURL)
        startMetadataTimer()
    }

    func stop() {
        player?.pause()
        player = nil
        playerItem = nil
        statusObserver?.invalidate()
        statusObserver = nil
        timeControlObserver?.invalidate()
        timeControlObserver = nil
        isPlaying = false
        isBuffering = false
        stopMetadataTimer()
        stopReconnectTimer()
        MetadataService.shared.stopPolling()
        if let station = currentStation { lastStation = station }
        currentStation = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func togglePlayPause() {
        if isPlaying {
            stop()
        } else if let station = currentStation ?? lastStation {
            play(station: station)
        }
    }

    // MARK: - Timers

    private func startMetadataTimer() {
        metadataTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateNowPlayingInfo()
        }
    }

    private func stopMetadataTimer() {
        metadataTimer?.invalidate()
        metadataTimer = nil
    }

    // MARK: - Reconnect

    @objc private func playerItemFailedToPlay() {
        DispatchQueue.main.async { self.isBuffering = true }
        scheduleReconnect()
    }

    @objc private func playbackStalled() {
        DispatchQueue.main.async { self.isBuffering = true }
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        guard reconnectAttempts < 5 else { return }
        let delay = min(pow(2.0, Double(reconnectAttempts)), 30.0)
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self, let station = self.currentStation else { return }
            self.reconnectAttempts += 1
            self.startStream(station: station)
        }
    }

    private func stopReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }

    // MARK: - Remote Controls

    private func setupRemoteControls() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self, let station = self.currentStation else { return .commandFailed }
            self.play(station: station)
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.stop()
            return .success
        }

        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
    }

    // MARK: - Now Playing Info

    func updateNowPlayingInfo() {
        var info = [String: Any]()

        let title = MetadataService.shared.currentTrack?.title ?? "Live Stream"
        let artist = MetadataService.shared.currentTrack?.artist ?? currentStation?.displayName ?? "Radio"

        info[MPMediaItemPropertyTitle] = title
        info[MPMediaItemPropertyArtist] = artist
        info[MPNowPlayingInfoPropertyIsLiveStream] = true
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0

        let artURL = MetadataService.shared.currentTrack?.art ?? MetadataService.shared.stationArtURL

        if let urlString = artURL, let url = URL(string: urlString), urlString != lastDisplayedArtURL {
            lastDisplayedArtURL = urlString
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let self else { return }
                if let data = data, let image = NSImage(data: data) {
                    let artwork = MPMediaItemArtwork(boundsSize: CGSize(width: 300, height: 300)) { _ in image }
                    self.currentArtwork = artwork
                    var updatedInfo = info
                    updatedInfo[MPMediaItemPropertyArtwork] = artwork
                    DispatchQueue.main.async {
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = updatedInfo
                    }
                }
            }.resume()
        } else {
            if let existing = currentArtwork {
                info[MPMediaItemPropertyArtwork] = existing
            }
            DispatchQueue.main.async {
                MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            }
        }
    }
}
