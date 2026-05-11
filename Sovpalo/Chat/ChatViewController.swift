import UIKit
import MessageKit
import InputBarAccessoryView
import PhotosUI

final class ChatViewController: MessagesViewController {
    var interactor: ChatBusinessLogic?
    var groupName: String = "Чат"
    private var connectionState: ChatWebSocketState = .disconnected
    private let connectionStatusLabel = UILabel()

    private var messages: [ChatMessageView] = []
    private var messageItems: [ChatMessageItem] = []
    private var hasMore = false
    private var isLoadingOlder = false
    private var isContextMenuActive = false
    private var deferredApply: (messages: [ChatMessageView], hasMore: Bool)?
    private var deferredReloadNeeded = false
    private var avatarCache: [String: UIImage] = [:]
    private var mediaCache: [String: UIImage] = [:]
    private var mediaInFlight: Set<String> = []
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
        let backButton = UIBarButtonItem(
            image: UIImage(systemName: "chevron.backward"),
            style: .plain,
            target: self,
            action: #selector(didTapBack)
        )
        backButton.tintColor = .label
        navigationItem.leftBarButtonItem = backButton
        setupMessageKit()
        setupInputBar()
        setupInlineBackButton()
        interactor?.loadInitial()
    }

    private func setupHeaderTitle() {
        let titleLabel = UILabel()
        titleLabel.text = groupName
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = UIColor(hex: "#7079FB")
        titleLabel.textAlignment = .center

        connectionStatusLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        connectionStatusLabel.textAlignment = .center
        connectionStatusLabel.text = ""

        let stack = UIStackView(arrangedSubviews: [titleLabel, connectionStatusLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 2
        navigationItem.titleView = stack
        applyConnectionStateUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        (tabBarController as? MainTabBarController)?.setCustomTabBarHidden(true, animated: true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        (tabBarController as? MainTabBarController)?.setCustomTabBarHidden(false, animated: true)
        interactor?.stop()
    }

    private func setupMessageKit() {
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messagesCollectionView.delegate = self
        messagesCollectionView.backgroundColor = .clear
        messagesCollectionView.contentInset.top = 8
        scrollsToLastItemOnKeyboardBeginsEditing = true
        maintainPositionOnInputBarHeightChanged = true
        showMessageTimestampOnSwipeLeft = false
    }

    private func setupInputBar() {
        messageInputBar.delegate = self
        messageInputBar.backgroundView.backgroundColor = .clear
        messageInputBar.inputTextView.backgroundColor = .white
        messageInputBar.inputTextView.layer.cornerRadius = 18
        messageInputBar.inputTextView.placeholder = "Напишите сообщение..."
       // messageInputBar.inputTextView.textContainerInset = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 10)
        messageInputBar.inputTextView.layer.borderWidth = 1
        messageInputBar.inputTextView.layer.borderColor = UIColor.systemGray5.cgColor
        messageInputBar.leftStackView.alignment = .center

        let sendButton = InputBarButtonItem()
        sendButton.setSize(CGSize(width: 36, height: 36), animated: false)
        sendButton.backgroundColor = UIColor(hex: "#F6F77A")
        sendButton.layer.cornerRadius = 18
        sendButton.layer.masksToBounds = true
        sendButton.tintColor = UIColor(hex: "#7079FB")
        sendButton.setImage(UIImage(systemName: "paperplane.fill"), for: .normal)
        sendButton.onTouchUpInside { [weak self] _ in
            self?.didTapSend()
        }
        messageInputBar.setStackViewItems([sendButton], forStack: .right, animated: false)
        messageInputBar.setRightStackViewWidthConstant(to: 22, animated: false)

        let cameraButton = InputBarButtonItem()
        cameraButton.setSize(CGSize(width: 36, height: 36), animated: false)
        cameraButton.backgroundColor = UIColor(hex: "#F6F77A")
        cameraButton.layer.cornerRadius = 18
        cameraButton.layer.masksToBounds = true
        cameraButton.tintColor = UIColor(hex: "#7079FB")
        cameraButton.setImage(UIImage(systemName: "camera.fill"), for: .normal)
        cameraButton.onTouchUpInside { [weak self] _ in
            self?.presentImageSourceSheet()
        }
        messageInputBar.setStackViewItems([cameraButton], forStack: .left, animated: false)
        messageInputBar.setLeftStackViewWidthConstant(to: 22, animated: false)
       // messageInputBar.padding = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
    }

    private func setupInlineBackButton() {
        view.addSubview(inlineBackButton)
        inlineBackButton.addTarget(self, action: #selector(didTapBack), for: .touchUpInside)
        NSLayoutConstraint.activate([
            inlineBackButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            inlineBackButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            inlineBackButton.widthAnchor.constraint(equalToConstant: 28),
            inlineBackButton.heightAnchor.constraint(equalToConstant: 28)
        ])
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
        }

        return ChatMessageItem(
            messageId: "\(view.id)",
            sender: sender,
            sentDate: view.sentAt,
            kind: kind
        )
    }

    private func presentImageSourceSheet() {
        let sheet = UIAlertController(title: "Фото", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Камера", style: .default) { [weak self] _ in
            self?.presentCamera()
        })
        sheet.addAction(UIAlertAction(title: "Галерея", style: .default) { [weak self] _ in
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
        config.filter = .images
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
        let key = (avatarURL ?? (message.sender.senderId + "|" + message.sender.displayName))
        if let cached = avatarCache[key] {
            return cached
        }

        if let avatarURL,
           let url = URL(string: avatarURL) {
            loadAvatar(url: url, cacheKey: key, messageId: message.messageId)
        }

        let isCurrent = message.sender.senderId == "me"
        let image = makeAvatarImage(
            initials: initials(from: message.sender.displayName),
            background: isCurrent ? (UIColor(hex: "#7079FB") ?? .systemIndigo) : (UIColor(hex: "#F6F77A") ?? .systemYellow),
            textColor: isCurrent ? .white : .black
        )
        avatarCache[key] = image
        return image
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
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard
                let self,
                let data,
                let image = UIImage(data: data)
            else { return }
            DispatchQueue.main.async {
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

            let edit = UIAction(
                title: "Изменить",
                image: UIImage(systemName: "pencil")
            ) { [weak self] _ in
                self?.interactor?.editMessageRequested(id: vm.id)
            }

            let delete = UIAction(
                title: "Удалить",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { [weak self] _ in
                self?.interactor?.deleteMessage(id: vm.id)
            }

            return UIMenu(title: "", children: [edit, delete])
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
        guard case let .photo(media) = message.kind else { return }
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        if let image = media.image {
            imageView.image = image
            return
        }
        if let url = media.url {
            loadMedia(url: url, messageId: message.messageId, imageView: imageView)
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

private extension ChatViewController {
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
        guard let item = results.first?.itemProvider, item.canLoadObject(ofClass: UIImage.self) else { return }
        item.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let image = object as? UIImage else { return }
            DispatchQueue.main.async {
                self?.interactor?.sendPhoto(image)
            }
        }
    }
}
