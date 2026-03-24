import Foundation
import SwiftUI
import ZvukMusic

@MainActor
@Observable
final class AppSettings {
    var preferredQuality: StreamQuality {
        get { StreamQuality(rawValue: _qualityRaw) ?? .high }
        set { _qualityRaw = newValue.rawValue }
    }

    var volume: Double {
        get { _volume }
        set { _volume = newValue }
    }

    @ObservationIgnored
    @AppStorage("preferredQuality") private var _qualityRaw = StreamQuality.high.rawValue

    @ObservationIgnored
    @AppStorage("volume") private var _volume: Double = 0.7

    var isScrobblingEnabled: Bool {
        get { _scrobblingEnabled }
        set { _scrobblingEnabled = newValue }
    }

    @ObservationIgnored
    @AppStorage("scrobblingEnabled") private var _scrobblingEnabled: Bool = true
}
