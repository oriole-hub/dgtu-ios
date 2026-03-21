import SwiftUI
import UIKit

struct SecureRootHostView<Content: View>: UIViewControllerRepresentable {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeUIViewController(context: Context) -> SecureHostingController<Content> {
        SecureHostingController(rootView: content)
    }

    func updateUIViewController(_ uiViewController: SecureHostingController<Content>, context: Context) {
        uiViewController.update(rootView: content)
    }
}

final class SecureHostingController<Content: View>: UIViewController {
    private let hostingController: UIHostingController<Content>
    private let secureContainerView = SecureContainerView()

    init(rootView: Content) {
        hostingController = UIHostingController(rootView: rootView)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = secureContainerView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(hostingController)
        secureContainerView.embedContent(hostingController.view)
        hostingController.didMove(toParent: self)
    }

    func update(rootView: Content) {
        hostingController.rootView = rootView
    }
}

private final class SecureContainerView: UIView {
    private let secureTextField = UITextField()
    private let fallbackContainer = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func embedContent(_ contentView: UIView) {
        contentView.translatesAutoresizingMaskIntoConstraints = false
        fallbackContainer.addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: fallbackContainer.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: fallbackContainer.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: fallbackContainer.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: fallbackContainer.bottomAnchor),
        ])
    }

    private func setup() {
        backgroundColor = .systemBackground

        secureTextField.isSecureTextEntry = true
        secureTextField.translatesAutoresizingMaskIntoConstraints = false
        secureTextField.backgroundColor = .clear
        secureTextField.textColor = .clear
        secureTextField.tintColor = .clear
        secureTextField.isUserInteractionEnabled = false
        addSubview(secureTextField)

        NSLayoutConstraint.activate([
            secureTextField.topAnchor.constraint(equalTo: topAnchor),
            secureTextField.leadingAnchor.constraint(equalTo: leadingAnchor),
            secureTextField.trailingAnchor.constraint(equalTo: trailingAnchor),
            secureTextField.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        fallbackContainer.translatesAutoresizingMaskIntoConstraints = false
        if let secureCanvas = findSecureCanvas(in: secureTextField) {
            secureCanvas.isUserInteractionEnabled = true
            secureCanvas.addSubview(fallbackContainer)
            NSLayoutConstraint.activate([
                fallbackContainer.leadingAnchor.constraint(equalTo: secureCanvas.leadingAnchor),
                fallbackContainer.trailingAnchor.constraint(equalTo: secureCanvas.trailingAnchor),
                fallbackContainer.topAnchor.constraint(equalTo: secureCanvas.topAnchor),
                fallbackContainer.bottomAnchor.constraint(equalTo: secureCanvas.bottomAnchor),
            ])
        } else {
            addSubview(fallbackContainer)
            NSLayoutConstraint.activate([
                fallbackContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
                fallbackContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
                fallbackContainer.topAnchor.constraint(equalTo: topAnchor),
                fallbackContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
        }
    }

    private func findSecureCanvas(in root: UIView) -> UIView? {
        for subview in root.subviews {
            let className = NSStringFromClass(type(of: subview))
            if className.contains("LayoutCanvasView") {
                return subview
            }
            if let nested = findSecureCanvas(in: subview) {
                return nested
            }
        }
        return nil
    }
}
