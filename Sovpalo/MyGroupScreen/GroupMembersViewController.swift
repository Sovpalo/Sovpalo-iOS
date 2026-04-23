//  GroupMembersViewController.swift
//  Sovpalo

import UIKit
import PhotosUI
import ImageIO
import UniformTypeIdentifiers

protocol GroupMembersDisplayLogic: AnyObject {
    func displayMembers(_ members: [GroupMembersModels.MemberViewModel])
    func displayError(_ message: String)
}

final class GroupMembersViewController: UIViewController {

    var interactor: GroupMembersBusinessLogic?
    private let company: Company
    private let settingsButton = UIButton(type: .system)
    private let companyAvatarWorker = CompanyAvatarWorker()

    private var members: [GroupMembersModels.MemberViewModel] = []
    private var pendingRemoval: (member: GroupMembersModels.MemberViewModel, index: Int)?
    private var cropController: AvatarImageCropViewController?
    private var currentCompanyAvatarURL: String?
    private var isUpdatingCompanyAvatar = false
    private var canEditCompanyAvatar = false

    // MARK: - UI

    private lazy var groupNameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 22, weight: .bold)
        label.textColor = .label
        return label
    }()

    private lazy var membersCountLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        return label
    }()

    private lazy var avatarView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemGray5
        view.layer.cornerRadius = 28
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

    private let avatarLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.backgroundColor = .systemGroupedBackground
        tv.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 0)
        tv.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 90, right: 0)
        tv.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: 90, right: 0)
        tv.register(MemberCell.self, forCellReuseIdentifier: MemberCell.reuseID)
        tv.register(AddMemberCell.self, forCellReuseIdentifier: AddMemberCell.reuseID)
        tv.dataSource = self
        tv.delegate = self
        tv.rowHeight = 56
        if #available(iOS 15.0, *) {
            tv.sectionHeaderTopPadding = 0
        }
        tv.contentInset = UIEdgeInsets(top: -36, left: 0, bottom: 0, right: 0)
        return tv
    }()

    private lazy var myGroupsButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Мои группы  →", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(hex: "#7079FB")
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.layer.cornerRadius = 24
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(myGroupsTapped), for: .touchUpInside)
        return button
    }()

    // MARK: - Init

    init(company: Company) {
        self.company = company
        self.currentCompanyAvatarURL = company.avatarURL
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        navigationController?.navigationBar.isHidden = true
        edgesForExtendedLayout = .all
        extendedLayoutIncludesOpaqueBars = true
        setupHeader()
        setupTableView()
        groupNameLabel.text = company.name
        avatarLabel.text = String(company.name.prefix(1)).uppercased()
        loadCompanyAvatarIfNeeded()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        refreshCompanyHeader()
        interactor?.loadMembers()
    }

    // MARK: - Setup

    private func setupHeader() {
        let headerStack = UIStackView()
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.spacing = 14
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        avatarView.addSubview(avatarImageView)
        avatarView.addSubview(avatarLabel)
        NSLayoutConstraint.activate([
            avatarImageView.topAnchor.constraint(equalTo: avatarView.topAnchor),
            avatarImageView.leadingAnchor.constraint(equalTo: avatarView.leadingAnchor),
            avatarImageView.trailingAnchor.constraint(equalTo: avatarView.trailingAnchor),
            avatarImageView.bottomAnchor.constraint(equalTo: avatarView.bottomAnchor),

            avatarLabel.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            avatarLabel.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor)
        ])

        let avatarTapGesture = UITapGestureRecognizer(target: self, action: #selector(didTapCompanyAvatar))
        avatarView.addGestureRecognizer(avatarTapGesture)
        avatarView.isUserInteractionEnabled = true

        let textStack = UIStackView(arrangedSubviews: [groupNameLabel, membersCountLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        // Settings button
        settingsButton.setImage(UIImage(systemName: "gearshape"), for: .normal)
        settingsButton.tintColor = .label
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        NSLayoutConstraint.activate([
            settingsButton.widthAnchor.constraint(equalToConstant: 32),
            settingsButton.heightAnchor.constraint(equalToConstant: 32)
        ])

        headerStack.addArrangedSubview(avatarView)
        headerStack.addArrangedSubview(textStack)
        headerStack.addArrangedSubview(UIView())
        headerStack.addArrangedSubview(settingsButton)

        NSLayoutConstraint.activate([
            avatarView.widthAnchor.constraint(equalToConstant: 56),
            avatarView.heightAnchor.constraint(equalToConstant: 56)
        ])

        view.addSubview(headerStack)
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 6),
            headerStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            headerStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    private func setupTableView() {
        view.addSubview(tableView)
        view.addSubview(myGroupsButton)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 76),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: myGroupsButton.topAnchor, constant: -12),

            myGroupsButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            myGroupsButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            myGroupsButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -80),
            myGroupsButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    // MARK: - Actions

    @objc private func myGroupsTapped() {
        let groupListVC = GroupListViewController()
        navigationController?.pushViewController(groupListVC, animated: true)
    }

    @objc private func didTapCompanyAvatar() {
        guard canEditCompanyAvatar else {
            let alert = UIAlertController(
                title: "Недоступно",
                message: "Только владелец компании может менять её фото.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        let alert = UIAlertController(title: "Фото компании", message: "Что хочешь сделать?", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Выбрать из галереи", style: .default) { [weak self] _ in
            self?.presentPhotoLibrary()
        })
        alert.addAction(UIAlertAction(title: "Сфотографировать", style: .default) { [weak self] _ in
            self?.presentCamera()
        })
        if avatarImageView.image != nil {
            alert.addAction(UIAlertAction(title: "Удалить фото", style: .destructive) { [weak self] _ in
                self?.deleteCompanyAvatar()
            })
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = avatarView
            popover.sourceRect = avatarView.bounds
        }

        present(alert, animated: true)
    }
}

// MARK: - DisplayLogic

extension GroupMembersViewController: GroupMembersDisplayLogic {
    func displayMembers(_ members: [GroupMembersModels.MemberViewModel]) {
        self.members = members
        pendingRemoval = nil
        membersCountLabel.text = "\(members.count) друзей"
        canEditCompanyAvatar = members.contains(where: { $0.userID == currentUserID && $0.isOwner })
        avatarView.alpha = canEditCompanyAvatar ? 1 : 0.9
        tableView.reloadData()
    }

    func displayError(_ message: String) {
        restorePendingRemovalIfNeeded()

        let alert = UIAlertController(
            title: "Ошибка",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Ок", style: .default))
        present(alert, animated: true)
    }

    @objc private func settingsTapped() {
        let settingsVC = SettingsAssembly.assembly()
        navigationController?.pushViewController(settingsVC, animated: true)
    }
}

extension GroupMembersViewController: PHPickerViewControllerDelegate {
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
                self.handleSelectedImageData(data, sourceLabel: "photo library")
            }
        }
    }

    private func loadImageObjectFallback(from provider: NSItemProvider) {
        guard provider.canLoadObject(ofClass: UIImage.self) else {
            showErrorAlert(message: "Не удалось прочитать выбранный файл")
            return
        }

        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let self else { return }
            guard let image = object as? UIImage,
                  let data = image.jpegData(compressionQuality: 0.95) else {
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

extension GroupMembersViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
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

            self.handleSelectedImageData(imageData, sourceLabel: "camera")
        }
    }
}

// MARK: - UITableViewDataSource

extension GroupMembersViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int { 1 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        members.count + 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == 0 {
            return tableView.dequeueReusableCell(withIdentifier: AddMemberCell.reuseID, for: indexPath) as! AddMemberCell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: MemberCell.reuseID, for: indexPath) as! MemberCell
        cell.configure(with: members[indexPath.row - 1])
        return cell
    }
}

// MARK: - UITableViewDelegate

extension GroupMembersViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.row == 0 {
            let inviteVC = InviteUserAssembly.assembly(companyId: Int(company.id))
            inviteVC.shouldPopOnDone = true
            navigationController?.pushViewController(inviteVC, animated: true)
        }
    }

    func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard indexPath.row > 0 else { return nil }

        let member = members[indexPath.row - 1]
        guard member.canBeRemoved else { return nil }

        let deleteAction = UIContextualAction(style: .destructive, title: "Удалить") { [weak self] _, _, completion in
            self?.presentDeleteConfirmation(for: member, completion: completion)
        }

        let configuration = UISwipeActionsConfiguration(actions: [deleteAction])
        configuration.performsFirstActionWithFullSwipe = true
        return configuration
    }
}

private extension GroupMembersViewController {
    var currentUserID: Int {
        guard let data = KeychainService().getData(forKey: "auth.userId"),
              let string = String(data: data, encoding: .utf8),
              let id = Int(string) else {
            return -1
        }
        return id
    }

    func refreshCompanyHeader() {
        Task { [weak self] in
            guard let self else { return }
            do {
                let refreshedCompany = try await companyAvatarWorker.fetchCompany(companyID: company.id)
                await MainActor.run {
                    print("[GroupMembersViewController] Refreshed company header: id=\(refreshedCompany.id), avatarURL=\(refreshedCompany.avatarURL ?? "nil")")
                    self.groupNameLabel.text = refreshedCompany.name
                    self.currentCompanyAvatarURL = refreshedCompany.avatarURL
                    self.avatarLabel.text = String(refreshedCompany.name.prefix(1)).uppercased()
                    self.loadCompanyAvatarIfNeeded()
                }
            } catch {
                await MainActor.run {
                    print("[GroupMembersViewController] Failed to refresh company header: \(error)")
                }
            }
        }
    }

    func loadCompanyAvatarIfNeeded() {
        guard let avatarURL = currentCompanyAvatarURL, !avatarURL.isEmpty else {
            avatarImageView.image = nil
            avatarLabel.isHidden = false
            return
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                let data = try await companyAvatarWorker.fetchAvatarData(from: avatarURL)
                let image = makeDisplayAvatarImage(from: data)
                await MainActor.run {
                    guard self.currentCompanyAvatarURL == avatarURL else { return }
                    self.avatarImageView.image = image
                    self.avatarLabel.isHidden = image != nil
                }
            } catch {
                await MainActor.run {
                    print("[GroupMembersViewController] Failed to load company avatar: \(error)")
                    self.avatarImageView.image = nil
                    self.avatarLabel.isHidden = false
                }
            }
        }
    }

    func presentPhotoLibrary() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    func presentCamera() {
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

    func handleSelectedImageData(_ data: Data, sourceLabel: String) {
        print("[GroupMembersViewController] Received raw company image data from \(sourceLabel): size=\(data.count) bytes")

        guard let image = makeEditingImage(from: data) else {
            print("[GroupMembersViewController] Failed to decode editable company image from \(sourceLabel)")
            showErrorAlert(message: "Не удалось подготовить фото")
            return
        }

        let cropController = AvatarImageCropViewController(image: image) { [weak self] croppedImage in
            guard let self else { return }
            guard let processed = self.makeAvatarPayload(from: croppedImage) else {
                self.showErrorAlert(message: "Не удалось подготовить обрезанное фото")
                return
            }

            self.uploadCompanyAvatar(imageData: processed.uploadData, previewImage: processed.previewImage)
        }

        self.cropController = cropController
        cropController.modalPresentationStyle = .fullScreen
        present(cropController, animated: true)
    }

    func uploadCompanyAvatar(imageData: Data, previewImage: UIImage) {
        print("[GroupMembersViewController] Prepared company avatar payload: size=\(imageData.count) bytes")
        setCompanyAvatarUpdating(true)

        Task { [weak self] in
            guard let self else { return }

            do {
                try await companyAvatarWorker.uploadAvatar(
                    companyID: company.id,
                    imageData: imageData,
                    fileName: "avatar.jpg",
                    mimeType: "image/jpeg"
                )

                await MainActor.run {
                    self.avatarImageView.image = previewImage
                    self.avatarLabel.isHidden = true
                    print("[GroupMembersViewController] Company avatar upload completed successfully")
                }
                await MainActor.run {
                    self.refreshCompanyHeader()
                    self.setCompanyAvatarUpdating(false)
                }
            } catch {
                await MainActor.run {
                    self.setCompanyAvatarUpdating(false)
                    self.showErrorAlert(message: error.localizedDescription)
                }
            }
        }
    }

    func deleteCompanyAvatar() {
        setCompanyAvatarUpdating(true)

        Task { [weak self] in
            guard let self else { return }

            do {
                try await companyAvatarWorker.deleteAvatar(companyID: company.id)
                await MainActor.run {
                    self.currentCompanyAvatarURL = nil
                    self.avatarImageView.image = nil
                    self.avatarLabel.isHidden = false
                    self.refreshCompanyHeader()
                    self.setCompanyAvatarUpdating(false)
                }
            } catch {
                await MainActor.run {
                    self.setCompanyAvatarUpdating(false)
                    self.showErrorAlert(message: error.localizedDescription)
                }
            }
        }
    }

    func setCompanyAvatarUpdating(_ isUpdating: Bool) {
        isUpdatingCompanyAvatar = isUpdating
        avatarView.alpha = isUpdating ? 0.65 : (canEditCompanyAvatar ? 1 : 0.9)
        avatarView.isUserInteractionEnabled = !isUpdating
    }

    func makeEditingImage(from data: Data) -> UIImage? {
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

    func makeAvatarPayload(from image: UIImage) -> (uploadData: Data, previewImage: UIImage)? {
        let previewMaxDimension = Int(max(avatarImageView.bounds.width, avatarImageView.bounds.height, 56) * UIScreen.main.scale)
        let previewImage = makePreviewImage(from: image, maxPixelSize: max(previewMaxDimension, 56)) ?? image
        guard let uploadData = compressJPEG(image) else { return nil }

        return (uploadData: uploadData, previewImage: previewImage)
    }

    func makePreviewImage(from image: UIImage, maxPixelSize: Int) -> UIImage? {
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

    func makeDisplayAvatarImage(from data: Data) -> UIImage? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, options) else {
            return nil
        }

        let maxPixelSize = Int(ceil(56 * UIScreen.main.scale))
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

    func compressJPEG(_ image: UIImage) -> Data? {
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

    func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "Ошибка", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    func presentDeleteConfirmation(
        for member: GroupMembersModels.MemberViewModel,
        completion: @escaping (Bool) -> Void
    ) {
        let alert = UIAlertController(
            title: "Удалить участника",
            message: "Вы уверены, что хотите удалить \(member.name) из компании?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Нет", style: .cancel) { _ in
            completion(false)
        })

        alert.addAction(UIAlertAction(title: "Да", style: .destructive) { [weak self] _ in
            guard let self else {
                completion(false)
                return
            }

            self.removeMemberLocally(member)
            self.interactor?.removeMember(userID: member.userID)
            completion(true)
        })

        present(alert, animated: true)
    }

    func removeMemberLocally(_ member: GroupMembersModels.MemberViewModel) {
        guard let index = members.firstIndex(where: { $0.userID == member.userID }) else { return }

        pendingRemoval = (member, index)
        members.remove(at: index)
        membersCountLabel.text = "\(members.count) друзей"

        tableView.performBatchUpdates({
            tableView.deleteRows(at: [IndexPath(row: index + 1, section: 0)], with: .automatic)
        })
    }

    func restorePendingRemovalIfNeeded() {
        guard let pendingRemoval else { return }

        let restoredIndex = min(pendingRemoval.index, members.count)
        members.insert(pendingRemoval.member, at: restoredIndex)
        membersCountLabel.text = "\(members.count) друзей"

        tableView.performBatchUpdates({
            tableView.insertRows(at: [IndexPath(row: restoredIndex + 1, section: 0)], with: .automatic)
        })

        self.pendingRemoval = nil
    }
}
