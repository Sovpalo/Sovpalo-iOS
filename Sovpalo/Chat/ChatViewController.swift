import UIKit
import MessageKit
import InputBarAccessoryView
import PhotosUI

final class ChatViewController: MessagesViewController {
    var interactor: ChatBusinessLogic?
    var groupName: String = "Чат"

    private var messages: [ChatMessageView] = []
    private var messageItems: [ChatMessageItem] = []
    private var hasMore = false
    private var isLoadingOlder = false
    private var avatarCache: [String: UIImage] = [:]
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
        navigationItem.titleView = titleLabel
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        (tabBarController as? MainTabBarController)?.setCustomTabBarHidden(true, animated: true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        (tabBarController as? MainTabBarController)?.setCustomTabBarHidden(false, animated: true)
    }

    private func setupMessageKit() {
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
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

    func showError(_ message: String) {
        let lower = message.lowercased()
        if lower.contains("chat doesn't exist")
            || lower.contains("chat does not exist")
            || lower.contains("чат не существует") {
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
                image: image,
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
                    self.messagesCollectionView.reloadSections(IndexSet(integer: index))
                } else {
                    self.messagesCollectionView.reloadData()
                }
            }
        }.resume()
    }
}

extension ChatViewController: MessagesDataSource {
    var currentSender: any SenderType {
        ChatSender(senderId: "me", displayName: "Вы")
    }

    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        messageItems.count
    }

    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        messageItems[indexPath.section]
    }

    func cellTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return NSAttributedString(
            string: formatter.string(from: message.sentDate),
            attributes: [
                .font: UIFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: UIColor.secondaryLabel
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
}

extension ChatViewController: MessagesLayoutDelegate {
    func cellTopLabelHeight(for message: any MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        16
    }

    func avatarSize(for message: any MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGSize? {
        CGSize(width: 30, height: 30)
    }
}


extension ChatViewController: InputBarAccessoryViewDelegate {}

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
