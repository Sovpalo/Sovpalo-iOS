//
//  MemberCell.swift
//  Sovpalo
//
//  Created by Jovana on 24.3.26.
//

import UIKit
import ImageIO

final class MemberCell: UITableViewCell {
    static let reuseID = "MemberCell"

    private let avatarView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 20
        view.backgroundColor = UIColor.systemGray5
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let avatarShimmerView: ShimmerView = {
        let view = ShimmerView()
        view.backgroundColor = UIColor.systemGray5
        view.layer.cornerRadius = 20
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private let avatarLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let ownerImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "star.fill"))
        imageView.tintColor = .systemYellow
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private var imageLoadTask: Task<Void, Never>?
    private var currentAvatarURL: String?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageLoadTask?.cancel()
        imageLoadTask = nil
        currentAvatarURL = nil
        avatarImageView.image = nil
        avatarLabel.isHidden = false
        avatarShimmerView.stopAnimating()
        avatarShimmerView.isHidden = true
    }

    private func setupUI() {
        avatarView.addSubview(avatarImageView)
        avatarView.addSubview(avatarShimmerView)
        avatarView.addSubview(avatarLabel)
        contentView.addSubview(avatarView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(ownerImageView)

        NSLayoutConstraint.activate([
            avatarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            avatarView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 40),
            avatarView.heightAnchor.constraint(equalToConstant: 40),

            avatarImageView.topAnchor.constraint(equalTo: avatarView.topAnchor),
            avatarImageView.leadingAnchor.constraint(equalTo: avatarView.leadingAnchor),
            avatarImageView.trailingAnchor.constraint(equalTo: avatarView.trailingAnchor),
            avatarImageView.bottomAnchor.constraint(equalTo: avatarView.bottomAnchor),

            avatarShimmerView.topAnchor.constraint(equalTo: avatarView.topAnchor),
            avatarShimmerView.leadingAnchor.constraint(equalTo: avatarView.leadingAnchor),
            avatarShimmerView.trailingAnchor.constraint(equalTo: avatarView.trailingAnchor),
            avatarShimmerView.bottomAnchor.constraint(equalTo: avatarView.bottomAnchor),

            avatarLabel.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            avatarLabel.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),

            nameLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: ownerImageView.leadingAnchor, constant: -12),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            ownerImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            ownerImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            ownerImageView.widthAnchor.constraint(equalToConstant: 16),
            ownerImageView.heightAnchor.constraint(equalToConstant: 16)
        ])
    }

    func configure(with member: GroupMembersModels.MemberViewModel) {
        nameLabel.text = member.name
        avatarLabel.text = member.avatarLetter
        ownerImageView.isHidden = !member.isOwner
        avatarView.backgroundColor = .systemGray5

        imageLoadTask?.cancel()
        imageLoadTask = nil
        currentAvatarURL = member.avatarURL
        avatarImageView.image = nil
        avatarLabel.isHidden = false
        avatarShimmerView.stopAnimating()
        avatarShimmerView.isHidden = true

        guard let avatarURL = member.avatarURL, !avatarURL.isEmpty else {
            return
        }

        startAvatarLoading()
        imageLoadTask = Task { [weak self] in
            guard let self else { return }
            let image = await MemberAvatarLoader.shared.loadImage(from: avatarURL, targetSize: CGSize(width: 40, height: 40))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard self.currentAvatarURL == avatarURL else { return }
                self.finishAvatarLoading(with: image)
            }
        }
    }

    private func startAvatarLoading() {
        avatarShimmerView.isHidden = false
        avatarShimmerView.startAnimating()
        avatarLabel.isHidden = true
    }

    private func finishAvatarLoading(with image: UIImage?) {
        avatarShimmerView.stopAnimating()
        avatarShimmerView.isHidden = true

        if let image {
            avatarImageView.image = image
            avatarLabel.isHidden = true
        } else {
            avatarImageView.image = nil
            avatarLabel.isHidden = false
        }
    }
}

private actor MemberAvatarLoader {
    static let shared = MemberAvatarLoader()

    private let cache = NSCache<NSString, UIImage>()
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = .shared
        self.session = URLSession(configuration: configuration)
        cache.countLimit = 150
    }

    func loadImage(from rawURL: String, targetSize: CGSize) async -> UIImage? {
        let cacheKey = "\(rawURL)-\(Int(targetSize.width))x\(Int(targetSize.height))" as NSString
        if let image = cache.object(forKey: cacheKey) {
            return image
        }

        guard let url = resolvedURL(from: rawURL) else {
            return nil
        }

        var request = URLRequest(url: url)
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
