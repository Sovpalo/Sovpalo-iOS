//
//  RegisterViewController.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 31.01.2026.
//

import UIKit

final class RegisterViewController: UIViewController, UITextFieldDelegate {
    var interactor: RegisterBusinessLogic?

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Регистрация"
        label.font = UIFont.systemFont(ofSize: 28, weight: .semibold)
        label.textAlignment = .center
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private func makeTextField(placeholder: String) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.font = UIFont.systemFont(ofSize: 17)
        textField.backgroundColor = UIColor(white: 0.95, alpha: 1)
        textField.layer.cornerRadius = 20
        textField.layer.masksToBounds = true
        textField.borderStyle = .none
        textField.setLeftPaddingPoints(16)
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.heightAnchor.constraint(equalToConstant: 44).isActive = true
        return textField
    }

    private lazy var nameTextField: UITextField = {
        let tf = makeTextField(placeholder: "Никнейм")
        tf.autocapitalizationType = .none
        return tf
    }()
    private lazy var emailTextField: UITextField = {
        let tf = makeTextField(placeholder: "E-mail")
        tf.autocapitalizationType = .none
        return tf
    }()
    private lazy var passwordTextField: UITextField = {
        let tf = makeTextField(placeholder: "Пароль")
        tf.isSecureTextEntry = true
        tf.autocapitalizationType = .none
        return tf
    }()

    private lazy var passwordRequirementsLabels: [UILabel] = [
        makePasswordRequirementLabel(),
        makePasswordRequirementLabel(),
        makePasswordRequirementLabel(),
        makePasswordRequirementLabel(),
        makePasswordRequirementLabel()
    ]

    private lazy var passwordRequirementsStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: passwordRequirementsLabels)
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var passwordSectionStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [
            passwordTextField,
            passwordRequirementsStack
        ])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var textFieldsStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [
            nameTextField, emailTextField, passwordSectionStack
        ])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let registerButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Зарегистрироваться", for: .normal)
        button.backgroundColor = .label
        button.setTitleColor(.systemBackground, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        button.layer.cornerRadius = 20
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    override func viewDidLoad() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
            tapGesture.cancelsTouchesInView = false
            view.addGestureRecognizer(tapGesture)
        
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        passwordTextField.delegate = self
        passwordTextField.addTarget(self, action: #selector(passwordDidChange), for: .editingChanged)

        view.addSubview(titleLabel)
        view.addSubview(textFieldsStack)
        view.addSubview(registerButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 56),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            textFieldsStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 40),
            textFieldsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            textFieldsStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            registerButton.heightAnchor.constraint(equalToConstant: 52),
            registerButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            registerButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            registerButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24)
        ])
        
        registerButton.addTarget(self, action: #selector(registerPressed), for: .touchUpInside)
        applyInitialPasswordRequirementsState()
    }

    func setRegisterLoading(_ isLoading: Bool) {
        registerButton.isEnabled = !isLoading
        registerButton.alpha = isLoading ? 0.55 : 1
        nameTextField.isEnabled = !isLoading
        emailTextField.isEnabled = !isLoading
        passwordTextField.isEnabled = !isLoading
    }

    func displayPasswordValidation(_ viewModel: RegisterPasswordValidationViewModel) {
        for (label, item) in zip(passwordRequirementsLabels, viewModel.items) {
            label.text = item.text
            label.textColor = item.color
        }
    }
    
    @objc private func registerPressed() {
        let username = nameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let email = emailTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let password = passwordTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !username.isEmpty, !email.isEmpty, !password.isEmpty else {
            let alert = UIAlertController(
                title: "Не все поля заполнены",
                message: "Пожалуйста, заполните все поля перед регистрацией.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        interactor?.register(username: username, email: email, password: password)
    }

    @objc private func passwordDidChange() {
        interactor?.validatePassword(passwordTextField.text ?? "")
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        guard textField === passwordTextField else { return }
        interactor?.validatePassword(passwordTextField.text ?? "")
    }

    private func applyInitialPasswordRequirementsState() {
        displayPasswordValidation(
            RegisterPasswordValidationViewModel(items: [
                RegisterPasswordRequirementViewModel(text: "• 1 заглавная буква (A-Z)", color: .black),
                RegisterPasswordRequirementViewModel(text: "• 1 прописная буква (a-z)", color: .black),
                RegisterPasswordRequirementViewModel(text: "• 3 цифры (1-9)", color: .black),
                RegisterPasswordRequirementViewModel(text: "• 1 спец символ", color: .black),
                RegisterPasswordRequirementViewModel(text: "• минимум 8 символов", color: .black)
            ])
        )
    }

    private func makePasswordRequirementLabel() -> UILabel {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = .black
        label.numberOfLines = 1
        return label
    }
}

// MARK: - Текстовое поле с отступом слева
private extension UITextField {
    func setLeftPaddingPoints(_ amount: CGFloat) {
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: amount, height: self.frame.height))
        leftView = paddingView
        leftViewMode = .always
    }
}
