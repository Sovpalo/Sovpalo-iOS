//
//  AIGenerateIdeaVC.swift
//  Sovpalo
//

import UIKit

private let aiBrandColor = UIColor(hex: "#6E73F4") ?? .systemIndigo

final class AIGenerateIdeaVC: UIViewController {
    var interactor: AIGenerateIdeaBusinessLogic?

    private let scrollView: UIScrollView = {
        let v = UIScrollView()
        v.alwaysBounceVertical = true
        v.keyboardDismissMode = .interactive
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let contentStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 20
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 15, weight: .medium)
        l.textColor = .secondaryLabel
        l.numberOfLines = 0
        l.text = "Опишите, какую идею вы хотите получить — мы подготовим несколько черновиков."
        return l
    }()

    private let requestContainer = UIView()
    private let requestTextView: UITextView = {
        let tv = UITextView()
        tv.font = .systemFont(ofSize: 17, weight: .regular)
        tv.textColor = .label
        tv.backgroundColor = .clear
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private let requestPlaceholder: UILabel = {
        let l = UILabel()
        l.text = "Ваш запрос…"
        l.font = .systemFont(ofSize: 17, weight: .regular)
        l.textColor = .placeholderText
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let generateButton: UIButton = {
        let b = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.title = "Сгенерировать идеи"
        config.baseBackgroundColor = aiBrandColor
        config.baseForegroundColor = .white
        config.cornerStyle = .large
        config.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 24, bottom: 16, trailing: 24)
        b.configuration = config
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let loadingContainer: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 16
        s.isHidden = true
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let thinkingLine2: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 20, weight: .semibold)
        l.textColor = aiBrandColor
        l.text = "Let me think…"
        l.textAlignment = .center
        return l
    }()

    private let resultsStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 14
        s.isHidden = true
        return s
    }()

    private let resultsTitle: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 20, weight: .bold)
        l.textColor = .label
        l.text = "Черновики"
        return l
    }()

    private var loadingPulseTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "Идея с ИИ"
        setupNavigation()
        setupLayout()
        setupActions()
        requestTextView.delegate = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        (tabBarController as? MainTabBarController)?.setCustomTabBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        (tabBarController as? MainTabBarController)?.setCustomTabBarHidden(false, animated: animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent || isBeingDismissed {
            stopLoadingAnimations()
        }
    }

    private func setupNavigation() {
        navigationItem.largeTitleDisplayMode = .never
    }

    private func setupLayout() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        requestContainer.backgroundColor = .white
        requestContainer.layer.cornerRadius = 22
        requestContainer.layer.borderWidth = 1
        requestContainer.layer.borderColor = UIColor.systemGray5.cgColor
        requestContainer.translatesAutoresizingMaskIntoConstraints = false
        requestContainer.addSubview(requestTextView)
        requestContainer.addSubview(requestPlaceholder)

        NSLayoutConstraint.activate([
            requestTextView.topAnchor.constraint(equalTo: requestContainer.topAnchor, constant: 12),
            requestTextView.leadingAnchor.constraint(equalTo: requestContainer.leadingAnchor, constant: 12),
            requestTextView.trailingAnchor.constraint(equalTo: requestContainer.trailingAnchor, constant: -12),
            requestTextView.bottomAnchor.constraint(equalTo: requestContainer.bottomAnchor, constant: -12),
            requestTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),

            requestPlaceholder.topAnchor.constraint(equalTo: requestContainer.topAnchor, constant: 20),
            requestPlaceholder.leadingAnchor.constraint(equalTo: requestContainer.leadingAnchor, constant: 17)
        ])

        loadingContainer.addArrangedSubview(thinkingLine2)

        contentStack.addArrangedSubview(subtitleLabel)
        contentStack.addArrangedSubview(requestContainer)
        contentStack.addArrangedSubview(generateButton)
        contentStack.addArrangedSubview(loadingContainer)
        contentStack.addArrangedSubview(resultsTitle)
        contentStack.addArrangedSubview(resultsStack)

        resultsTitle.isHidden = true

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: 32)
        ])
    }

    private func setupActions() {
        generateButton.addTarget(self, action: #selector(didTapGenerate), for: .touchUpInside)
        let tap = UITapGestureRecognizer(target: self, action: #selector(endEditing))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    @objc private func endEditing() {
        view.endEditing(true)
    }

    @objc private func didTapGenerate() {
        interactor?.generateDrafts(topic: requestTextView.text ?? "")
    }

    func setLoading(_ loading: Bool) {
        if loading {
            loadingContainer.isHidden = false
            generateButton.isEnabled = false
            generateButton.configuration?.baseBackgroundColor = aiBrandColor.withAlphaComponent(0.45)
            resultsStack.isHidden = true
            resultsTitle.isHidden = true
            startThinkingPulse()
        } else {
            stopLoadingAnimations()
            loadingContainer.isHidden = true
            generateButton.isEnabled = true
            generateButton.configuration?.baseBackgroundColor = aiBrandColor
        }
    }

    private func startThinkingPulse() {
        loadingPulseTimer?.invalidate()
        var toggle = false
        loadingPulseTimer = Timer.scheduledTimer(withTimeInterval: 1.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            toggle.toggle()
            UIView.animate(withDuration: 0.45, delay: 0, options: [.curveEaseInOut, .allowUserInteraction]) {
                self.thinkingLine2.alpha = toggle ? 1 : 0.6
            }
        }
        RunLoop.main.add(loadingPulseTimer!, forMode: .common)
    }

    private func stopLoadingAnimations() {
        loadingPulseTimer?.invalidate()
        loadingPulseTimer = nil
        thinkingLine2.alpha = 1
    }

    func applyDrafts(_ drafts: [AIGeneratedDraftViewModel]) {
        resultsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for draft in drafts {
            let card = AIGeneratedDraftCardView()
            card.configure(draft: draft) { [weak self] in
                self?.interactor?.publishDraft(draft)
            }
            resultsStack.addArrangedSubview(card)
        }
        resultsStack.isHidden = drafts.isEmpty
        resultsTitle.isHidden = drafts.isEmpty
    }

    func showError(message: String) {
        let alert = UIAlertController(title: "Ошибка", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "ОК", style: .default))
        present(alert, animated: true)
    }
}

extension AIGenerateIdeaVC: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        let empty = textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        requestPlaceholder.isHidden = !empty
    }
}

// MARK: - Draft card

private final class AIGeneratedDraftCardView: UIView {
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()
    private let sourceLabel = UILabel()
    private let publishButton = UIButton(type: .system)
    private var onPublish: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        layer.cornerRadius = 20
        layer.borderWidth = 1
        layer.borderColor = UIColor.systemGray5.cgColor

        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0

        bodyLabel.font = .systemFont(ofSize: 15, weight: .regular)
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.numberOfLines = 0

        sourceLabel.font = .systemFont(ofSize: 12, weight: .medium)
        sourceLabel.textColor = aiBrandColor

        var config = UIButton.Configuration.borderedTinted()
        config.title = "Опубликовать"
        config.baseForegroundColor = aiBrandColor
        config.cornerStyle = .capsule
        publishButton.configuration = config
        publishButton.addTarget(self, action: #selector(tapPublish), for: .touchUpInside)

        let inner = UIStackView(arrangedSubviews: [titleLabel, bodyLabel, sourceLabel, publishButton])
        inner.axis = .vertical
        inner.spacing = 10
        inner.translatesAutoresizingMaskIntoConstraints = false
        inner.setCustomSpacing(14, after: sourceLabel)

        addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            inner.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            inner.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            inner.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(draft: AIGeneratedDraftViewModel, onPublish: @escaping () -> Void) {
        titleLabel.text = draft.title
        bodyLabel.text = draft.description
        sourceLabel.text = draft.source.isEmpty ? "" : "Источник: \(draft.source)"
        sourceLabel.isHidden = draft.source.isEmpty
        self.onPublish = onPublish
    }

    @objc private func tapPublish() {
        onPublish?()
    }
}
