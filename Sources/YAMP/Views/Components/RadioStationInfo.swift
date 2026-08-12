import SwiftUI
import ZvukMusic

/// Логотип станции и две строки о ней — для панели плеера и мини-плеера.
///
/// Пока станция не сообщила, что играет, первой строкой идёт её название,
/// а второй — просто «Радио»; как только метаданные пришли, они меняются
/// местами по смыслу: сверху трек, снизу станция.
struct RadioStationInfo: View {
    @Environment(PlayerService.self) private var playerService

    let station: RadioStation
    let logoSize: CGFloat
    var titleLineLimit: Int = 1

    private var onAirLine: String? { playerService.onAir?.displayLine }

    var body: some View {
        HStack(spacing: 12) {
            RadioStationLogo(station: station)
                .frame(width: logoSize, height: logoSize)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 3) {
                Text(onAirLine ?? station.name)
                    .font(.callout.weight(.medium))
                    .lineLimit(titleLineLimit)
                Text(onAirLine == nil ? "Радио" : station.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
