//
//  RegisterViewController.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 31.01.2026.
//

import UIKit

final class RegisterViewController: UIViewController {
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
        let tf = makeTextField(placeholder: "E-mail")
        tf.autocapitalizationType = .none
        return tf
    }()
    private lazy var emailTextField: UITextField = {
        let tf = makeTextField(placeholder: "ID аккаунта")
        tf.autocapitalizationType = .none
        return tf
    }()
    private lazy var passwordTextField: UITextField = {
        let tf = makeTextField(placeholder: "Пароль")
        tf.isSecureTextEntry = true
        tf.autocapitalizationType = .none
        return tf
    }()

    private lazy var textFieldsStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [
            nameTextField, emailTextField, passwordTextField
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
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

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
    }
    
    @objc private func registerPressed() {
        let username = nameTextField.text ?? ""
        let email = emailTextField.text ?? ""
        let password = passwordTextField.text ?? ""
        interactor?.register(username: username, email: email, password: password)
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

