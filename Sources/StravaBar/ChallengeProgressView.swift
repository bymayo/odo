import SwiftUI

struct ChallengeProgressView: View {
    let title: String
    let icon: String
    let current: Double
    let goal: Double
    let unit: String
    var useTimeFormat: Bool = false

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(current / goal, 1.0)
    }

    private var percentage: Double { progress * 100 }

    private var expectedProgress: Double {
        let dayOfYear = Double(Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1)
        let daysInYear: Double = Calendar.current.range(of: .day, in: .year, for: Date())?.count == 366 ? 366 : 365
        return dayOfYear / daysInYear
    }

    private var expectedValue: Double { goal * expectedProgress }

    private var projectedTotal: Double {
        guard expectedProgress > 0 else { return 0 }
        return current / expectedProgress
    }

    private var aheadBehind: Double { current - expectedValue }

    private func fmt(_ value: Double) -> String {
        useTimeFormat ? formatTime(value) : formatNumber(value)
    }

    private let ringSize: CGFloat = 80
    private let ringWidth: CGFloat = 8

    var body: some View {
        HStack(spacing: 16) {
            // Left: text info
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.white.opacity(0.5))

                Text("\(fmt(goal)) \(unit)")
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.35))

                Text(fmt(current))
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                +
                Text(" \(unit)")
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.5))

                Spacer().frame(height: 2)

                if aheadBehind >= 0 {
                    Label("+\(fmt(aheadBehind)) ahead", systemImage: "arrow.up.right")
                        .font(.caption2)
                        .foregroundColor(Color(red: 0.4, green: 0.85, blue: 0.5))
                } else {
                    Label("\(fmt(abs(aheadBehind))) behind", systemImage: "arrow.down.right")
                        .font(.caption2)
                        .foregroundColor(Color(red: 1.0, green: 0.45, blue: 0.4))
                }

                Text("Proj: \(fmt(projectedTotal)) \(unit)")
                    .font(.caption2)
                    .foregroundColor(Color.white.opacity(0.3))
            }

            Spacer()

            // Right: circular ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: ringWidth)

                // Pace marker tick (expected progress)
                Circle()
                    .trim(from: max(0, expectedProgress - 0.005), to: min(1, expectedProgress + 0.005))
                    .stroke(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: ringWidth + 4, lineCap: .butt))
                    .rotationEffect(.degrees(-90))

                // Progress arc
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: [Theme.accent, Theme.accent.opacity(0.7)],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360 * progress)
                        ),
                        style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                // Center icon + percentage
                VStack(spacing: 1) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    Text(String(format: "%.0f%%", percentage))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.5))
                }
            }
            .frame(width: ringSize, height: ringSize)
        }
        .padding(14)
        .background(Theme.card)
        .cornerRadius(14)
    }
}
