import UIKit
import ImageIO

final class MeetingCell: UITableViewCell {
    static let identifier = "MeetingCell"

    var onGoingTap: (() -> Void)?
    var onNotGoingTap: (() -> Void)?
    var onCancelTap: (() -> Void)?

    private let shadowView = UIView()
    private let cardView = UIView()

    private let coverImageView = UIImageView()
    private var coverHeightConstraint: NSLayoutConstraint?

    private let titleLabel = UILabel()
    private let timeLabel = UILabel()
    private let locationIcon = UIImageView()
    private let locationLabel = UILabel()
    private let whoGoesTitleLabel = UILabel()
    private let attendeesStack = UIStackView()

    private let buttonsContainer = UIStackView()
    private let goingButton = UIButton(type: .system)
    private let notGoingButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)

    private var imageLoadTask: Task<Void, Never>?
    private var currentPhotoURL: String?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageLoadTask?.cancel()
        imageLoadTask = nil
        currentPhotoURL = nil
        coverImageView.image = nil
        coverImageView.isHidden = true
        coverHeightConstraint?.constant = 0
        attendeesStack.arrangedSubviews.forEach {
            attendeesStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        onGoingTap = nil
        onNotGoingTap = nil
        onCancelTap = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        shadowView.layer.shadowPath = UIBezierPath(roundedRect: shadowView.bounds, cornerRadius: 22).cgPath
    }

    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        shadowView.backgroundColor = .clear
        shadowView.layer.shadowColor = UIColor.black.cgColor
        shadowView.layer.shadowOpacity = 0.08
        shadowView.layer.shadowRadius = 12
        shadowView.layer.shadowOffset = CGSize(width: 0, height: 4)

        cardView.backgroundColor = .white
        cardView.layer.cornerRadius = 22
        cardView.layer.masksToBounds = true

        contentView.addSubview(shadowView)
        shadowView.addSubview(cardView)

        shadowView.translatesAutoresizingMaskIntoConstraints = false
        cardView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            shadowView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            shadowView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            shadowView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            shadowView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),

            cardView.topAnchor.constraint(equalTo: shadowView.topAnchor),
            cardView.leadingAnchor.constraint(equalTo: shadowView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: shadowView.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: shadowView.bottomAnchor)
        ])

        coverImageView.translatesAutoresizingMaskIntoConstraints = false
        coverImageView.contentMode = .scaleAspectFill
        coverImageView.clipsToBounds = true
        coverImageView.layer.cornerRadius = 16
        coverImageView.isHidden = true

        titleLabel.font = .systemFont(ofSize: 21, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0

        timeLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        timeLabel.textColor = UIColor(hex: "#6E73F4")

        locationIcon.image = UIImage(systemName: "mappin.circle")
        locationIcon.tintColor = UIColor(hex: "#6E73F4")
        locationIcon.contentMode = .scaleAspectFit

        locationLabel.font = .systemFont(ofSize: 14, weight: .regular)
        locationLabel.textColor = .darkGray
        locationLabel.numberOfLines = 1

        whoGoesTitleLabel.text = "Кто идет"
        whoGoesTitleLabel.font = .systemFont(ofSize: 16, weight: .bold)
        whoGoesTitleLabel.textColor = .label

        attendeesStack.axis = .vertical
        attendeesStack.spacing = 6
        attendeesStack.alignment = .fill

        buttonsContainer.axis = .horizontal
        buttonsContainer.spacing = 10
        buttonsContainer.distribution = .fillEqually

        [goingButton, notGoingButton, cancelButton].forEach {
            $0.layer.cornerRadius = 22
            $0.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
            $0.heightAnchor.constraint(equalToConstant: 46).isActive = true
        }

        goingButton.addTarget(self, action: #selector(didTapGoing), for: .touchUpInside)
        notGoingButton.addTarget(self, action: #selector(didTapNotGoing), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(didTapCancel), for: .touchUpInside)

        buttonsContainer.addArrangedSubview(goingButton)
        buttonsContainer.addArrangedSubview(notGoingButton)

        let mainStack = UIStackView(arrangedSubviews: [
            coverImageView,
            titleLabel,
            timeLabel,
            makeLocationRow(),
            whoGoesTitleLabel,
            attendeesStack,
            buttonsContainer,
            cancelButton
        ])
        mainStack.axis = .vertical
        mainStack.spacing = 10

        cardView.addSubview(mainStack)
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        coverHeightConstraint = coverImageView.heightAnchor.constraint(equalToConstant: 0)
        coverHeightConstraint?.isActive = true

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 18),
            mainStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -14)
        ])
    }

    private func makeLocationRow() -> UIStackView {
        NSLayoutConstraint.activate([
            locationIcon.widthAnchor.constraint(equalToConstant: 18),
            locationIcon.heightAnchor.constraint(equalToConstant: 18)
        ])

        let stack = UIStackView(arrangedSubviews: [locationIcon, locationLabel])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 4
        return stack
    }

    func configure(with meeting: Meeting) {
        titleLabel.text = "\(meeting.title) \(meeting.dateText)"
        timeLabel.text = meeting.timeText

        if meeting.cityText.isEmpty {
            locationLabel.text = meeting.addressText
        } else {
            locationLabel.text = "\(meeting.cityText), \(meeting.addressText)"
        }

        attendeesStack.arrangedSubviews.forEach {
            attendeesStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let visibleAttendees = Array(meeting.attendeesGoing.prefix(2))
        whoGoesTitleLabel.isHidden = visibleAttendees.isEmpty
        attendeesStack.isHidden = visibleAttendees.isEmpty

        for attendee in visibleAttendees {
            attendeesStack.addArrangedSubview(makeAttendeeRow(name: attendee))
        }

        applyButtonsState(for: meeting.responseStatus, archived: meeting.isArchived)
        loadPhotoIfNeeded(from: meeting.photoURL)
    }

    private func makeAttendeeRow(name: String) -> UIView {
        let dot = UIView()
        dot.backgroundColor = .systemGray
        dot.layer.cornerRadius = 6
        dot.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: 12),
            dot.heightAnchor.constraint(equalToConstant: 12)
        ])

        let label = UILabel()
        label.text = name
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .darkGray

        let stack = UIStackView(arrangedSubviews: [dot, label])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        return stack
    }

    private func applyButtonsState(for status: MeetingResponseStatus, archived: Bool) {
        if archived || status == .createdByMe {
            buttonsContainer.isHidden = true
            cancelButton.isHidden = true
            return
        }

        switch status {
        case .none:
            buttonsContainer.isHidden = false
            cancelButton.isHidden = true

            styleFilledButton(goingButton, title: "Иду", selected: true)
            styleFilledButton(notGoingButton, title: "Не иду", selected: false)

        case .going, .notGoing:
            buttonsContainer.isHidden = true
            cancelButton.isHidden = false
            styleOutlineButton(cancelButton, title: "Отменить ✕")

        case .createdByMe:
            buttonsContainer.isHidden = true
            cancelButton.isHidden = true
        }
    }

    private func styleFilledButton(_ button: UIButton, title: String, selected: Bool) {
        if selected {
            var config = UIButton.Configuration.filled()
            config.title = title
            config.cornerStyle = .capsule
            config.baseBackgroundColor = UIColor(hex: "#6E73F4")
            config.baseForegroundColor = .white
            button.configuration = config
        } else {
            var config = UIButton.Configuration.plain()
            config.title = title
            config.cornerStyle = .capsule
            config.baseForegroundColor = .label
            config.background.backgroundColor = .white
            config.background.strokeColor = UIColor.systemGray5
            config.background.strokeWidth = 1
            button.configuration = config
        }
    }

    private func styleOutlineButton(_ button: UIButton, title: String) {
        var config = UIButton.Configuration.plain()
        config.title = title
        config.cornerStyle = .capsule
        config.baseForegroundColor = .label
        config.background.backgroundColor = .white
        config.background.strokeColor = UIColor.systemGray5
        config.background.strokeWidth = 1
        button.configuration = config
    }

    private func loadPhotoIfNeeded(from photoURL: String?) {
        imageLoadTask?.cancel()
        currentPhotoURL = photoURL

        guard let photoURL else {
            coverImageView.image = nil
            coverImageView.isHidden = true
            coverHeightConstraint?.constant = 0
            return
        }

        coverImageView.image = nil
        coverImageView.isHidden = false
        coverHeightConstraint?.constant = 148

        imageLoadTask = Task { [weak self] in
            guard let self else { return }
            let image = await MeetingImageLoader.shared.loadImage(
                from: photoURL,
                targetSize: CGSize(width: UIScreen.main.bounds.width - 64, height: 148)
            )

            if Task.isCancelled { return }

            await MainActor.run {
                guard self.currentPhotoURL == photoURL else { return }
                if let image {
                    self.coverImageView.image = image
                    self.coverImageView.isHidden = false
                    self.coverHeightConstraint?.constant = 148
                } else {
                    self.coverImageView.image = nil
                    self.coverImageView.isHidden = true
                    self.coverHeightConstraint?.constant = 0
                }
            }
        }
    }

    @objc private func didTapGoing() {
        onGoingTap?()
    }

    @objc private func didTapNotGoing() {
        onNotGoingTap?()
    }

    @objc private func didTapCancel() {
        onCancelTap?()
    }
}

private actor MeetingImageLoader {
    static let shared = MeetingImageLoader()

    private let cache = NSCache<NSString, UIImage>()
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = .shared
        session = URLSession(configuration: configuration)
        cache.countLimit = 120
    }

    func loadImage(from rawURL: String, targetSize: CGSize) async -> UIImage? {
        let cacheKey = "\(rawURL)-\(Int(targetSize.width))x\(Int(targetSize.height))" as NSString
        if let cachedImage = cache.object(forKey: cacheKey) {
            return cachedImage
        }

        guard let resolvedURL = resolvedURL(from: rawURL) else {
            return nil
        }

        var request = URLRequest(url: resolvedURL)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 30

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let image = downsampleImage(data: data, targetSize: targetSize) else {
                return nil
            }

            cache.setObject(image, forKey: cacheKey)
            return image
        } catch {
            return nil
        }
    }

    private func resolvedURL(from rawURL: String) -> URL? {
        if let absoluteURL = URL(string: rawURL), absoluteURL.scheme != nil {
            return absoluteURL
        }

        guard let baseURL = URL(string: Server.url) else {
            return nil
        }

        return baseURL.appendingPathComponent(rawURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }

    private func downsampleImage(data: Data, targetSize: CGSize) -> UIImage? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, options) else {
            return nil
        }

        let maxPixelSize = Int(max(targetSize.width, targetSize.height) * UIScreen.main.scale)
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}
