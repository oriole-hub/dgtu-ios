import SwiftUI
import UIKit

struct AuthBubbleBackground: View {
    private static let leftCropFactor: CGFloat = 0.45

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            let p1w: CGFloat = 231
            let p1h: CGFloat = 270
            let o1w: CGFloat = 231
            let o1h: CGFloat = 238
            let p3w: CGFloat = 247
            let p3h: CGFloat = 203
            let p2w: CGFloat = 186
            let p2h: CGFloat = 217
            let o2w: CGFloat = 288
            let o2h: CGFloat = 263

            let leftStack = p1h + o1h + p3h
            let sLeft = max(0, (h - leftStack) / 2)
            let leftTopY = p1h / 2
            let leftMidY = p1h + sLeft + o1h / 2
            let leftBotY = p1h + sLeft + o1h + sLeft + p3h / 2

            let rightStack = p2h + o2h + p3h
            let sRight = max(0, (h - rightStack) / 2)
            let rightTopY = p2h / 2
            let rightMidY = p2h + sRight + o2h / 2
            let rightBotY = p2h + sRight + o2h + sRight + p3h / 2

            let leftCX: (CGFloat) -> CGFloat = { width in
                width / 2 - Self.leftCropFactor * width
            }
            let rightCX: (CGFloat) -> CGFloat = { width in
                w - width / 2 + Self.leftCropFactor * width
            }

            ZStack {
                Color(UIColor.systemBackground)

                Image("bubble-purple-1")
                    .resizable()
                    .scaledToFit()
                    .frame(width: p1w, height: p1h)
                    .position(x: leftCX(p1w) - 30, y: leftTopY + 20)

                Image("bubble-orange-1")
                    .resizable()
                    .scaledToFit()
                    .frame(width: o1w, height: o1h)
                    .position(x: leftCX(o1w) - 40, y: leftMidY + 50)

                Image("bubble-purple-3")
                    .resizable()
                    .scaledToFit()
                    .frame(width: p3w, height: p3h)
                    .position(x: leftCX(p3w), y: leftBotY + 40)

                Image("bubble-purple-2")
                    .resizable()
                    .scaledToFit()
                    .frame(width: p2w, height: p2h)
                    .position(x: rightCX(p2w) + 40, y: rightTopY + 50)

                Image("bubble-orange-2")
                    .resizable()
                    .scaledToFit()
                    .frame(width: o2w, height: o2h)
                    .position(x: rightCX(o2w), y: rightMidY + 80)
            }
            .frame(width: w, height: h)
            .clipped()
        }
    }
}
