import SwiftUI

/// The live-session rep counter. Large, dim, non-distracting, always visible
/// without tapping (PRD §5.1). A subtle pulse accompanies the count update.
public struct RepCounterHUD: View {
    public let repCount: Int
    public let partialMarker: Bool
    public let cueText: String?

    public init(repCount: Int, partialMarker: Bool = false, cueText: String? = nil) {
        self.repCount = repCount
        self.partialMarker = partialMarker
        self.cueText = cueText
    }

    public var body: some View {
        VStack(spacing: DS.Space.l) {
            ZStack {
                Text("\(repCount)")
                    .font(DS.Font.repCounter)
                    .minimumScaleFactor(0.5)   // keep the rep number visible at AX sizes
                    .lineLimit(1)
                    .foregroundStyle(partialMarker ? DS.Color.warning : DS.Color.textPrimary.opacity(0.85))
                    .contentTransition(.numericText())
                    .accessibilityIdentifier("rep_counter")
                    // A single element for VoiceOver with a clear label. The rep
                    // counter is the UI element most likely to be read aloud
                    // during an active set; a count-plus-noun phrasing reads
                    // better than "five" alone.
                    .accessibilityLabel(Text("\(repCount) \(repCount == 1 ? "rep" : "reps")"))
                    .accessibilityValue(Text(partialMarker ? "partial rep" : "full rep"))
                    .accessibilityAddTraits(.updatesFrequently)
                if partialMarker {
                    Text("partial")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.warning)
                        .padding(DS.Space.xs)
                        .background(.ultraThinMaterial, in: Capsule())
                        .offset(y: 80)
                        .accessibilityHidden(true)   // label already encoded above
                }
            }
            if let cueText {
                Text(cueText)
                    .font(DS.Font.headline)
                    .foregroundStyle(DS.Color.textPrimary)
                    .padding(DS.Space.m)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.medium))
                    .accessibilityIdentifier("cue_text")
                    .accessibilityLabel(Text("Form cue: \(cueText)"))
            }
        }
    }
}
