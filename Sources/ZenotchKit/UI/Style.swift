import SwiftUI

/// The notch is black hardware, so the panel is always dark. Text opacities stay at or
/// above 0.55 on black to keep WCAG AA contrast for small text.
enum Style {
    static let primary = Color.white
    static let secondary = Color.white.opacity(0.68)
    static let tertiary = Color.white.opacity(0.55)
    static let fill = Color.white.opacity(0.08)
    static let fillHover = Color.white.opacity(0.14)
    static let stroke = Color.white.opacity(0.16)
    static let spring = Animation.spring(response: 0.38, dampingFraction: 0.82)
}

/// Icon-only button with a hover fill and a tooltip that doubles as its accessibility label.
struct IconButton: View {
    let symbol: String
    let label: String
    var size: CGFloat = 26
    var font: Font = .system(size: 13, weight: .semibold)
    var isSelected = false
    let action: () -> Void

    @ViewState private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(font)
                .foregroundStyle(isSelected ? Style.primary : Style.secondary)
                .frame(width: size, height: size)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isSelected ? Style.fillHover : hovering ? Style.fill : .clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(label)
        .accessibilityLabel(label)
    }
}

/// Small text button used for secondary actions inside widgets.
struct PillButton: View {
    let title: String
    var symbol: String?
    var prominent = false
    let action: () -> Void

    @ViewState private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let symbol { Image(systemName: symbol).font(.system(size: 10, weight: .bold)) }
                Text(title).font(.system(size: 11.5, weight: .semibold))
            }
            .foregroundStyle(prominent ? Color.black : Style.primary)
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(prominent ? Color.white.opacity(hovering ? 0.85 : 1) : hovering ? Style.fillHover : Style.fill)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// Shared empty, loading and error presentation so every widget handles those states the same way.
struct WidgetMessage: View {
    let symbol: String
    let title: String
    var detail: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Style.tertiary)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Style.primary)
            if let detail {
                Text(detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Style.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let actionTitle, let action {
                PillButton(title: actionTitle, prominent: true, action: action).padding(.top, 4)
            }
        }
        .frame(maxWidth: 360)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct LoadingMessage: View {
    let title: String

    var body: some View {
        VStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text(title).font(.system(size: 11.5)).foregroundStyle(Style.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
