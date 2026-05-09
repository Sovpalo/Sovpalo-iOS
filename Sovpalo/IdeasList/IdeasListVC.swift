//
//  IdeasListVC.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 26.03.2026.
//

import UIKit

final class IdeasListVC: UIViewController {
    var interactor: IdeasListBusinessLogic?

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 34, weight: .bold)
        label.textColor = UIColor(hex: "#7079FB")
        label.textAlignment = .center
        label.text = "Идеи"
        return label
    }()

    private let tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.showsVerticalScrollIndicator = false
        table.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 100, right: 0)
        return table
    }()

    private let bottomButtonStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 20
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let aiButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .white
        button.tintColor = UIColor(hex: "#6E73F4")
        button.setImage(UIImage(systemName: "wand.and.stars"), for: .normal)
        button.layer.cornerRadius = 28
        button.layer.borderWidth = 2
        button.layer.borderColor = (UIColor(hex: "#6E73F4") ?? .systemIndigo)
            .withAlphaComponent(0.35).cgColor
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.08
        button.layer.shadowRadius = 8
        button.layer.shadowOffset = CGSize(width: 0, height: 3)
        button.accessibilityLabel = "Идея с ИИ"
        return button
    }()

    private let floatingButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor(hex: "#6E73F4")
        button.tintColor = UIColor(hex: "#F6F77A")
        button.setImage(UIImage(systemName: "plus"), for: .normal)
        button.layer.cornerRadius = 33
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.12
        button.layer.shadowRadius = 10
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.accessibilityLabel = "Новая идея"
        return button
    }()

    private var ideas: [IdeaCardViewModel] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        setupLayout()
        setupTable()
        setupActions()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        interactor?.loadIdeas()
    }

    func applyIdeas(_ ideas: [IdeaCardViewModel]) {
        self.ideas = ideas
        tableView.reloadData()
    }

    func applyLikeUpdate(_ idea: IdeaCardViewModel) {
        guard let index = ideas.firstIndex(where: { $0.id == idea.id }) else { return }
        ideas[index] = idea
        tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
    }

    func showError(message: String) {
        let alert = UIAlertController(title: "Ошибка", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "ОК", style: .default))
        present(alert, animated: true)
    }

    private func setupLayout() {
        [titleLabel, tableView, bottomButtonStack].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        bottomButtonStack.addArrangedSubview(aiButton)
        bottomButtonStack.addArrangedSubview(floatingButton)

        aiButton.translatesAutoresizingMaskIntoConstraints = false
        floatingButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            aiButton.widthAnchor.constraint(equalToConstant: 56),
            aiButton.heightAnchor.constraint(equalToConstant: 56),
            floatingButton.widthAnchor.constraint(equalToConstant: 66),
            floatingButton.heightAnchor.constraint(equalToConstant: 66)
        ])

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            bottomButtonStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bottomButtonStack.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -AppLayout.floatingButtonBottomOffset
            )
        ])
    }

    private func setupTable() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(IdeaCardCell.self, forCellReuseIdentifier: IdeaCardCell.identifier)
    }

    private func setupActions() {
        floatingButton.addTarget(self, action: #selector(didTapPrimaryCreate), for: .touchUpInside)
        aiButton.addTarget(self, action: #selector(didTapAIButton), for: .touchUpInside)
    }

    @objc private func didTapPrimaryCreate() {
        let sheet = UIAlertController(title: "Новая идея", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Создать идею", style: .default) { [weak self] _ in
            self?.interactor?.openCreateIdeaManually()
        })
        sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = floatingButton
            pop.sourceRect = floatingButton.bounds
        }
        present(sheet, animated: true)
    }

    @objc private func didTapAIButton() {
        interactor?.openAIGenerateIdea()
    }
}

extension IdeasListVC: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        ideas.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let idea = ideas[indexPath.row]
        guard let cell = tableView.dequeueReusableCell(withIdentifier: IdeaCardCell.identifier, for: indexPath) as? IdeaCardCell else {
            return UITableViewCell()
        }

        cell.configure(with: idea)
        cell.onLikeTap = { [weak self] in
            self?.interactor?.toggleLike(ideaId: idea.id)
        }

        return cell
    }
}

private final class IdeaCardCell: UITableViewCell {
    static let identifier = "IdeaCardCell"

    var onLikeTap: (() -> Void)?

    private let shadowView = UIView()
    private let cardView = UIView()
    private let likeButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let authorLabel = UILabel()
    private let descriptionLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onLikeTap = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        shadowView.layer.shadowPath = UIBezierPath(roundedRect: shadowView.bounds, cornerRadius: 22).cgPath
    }

    func configure(with idea: IdeaCardViewModel) {
        cardView.backgroundColor = .white

        titleLabel.text = idea.title
        authorLabel.text = idea.authorName
        descriptionLabel.text = idea.descriptionText
        descriptionLabel.isHidden = (idea.descriptionText?.isEmpty ?? true)

        updateLikeButton(isLiked: idea.isLiked, likesText: idea.likesText)
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

        cardView.layer.cornerRadius = 22
        cardView.layer.masksToBounds = true

        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0

        authorLabel.font = .systemFont(ofSize: 15, weight: .medium)
        authorLabel.textColor = .secondaryLabel

        descriptionLabel.font = .systemFont(ofSize: 14, weight: .regular)
        descriptionLabel.textColor = .darkGray
        descriptionLabel.numberOfLines = 2

        likeButton.addTarget(self, action: #selector(didTapLike), for: .touchUpInside)
        likeButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        likeButton.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        contentView.addSubview(shadowView)
        shadowView.addSubview(cardView)

        [titleLabel, authorLabel, descriptionLabel, likeButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            cardView.addSubview($0)
        }

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
            cardView.bottomAnchor.constraint(equalTo: shadowView.bottomAnchor),

            likeButton.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            likeButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),

            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            // Reserve fixed space on the right so long titles never overlap like button.
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -92),

            authorLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            authorLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            authorLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),

            descriptionLabel.topAnchor.constraint(equalTo: authorLabel.bottomAnchor, constant: 8),
            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            descriptionLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16)
        ])
    }

    private func updateLikeButton(isLiked: Bool, likesText: String) {
        var config = UIButton.Configuration.plain()
        config.title = likesText
        config.image = UIImage(systemName: isLiked ? "heart.fill" : "heart")
        config.imagePadding = 4
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        config.cornerStyle = .capsule
        config.baseForegroundColor = isLiked ? .systemRed : .label
        config.background.strokeWidth = 1
        config.background.cornerRadius = 16

        if isLiked {
            config.background.backgroundColor = UIColor.systemRed.withAlphaComponent(0.08)
            config.background.strokeColor = UIColor.systemRed.withAlphaComponent(0.15)
        } else {
            config.background.backgroundColor = UIColor.clear
            config.background.strokeColor = UIColor.systemGray4
        }

        likeButton.configuration = config
    }

    @objc private func didTapLike() {
        onLikeTap?()
    }
}
