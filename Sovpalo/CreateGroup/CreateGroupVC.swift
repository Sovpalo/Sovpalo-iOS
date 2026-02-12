//
//  CreateGroupVC.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 12.02.2026.
//

import UIKit

final class CreateGroupVC: UIViewController {
    var interactor: CreateGroupBusinessLogic?

    // MARK: - UI
    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Новая компания"
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Введи название компании, далее сможешь пригласить своих друзей"
        label.font = .systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private func makeTextField(placeholder: String, isSecure: Bool = false) -> UITextField {
        let tf = UITextField()
        tf.placeholder = placeholder
        tf.isSecureTextEntry = isSecure
        tf.borderStyle = .none
        tf.textAlignment = .center
        tf.backgroundColor = .secondarySystemBackground
        tf.layer.cornerRadius = 24
        tf.layer.masksToBounds = true
        tf.heightAnchor.constraint(equalToConstant: 44).isActive = true
        return tf
    }

    private lazy var companyNameField = makeTextField(placeholder: "Название компании")
    private lazy var descriptionNameField = makeTextField(placeholder: "Описание (опционально)")

    private let createButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Создать компанию", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.backgroundColor = UIColor(hex: "#7079FB")
        button.tintColor = .white
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 24
        button.layer.masksToBounds = true
        button.heightAnchor.constraint(equalToConstant: 52).isActive = true
        return button
    }()

    private let stack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.distribution = .fill
        stack.spacing = 12
        return stack
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.backButtonDisplayMode = .minimal // keep native back

        setupLayout()
        createButton.addTarget(self, action: #selector(didTapCreate), for: .touchUpInside)

        // Keyboard dismissal on scroll tap
        let tap = UITapGestureRecognizer(target: self, action: #selector(endEditing))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        // Observe keyboard to adjust inset
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChange(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Layout
    private func setupLayout() {
        // Add bottom button anchored to safe area (must be added before scrollView constraints)
        view.addSubview(createButton)
        createButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            createButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            createButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            createButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])

        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: createButton.topAnchor, constant: -12)
        ])

        scrollView.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        contentView.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false

        // Header group
        let header = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        header.axis = .vertical
        header.spacing = 8
        header.alignment = .center

        // Fields group with only companyNameField
        let fields = UIStackView(arrangedSubviews: [companyNameField, descriptionNameField])
        fields.axis = .vertical
        fields.spacing = 12

        // Main stack content
        stack.addArrangedSubview(header)
        stack.setCustomSpacing(24, after: header)
        stack.addArrangedSubview(fields)
        stack.setCustomSpacing(24, after: fields)
        // Removed stack.addArrangedSubview(createButton)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -24)
        ])
        let centerY = stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        centerY.priority = .defaultHigh
        centerY.isActive = true

        // Also pin contentView min height to safe area so button can sit near bottom on tall screens
        let minHeight = contentView.heightAnchor.constraint(greaterThanOrEqualTo: guide.heightAnchor)
        minHeight.priority = .defaultLow
        minHeight.isActive = true
    }

    // MARK: - Actions
    @objc private func didTapCreate() {
        view.endEditing(true)
        let company = companyNameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let description = descriptionNameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        interactor?.createCompany(name: company, description: description)
    }

    @objc private func endEditing() {
        view.endEditing(true)
    }

    @objc private func keyboardWillChange(_ note: Notification) {
        guard
            let userInfo = note.userInfo,
            let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
            let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval,
            let curveRaw = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
        else { return }

        let converted = view.convert(endFrame, from: nil)
        let intersects = converted.intersects(view.bounds)
        let bottomInset = intersects ? max(0, view.bounds.maxY - converted.minY - view.safeAreaInsets.bottom) + 12 : 0

        UIView.animate(withDuration: duration, delay: 0, options: UIView.AnimationOptions(rawValue: curveRaw << 16), animations: {
            self.scrollView.contentInset.bottom = bottomInset
            self.scrollView.verticalScrollIndicatorInsets.bottom = bottomInset
        }, completion: nil)
    }
}

