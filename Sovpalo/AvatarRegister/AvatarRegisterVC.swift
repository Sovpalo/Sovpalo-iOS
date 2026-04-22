//
//  AvatarRegisterVC.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 22.04.2026.
//

import UIKit
import PhotosUI
import ImageIO
import UniformTypeIdentifiers

final class AvatarRegisterVC: UIViewController {
    private var interactor: AvatarRegisterBusinessLogic?

    private var selectedImageData: Data?
    private let selectedImageMimeType = "image/jpeg"
    private let selectedImageFileName = "avatar.jpg"
    private var cropController: AvatarImageCropViewController?

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let heroCard = UIView()
    private let accentCircle = UIView()
    private let accentPill = UIView()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Добавь фото профиля"
        label.font = .systemFont(ofSize: 34, weight: .bold)
        label.textColor = .label
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Так тебя будет проще узнать в группе и на экранах встреч. Можно пропустить и сделать это позже."
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    private lazy var avatarButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .white
        button.layer.cornerRadius = 80
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.10
        button.layer.shadowRadius = 18
        button.layer.shadowOffset = CGSize(width: 0, height: 10)
        button.layer.borderWidth = 5
        button.layer.borderColor = UIColor(hex: "#FCFF91")?.cgColor
        button.clipsToBounds = false
        button.addTarget(self, action: #selector(didTapSelectPhoto), for: .touchUpInside)
        return button
    }()

    private let avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.backgroundColor = UIColor(hex: "#EEF1FF")
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 72
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = false
        return imageView
    }()

    private let avatarPlaceholderIcon: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "camera.fill"))
        imageView.tintColor = UIColor(hex: "#7079FB")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let avatarPlaceholderLabel: UILabel = {
        let label = UILabel()
        label.text = "Нажми, чтобы выбрать фото"
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = UIColor(hex: "#7079FB")
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }()

    private let helperLabel: UILabel = {
        let label = UILabel()
        label.text = "Подойдёт квадратное или вертикальное фото. Мы автоматически покажем его в круге."
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    private let selectedBadgeView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hex: "#7079FB")
        view.layer.cornerRadius = 18
        view.layer.borderWidth = 3
        view.layer.borderColor = UIColor.white.cgColor
        view.isHidden = true
        return view
    }()

    private let selectedBadgeIcon: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "checkmark"))
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let bottomContainer = UIView()

    private lazy var skipButton: UIButton = {
        let button = UIButton(type: .system)
        var config = UIButton.Configuration.plain()
        config.title = "Пропустить"
        config.baseForegroundColor = .white
        config.contentInsets = .init(top: 16, leading: 16, bottom: 16, trailing: 16)
        button.configuration = config
        button.addTarget(self, action: #selector(didTapSkip), for: .touchUpInside)
        return button
    }()

    private lazy var uploadButton: UIButton = {
        let button = UIButton(type: .system)
        var config = UIButton.Configuration.plain()
        config.title = "Загрузить"
        config.baseForegroundColor = .white
        config.contentInsets = .init(top: 16, leading: 16, bottom: 16, trailing: 16)
        button.configuration = config
        button.alpha = 0
        button.isHidden = true
        button.addTarget(self, action: #selector(didTapUpload), for: .touchUpInside)
        return button
    }()

    private let dividerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.25)
        view.isHidden = true
        return view
    }()

    init(interactor: AvatarRegisterBusinessLogic? = nil) {
        self.interactor = interactor
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        navigationItem.hidesBackButton = true
        setupLayout()
    }

    func setUploadLoading(_ isLoading: Bool) {
        avatarButton.isEnabled = !isLoading
        skipButton.isEnabled = !isLoading
        uploadButton.isEnabled = !isLoading && selectedImageData != nil

        avatarButton.alpha = isLoading ? 0.8 : 1
        skipButton.alpha = isLoading ? 0.55 : 1
        uploadButton.alpha = isLoading ? 0.55 : (selectedImageData == nil ? 0 : 1)
        dividerView.alpha = isLoading ? 0.25 : 1
    }

    func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "Ошибка", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    func navigateToFirstGroup() {
        let firstGroupVC = FirstGroupAssembly.assembly()
        navigationController?.setViewControllers([firstGroupVC], animated: true)
    }

    private func setupLayout() {
        [scrollView, bottomContainer].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        heroCard.translatesAutoresizingMaskIntoConstraints = false
        heroCard.backgroundColor = .white
        heroCard.layer.cornerRadius = 30
        heroCard.layer.shadowColor = UIColor.black.cgColor
        heroCard.layer.shadowOpacity = 0.07
        heroCard.layer.shadowRadius = 20
        heroCard.layer.shadowOffset = CGSize(width: 0, height: 12)
        contentView.addSubview(heroCard)

        accentCircle.translatesAutoresizingMaskIntoConstraints = false
        accentCircle.backgroundColor = UIColor(hex: "#F6F7FF")
        accentCircle.layer.cornerRadius = 44
        heroCard.addSubview(accentCircle)

        accentPill.translatesAutoresizingMaskIntoConstraints = false
        accentPill.backgroundColor = UIColor(hex: "#FCFF91")?.withAlphaComponent(0.95)
        accentPill.layer.cornerRadius = 12
        heroCard.addSubview(accentPill)

        [titleLabel, subtitleLabel, helperLabel, avatarButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            heroCard.addSubview($0)
        }

        [avatarImageView, avatarPlaceholderIcon, avatarPlaceholderLabel, selectedBadgeView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            avatarButton.addSubview($0)
        }

        selectedBadgeIcon.translatesAutoresizingMaskIntoConstraints = false
        selectedBadgeView.addSubview(selectedBadgeIcon)

        bottomContainer.backgroundColor = UIColor(hex: "#7079FB")
        bottomContainer.layer.cornerRadius = 22

        let buttonsStack = UIStackView(arrangedSubviews: [skipButton, uploadButton])
        buttonsStack.axis = .horizontal
        buttonsStack.alignment = .fill
        buttonsStack.distribution = .fillEqually
        buttonsStack.translatesAutoresizingMaskIntoConstraints = false
        dividerView.translatesAutoresizingMaskIntoConstraints = false

        bottomContainer.addSubview(buttonsStack)
        bottomContainer.addSubview(dividerView)

        NSLayoutConstraint.activate([
            heroCard.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            heroCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            heroCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            accentCircle.widthAnchor.constraint(equalToConstant: 88),
            accentCircle.heightAnchor.constraint(equalToConstant: 88),
            accentCircle.topAnchor.constraint(equalTo: heroCard.topAnchor, constant: 22),
            accentCircle.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -24),

            accentPill.widthAnchor.constraint(equalToConstant: 72),
            accentPill.heightAnchor.constraint(equalToConstant: 24),
            accentPill.topAnchor.constraint(equalTo: heroCard.topAnchor, constant: 48),
            accentPill.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 28),

            titleLabel.topAnchor.constraint(equalTo: heroCard.topAnchor, constant: 40),
            titleLabel.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -24),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -24),

            avatarButton.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 28),
            avatarButton.centerXAnchor.constraint(equalTo: heroCard.centerXAnchor),
            avatarButton.widthAnchor.constraint(equalToConstant: 160),
            avatarButton.heightAnchor.constraint(equalToConstant: 160),

            avatarImageView.centerXAnchor.constraint(equalTo: avatarButton.centerXAnchor),
            avatarImageView.centerYAnchor.constraint(equalTo: avatarButton.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 144),
            avatarImageView.heightAnchor.constraint(equalToConstant: 144),

            avatarPlaceholderIcon.centerXAnchor.constraint(equalTo: avatarButton.centerXAnchor),
            avatarPlaceholderIcon.centerYAnchor.constraint(equalTo: avatarButton.centerYAnchor, constant: -16),
            avatarPlaceholderIcon.widthAnchor.constraint(equalToConstant: 32),
            avatarPlaceholderIcon.heightAnchor.constraint(equalToConstant: 32),

            avatarPlaceholderLabel.leadingAnchor.constraint(equalTo: avatarButton.leadingAnchor, constant: 18),
            avatarPlaceholderLabel.trailingAnchor.constraint(equalTo: avatarButton.trailingAnchor, constant: -18),
            avatarPlaceholderLabel.topAnchor.constraint(equalTo: avatarPlaceholderIcon.bottomAnchor, constant: 10),

            selectedBadgeView.widthAnchor.constraint(equalToConstant: 36),
            selectedBadgeView.heightAnchor.constraint(equalToConstant: 36),
            selectedBadgeView.trailingAnchor.constraint(equalTo: avatarButton.trailingAnchor, constant: -8),
            selectedBadgeView.bottomAnchor.constraint(equalTo: avatarButton.bottomAnchor, constant: -8),

            selectedBadgeIcon.centerXAnchor.constraint(equalTo: selectedBadgeView.centerXAnchor),
            selectedBadgeIcon.centerYAnchor.constraint(equalTo: selectedBadgeView.centerYAnchor),
            selectedBadgeIcon.widthAnchor.constraint(equalToConstant: 16),
            selectedBadgeIcon.heightAnchor.constraint(equalToConstant: 16),

            helperLabel.topAnchor.constraint(equalTo: avatarButton.bottomAnchor, constant: 20),
            helperLabel.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 24),
            helperLabel.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -24),
            helperLabel.bottomAnchor.constraint(equalTo: heroCard.bottomAnchor, constant: -30),

            bottomContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            bottomContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            bottomContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            bottomContainer.heightAnchor.constraint(equalToConstant: 64),

            buttonsStack.topAnchor.constraint(equalTo: bottomContainer.topAnchor),
            buttonsStack.leadingAnchor.constraint(equalTo: bottomContainer.leadingAnchor),
            buttonsStack.trailingAnchor.constraint(equalTo: bottomContainer.trailingAnchor),
            buttonsStack.bottomAnchor.constraint(equalTo: bottomContainer.bottomAnchor),

            dividerView.centerXAnchor.constraint(equalTo: bottomContainer.centerXAnchor),
            dividerView.topAnchor.constraint(equalTo: bottomContainer.topAnchor, constant: 12),
            dividerView.bottomAnchor.constraint(equalTo: bottomContainer.bottomAnchor, constant: -12),
            dividerView.widthAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),

            contentView.bottomAnchor.constraint(equalTo: heroCard.bottomAnchor, constant: 120)
        ])
    }

    private func applySelectedImage(uploadData: Data, previewImage: UIImage) {
        print("[AvatarRegisterVC] Prepared avatar payload: fileName=\(selectedImageFileName), mimeType=\(selectedImageMimeType), size=\(uploadData.count) bytes")

        selectedImageData = uploadData
        avatarImageView.image = previewImage
        avatarPlaceholderIcon.isHidden = true
        avatarPlaceholderLabel.isHidden = true
        selectedBadgeView.isHidden = false
        helperLabel.text = "Фото выбрано. Если всё нравится, нажми «Загрузить»."

        uploadButton.isHidden = false
        dividerView.isHidden = false
        UIView.animate(withDuration: 0.2) {
            self.uploadButton.alpha = 1
            self.dividerView.alpha = 1
        }
    }

    private func handleSelectedImageData(_ data: Data, sourceLabel: String) {
        print("[AvatarRegisterVC] Received raw image data from \(sourceLabel): size=\(data.count) bytes")

        guard let image = makeEditingImage(from: data) else {
            print("[AvatarRegisterVC] Failed to decode editable image from \(sourceLabel)")
            showErrorAlert(message: "Не удалось подготовить фото")
            return
        }

        presentCropEditor(with: image)
    }

    @objc private func didTapSelectPhoto() {
        let alert = UIAlertController(title: "Фото профиля", message: "Выбери, как добавить фото", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Сделать фото", style: .default) { [weak self] _ in
            self?.presentCamera()
        })
        alert.addAction(UIAlertAction(title: "Выбрать из галереи", style: .default) { [weak self] _ in
            self?.presentPhotoLibrary()
        })
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = avatarButton
            popover.sourceRect = avatarButton.bounds
        }

        present(alert, animated: true)
    }

    private func presentPhotoLibrary() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        print("[AvatarRegisterVC] Presenting photo library picker")
        present(picker, animated: true)
    }

    private func presentCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            print("[AvatarRegisterVC] Camera is not available on this device")
            showErrorAlert(message: "Камера недоступна на этом устройстве")
            return
        }

        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .camera
        picker.cameraDevice = .front
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        print("[AvatarRegisterVC] Presenting camera picker")
        present(picker, animated: true)
    }

    @objc private func didTapSkip() {
        interactor?.skipAvatarUpload()
    }

    @objc private func didTapUpload() {
        guard let selectedImageData else { return }
        interactor?.uploadAvatar(
            imageData: selectedImageData,
            fileName: selectedImageFileName,
            mimeType: selectedImageMimeType
        )
    }

    private func makeAvatarPayload(from data: Data) -> (uploadData: Data, previewImage: UIImage)? {
        guard let image = makeEditingImage(from: data) else {
            return nil
        }

        return makeAvatarPayload(from: image)
    }

    private func makeAvatarPayload(from image: UIImage) -> (uploadData: Data, previewImage: UIImage)? {
        let previewMaxDimension = Int(max(avatarImageView.bounds.width, avatarImageView.bounds.height, 144) * UIScreen.main.scale)
        let previewImage = makePreviewImage(from: image, maxPixelSize: max(previewMaxDimension, 144)) ?? image
        guard let uploadData = compressJPEG(image) else { return nil }

        return (uploadData: uploadData, previewImage: previewImage)
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

    private func makePreviewImage(from image: UIImage, maxPixelSize: Int) -> UIImage? {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return nil }
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, options) else {
            return nil
        }

        let previewOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, previewOptions) else {
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

    private func presentCropEditor(with image: UIImage) {
        let cropController = AvatarImageCropViewController(image: image) { [weak self] croppedImage in
            guard let self else { return }

            guard let processed = self.makeAvatarPayload(from: croppedImage) else {
                print("[AvatarRegisterVC] Failed to prepare cropped avatar payload")
                self.showErrorAlert(message: "Не удалось подготовить обрезанное фото")
                return
            }

            self.applySelectedImage(uploadData: processed.uploadData, previewImage: processed.previewImage)
        }

        self.cropController = cropController
        cropController.modalPresentationStyle = .fullScreen
        present(cropController, animated: true)
    }
}

extension AvatarRegisterVC: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let result = results.first else {
            print("[AvatarRegisterVC] Picker finished without selecting an image")
            return
        }

        let provider = result.itemProvider
        let typeIdentifier = UTType.image.identifier
        print("[AvatarRegisterVC] Loading picked image data, typeIdentifier=\(typeIdentifier)")

        provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { [weak self] data, error in
            guard let self else { return }

            if let error {
                print("[AvatarRegisterVC] Failed to load image data representation: \(error)")
                DispatchQueue.main.async {
                    self.loadImageObjectFallback(from: provider)
                }
                return
            }

            guard let data else {
                print("[AvatarRegisterVC] Image data representation is nil")
                DispatchQueue.main.async {
                    self.loadImageObjectFallback(from: provider)
                }
                return
            }

            DispatchQueue.main.async {
                self.handleSelectedImageData(data, sourceLabel: "photo library")
            }
        }
    }

    private func loadImageObjectFallback(from provider: NSItemProvider) {
        guard provider.canLoadObject(ofClass: UIImage.self) else {
            print("[AvatarRegisterVC] Fallback to UIImage loading is unavailable")
            showErrorAlert(message: "Не удалось прочитать выбранный файл")
            return
        }

        print("[AvatarRegisterVC] Falling back to UIImage object loading")
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            guard let self else { return }

            if let error {
                print("[AvatarRegisterVC] UIImage fallback loading failed: \(error)")
                DispatchQueue.main.async {
                    self.showErrorAlert(message: "Не удалось прочитать выбранный файл")
                }
                return
            }

            guard let image = object as? UIImage, let data = image.jpegData(compressionQuality: 0.95) else {
                print("[AvatarRegisterVC] UIImage fallback returned invalid object")
                DispatchQueue.main.async {
                    self.showErrorAlert(message: "Не удалось подготовить выбранное фото")
                }
                return
            }

            DispatchQueue.main.async {
                self.handleSelectedImageData(data, sourceLabel: "photo library fallback")
            }
        }
    }
}

extension AvatarRegisterVC: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        print("[AvatarRegisterVC] Camera picker cancelled")
        picker.dismiss(animated: true)
    }

    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage
        picker.dismiss(animated: true) { [weak self] in
            guard let self else { return }
            guard let image else {
                print("[AvatarRegisterVC] Camera picker returned without image")
                self.showErrorAlert(message: "Не удалось получить фото с камеры")
                return
            }

            guard let imageData = image.jpegData(compressionQuality: 0.95) else {
                print("[AvatarRegisterVC] Failed to serialize captured image")
                self.showErrorAlert(message: "Не удалось подготовить фото с камеры")
                return
            }

            print("[AvatarRegisterVC] Captured raw image from camera: size=\(imageData.count) bytes")
            self.handleSelectedImageData(imageData, sourceLabel: "camera")
        }
    }
}
