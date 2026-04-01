//
//  ForgotPasswordVC.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 01.04.2026.
//

import UIKit

final class ForgotPasswordVC: UIViewController {
    var interactor: ForgotPasswordBusinessLogic?

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Забыли пароль"
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textColor = .label
        label.textAlignment = .center
        return label
    }()

    private lazy var emailTextField: UITextField = {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholder = "Введите email"
        textField.backgroundColor = .white
        textField.layer.cornerRadius = 22
        textField.layer.borderWidth = 1
        textField.layer.borderColor = UIColor.systemGray5.cgColor
        textField.font = .systemFont(ofSize: 17, weight: .regular)
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 18, height: 1))
        textField.leftViewMode = .always
        textField.keyboardType = .emailAddress
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        return textField
    }()

    private lazy var continueButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        var config = UIButton.Configuration.filled()
        config.title = "Продолжить"
        config.baseBackgroundColor = UIColor(hex: "#6E73F4")
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.contentInsets = .init(top: 14, leading: 28, bottom: 14, trailing: 28)
        button.configuration = config
        button.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        return button
    }()

    private lazy var formContainer: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [emailTextField, continueButton])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 12
        return stackView
    }()

    override func viewDidLoad() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
            tapGesture.cancelsTouchesInView = false
            view.addGestureRecognizer(tapGesture)
        super.viewDidLoad()
        setupView()
        setupLayout()
    }

    func setContinueLoading(_ isLoading: Bool) {
        continueButton.isEnabled = !isLoading
        continueButton.alpha = isLoading ? 0.55 : 1
        emailTextField.isEnabled = !isLoading
    }

    private func setupView() {
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .never

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }

    private func setupLayout() {
        view.addSubview(titleLabel)
        view.addSubview(formContainer)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            titleLabel.bottomAnchor.constraint(equalTo: formContainer.topAnchor, constant: -28),

            formContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            formContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            formContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            emailTextField.heightAnchor.constraint(equalToConstant: 54),
            continueButton.heightAnchor.constraint(equalToConstant: 52)
        ])
    }

    @objc private func continueTapped() {
        interactor?.continueWithEmail(emailTextField.text ?? "")
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        
        guard let userInfo = notification.userInfo,
                let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        let keyboardHeight = keyboardFrame.height

        // Raise view's elements if the keyboard overlaps the create account button.
        if let buttonFrame = continueButton.superview?.convert(continueButton.frame, to: nil) {
            let bottomY = buttonFrame.maxY
            let screenHeight = UIScreen.main.bounds.height
        
            if bottomY > screenHeight - keyboardHeight {
                let overlap = bottomY - (screenHeight - keyboardHeight)
                self.view.frame.origin.y -= overlap + 16
            }
        }
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        if self.view.frame.origin.y != 0 {
            self.view.frame.origin.y = 0
        }
    }
}
