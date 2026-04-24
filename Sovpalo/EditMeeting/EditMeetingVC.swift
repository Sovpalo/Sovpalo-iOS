//
//  EditMeetingVC.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 25.03.2026.
//

import UIKit
import PhotosUI
import ImageIO
import UniformTypeIdentifiers

final class EditMeetingVC: UIViewController {
    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let photoPreviewImageView = UIImageView()
    private let uploadPhotoButton = UIButton(type: .system)
    private let photoLimitLabel = UILabel()

    private let placeField = UITextField()
    private let startDateField = UITextField()
    private let endDateField = UITextField()
    private let startTimeField = UITextField()
    private let endTimeField = UITextField()
    private let addressField = UITextField()
    private let descriptionField = UITextField()
    private let doneButton = UIButton(type: .system)

    private let startDatePicker = UIDatePicker()
    private let endDatePicker = UIDatePicker()
    private let startTimePicker = UIDatePicker()
    private let endTimePicker = UIDatePicker()

    private var selectedStartDate: Date?
    private var selectedEndDate: Date?
    private var selectedStartTime: Date?
    private var selectedEndTime: Date?
    private var selectedPhoto: EditMeetingPhotoUpload?
    private var currentPhotoURL: String?
    private var shouldRemovePhoto = false
    private var imageLoadTask: Task<Void, Never>?

    var interactor: EditMeetingBusinessLogic?

    override func viewDidLoad() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)

        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "Редактировать встречу"
        navigationItem.largeTitleDisplayMode = .never
        setupUI()
        setupPickers()
        setupActions()
        interactor?.loadInitialData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(notification:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(notification:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(
            self,
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    func applyInitialData(_ viewModel: EditMeetingPrefillViewModel) {
        placeField.text = viewModel.title
        startDateField.text = viewModel.startDateText
        endDateField.text = viewModel.endDateText
        startTimeField.text = viewModel.startTimeText
        endTimeField.text = viewModel.endTimeText
        addressField.text = viewModel.address
        descriptionField.text = viewModel.description

        selectedStartDate = viewModel.startDate
        selectedEndDate = viewModel.endDate
        selectedStartTime = viewModel.startDate
        selectedEndTime = viewModel.endDate
        startDatePicker.date = viewModel.startDate
        endDatePicker.date = viewModel.endDate
        startTimePicker.date = viewModel.startDate
        endTimePicker.date = viewModel.endDate

        currentPhotoURL = viewModel.photoURL
        shouldRemovePhoto = false
        selectedPhoto = nil
        loadExistingPhotoIfNeeded()
    }

    func showError(message: String) {
        let alert = UIAlertController(title: "Ошибка", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "ОК", style: .default))
        present(alert, animated: true)
    }

    func showSuccessAndClose() {
        navigationController?.popViewController(animated: true)
    }

    private func setupUI() {
        photoPreviewImageView.translatesAutoresizingMaskIntoConstraints = false
        photoPreviewImageView.contentMode = .scaleAspectFill
        photoPreviewImageView.clipsToBounds = true
        photoPreviewImageView.layer.cornerRadius = 34
        photoPreviewImageView.backgroundColor = .secondarySystemGroupedBackground
        photoPreviewImageView.isHidden = true

        var uploadConfig = UIButton.Configuration.plain()
        uploadConfig.title = "Загрузить изображение"
        uploadConfig.image = UIImage(systemName: "square.and.arrow.up")
        uploadConfig.imagePlacement = .trailing
        uploadConfig.imagePadding = 14
        uploadConfig.contentInsets = .init(top: 18, leading: 24, bottom: 18, trailing: 24)
        uploadConfig.baseForegroundColor = UIColor(hex: "#2B2730")
        uploadPhotoButton.configuration = uploadConfig
        uploadPhotoButton.backgroundColor = .white
        uploadPhotoButton.layer.cornerRadius = 28
        uploadPhotoButton.layer.borderWidth = 1
        uploadPhotoButton.layer.borderColor = UIColor(hex: "#0D191E1A", alpha: 10)?.cgColor

        photoLimitLabel.translatesAutoresizingMaskIntoConstraints = false
        photoLimitLabel.text = "Максимальный размер файла: 5 ГБ"
        photoLimitLabel.font = .systemFont(ofSize: 13, weight: .regular)
        photoLimitLabel.textColor = .secondaryLabel
        photoLimitLabel.numberOfLines = 0

        let startDateRow = makeHorizontalRow(
            configuredField(startDateField, placeholder: "Дата начала"),
            configuredField(endDateField, placeholder: "Дата окончания")
        )
        let timeRow = makeHorizontalRow(
            configuredField(startTimeField, placeholder: "Время начала"),
            configuredField(endTimeField, placeholder: "Время окончания")
        )

        let stack = UIStackView(arrangedSubviews: [
            photoPreviewImageView,
            uploadPhotoButton,
            photoLimitLabel,
            configuredField(placeField, placeholder: "Заголовок"),
            startDateRow,
            timeRow,
            configuredField(addressField, placeholder: "Адрес"),
            configuredField(descriptionField, placeholder: "Описание")
        ])
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(stack)

        var config = UIButton.Configuration.filled()
        config.title = "Готово ✓"
        config.baseBackgroundColor = UIColor(hex: "#6E73F4")
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.contentInsets = .init(top: 14, leading: 28, bottom: 14, trailing: 28)
        doneButton.configuration = config
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(doneButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -130),

            photoPreviewImageView.heightAnchor.constraint(equalToConstant: 300),
            uploadPhotoButton.heightAnchor.constraint(equalToConstant: 56),

            doneButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            doneButton.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -AppLayout.floatingButtonBottomOffset
            ),
            doneButton.heightAnchor.constraint(equalToConstant: 52)
        ])
    }

    private func configuredField(_ field: UITextField, placeholder: String) -> UITextField {
        field.placeholder = placeholder
        field.backgroundColor = .white
        field.layer.cornerRadius = 22
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.systemGray5.cgColor
        field.font = .systemFont(ofSize: 17, weight: .regular)
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 18, height: 1))
        field.leftViewMode = .always
        field.heightAnchor.constraint(equalToConstant: 54).isActive = true
        return field
    }

    private func makeHorizontalRow(_ leftView: UIView, _ rightView: UIView) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: [leftView, rightView])
        stack.axis = .horizontal
        stack.spacing = 12
        stack.distribution = .fillEqually
        return stack
    }

    private func setupPickers() {
        configureDatePicker(
            startDatePicker,
            field: startDateField,
            selector: #selector(startDateChanged),
            doneSelector: #selector(donePickingStartDate)
        )
        configureDatePicker(
            endDatePicker,
            field: endDateField,
            selector: #selector(endDateChanged),
            doneSelector: #selector(donePickingEndDate)
        )

        configureTimePicker(
            startTimePicker,
            field: startTimeField,
            selector: #selector(startTimeChanged),
            doneSelector: #selector(donePickingStartTime)
        )
        configureTimePicker(
            endTimePicker,
            field: endTimeField,
            selector: #selector(endTimeChanged),
            doneSelector: #selector(donePickingEndTime)
        )
    }

    private func configureDatePicker(
        _ picker: UIDatePicker,
        field: UITextField,
        selector: Selector,
        doneSelector: Selector
    ) {
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .wheels
        picker.locale = Locale(identifier: "ru_RU")
        picker.minimumDate = Date()
        picker.addTarget(self, action: selector, for: .valueChanged)

        field.inputView = picker
        field.tintColor = .clear
        field.inputAccessoryView = makeToolbar(selector: doneSelector)
    }

    private func configureTimePicker(
        _ picker: UIDatePicker,
        field: UITextField,
        selector: Selector,
        doneSelector: Selector
    ) {
        picker.datePickerMode = .time
        picker.preferredDatePickerStyle = .wheels
        picker.locale = Locale(identifier: "ru_RU")
        picker.addTarget(self, action: selector, for: .valueChanged)

        field.inputView = picker
        field.tintColor = .clear
        field.inputAccessoryView = makeToolbar(selector: doneSelector)
    }

    private func setupActions() {
        doneButton.addTarget(self, action: #selector(didTapDone), for: .touchUpInside)
        uploadPhotoButton.addTarget(self, action: #selector(didTapUploadPhoto), for: .touchUpInside)
    }

    private func makeToolbar(selector: Selector) -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()

        let flexible = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(title: "Готово", style: .done, target: self, action: selector)

        toolbar.items = [flexible, done]
        return toolbar
    }

    @objc private func startDateChanged() {
        selectedStartDate = startDatePicker.date
        startDateField.text = Self.dateFormatter.string(from: startDatePicker.date)
    }

    @objc private func endDateChanged() {
        selectedEndDate = endDatePicker.date
        endDateField.text = Self.dateFormatter.string(from: endDatePicker.date)
    }

    @objc private func startTimeChanged() {
        selectedStartTime = startTimePicker.date
        startTimeField.text = Self.timeFormatter.string(from: startTimePicker.date)
    }

    @objc private func endTimeChanged() {
        selectedEndTime = endTimePicker.date
        endTimeField.text = Self.timeFormatter.string(from: endTimePicker.date)
    }

    @objc private func donePickingStartDate() {
        if selectedStartDate == nil {
            selectedStartDate = startDatePicker.date
            startDateField.text = Self.dateFormatter.string(from: startDatePicker.date)
        }
        startDateField.resignFirstResponder()
    }

    @objc private func donePickingEndDate() {
        if selectedEndDate == nil {
            selectedEndDate = endDatePicker.date
            endDateField.text = Self.dateFormatter.string(from: endDatePicker.date)
        }
        endDateField.resignFirstResponder()
    }

    @objc private func donePickingStartTime() {
        if selectedStartTime == nil {
            selectedStartTime = startTimePicker.date
            startTimeField.text = Self.timeFormatter.string(from: startTimePicker.date)
        }
        startTimeField.resignFirstResponder()
    }

    @objc private func donePickingEndTime() {
        if selectedEndTime == nil {
            selectedEndTime = endTimePicker.date
            endTimeField.text = Self.timeFormatter.string(from: endTimePicker.date)
        }
        endTimeField.resignFirstResponder()
    }

    @objc private func didTapDone() {
        guard let selectedStartDate else {
            showError(message: "Выберите дату начала")
            return
        }

        guard let selectedEndDate else {
            showError(message: "Выберите дату окончания")
            return
        }

        guard let selectedStartTime else {
            showError(message: "Выберите время начала")
            return
        }

        guard let selectedEndTime else {
            showError(message: "Выберите время окончания")
            return
        }

        let request = EditMeetingRequest(
            title: placeField.text ?? "",
            startDate: selectedStartDate,
            endDate: selectedEndDate,
            startTime: selectedStartTime,
            endTime: selectedEndTime,
            address: addressField.text ?? "",
            description: descriptionField.text ?? "",
            photo: selectedPhoto,
            shouldRemovePhoto: shouldRemovePhoto
        )

        interactor?.updateMeeting(request: request)
    }

    @objc private func didTapUploadPhoto() {
        let alert = UIAlertController(title: "Фото встречи", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Выбрать из галереи", style: .default) { [weak self] _ in
            self?.presentPhotoLibrary()
        })
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            alert.addAction(UIAlertAction(title: "Сделать фото", style: .default) { [weak self] _ in
                self?.presentCamera()
            })
        }
        if selectedPhoto != nil || currentPhotoURL != nil {
            alert.addAction(UIAlertAction(title: "Удалить фото", style: .destructive) { [weak self] _ in
                self?.removeSelectedPhoto()
            })
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = uploadPhotoButton
            popover.sourceRect = uploadPhotoButton.bounds
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
        present(picker, animated: true)
    }

    private func presentCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showError(message: "Камера недоступна на этом устройстве")
            return
        }

        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        present(picker, animated: true)
    }

    private func loadExistingPhotoIfNeeded() {
        imageLoadTask?.cancel()

        guard selectedPhoto == nil,
              !shouldRemovePhoto,
              let currentPhotoURL,
              !currentPhotoURL.isEmpty else {
            if selectedPhoto == nil {
                photoPreviewImageView.image = nil
                photoPreviewImageView.isHidden = true
                uploadPhotoButton.configuration?.title = "Загрузить изображение"
            }
            return
        }

        photoPreviewImageView.image = nil
        photoPreviewImageView.isHidden = false
        uploadPhotoButton.configuration?.title = "Изменить изображение"

        imageLoadTask = Task { [weak self] in
            guard let self, let interactor = self.interactor else { return }
            let image = await interactor.loadMeetingImage(
                from: currentPhotoURL,
                targetSize: CGSize(width: UIScreen.main.bounds.width - 40, height: 300)
            )

            if Task.isCancelled { return }

            await MainActor.run {
                guard self.currentPhotoURL == currentPhotoURL,
                      self.selectedPhoto == nil,
                      !self.shouldRemovePhoto else { return }
                self.photoPreviewImageView.image = image
                self.photoPreviewImageView.isHidden = image == nil
                self.uploadPhotoButton.configuration?.title = image == nil ? "Загрузить изображение" : "Изменить изображение"
            }
        }
    }

    private func handleSelectedImageData(_ data: Data) {
        guard data.count <= Self.maxPhotoSizeInBytes else {
            showError(message: "Размер файла не должен превышать 5 ГБ")
            return
        }

        guard let previewImage = makePreviewImage(from: data) else {
            showError(message: "Не удалось подготовить изображение")
            return
        }

        guard let uploadData = compressJPEG(previewImage) else {
            showError(message: "Не удалось подготовить изображение к загрузке")
            return
        }

        shouldRemovePhoto = false
        currentPhotoURL = nil
        selectedPhoto = EditMeetingPhotoUpload(
            data: uploadData,
            fileName: "meeting-photo.jpg",
            mimeType: "image/jpeg"
        )

        photoPreviewImageView.image = previewImage
        photoPreviewImageView.isHidden = false
        uploadPhotoButton.configuration?.title = "Изменить изображение"
    }

    private func removeSelectedPhoto() {
        imageLoadTask?.cancel()
        selectedPhoto = nil
        shouldRemovePhoto = true
        currentPhotoURL = nil
        photoPreviewImageView.image = nil
        photoPreviewImageView.isHidden = true
        uploadPhotoButton.configuration?.title = "Загрузить изображение"
    }

    private func makePreviewImage(from data: Data) -> UIImage? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, options) else {
            return nil
        }

        let decodeOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 2400
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, decodeOptions) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    private func compressJPEG(_ image: UIImage) -> Data? {
        var quality: CGFloat = 0.92
        let targetLimit = 8_000_000

        while quality >= 0.45 {
            if let data = image.jpegData(compressionQuality: quality), data.count <= targetLimit {
                return data
            }
            quality -= 0.1
        }

        return image.jpegData(compressionQuality: 0.35)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }

        let bottomInset = keyboardFrame.height + 24
        scrollView.contentInset.bottom = bottomInset
        scrollView.verticalScrollIndicatorInsets.bottom = bottomInset
    }

    @objc private func keyboardWillHide(notification: NSNotification) {
        scrollView.contentInset.bottom = 0
        scrollView.verticalScrollIndicatorInsets.bottom = 0
    }
}

extension EditMeetingVC: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let result = results.first else { return }
        let provider = result.itemProvider

        provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] data, error in
            guard let self else { return }

            if error != nil || data == nil {
                self.loadImageObjectFallback(from: provider)
                return
            }

            guard let data else {
                DispatchQueue.main.async {
                    self.showError(message: "Не удалось прочитать выбранный файл")
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
                self.showError(message: "Не удалось прочитать выбранный файл")
            }
            return
        }

        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let self else { return }
            guard let image = object as? UIImage,
                  let data = image.jpegData(compressionQuality: 0.95) else {
                DispatchQueue.main.async {
                    self.showError(message: "Не удалось подготовить выбранное фото")
                }
                return
            }

            DispatchQueue.main.async {
                self.handleSelectedImageData(data)
            }
        }
    }
}

extension EditMeetingVC: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
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
                self.showError(message: "Не удалось получить фото с камеры")
                return
            }

            self.handleSelectedImageData(imageData)
        }
    }
}

private extension EditMeetingVC {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static let maxPhotoSizeInBytes = 5 * 1024 * 1024 * 1024
}
