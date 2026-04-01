//
//  SettingsVC.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 01.04.2026.
//

import UIKit

final class SettingsVC: UIViewController {
    var interactor: SettingsBusinessLogic?

    private lazy var nameContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 20
        view.layer.shadowColor = UIColor.black.withAlphaComponent(0.08).cgColor
        view.layer.shadowOpacity = 1
        view.layer.shadowRadius = 16
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        return view
    }()

    private lazy var usernameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 28, weight: .semibold)
        label.textColor = .label
        label.text = "..."
        return label
    }()

    private lazy var policyStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [
            makeActionButton(title: "Политика использования", action: #selector(termsTapped)),
            makeDivider(),
            makeActionButton(title: "Политика конфиденциальности", action: #selector(privacyTapped))
        ])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.backgroundColor = .systemBackground
        stackView.layer.cornerRadius = 20
        stackView.layer.shadowColor = UIColor.black.withAlphaComponent(0.08).cgColor
        stackView.layer.shadowOpacity = 1
        stackView.layer.shadowRadius = 16
        stackView.layer.shadowOffset = CGSize(width: 0, height: 4)
        stackView.clipsToBounds = false
        return stackView
    }()

    private lazy var logoutButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Выйти из аккаунта", for: .normal)
        button.setTitleColor(.systemRed, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        button.backgroundColor = .systemBackground
        button.layer.cornerRadius = 14
        button.layer.shadowColor = UIColor.black.withAlphaComponent(0.08).cgColor
        button.layer.shadowOpacity = 1
        button.layer.shadowRadius = 16
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.addTarget(self, action: #selector(logoutTapped), for: .touchUpInside)
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupLayout()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        (tabBarController as? MainTabBarController)?.setCustomTabBarHidden(true, animated: animated)
        interactor?.loadProfile()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        (tabBarController as? MainTabBarController)?.setCustomTabBarHidden(false, animated: animated)
    }

    func display(username: String) {
        usernameLabel.text = username
    }

    private func setupView() {
        view.backgroundColor = .systemGroupedBackground
        title = "Настройки"
        navigationItem.largeTitleDisplayMode = .never
    }

    private func setupLayout() {
        view.addSubview(nameContainerView)
        nameContainerView.addSubview(usernameLabel)
        view.addSubview(policyStackView)
        view.addSubview(logoutButton)

        NSLayoutConstraint.activate([
            nameContainerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            nameContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            nameContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            usernameLabel.topAnchor.constraint(equalTo: nameContainerView.topAnchor, constant: 24),
            usernameLabel.leadingAnchor.constraint(equalTo: nameContainerView.leadingAnchor, constant: 20),
            usernameLabel.trailingAnchor.constraint(equalTo: nameContainerView.trailingAnchor, constant: -20),
            usernameLabel.bottomAnchor.constraint(equalTo: nameContainerView.bottomAnchor, constant: -24),

            policyStackView.topAnchor.constraint(equalTo: nameContainerView.bottomAnchor, constant: 16),
            policyStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            policyStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            logoutButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            logoutButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            logoutButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            logoutButton.heightAnchor.constraint(equalToConstant: 52)
        ])
    }

    private func makeActionButton(title: String, action: Selector) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.title = title
        config.baseForegroundColor = .label
        config.image = UIImage(systemName: "chevron.right")
        config.imagePlacement = .trailing
        config.imagePadding = 8
        config.contentInsets = NSDirectionalEdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18)

        let button = UIButton(configuration: config, primaryAction: nil)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.contentHorizontalAlignment = .fill
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .regular)
        button.tintColor = .tertiaryLabel
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func makeDivider() -> UIView {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .separator
        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale)
        ])
        return view
    }

    @objc private func termsTapped() {}

    @objc private func privacyTapped() {}

    @objc private func logoutTapped() {
        let alert = UIAlertController(
            title: "Выход из аккаунта",
            message: "Вы точно хотите выйти из аккаунта?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(
            UIAlertAction(title: "Выйти", style: .destructive) { [weak self] _ in
                self?.interactor?.logout()
            }
        )
        present(alert, animated: true)
    }
}
