import CoreGraphics

enum AppLayout {
    static let floatingButtonBottomOffset: CGFloat = 60
    static let floatingButtonSize: CGFloat = 74
    static let bubbleGapAboveFloatingButton: CGFloat = 24

    static let bubbleBottomOffset: CGFloat =
        floatingButtonBottomOffset + floatingButtonSize + bubbleGapAboveFloatingButton
}
