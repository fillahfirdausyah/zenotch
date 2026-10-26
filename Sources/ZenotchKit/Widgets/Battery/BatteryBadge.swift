import SwiftUI

struct BatteryBadge: View {
    let info: BatteryInfo

    var body: some View {
        HStack(spacing: 5) {
            Text("\(info.percent)%")
                .font(.system(size: 11.5, weight: .semibold).monospacedDigit())
                .foregroundStyle(Style.secondary)
            BatteryGlyph(percent: info.percent, charging: info.isCharging || info.isPluggedIn)
        }
        .help(info.statusText)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Battery \(info.percent) percent, \(info.statusText)")
    }
}

/// Drawn rather than using SF Symbols so the fill matches the exact percentage.
struct BatteryGlyph: View {
    let percent: Int
    let charging: Bool

    private var fillColor: Color {
        if charging { return .green }
        if percent <= 10 { return .red }
        if percent <= 20 { return .orange }
        return Style.primary
    }

    var body: some View {
        HStack(spacing: 1) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(Style.tertiary, lineWidth: 1)
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(fillColor)
                    .frame(width: max(1.5, 18 * CGFloat(percent) / 100))
                    .padding(1.5)
                if charging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(width: 24, height: 11.5)
            RoundedRectangle(cornerRadius: 1).fill(Style.tertiary).frame(width: 1.5, height: 4)
        }
    }
}
