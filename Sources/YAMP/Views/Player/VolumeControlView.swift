import SwiftUI

struct VolumeControlView: View {
    @Environment(PlayerService.self) private var playerService
    @State private var showSlider = false

    var body: some View {
        Button {
            showSlider.toggle()
        } label: {
            Image(systemName: volumeIcon)
                .font(.callout)
                .frame(width: 20)
        }
        .buttonStyle(.plain)
        .help("Громкость")
        .popover(isPresented: $showSlider) {
            volumePopover
        }
    }

    private var volumePopover: some View {
        @Bindable var service = playerService

        return VStack(spacing: 6) {
            Image(systemName: "speaker.wave.3.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Slider(value: $service.volume, in: 0...1)
                .controlSize(.small)
                .frame(width: 100)
                .rotationEffect(.degrees(-90))
                .frame(width: 28, height: 100)

            Image(systemName: "speaker.slash.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }

    private var volumeIcon: String {
        if playerService.volume == 0 { return "speaker.slash.fill" }
        if playerService.volume < 0.33 { return "speaker.wave.1.fill" }
        if playerService.volume < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}
