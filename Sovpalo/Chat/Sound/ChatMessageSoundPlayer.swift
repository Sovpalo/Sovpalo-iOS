import AVFoundation
import Foundation

protocol ChatMessageSoundPlaying: AnyObject {
    func playIncomingMessageSound()
    func playOutgoingMessageSound()
}

final class ChatMessageSoundPlayer: ChatMessageSoundPlaying {
    private let incomingResourceNames = [
        "chat_message_received",
        "760369__froey__message-receive"
    ]
    private let outgoingResourceNames = [
        "chat_message_sent",
        "760370__froey__message-sent"
    ]
    private let supportedExtensions = ["wav", "mp3", "m4a", "caf"]
    private var players: [URL: AVAudioPlayer] = [:]

    func playIncomingMessageSound() {
        playSound(resourceNames: incomingResourceNames, debugName: "incoming")
    }

    func playOutgoingMessageSound() {
        playSound(resourceNames: outgoingResourceNames, debugName: "outgoing")
    }

    private func playSound(resourceNames: [String], debugName: String) {
        guard let url = soundURL(resourceNames: resourceNames) else { return }
        do {
            try configureAudioSession()

            let player: AVAudioPlayer
            if let cachedPlayer = players[url] {
                player = cachedPlayer
            } else {
                player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                players[url] = player
            }

            player.currentTime = 0
            player.play()
        } catch {
#if DEBUG
            print("[ChatSound] Failed to play \(debugName) message sound: \(error)")
#endif
        }
    }

    private func soundURL(resourceNames: [String]) -> URL? {
        for resourceName in resourceNames {
            for fileExtension in supportedExtensions {
                if let url = Bundle.main.url(forResource: resourceName, withExtension: fileExtension) {
                    return url
                }
                if let url = Bundle.main.url(
                    forResource: resourceName,
                    withExtension: fileExtension,
                    subdirectory: "Resources/Sounds"
                ) {
                    return url
                }
            }
        }
        return nil
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try session.setActive(true, options: [])
    }
}
