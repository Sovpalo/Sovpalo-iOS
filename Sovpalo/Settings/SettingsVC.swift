//
//  SettingsVC.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 01.04.2026.
//

import UIKit
import PhotosUI
import ImageIO
import UniformTypeIdentifiers

final class SettingsVC: UIViewController {
    var interactor: SettingsBusinessLogic?
    private var isProfileLoading = true

    private lazy var nameContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 24
        view.layer.shadowColor = UIColor.black.withAlphaComponent(0.08).cgColor
        view.layer.shadowOpacity = 1
        view.layer.shadowRadius = 16
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        return view
    }()

    private lazy var avatarButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = UIColor(hex: "#EEF1FF")
        button.layer.cornerRadius = 38
        button.layer.borderWidth = 3
        button.layer.borderColor = UIColor(hex: "#FCFF91")?.cgColor
        button.clipsToBounds = true
        button.addTarget(self, action: #selector(avatarTapped), for: .touchUpInside)
        return button
    }()

    private let avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()

    private let avatarPlaceholderLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 28, weight: .semibold)
        label.textColor = UIColor(hex: "#7079FB")
        label.textAlignment = .center
        label.text = "?"
        return label
    }()

    private lazy var usernameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 30, weight: .bold)
        label.textColor = .label
        label.text = "..."
        label.numberOfLines = 2
        return label
    }()

    private lazy var avatarHintButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.title = "Изменить фото"
        configuration.image = UIImage(systemName: "chevron.right")
        configuration.imagePlacement = .trailing
        configuration.imagePadding = 6
        configuration.baseForegroundColor = .secondaryLabel
        configuration.contentInsets = .zero

        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.configuration = configuration
        button.contentHorizontalAlignment = .leading
        button.addTarget(self, action: #selector(avatarTapped), for: .touchUpInside)
        return button
    }()

    private let avatarShimmerView: ShimmerView = {
        let view = ShimmerView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.systemGray5
        view.layer.cornerRadius = 38
        view.clipsToBounds = true
        return view
    }()

    private let usernameShimmerView: ShimmerView = {
        let view = ShimmerView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.systemGray5
        view.layer.cornerRadius = 11
        view.clipsToBounds = true
        return view
    }()

    private let subtitleShimmerView: ShimmerView = {
        let view = ShimmerView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.systemGray5
        view.layer.cornerRadius = 9
        view.clipsToBounds = true
        return view
    }()

    private lazy var policyStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [
            makeActionButton(title: "Политика использования", action: #selector(termsTapped)),
            makeDivider(),
            makeActionButton(title: "Политика конфиденциальности", action: #selector(privacyTapped))
        ])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.backgroundColor = .systemBackground
        stackView.layer.cornerRadius = 20
        stackView.layer.shadowColor = UIColor.black.withAlphaComponent(0.08).cgColor
        stackView.layer.shadowOpacity = 1
        stackView.layer.shadowRadius = 16
        stackView.layer.shadowOffset = CGSize(width: 0, height: 4)
        stackView.clipsToBounds = false
        return stackView
    }()

    private lazy var logoutButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Выйти из аккаунта", for: .normal)
        button.setTitleColor(.systemRed, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        button.backgroundColor = .systemBackground
        button.layer.cornerRadius = 14
        button.layer.shadowColor = UIColor.black.withAlphaComponent(0.08).cgColor
        button.layer.shadowOpacity = 1
        button.layer.shadowRadius = 16
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.addTarget(self, action: #selector(logoutTapped), for: .touchUpInside)
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupLayout()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        (tabBarController as? MainTabBarController)?.setCustomTabBarHidden(true, animated: animated)
        interactor?.loadProfile()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        (tabBarController as? MainTabBarController)?.setCustomTabBarHidden(false, animated: animated)
    }

    func display(username: String, avatarData: Data?) {
        usernameLabel.text = username
        avatarPlaceholderLabel.text = String(username.prefix(1)).uppercased()

        if let avatarData, let image = makeDisplayAvatarImage(from: avatarData) {
            avatarImageView.image = image
            avatarPlaceholderLabel.isHidden = true
        } else {
            avatarImageView.image = nil
            avatarPlaceholderLabel.isHidden = false
        }
    }

    func setProfileLoading(_ isLoading: Bool) {
        isProfileLoading = isLoading

        avatarShimmerView.isHidden = !isLoading
        usernameShimmerView.isHidden = !isLoading
        subtitleShimmerView.isHidden = !isLoading

        avatarButton.alpha = isLoading ? 0.001 : 1
        usernameLabel.alpha = isLoading ? 0.001 : 1
        avatarHintButton.alpha = isLoading ? 0.001 : 1

        if isLoading {
            avatarShimmerView.startAnimating()
            usernameShimmerView.startAnimating()
            subtitleShimmerView.startAnimating()
        } else {
            avatarShimmerView.stopAnimating()
            usernameShimmerView.stopAnimating()
            subtitleShimmerView.stopAnimating()
        }
    }

    func setAvatarUpdating(_ isUpdating: Bool) {
        avatarButton.isEnabled = !isUpdating && !isProfileLoading
        avatarHintButton.isEnabled = !isUpdating && !isProfileLoading
        avatarButton.alpha = isUpdating ? 0.65 : (isProfileLoading ? 0.001 : 1)
        avatarHintButton.alpha = isUpdating ? 0.55 : (isProfileLoading ? 0.001 : 1)
    }

    func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "Ошибка", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func setupView() {
        view.backgroundColor = .systemGroupedBackground
        title = "Настройки"
        navigationItem.largeTitleDisplayMode = .never
    }

    private func setupLayout() {
        view.addSubview(nameContainerView)
        view.addSubview(policyStackView)
        view.addSubview(logoutButton)

        [avatarButton, usernameLabel, avatarHintButton].forEach {
            nameContainerView.addSubview($0)
        }
        [avatarShimmerView, avatarImageView, avatarPlaceholderLabel].forEach {
            avatarButton.addSubview($0)
        }
        [usernameShimmerView, subtitleShimmerView].forEach {
            nameContainerView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            nameContainerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            nameContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            nameContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            avatarButton.topAnchor.constraint(equalTo: nameContainerView.topAnchor, constant: 18),
            avatarButton.leadingAnchor.constraint(equalTo: nameContainerView.leadingAnchor, constant: 18),
            avatarButton.bottomAnchor.constraint(equalTo: nameContainerView.bottomAnchor, constant: -18),
            avatarButton.widthAnchor.constraint(equalToConstant: 76),
            avatarButton.heightAnchor.constraint(equalToConstant: 76),

            avatarImageView.topAnchor.constraint(equalTo: avatarButton.topAnchor),
            avatarImageView.leadingAnchor.constraint(equalTo: avatarButton.leadingAnchor),
            avatarImageView.trailingAnchor.constraint(equalTo: avatarButton.trailingAnchor),
            avatarImageView.bottomAnchor.constraint(equalTo: avatarButton.bottomAnchor),

            avatarShimmerView.topAnchor.constraint(equalTo: avatarButton.topAnchor),
            avatarShimmerView.leadingAnchor.constraint(equalTo: avatarButton.leadingAnchor),
            avatarShimmerView.trailingAnchor.constraint(equalTo: avatarButton.trailingAnchor),
            avatarShimmerView.bottomAnchor.constraint(equalTo: avatarButton.bottomAnchor),

            avatarPlaceholderLabel.centerXAnchor.constraint(equalTo: avatarButton.centerXAnchor),
            avatarPlaceholderLabel.centerYAnchor.constraint(equalTo: avatarButton.centerYAnchor),

            usernameLabel.topAnchor.constraint(equalTo: nameContainerView.topAnchor, constant: 22),
            usernameLabel.leadingAnchor.constraint(equalTo: avatarButton.trailingAnchor, constant: 18),
            usernameLabel.trailingAnchor.constraint(equalTo: nameContainerView.trailingAnchor, constant: -18),

            usernameShimmerView.topAnchor.constraint(equalTo: usernameLabel.topAnchor, constant: 6),
            usernameShimmerView.leadingAnchor.constraint(equalTo: usernameLabel.leadingAnchor),
            usernameShimmerView.widthAnchor.constraint(equalToConstant: 168),
            usernameShimmerView.heightAnchor.constraint(equalToConstant: 22),

            avatarHintButton.topAnchor.constraint(equalTo: usernameLabel.bottomAnchor, constant: 6),
            avatarHintButton.leadingAnchor.constraint(equalTo: usernameLabel.leadingAnchor),
            avatarHintButton.trailingAnchor.constraint(lessThanOrEqualTo: nameContainerView.trailingAnchor, constant: -18),
            avatarHintButton.bottomAnchor.constraint(lessThanOrEqualTo: nameContainerView.bottomAnchor, constant: -20),

            subtitleShimmerView.topAnchor.constraint(equalTo: avatarHintButton.topAnchor, constant: 8),
            subtitleShimmerView.leadingAnchor.constraint(equalTo: avatarHintButton.leadingAnchor),
            subtitleShimmerView.widthAnchor.constraint(equalToConstant: 124),
            subtitleShimmerView.heightAnchor.constraint(equalToConstant: 18),

            policyStackView.topAnchor.constraint(equalTo: nameContainerView.bottomAnchor, constant: 16),
            policyStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            policyStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            logoutButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            logoutButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            logoutButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            logoutButton.heightAnchor.constraint(equalToConstant: 52)
        ])

        setProfileLoading(true)
    }

    private func makeActionButton(title: String, action: Selector) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.title = title
        config.baseForegroundColor = .label
        config.image = UIImage(systemName: "chevron.right")
        config.imagePlacement = .trailing
        config.imagePadding = 8
        config.contentInsets = NSDirectionalEdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18)

        let button = UIButton(configuration: config, primaryAction: nil)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.contentHorizontalAlignment = .fill
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .regular)
        button.tintColor = .tertiaryLabel
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func makeDivider() -> UIView {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .separator
        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale)
        ])
        return view
    }

    @objc private func termsTapped() {}

    @objc private func privacyTapped() {}

    @objc private func avatarTapped() {
        let alert = UIAlertController(title: "Фото профиля", message: "Что хочешь сделать?", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Выбрать из галереи", style: .default) { [weak self] _ in
            self?.presentPhotoLibrary()
        })
        alert.addAction(UIAlertAction(title: "Сфотографировать", style: .default) { [weak self] _ in
            self?.presentCamera()
        })
        if avatarImageView.image != nil {
            alert.addAction(UIAlertAction(title: "Удалить фото", style: .destructive) { [weak self] _ in
                self?.interactor?.deleteAvatar()
            })
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = avatarButton
            popover.sourceRect = avatarButton.bounds
        }

        present(alert, animated: true)
    }

    @objc private func logoutTapped() {
        let alert = UIAlertController(
            title: "Выход из аккаунта",
            message: "Вы точно хотите выйти из аккаунта?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(
            UIAlertAction(title: "Выйти", style: .destructive) { [weak self] _ in
                self?.interactor?.logout()
            }
        )
        present(alert, animated: true)
    }

    private func presentPhotoLibrary() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func presentCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showErrorAlert(message: "Камера недоступна на этом устройстве")
            return
        }

        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .camera
        picker.cameraDevice = .front
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        present(picker, animated: true)
    }

    private func handleSelectedImageData(_ data: Data) {
        guard let image = makeEditingImage(from: data) else {
            showErrorAlert(message: "Не удалось подготовить фото")
            return
        }

        let cropController = AvatarImageCropViewController(image: image) { [weak self] croppedImage in
            guard let self else { return }
            guard let uploadData = compressJPEG(croppedImage) else {
                self.showErrorAlert(message: "Не удалось подготовить обрезанное фото")
                return
            }

            self.interactor?.uploadAvatar(
                imageData: uploadData,
                fileName: "avatar.jpg",
                mimeType: "image/jpeg"
            )
        }

        cropController.modalPresentationStyle = .fullScreen
        present(cropController, animated: true)
    }

    private func makeEditingImage(from data: Data) -> UIImage? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, options) else {
            return nil
        }

        let decodeOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 2200
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, decodeOptions) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    private func makeDisplayAvatarImage(from data: Data) -> UIImage? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, options) else {
            return nil
        }

        let maxPixelSize = Int(ceil(76 * UIScreen.main.scale))
        let decodeOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, decodeOptions) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    private func compressJPEG(_ image: UIImage) -> Data? {
        var quality: CGFloat = 0.9
        let targetLimit = 4_800_000

        while quality >= 0.45 {
            if let data = image.jpegData(compressionQuality: quality), data.count <= targetLimit {
                return data
            }
            quality -= 0.1
        }

        return image.jpegData(compressionQuality: 0.35)
    }
}

extension SettingsVC: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let result = results.first else { return }
        let provider = result.itemProvider

        provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] data, error in
            guard let self else { return }

            if error != nil || data == nil {
                DispatchQueue.main.async {
                    self.loadImageObjectFallback(from: provider)
                }
                return
            }

            guard let data else {
                DispatchQueue.main.async {
                    self.showErrorAlert(message: "Не удалось прочитать выбранный файл")
                }
                return
            }

            DispatchQueue.main.async {
                self.handleSelectedImageData(data)
            }
        }
    }

    private func loadImageObjectFallback(from provider: NSItemProvider) {
        guard provider.canLoadObject(ofClass: UIImage.self) else {
            DispatchQueue.main.async {
                self.showErrorAlert(message: "Не удалось прочитать выбранный файл")
            }
            return
        }

        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let self else { return }
            guard let image = object as? UIImage, let data = image.jpegData(compressionQuality: 0.95) else {
                DispatchQueue.main.async {
                    self.showErrorAlert(message: "Не удалось подготовить выбранное фото")
                }
                return
            }

            DispatchQueue.main.async {
                self.handleSelectedImageData(data)
            }
        }
    }
}

extension SettingsVC: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage
        picker.dismiss(animated: true) { [weak self] in
            guard let self else { return }
            guard let image, let imageData = image.jpegData(compressionQuality: 0.95) else {
                self.showErrorAlert(message: "Не удалось получить фото с камеры")
                return
            }

            self.handleSelectedImageData(imageData)
        }
    }
}
