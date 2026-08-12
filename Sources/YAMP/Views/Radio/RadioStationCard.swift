import SwiftUI
import ZvukMusic

/// Карточка радиостанции: логотип, поверх него плей-оверлей по наведению, подпись снизу.
///
/// У станции нет собственного экрана, поэтому нажатие в любом месте карточки запускает
/// эфир — общее правило «карточка ведёт на страницу, оверлей играет» здесь неприменимо.
struct RadioStationCard: View {
    @Environment(PlayerService.self) private var playerService

    let station: RadioStation

    @State private var isHovered = false

    private var isCurrent: Bool {
        playerService.currentStation?.id == station.id
    }

    private var isPlayingThisStation: Bool {
        isCurrent && playerService.isPlaying
    }

    var body: some View {
        VStack(spacing: 8) {
            logo
            Text(station.name)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(isCurrent ? Color.accentColor : .primary)
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture(perform: toggle)
    }

    private var logo: some View {
        GeometryReader { geo in
            RadioStationLogo(station: station)
                .font(.largeTitle)
                .frame(width: geo.size.width, height: geo.size.width)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay {
                    if isHovered || isPlayingThisStation {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.black.opacity(0.45))
                            .overlay {
                                Image(systemName: isPlayingThisStation ? "pause.fill" : "play.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white)
                            }
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: isHovered)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func toggle() {
        if isCurrent {
            playerService.togglePlayPause()
        } else {
            playerService.playStation(station)
        }
    }
}
