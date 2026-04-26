import SwiftUI

public struct Card<Content: View>: View {
    private let content: Content
    public init(@ViewBuilder _ content: () -> Content) {
        self.content = content()
    }
    public var body: some View {
        content
            .padding(DS.Space.l)
            .background(DS.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.large, style: .continuous))
            .shadow(color: DS.Shadow.soft.color,
                    radius: DS.Shadow.soft.radius,
                    y: DS.Shadow.soft.y)
    }
}
