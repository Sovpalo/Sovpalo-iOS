//
//  CreateIdeasVC.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 26.03.2026.
//

import UIKit

final class CreateIdeasVC: UIViewController {
    var interactor: CreateIdeasBusinessLogic?

    private let titleField = UITextField()
    private let descriptionTextView = UITextView()
    private let descriptionPlaceholderLabel = UILabel()
    private let doneButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "Новая идея"
        setupNavigation()
        setupUI()
        setupActions()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    private func setupNavigation() {
        navigationItem.largeTitleDisplayMode = .never
    }

    private func setupUI() {
        let stack = UIStackView(arrangedSubviews: [
            configuredField(titleField, placeholder: "Название идеи"),
            makeDescriptionContainer()
        ])
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

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
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

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

    private func makeDescriptionContainer() -> UIView {
        let container = UIView()
        container.backgroundColor = .white
        container.layer.cornerRadius = 22
        container.layer.borderWidth = 1
        container.layer.borderColor = UIColor.systemGray5.cgColor
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: 140).isActive = true

        descriptionTextView.backgroundColor = .clear
        descriptionTextView.font = .systemFont(ofSize: 17, weight: .regular)
        descriptionTextView.textColor = .label
        descriptionTextView.delegate = self
        descriptionTextView.translatesAutoresizingMaskIntoConstraints = false

        descriptionPlaceholderLabel.text = "Описание"
        descriptionPlaceholderLabel.font = .systemFont(ofSize: 17, weight: .regular)
        descriptionPlaceholderLabel.textColor = .placeholderText
        descriptionPlaceholderLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(descriptionTextView)
        container.addSubview(descriptionPlaceholderLabel)

        NSLayoutConstraint.activate([
            descriptionTextView.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            descriptionTextView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            descriptionTextView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            descriptionTextView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),

            descriptionPlaceholderLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            descriptionPlaceholderLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 19),
            descriptionPlaceholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -19)
        ])

        return container
    }

    private func setupActions() {
        doneButton.addTarget(self, action: #selector(didTapDone), for: .touchUpInside)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }

    @objc private func didTapDone() {
        let request = CreateIdeaRequest(
            title: titleField.text ?? "",
            description: descriptionTextView.text ?? ""
        )

        interactor?.createIdea(request: request)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    func showError(message: String) {
        let alert = UIAlertController(title: "Ошибка", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "ОК", style: .default))
        present(alert, animated: true)
    }

    func showSuccessAndClose() {
        navigationController?.popViewController(animated: true)
    }
}

extension CreateIdeasVC: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        descriptionPlaceholderLabel.isHidden = !textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
