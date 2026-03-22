import CoreGraphics
import EFQRCode
import UIKit

enum QRPassImageGenerator {
    private static let qrOutputWidth: CGFloat = 220
    private static let qrPadding: CGFloat = 0

    private static let gradientImage: CGImage? = makeRadialGradientCGImage(sideLength: 512)

    static func image(from payload: String) -> UIImage? {
        guard let gradient = gradientImage else { return nil }

        let fillParams = EFStyleImageFillParams(
            icon: makeCenterIcon(),
            backdrop: EFStyleParamBackdrop(
                cornerRadius: 0,
                color: UIColor.white.cgColor,
                quietzone: nil
            ),
            image: EFStyleImageFillParamsImage(
                image: .static(image: gradient),
                mode: .scaleAspectFill,
                alpha: 1
            ),
            backgroundColor: UIColor.white.cgColor,
            maskColor: UIColor(white: 0, alpha: 0.01).cgColor
        )

        do {
            let generator = try EFQRCode.Generator(
                payload,
                errorCorrectLevel: .h,
                style: .imageFill(params: fillParams)
            )
            return try generator.toImage(
                width: qrOutputWidth,
                insets: UIEdgeInsets(
                    top: qrPadding,
                    left: qrPadding,
                    bottom: qrPadding,
                    right: qrPadding
                )
            )
        } catch {
            return nil
        }
    }

    private static func makeCenterIcon() -> EFStyleParamIcon? {
        guard let cg = UIImage(named: "qr-logo")?.cgImage else { return nil }
        return EFStyleParamIcon(
            image: .static(image: cg),
            mode: .scaleAspectFit,
            alpha: 1,
            borderColor: UIColor.white.cgColor,
            percentage: 0.22
        )
    }

    private static func makeRadialGradientCGImage(sideLength: CGFloat) -> CGImage? {
        let size = CGSize(width: sideLength, height: sideLength)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [
            UIColor.black.cgColor,
            UIColor(red: 0x77 / 255, green: 0, blue: 1, alpha: 1).cgColor,
        ] as CFArray
        let locations: [CGFloat] = [0, 1]
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) else {
            return nil
        }

        let center = CGPoint(x: sideLength / 2, y: sideLength / 2)
        let radius = sideLength / 2
        ctx.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: radius,
            options: [.drawsAfterEndLocation]
        )

        return UIGraphicsGetImageFromCurrentImageContext()?.cgImage
    }
}
