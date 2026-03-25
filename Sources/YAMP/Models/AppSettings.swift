import Foundation
import SwiftUI
import ZvukMusic

@MainActor
@Observable
final class AppSettings {
    var preferredQuality: StreamQuality {
        get {
            access(keyPath: \.preferredQuality)
            return StreamQuality(rawValue: _qualityRaw) ?? .high
        }
        set {
            withMutation(keyPath: \.preferredQuality) {
                _qualityRaw = newValue.rawValue
            }
        }
    }

    var volume: Double {
        get {
            access(keyPath: \.volume)
            return _volume
        }
        set {
            withMutation(keyPath: \.volume) {
                _volume = newValue
            }
        }
    }

    @ObservationIgnored
    @AppStorage("preferredQuality") private var _qualityRaw = StreamQuality.high.rawValue

    @ObservationIgnored
    @AppStorage("volume") private var _volume: Double = 0.7

    var isScrobblingEnabled: Bool {
        get {
            access(keyPath: \.isScrobblingEnabled)
            return _scrobblingEnabled
        }
        set {
            withMutation(keyPath: \.isScrobblingEnabled) {
                _scrobblingEnabled = newValue
            }
        }
    }

    @ObservationIgnored
    @AppStorage("scrobblingEnabled") private var _scrobblingEnabled: Bool = true
}
