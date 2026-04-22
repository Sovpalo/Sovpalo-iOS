import UIKit

final class AvatarImageCropViewController: UIViewController, UIScrollViewDelegate {
    private let image: UIImage
    private let onCrop: (UIImage) -> Void

    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let overlayView = UIView()
    private let cropBorderView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let cancelButton = UIButton(type: .system)
    private let doneButton = UIButton(type: .system)

    private var cropRect: CGRect = .zero
    private var didConfigureLayout = false

    init(image: UIImage, onCrop: @escaping (UIImage) -> Void) {
        self.image = image
        self.onCrop = onCrop
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupUI()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        cropRect = calculateCropRect()
        updateOverlayMask()
        cropBorderView.frame = cropRect
        if !didConfigureLayout {
            configureScrollView()
            didConfigureLayout = true
        }
    }

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.delegate = self
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.clipsToBounds = true
        view.addSubview(scrollView)

        imageView.image = image
        scrollView.addSubview(imageView)

        overlayView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.isUserInteractionEnabled = false
        view.addSubview(overlayView)

        cropBorderView.layer.borderColor = UIColor.white.cgColor
        cropBorderView.layer.borderWidth = 2
        cropBorderView.layer.cornerRadius = 28
        cropBorderView.isUserInteractionEnabled = false
        view.addSubview(cropBorderView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Обрежь фото"
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        view.addSubview(titleLabel)

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "Масштабируй и двигай фото, чтобы оно хорошо смотрелось в круглом аватаре."
        subtitleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.78)
        subtitleLabel.numberOfLines = 0
        subtitleLabel.textAlignment = .center
        view.addSubview(subtitleLabel)

        var cancelConfig = UIButton.Configuration.plain()
        cancelConfig.title = "Отмена"
        cancelConfig.baseForegroundColor = .white
        cancelButton.configuration = cancelConfig
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addTarget(self, action: #selector(didTapCancel), for: .touchUpInside)
        view.addSubview(cancelButton)

        var doneConfig = UIButton.Configuration.filled()
        doneConfig.title = "Использовать"
        doneConfig.baseBackgroundColor = UIColor(hex: "#7079FB")
        doneConfig.baseForegroundColor = .white
        doneConfig.cornerStyle = .large
        doneConfig.contentInsets = .init(top: 14, leading: 22, bottom: 14, trailing: 22)
        doneButton.configuration = doneConfig
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        doneButton.addTarget(self, action: #selector(didTapDone), for: .touchUpInside)
        view.addSubview(doneButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            cancelButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -18),

            doneButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            doneButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    private func calculateCropRect() -> CGRect {
        let width = view.bounds.width
        let height = view.bounds.height
        let side = min(width - 40, height * 0.48)
        let originX = (width - side) / 2
        let originY = (height - side) / 2 + 16
        return CGRect(x: originX, y: originY, width: side, height: side)
    }

    private func configureScrollView() {
        imageView.frame = CGRect(origin: .zero, size: image.size)
        scrollView.contentSize = image.size

        let minZoomScale = max(cropRect.width / image.size.width, cropRect.height / image.size.height)
        scrollView.minimumZoomScale = minZoomScale
        scrollView.maximumZoomScale = max(minZoomScale * 4, 4)
        scrollView.zoomScale = minZoomScale

        let inset = UIEdgeInsets(
            top: cropRect.minY,
            left: cropRect.minX,
            bottom: view.bounds.height - cropRect.maxY,
            right: view.bounds.width - cropRect.maxX
        )
        scrollView.contentInset = inset

        let scaledWidth = image.size.width * minZoomScale
        let scaledHeight = image.size.height * minZoomScale
        let offsetX = max((scaledWidth - cropRect.width) / 2 - inset.left, -inset.left)
        let offsetY = max((scaledHeight - cropRect.height) / 2 - inset.top, -inset.top)
        scrollView.contentOffset = CGPoint(x: offsetX, y: offsetY)
    }

    private func updateOverlayMask() {
        let path = UIBezierPath(rect: view.bounds)
        let holePath = UIBezierPath(roundedRect: cropRect, cornerRadius: 28)
        path.append(holePath)

        let mask = CAShapeLayer()
        mask.path = path.cgPath
        mask.fillRule = .evenOdd
        overlayView.layer.mask = mask
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.52)
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    @objc private func didTapCancel() {
        dismiss(animated: true)
    }

    @objc private func didTapDone() {
        guard let croppedImage = cropImage() else {
            dismiss(animated: true)
            return
        }

        dismiss(animated: true) { [onCrop] in
            onCrop(croppedImage)
        }
    }

    private func cropImage() -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        let scale = 1 / scrollView.zoomScale
        let originX = (scrollView.contentOffset.x + scrollView.contentInset.left) * scale
        let originY = (scrollView.contentOffset.y + scrollView.contentInset.top) * scale
        let width = cropRect.width * scale
        let height = cropRect.height * scale

        let cropArea = CGRect(x: originX, y: originY, width: width, height: height).integral
        guard let cropped = cgImage.cropping(to: cropArea.intersection(CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))) else {
            return nil
        }

        return UIImage(cgImage: cropped, scale: image.scale, orientation: .up)
    }
}
