//
//  VerificationVC.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 01.04.2026.
//

import UIKit

final class VerificationVC: UIViewController, UITextFieldDelegate {
    var interactor: VerificationBusinessLogic?

    private let codeLength = 4

    private lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 17, weight: .regular)
        label.textColor = .label
        label.numberOfLines = 0
        label.textAlignment = .left
        return label
    }()

    private lazy var hiddenTextField: UITextField = {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.keyboardType = .numberPad
        textField.textContentType = .oneTimeCode
        textField.tintColor = .clear
        textField.textColor = .clear
        textField.delegate = self
        return textField
    }()

    private lazy var codeLabels: [UILabel] = (0..<codeLength).map { _ in
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .monospacedDigitSystemFont(ofSize: 28, weight: .semibold)
        label.textAlignment = .center
        label.textColor = .label
        label.backgroundColor = .white
        label.layer.cornerRadius = 16
        label.layer.borderWidth = 1.5
        label.layer.borderColor = UIColor.black.cgColor
        label.clipsToBounds = true
        NSLayoutConstraint.activate([
            label.heightAnchor.constraint(equalToConstant: 50),
            label.widthAnchor.constraint(equalToConstant: 50)
        ])
        return label
    }

    private lazy var codeStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: codeLabels)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .equalSpacing
        stackView.spacing = 12
        return stackView
    }()

    private lazy var confirmButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Подтвердить", for: .normal)
        button.backgroundColor = .label
        button.setTitleColor(.systemBackground, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.layer.cornerRadius = 20
        button.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        return button
    }()

    private lazy var newPasswordTextField: UITextField = {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholder = "Введите новый пароль"
        textField.backgroundColor = .white
        textField.layer.cornerRadius = 22
        textField.layer.borderWidth = 1
        textField.layer.borderColor = UIColor.systemGray5.cgColor
        textField.font = .systemFont(ofSize: 17, weight: .regular)
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 18, height: 1))
        textField.leftViewMode = .always
        textField.isSecureTextEntry = true
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.isHidden = true
        return textField
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupLayout()
        interactor?.loadInitialState()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        hiddenTextField.becomeFirstResponder()
    }

    func display(description: String, showsPasswordField: Bool) {
        descriptionLabel.text = description
        newPasswordTextField.isHidden = !showsPasswordField
    }

    private func setupView() {
        view.backgroundColor = .white
        title = "Подтвеждение почты"
        navigationItem.largeTitleDisplayMode = .never

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        view.addGestureRecognizer(tapGesture)
    }

    private func setupLayout() {
        view.addSubview(descriptionLabel)
        view.addSubview(codeStackView)
        view.addSubview(hiddenTextField)
        view.addSubview(newPasswordTextField)
        view.addSubview(confirmButton)

        NSLayoutConstraint.activate([
            descriptionLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            descriptionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            descriptionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            codeStackView.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 28),
            codeStackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            hiddenTextField.topAnchor.constraint(equalTo: codeStackView.bottomAnchor),
            hiddenTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hiddenTextField.widthAnchor.constraint(equalToConstant: 1),
            hiddenTextField.heightAnchor.constraint(equalToConstant: 1),

            newPasswordTextField.topAnchor.constraint(equalTo: codeStackView.bottomAnchor, constant: 20),
            newPasswordTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            newPasswordTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            newPasswordTextField.heightAnchor.constraint(equalToConstant: 54),

            confirmButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            confirmButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            confirmButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            confirmButton.heightAnchor.constraint(equalToConstant: 52)
        ])
    }

    @objc private func handleTap() {
        hiddenTextField.becomeFirstResponder()
    }

    @objc private func confirmTapped() {
        interactor?.verify(
            code: hiddenTextField.text ?? "",
            newPassword: newPasswordTextField.isHidden ? nil : newPasswordTextField.text
        )
    }

    private func updateCodeUI() {
        let code = Array(hiddenTextField.text ?? "")

        for (index, label) in codeLabels.enumerated() {
            if index < code.count {
                label.text = String(code[index])
                label.layer.borderColor = UIColor.black.cgColor
            } else {
                label.text = nil
                label.layer.borderColor = UIColor.black.cgColor
            }
        }
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard string.isEmpty || string.allSatisfy(\.isNumber) else { return false }
        let currentText = textField.text ?? ""
        guard let textRange = Range(range, in: currentText) else { return false }

        let updatedText = currentText.replacingCharacters(in: textRange, with: string)
        guard updatedText.count <= codeLength else { return false }

        textField.text = updatedText
        updateCodeUI()
        return false
    }
}
