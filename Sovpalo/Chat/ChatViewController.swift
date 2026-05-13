import UIKit
import AVFoundation
import AVKit
import MessageKit
import InputBarAccessoryView
import PhotosUI
import UniformTypeIdentifiers

final class ChatViewController: MessagesViewController {
    var interactor: ChatBusinessLogic?
    var groupName: String = "Чат"
    private var connectionState: ChatWebSocketState = .disconnected
    private let connectionStatusLabel = UILabel()
    private let chatHeaderContentHeight: CGFloat = 64
    private let chatHeaderView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemGroupedBackground
        return view
    }()
    private let chatTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Чат"
        label.font = .systemFont(ofSize: 17, weight: .bold)
        label.textColor = .label
        label.textAlignment = .center
        return label
    }()
    private let companyNameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = UIColor(hex: "#7079FB")
        label.textAlignment = .center
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private var messages: [ChatMessageView] = []
    private var messageItems: [ChatMessageItem] = []
    private var hasMore = false
    private var isLoadingOlder = false
    private var isContextMenuActive = false
    private var deferredApply: (messages: [ChatMessageView], hasMore: Bool)?
    private var deferredReloadNeeded = false
    private var avatarCache: [String: UIImage] = [:]
    private var avatarInFlight: Set<String> = []
    private var mediaCache: [String: UIImage] = [:]
    private var mediaInFlight: Set<String> = []
    private var videoThumbnailCache: [String: UIImage] = [:]
    private var videoThumbnailInFlight: Set<String> = []
    private let inlineBackButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "chevron.backward"), for: .normal)
        button.tintColor = .label
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        setupHeaderTitle()
        setupMessageKit()
        setupInputBar()
        setupChatHeader()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(currentUserAvatarDidChange),
            name: .currentUserAvatarDidChange,
            object: nil
        )
        interactor?.loadInitial()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateMessagesTopInset()
        view.bringSubviewToFront(chatHeaderView)
    }

    private func setupHeaderTitle() {
        navigationItem.titleView = nil
        navigationItem.leftBarButtonItem = nil
        companyNameLabel.text = groupName
        applyConnectionStateUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        (tabBarController as? MainTabBarController)?.setCustomTabBarHidden(true, animated: true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        (tabBarController as? MainTabBarController)?.setCustomTabBarHidden(false, animated: true)
        interactor?.stop()
    }

    private func setupMessageKit() {
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messagesCollectionView.messageCellDelegate = self
        messagesCollectionView.delegate = self
        messagesCollectionView.backgroundColor = .clear
        updateMessagesTopInset()
        scrollsToLastItemOnKeyboardBeginsEditing = true
        maintainPositionOnInputBarHeightChanged = true
        showMessageTimestampOnSwipeLeft = false
    }

    private func setupInputBar() {
        let actionButtonSize: CGFloat = 36
        let horizontalPadding: CGFloat = 12
        let buttonFieldSpacing: CGFloat = 8

        messageInputBar.delegate = self
        messageInputBar.backgroundView.backgroundColor = .clear
        messageInputBar.separatorLine.isHidden = true
        messageInputBar.padding = UIEdgeInsets(top: 6, left: horizontalPadding, bottom: 6, right: horizontalPadding)
        messageInputBar.middleContentViewPadding = UIEdgeInsets(top: 0, left: buttonFieldSpacing, bottom: 0, right: buttonFieldSpacing)
        messageInputBar.inputTextView.backgroundColor = .white
        messageInputBar.inputTextView.layer.cornerRadius = 18
        messageInputBar.inputTextView.layer.masksToBounds = true
        messageInputBar.inputTextView.placeholder = "Напишите сообщение..."
        messageInputBar.inputTextView.textContainerInset = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 10)
        messageInputBar.inputTextView.layer.borderWidth = 1
        messageInputBar.inputTextView.layer.borderColor = UIColor.systemGray5.cgColor
        messageInputBar.leftStackView.alignment = .center
        messageInputBar.rightStackView.alignment = .center

        let sendButton = InputBarButtonItem()
        sendButton.setSize(CGSize(width: actionButtonSize, height: actionButtonSize), animated: false)
        sendButton.backgroundColor = UIColor(hex: "#F6F77A")
        sendButton.layer.cornerRadius = actionButtonSize / 2
        sendButton.layer.masksToBounds = true
        sendButton.tintColor = UIColor(hex: "#7079FB")
        sendButton.setImage(UIImage(systemName: "paperplane.fill"), for: .normal)
        sendButton.onTouchUpInside { [weak self] _ in
            self?.didTapSend()
        }
        messageInputBar.setStackViewItems([sendButton], forStack: .right, animated: false)
        messageInputBar.setRightStackViewWidthConstant(to: actionButtonSize, animated: false)

        let cameraButton = InputBarButtonItem()
        cameraButton.setSize(CGSize(width: actionButtonSize, height: actionButtonSize), animated: false)
        cameraButton.backgroundColor = UIColor(hex: "#F6F77A")
        cameraButton.layer.cornerRadius = actionButtonSize / 2
        cameraButton.layer.masksToBounds = true
        cameraButton.tintColor = UIColor(hex: "#7079FB")
        cameraButton.setImage(UIImage(systemName: "camera.fill"), for: .normal)
        cameraButton.onTouchUpInside { [weak self] _ in
            self?.presentImageSourceSheet()
        }
        messageInputBar.setStackViewItems([cameraButton], forStack: .left, animated: false)
        messageInputBar.setLeftStackViewWidthConstant(to: actionButtonSize, animated: false)
    }

    private func setupChatHeader() {
        view.addSubview(chatHeaderView)
        chatHeaderView.addSubview(inlineBackButton)
        chatHeaderView.addSubview(chatTitleLabel)
        chatHeaderView.addSubview(companyNameLabel)
        inlineBackButton.addTarget(self, action: #selector(didTapBack), for: .touchUpInside)
        NSLayoutConstraint.activate([
            chatHeaderView.topAnchor.constraint(equalTo: view.topAnchor),
            chatHeaderView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            chatHeaderView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            chatHeaderView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: chatHeaderContentHeight),

            inlineBackButton.leadingAnchor.constraint(equalTo: chatHeaderView.leadingAnchor, constant: 16),
            inlineBackButton.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: chatHeaderContentHeight / 2),
            inlineBackButton.widthAnchor.constraint(equalToConstant: 28),
            inlineBackButton.heightAnchor.constraint(equalToConstant: 28),

            chatTitleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            chatTitleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: inlineBackButton.trailingAnchor, constant: 12),
            chatTitleLabel.centerXAnchor.constraint(equalTo: chatHeaderView.centerXAnchor),

            companyNameLabel.topAnchor.constraint(equalTo: chatTitleLabel.bottomAnchor, constant: 2),
            companyNameLabel.leadingAnchor.constraint(equalTo: chatHeaderView.leadingAnchor, constant: 72),
            companyNameLabel.trailingAnchor.constraint(equalTo: chatHeaderView.trailingAnchor, constant: -72)
        ])
    }

    private func updateMessagesTopInset() {
        let topInset = view.safeAreaInsets.top + chatHeaderContentHeight + 8
        guard abs(messagesCollectionView.contentInset.top - topInset) > 0.5 else { return }
        messagesCollectionView.contentInset.top = topInset
        messagesCollectionView.verticalScrollIndicatorInsets.top = topInset
    }

    func apply(messages: [ChatMessageView], hasMore: Bool, animate: Bool) {
        if isContextMenuActive {
            deferredApply = (messages: messages, hasMore: hasMore)
            return
        }
        self.messages = messages
        self.hasMore = hasMore
        self.messageItems = messages.map(mapToMessageType)
        messagesCollectionView.reloadData()
        if animate {
            messagesCollectionView.scrollToLastItem(animated: true)
        }
    }

    func setInitialLoading(_ isLoading: Bool) {
        if isLoading {
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.startAnimating()
            navigationItem.rightBarButtonItem = UIBarButtonItem(customView: spinner)
        } else {
            navigationItem.rightBarButtonItem = nil
        }
    }

    func setLoadingOlder(_ isLoading: Bool) {
        isLoadingOlder = isLoading
    }

    func setConnectionState(_ state: ChatWebSocketState) {
        connectionState = state
        applyConnectionStateUI()
    }

    func showError(_ message: String) {
        let lower = message.lowercased()
        if lower.contains("chat doesn't exist")
            || lower.contains("chat does not exist")
            || lower.contains("чат не существует") {
            return
        }
        if presentedViewController != nil {
            return
        }
        let alert = UIAlertController(title: "Ошибка", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "ОК", style: .default))
        present(alert, animated: true)
    }

    @objc private func didTapBack() {
        if let tabBarController {
            tabBarController.selectedIndex = TabBar.Tab.home.rawValue
        } else if let navigationController, navigationController.viewControllers.count > 1 {
            navigationController.popViewController(animated: true)
        }
    }

    private func didTapSend() {
        let text = messageInputBar.inputTextView.text ?? ""
        interactor?.sendText(text)
        messageInputBar.inputTextView.text = ""
    }

    private func mapToMessageType(_ view: ChatMessageView) -> ChatMessageItem {
        let sender = ChatSender(
            senderId: view.isOutgoing ? "me" : "\(view.senderId)",
            displayName: view.senderName
        )
        let kind: MessageKind
        switch view.kind {
        case let .text(text):
            kind = .text(text)
        case let .photo(image):
            let media = ChatImageMediaItem(
                url: nil,
                image: image,
                placeholderImage: UIImage(systemName: "photo") ?? UIImage(),
                size: CGSize(width: 220, height: 160)
            )
            kind = .photo(media)
        case let .photoURL(url):
            let media = ChatImageMediaItem(
                url: url,
                image: mediaCache[url.absoluteString],
                placeholderImage: UIImage(systemName: "photo") ?? UIImage(),
                size: CGSize(width: 220, height: 160)
            )
            kind = .photo(media)
        case let .videoURL(url):
            let media = ChatImageMediaItem(
                url: url,
                image: videoThumbnailCache[url.absoluteString],
                placeholderImage: UIImage(systemName: "play.rectangle.fill") ?? UIImage(),
                size: CGSize(width: 220, height: 160)
            )
            kind = .video(media)
        }

        return ChatMessageItem(
            messageId: "\(view.id)",
            sender: sender,
            sentDate: view.sentAt,
            kind: kind
        )
    }

    private func presentImageSourceSheet() {
        let sheet = UIAlertController(title: "Медиа", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Камера", style: .default) { [weak self] _ in
            self?.presentCamera()
        })
        sheet.addAction(UIAlertAction(title: "Фото или видео", style: .default) { [weak self] _ in
            self?.presentPhotoPicker()
        })
        sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = view
            pop.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.maxY - 80, width: 1, height: 1)
        }
        present(sheet, animated: true)
    }

    private func presentCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showError("Камера недоступна на этом устройстве")
            return
        }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        present(picker, animated: true)
    }

    private func presentPhotoPicker() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .any(of: [.images, .videos])
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        super.scrollViewDidScroll(scrollView)
        guard hasMore, !isLoadingOlder else { return }
        if scrollView.contentOffset.y <= 20 {
            interactor?.loadOlder()
        }
    }

    private func avatarImage(for message: MessageType) -> UIImage {
        let messageView = messageViewModel(for: message)
        let avatarURL = messageView?.senderAvatarURL
        if let avatarURL, let url = URL(string: avatarURL) {
            if let cached = avatarCache[avatarURL] {
                return cached
            }
            loadAvatar(url: url, cacheKey: avatarURL, messageId: message.messageId)
        } else {
            let key = message.sender.senderId + "|" + message.sender.displayName
            if let cached = avatarCache[key] {
                return cached
            }
            let image = placeholderAvatarImage(for: message)
            avatarCache[key] = image
            return image
        }

        return placeholderAvatarImage(for: message)
    }

    private func placeholderAvatarImage(for message: MessageType) -> UIImage {
        let isCurrent = message.sender.senderId == "me"
        return makeAvatarImage(
            initials: initials(from: message.sender.displayName),
            background: isCurrent ? (UIColor(hex: "#7079FB") ?? .systemIndigo) : (UIColor(hex: "#F6F77A") ?? .systemYellow),
            textColor: isCurrent ? .white : .black
        )
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map { String($0) }.joined()
        if letters.isEmpty {
            return "U"
        }
        return letters.uppercased()
    }

    private func makeAvatarImage(initials: String, background: UIColor, textColor: UIColor) -> UIImage {
        let size = CGSize(width: 30, height: 30)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            background.setFill()
            UIBezierPath(ovalIn: rect).fill()

            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .bold),
                .foregroundColor: textColor
            ]
            let textSize = initials.size(withAttributes: attrs)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            initials.draw(in: textRect, withAttributes: attrs)
            context.cgContext.setStrokeColor(UIColor.white.cgColor)
            context.cgContext.setLineWidth(1)
            context.cgContext.strokeEllipse(in: rect.insetBy(dx: 0.5, dy: 0.5))
        }
    }

    private func messageViewModel(for message: MessageType) -> ChatMessageView? {
        messages.first(where: { "\($0.id)" == message.messageId })
    }

    private func loadAvatar(url: URL, cacheKey: String, messageId: String) {
        guard !avatarInFlight.contains(cacheKey) else { return }
        avatarInFlight.insert(cacheKey)

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard
                let self,
                let data,
                let image = UIImage(data: data)
            else {
                DispatchQueue.main.async {
                    self?.avatarInFlight.remove(cacheKey)
                }
                return
            }
            DispatchQueue.main.async {
                self.avatarInFlight.remove(cacheKey)
                self.avatarCache[cacheKey] = image
                if let index = self.messageItems.firstIndex(where: { $0.messageId == messageId }) {
                    let indexPath = IndexPath(item: 0, section: index)
                    if let cell = self.messagesCollectionView.cellForItem(at: indexPath) as? MessageContentCell {
                        cell.avatarView.set(avatar: Avatar(image: image))
                        return
                    }
                    if self.isContextMenuActive {
                        self.deferredReloadNeeded = true
                        return
                    }
                    self.messagesCollectionView.reloadSections(IndexSet(integer: index))
                    return
                }
                if self.isContextMenuActive {
                    self.deferredReloadNeeded = true
                    return
                }
                self.messagesCollectionView.reloadData()
            }
        }.resume()
    }

    @objc private func currentUserAvatarDidChange(_ notification: Notification) {
        avatarInFlight.removeAll()
        if let avatarURL = notification.userInfo?["avatarURL"] as? String,
           let absoluteAvatarURL = absoluteAvatarURLString(avatarURL),
           let avatarData = notification.userInfo?["avatarData"] as? Data,
           let image = UIImage(data: avatarData) {
            avatarCache[absoluteAvatarURL] = image
        } else {
            avatarCache.removeAll()
        }

        if isContextMenuActive {
            deferredReloadNeeded = true
        } else {
            messagesCollectionView.reloadData()
        }
    }

    private func absoluteAvatarURLString(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if let url = URL(string: trimmed), url.scheme != nil {
            return url.absoluteString
        }
        let base = Server.url.hasSuffix("/") ? String(Server.url.dropLast()) : Server.url
        let path = trimmed.hasPrefix("/") ? trimmed : ("/" + trimmed)
        return base + path
    }
}

extension ChatViewController {
    func collectionView(
        _ collectionView: UICollectionView,
        contextMenuConfigurationForItemAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard collectionView === messagesCollectionView else { return nil }
        guard indexPath.section >= 0, indexPath.section < messageItems.count else { return nil }

        let item = messageItems[indexPath.section]
        guard let vm = messageViewModel(for: item) else { return nil }
        guard vm.isOutgoing, vm.id > 0 else { return nil }

        return UIContextMenuConfiguration(identifier: indexPath as NSIndexPath, previewProvider: nil) { [weak self] _ in
            guard let self else { return UIMenu() }

            let delete = UIAction(
                title: "Удалить",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { [weak self] _ in
                self?.interactor?.deleteMessage(id: vm.id)
            }

            return UIMenu(title: "", children: [delete])
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration
    ) -> UITargetedPreview? {
        guard collectionView === messagesCollectionView else { return nil }
        guard let indexPath = (configuration.identifier as? NSIndexPath).map({ IndexPath(row: $0.row, section: $0.section) }) else { return nil }
        guard let cell = messagesCollectionView.cellForItem(at: indexPath) as? MessageContentCell else { return nil }
        return bubbleSnapshotPreview(for: cell)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration
    ) -> UITargetedPreview? {
        guard collectionView === messagesCollectionView else { return nil }
        guard let indexPath = (configuration.identifier as? NSIndexPath).map({ IndexPath(row: $0.row, section: $0.section) }) else { return nil }
        guard let cell = messagesCollectionView.cellForItem(at: indexPath) as? MessageContentCell else { return nil }
        return bubbleSnapshotPreview(for: cell)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        willDisplayContextMenuWithConfiguration configuration: UIContextMenuConfiguration,
        animator: UIContextMenuInteractionAnimating?
    ) {
        guard collectionView === messagesCollectionView else { return }
        isContextMenuActive = true
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didEndDisplayingContextMenuWithConfiguration configuration: UIContextMenuConfiguration,
        animator: UIContextMenuInteractionAnimating?
    ) {
        guard collectionView === messagesCollectionView else { return }
        isContextMenuActive = false
        if let deferred = deferredApply {
            deferredApply = nil
            apply(messages: deferred.messages, hasMore: deferred.hasMore, animate: false)
        }
        if deferredReloadNeeded {
            deferredReloadNeeded = false
            messagesCollectionView.reloadData()
        }
    }
}

private extension ChatViewController {
    func bubbleSnapshotPreview(for cell: MessageContentCell) -> UITargetedPreview {
        let params = UIPreviewParameters()
        params.backgroundColor = .clear
        let bubbleFrame = cell.messageContainerView.frame
        let bubbleBounds = CGRect(origin: .zero, size: bubbleFrame.size)
        guard bubbleBounds.width > 0, bubbleBounds.height > 0 else {
            return UITargetedPreview(view: cell)
        }
        let bubbleRadius = max(12, cell.messageContainerView.layer.cornerRadius)
        params.visiblePath = UIBezierPath(roundedRect: bubbleBounds, cornerRadius: bubbleRadius)

        let renderer = UIGraphicsImageRenderer(size: bubbleFrame.size)
        let image = renderer.image { context in
            context.cgContext.translateBy(x: -bubbleFrame.minX, y: -bubbleFrame.minY)
            cell.drawHierarchy(in: cell.bounds, afterScreenUpdates: false)
        }

        let snapshotView = UIImageView(image: image)
        snapshotView.bounds = bubbleBounds
        snapshotView.contentMode = .scaleAspectFill
        snapshotView.clipsToBounds = true

        let bubbleCenterInCell = CGPoint(x: bubbleFrame.midX, y: bubbleFrame.midY)
        let bubbleCenterInCollection = cell.convert(bubbleCenterInCell, to: messagesCollectionView)
        let target = UIPreviewTarget(container: messagesCollectionView, center: bubbleCenterInCollection)
        return UITargetedPreview(view: snapshotView, parameters: params, target: target)
    }
}

extension ChatViewController: MessagesDataSource {
    var currentSender: any SenderType {
        // MessageKit uses this sender for layout decisions; actual content comes from message items.
        ChatSender(senderId: "me", displayName: "Вы")
    }

    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        messageItems.count
    }

    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        messageItems[indexPath.section]
    }

    func cellTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        guard shouldShowDateSeparator(at: indexPath.section) else { return nil }
        let text = dateSeparatorText(for: message.sentDate)
        return NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: UIColor.secondaryLabel
            ]
        )
    }

    func messageTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        // Show sender name above bubble for incoming messages.
        guard !isFromCurrentSender(message: message) else { return nil }
        let name = message.sender.displayName
        return NSAttributedString(
            string: name,
            attributes: [
                .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: UIColor.secondaryLabel
            ]
        )
    }

    func messageBottomLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        // Telegram-like: show time close to the bubble (MessageKit places it under; we tune insets/alignment).
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        let time = formatter.string(from: message.sentDate)
        return NSAttributedString(
            string: time,
            attributes: [
                .font: UIFont.systemFont(ofSize: 10, weight: .medium),
                .foregroundColor: UIColor.tertiaryLabel
            ]
        )
    }
}

extension ChatViewController: MessagesDisplayDelegate {
    func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        isFromCurrentSender(message: message) ? (UIColor(hex: "#7079FB") ?? .systemIndigo) : (UIColor(hex: "#F6F77A") ?? .systemYellow)
    }

    func textColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        isFromCurrentSender(message: message) ? .white : .label
    }

    func messageStyle(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageStyle {
        .bubbleTail(isFromCurrentSender(message: message) ? .bottomRight : .bottomLeft, .curved)
    }

    func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        avatarView.set(avatar: Avatar(image: avatarImage(for: message)))
    }

    func configureMediaMessageImageView(
        _ imageView: UIImageView,
        for message: MessageType,
        at indexPath: IndexPath,
        in messagesCollectionView: MessagesCollectionView
    ) {
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill

        let media: any MediaItem
        switch message.kind {
        case let .photo(photoMedia):
            media = photoMedia
        case let .video(photoMedia):
            media = photoMedia
        default:
            return
        }

        if let image = media.image {
            imageView.image = image
            return
        }
        if let url = media.url {
            switch message.kind {
            case .photo:
                loadMedia(url: url, messageId: message.messageId, imageView: imageView)
            case .video:
                loadVideoThumbnail(url: url, messageId: message.messageId, imageView: imageView)
            default:
                imageView.image = media.placeholderImage
            }
        } else {
            imageView.image = media.placeholderImage
        }
    }
}

extension ChatViewController: MessagesLayoutDelegate {
    func cellTopLabelHeight(for message: any MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        shouldShowDateSeparator(at: indexPath.section) ? 18 : 0
    }

    func avatarSize(for message: any MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGSize? {
        CGSize(width: 30, height: 30)
    }

    func messageTopLabelHeight(for message: any MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        isFromCurrentSender(message: message) ? 0 : 16
    }

    func messageBottomLabelHeight(for message: any MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        14
    }

    func messageBottomLabelAlignment(for message: any MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> LabelAlignment {
        LabelAlignment(
            textAlignment: .right,
            textInsets: UIEdgeInsets(top: -10, left: 0, bottom: 0, right: isFromCurrentSender(message: message) ? 8 : 30)
        )
    }
}


extension ChatViewController: InputBarAccessoryViewDelegate {}

extension ChatViewController: MessageCellDelegate {
    func didTapImage(in cell: MessageCollectionViewCell) {
        guard
            let mediaCell = cell as? MediaMessageCell,
            let indexPath = messagesCollectionView.indexPath(for: mediaCell)
        else { return }

        let message = messageItems[indexPath.section]
        switch message.kind {
        case let .video(media):
            guard let url = media.url else { return }
            presentVideoPlayer(url)
        case .photo:
            guard let image = mediaCell.imageView.image else { return }
            presentImagePreview(image)
        default:
            return
        }
    }
}

private extension ChatViewController {
    func presentVideoPlayer(_ url: URL) {
        let playerViewController = AVPlayerViewController()
        playerViewController.player = AVPlayer(url: url)
        present(playerViewController, animated: true) {
            playerViewController.player?.play()
        }
    }

    func presentImagePreview(_ image: UIImage) {
        let overlayView = UIView(frame: view.bounds)
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.92)
        overlayView.alpha = 0
        overlayView.accessibilityIdentifier = "chatImagePreviewOverlay"

        let imageView = UIImageView(image: image)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true

        overlayView.addSubview(imageView)
        view.addSubview(overlayView)
        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            imageView.topAnchor.constraint(equalTo: overlayView.safeAreaLayoutGuide.topAnchor, constant: 16),
            imageView.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor, constant: 16),
            imageView.trailingAnchor.constraint(equalTo: overlayView.trailingAnchor, constant: -16),
            imageView.bottomAnchor.constraint(equalTo: overlayView.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])

        let closeTap = UITapGestureRecognizer(target: self, action: #selector(dismissImagePreview(_:)))
        overlayView.addGestureRecognizer(closeTap)

        UIView.animate(withDuration: 0.2) {
            overlayView.alpha = 1
        }
    }

    @objc func dismissImagePreview(_ gesture: UITapGestureRecognizer) {
        guard let overlayView = gesture.view else { return }
        UIView.animate(
            withDuration: 0.18,
            animations: {
                overlayView.alpha = 0
            },
            completion: { _ in
                overlayView.removeFromSuperview()
            }
        )
    }

    func applyConnectionStateUI() {
        // Временный индикатор статуса WS (можно удалить после защиты).
        switch connectionState {
        case .connected:
            connectionStatusLabel.text = "Online"
            connectionStatusLabel.textColor = .systemGreen
        case .connecting:
            connectionStatusLabel.text = "Connecting…"
            connectionStatusLabel.textColor = .systemOrange
        case .disconnected:
            connectionStatusLabel.text = "Offline"
            connectionStatusLabel.textColor = .secondaryLabel
        case let .failedHandshake(code):
            connectionStatusLabel.text = "WS \(code)"
            connectionStatusLabel.textColor = .systemRed
        }
    }

    func shouldShowDateSeparator(at section: Int) -> Bool {
        guard section >= 0, section < messageItems.count else { return false }
        if section == 0 { return true }
        let current = messageItems[section].sentDate
        let prev = messageItems[section - 1].sentDate
        return !Calendar.current.isDate(current, inSameDayAs: prev)
    }

    func dateSeparatorText(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Сегодня"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }

    func loadMedia(url: URL, messageId: String, imageView: UIImageView) {
        let key = url.absoluteString
        if let cached = mediaCache[key] {
            imageView.image = cached
            return
        }
        if mediaInFlight.contains(key) {
            imageView.image = UIImage(systemName: "photo") ?? UIImage()
            return
        }
        mediaInFlight.insert(key)
        imageView.image = UIImage(systemName: "photo") ?? UIImage()
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self else { return }

            let httpCode = (response as? HTTPURLResponse)?.statusCode
            if let error {
                DispatchQueue.main.async {
                    self.mediaInFlight.remove(key)
                }
#if DEBUG
                print("[ChatMedia] load failed url=\(key) error=\(error)")
#endif
                return
            }
            guard let data, !data.isEmpty, httpCode == nil || (200...299).contains(httpCode ?? 200) else {
                DispatchQueue.main.async {
                    self.mediaInFlight.remove(key)
                }
#if DEBUG
                print("[ChatMedia] bad response url=\(key) status=\(httpCode ?? -1) bytes=\(data?.count ?? 0)")
#endif
                return
            }
            guard let image = UIImage(data: data) else {
                DispatchQueue.main.async {
                    self.mediaInFlight.remove(key)
                }
#if DEBUG
                print("[ChatMedia] decode failed url=\(key) bytes=\(data.count)")
#endif
                return
            }

            DispatchQueue.main.async {
                self.mediaInFlight.remove(key)
                self.mediaCache[key] = image

                // Update visible cell if it's still on screen.
                if let index = self.messageItems.firstIndex(where: { $0.messageId == messageId }) {
                    let indexPath = IndexPath(item: 0, section: index)
                    if let cell = self.messagesCollectionView.cellForItem(at: indexPath) as? MediaMessageCell {
                        cell.imageView.image = image
                    } else {
                        if self.isContextMenuActive {
                            self.deferredReloadNeeded = true
                            return
                        }
                        self.messagesCollectionView.reloadSections(IndexSet(integer: index))
                    }
                } else {
                    if self.isContextMenuActive {
                        self.deferredReloadNeeded = true
                        return
                    }
                    self.messagesCollectionView.reloadData()
                }
            }
        }.resume()
    }

    func loadVideoThumbnail(url: URL, messageId: String, imageView: UIImageView) {
        let key = url.absoluteString
        if let cached = videoThumbnailCache[key] {
            imageView.image = cached
            return
        }
        imageView.image = UIImage(systemName: "play.rectangle.fill") ?? UIImage()
        guard !videoThumbnailInFlight.contains(key) else { return }
        videoThumbnailInFlight.insert(key)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let image = Self.makeVideoThumbnail(url: url)
            DispatchQueue.main.async {
                guard let self else { return }
                self.videoThumbnailInFlight.remove(key)
                guard let image else { return }
                self.videoThumbnailCache[key] = image
                if let index = self.messageItems.firstIndex(where: { $0.messageId == messageId }) {
                    let indexPath = IndexPath(item: 0, section: index)
                    if let cell = self.messagesCollectionView.cellForItem(at: indexPath) as? MediaMessageCell {
                        cell.imageView.image = image
                    } else if !self.isContextMenuActive {
                        self.messagesCollectionView.reloadSections(IndexSet(integer: index))
                    } else {
                        self.deferredReloadNeeded = true
                    }
                }
            }
        }
    }

    static func makeVideoThumbnail(url: URL) -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 440, height: 320)
        do {
            let cgImage = try generator.copyCGImage(at: CMTime(seconds: 0.2, preferredTimescale: 600), actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }
}

extension ChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        guard let image = info[.originalImage] as? UIImage else { return }
        interactor?.sendPhoto(image)
    }
}

extension ChatViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let item = results.first?.itemProvider else { return }
        if item.canLoadObject(ofClass: UIImage.self) {
            item.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                guard let image = object as? UIImage else { return }
                DispatchQueue.main.async {
                    self?.interactor?.sendPhoto(image)
                }
            }
            return
        }

        guard item.hasItemConformingToTypeIdentifier(UTType.movie.identifier) else { return }
        item.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { [weak self] url, _ in
            guard let url else { return }
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("chat-video-\(UUID().uuidString)")
                .appendingPathExtension(url.pathExtension.isEmpty ? "mov" : url.pathExtension)
            do {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.copyItem(at: url, to: destination)
                DispatchQueue.main.async {
                    self?.interactor?.sendVideo(destination)
                }
            } catch {
                DispatchQueue.main.async {
                    self?.showError(error.localizedDescription)
                }
            }
        }
    }
}
