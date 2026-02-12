//
//  FirstGroupVC.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 12.02.2026.
//

import UIKit
import SwiftUI

final class FirstGroupVC: UIViewController {
    // MARK: - Public API
    /// Массив компаний. Меняйте как удобно — UI обновится автоматически.
    var companies: [String] = [] {
        didSet { reloadCompanies() }
    }

    var interactor: FirstGroupBusinessLogic?

    // MARK: - UI
    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Привет"
        label.font = UIFont.systemFont(ofSize: 34, weight: .bold)
        label.textColor = .label
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Выбери одну из своих компаний, присоединись к новой или создай свою"
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    private let companiesStack = UIStackView()

    private let bottomContainer = UIView()
    private let createButton = UIButton(type: .system)
    private let joinButton = UIButton(type: .system)

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.systemGroupedBackground
        setupLayout()
        configureButtons()
        reloadCompanies()
        interactor?.getCompaniesList()
    }

    // MARK: - Setup
    private func setupLayout() {
        // Scroll area
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .onDrag
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        // Title & subtitle
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            subtitleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor)
        ])

        // Companies stack
        companiesStack.axis = .vertical
        companiesStack.spacing = 12
        companiesStack.alignment = .fill
        companiesStack.distribution = .fill
        contentView.addSubview(companiesStack)
        companiesStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            companiesStack.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            companiesStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            companiesStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])

        // Bottom actions container
        bottomContainer.translatesAutoresizingMaskIntoConstraints = false
        bottomContainer.layer.cornerRadius = 20
        bottomContainer.backgroundColor = UIColor(hex: "#7079FB")
        view.addSubview(bottomContainer)

        let bottomSafe = view.safeAreaLayoutGuide

        // Style buttons to sit on purple container
        configureBottomButton(createButton, title: "Создать компанию", systemImage: "plus")
        configureBottomButton(joinButton, title: "Присоединиться к компании", systemImage: "arrow.forward")

        let hStack = UIStackView(arrangedSubviews: [createButton, joinButton])
        hStack.axis = .horizontal
        hStack.spacing = 0
        hStack.alignment = .fill
        hStack.distribution = .fillEqually

        bottomContainer.addSubview(hStack)
        hStack.translatesAutoresizingMaskIntoConstraints = false

        // Divider between buttons
        let divider = UIView()
        divider.backgroundColor = UIColor.white.withAlphaComponent(0.25)
        divider.translatesAutoresizingMaskIntoConstraints = false
        bottomContainer.addSubview(divider)

        NSLayoutConstraint.activate([
            bottomContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            bottomContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            bottomContainer.bottomAnchor.constraint(equalTo: bottomSafe.bottomAnchor, constant: -12),

            hStack.topAnchor.constraint(equalTo: bottomContainer.topAnchor),
            hStack.leadingAnchor.constraint(equalTo: bottomContainer.leadingAnchor),
            hStack.trailingAnchor.constraint(equalTo: bottomContainer.trailingAnchor),
            hStack.bottomAnchor.constraint(equalTo: bottomContainer.bottomAnchor),

            divider.centerXAnchor.constraint(equalTo: bottomContainer.centerXAnchor),
            divider.topAnchor.constraint(equalTo: bottomContainer.topAnchor, constant: 12),
            divider.bottomAnchor.constraint(equalTo: bottomContainer.bottomAnchor, constant: -12),
            divider.widthAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale)
        ])

        // Ensure scroll content doesn't hide behind bottom buttons
        let bottomSpacer = contentView.bottomAnchor.constraint(equalTo: companiesStack.bottomAnchor, constant: 24)
        bottomSpacer.priority = .defaultHigh
        bottomSpacer.isActive = true
        let extraSpaceGuide = UILayoutGuide()
        contentView.addLayoutGuide(extraSpaceGuide)
        extraSpaceGuide.heightAnchor.constraint(equalTo: bottomContainer.heightAnchor, constant: 24).isActive = true
        extraSpaceGuide.topAnchor.constraint(equalTo: companiesStack.bottomAnchor).isActive = true
        extraSpaceGuide.leadingAnchor.constraint(equalTo: contentView.leadingAnchor).isActive = true
        extraSpaceGuide.trailingAnchor.constraint(equalTo: contentView.trailingAnchor).isActive = true
        contentView.bottomAnchor.constraint(equalTo: extraSpaceGuide.bottomAnchor).isActive = true

        // Actions
        createButton.addTarget(self, action: #selector(didTapCreate), for: .touchUpInside)
        joinButton.addTarget(self, action: #selector(didTapJoin), for: .touchUpInside)
    }

    private func configureButtons() {
        // Nothing extra for now; placeholder if we need dynamic state later
    }

    private func stylePrimaryActionButton(_ button: UIButton, title: String, systemImage: String) {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.image = UIImage(systemName: systemImage)
        config.imagePadding = 8
        config.baseBackgroundColor = UIColor(hex: "#7079FB")
        config.baseForegroundColor = .white
        config.cornerStyle = .large
        config.contentInsets = .init(top: 14, leading: 16, bottom: 14, trailing: 16)
        button.configuration = config
        button.layer.masksToBounds = true
    }

    private func configureBottomButton(_ button: UIButton, title: String, systemImage: String) {
        var config = UIButton.Configuration.plain()
        config.title = title
        config.image = UIImage(systemName: systemImage)
        config.imagePadding = 8
        config.baseForegroundColor = .white
        config.contentInsets = .init(top: 16, leading: 16, bottom: 16, trailing: 16)
        config.background.backgroundColor = .clear
        config.background.cornerRadius = 0
        button.configuration = config
    }

    // MARK: - Companies UI
    private func reloadCompanies() {
        // Remove previous arranged subviews
        companiesStack.arrangedSubviews.forEach { view in
            companiesStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for name in companies {
            let button = makeCompanyButton(title: name)
            companiesStack.addArrangedSubview(button)
        }
    }

    private func makeCompanyButton(title: String) -> UIControl {
        let container = UIControl()
        container.backgroundColor = .white
        container.layer.cornerRadius = 14
        container.layer.masksToBounds = true

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 1

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = .tertiaryLabel
        chevron.contentMode = .scaleAspectFit

        let hStack = UIStackView(arrangedSubviews: [titleLabel, UIView(), chevron])
        hStack.axis = .horizontal
        hStack.alignment = .center
        hStack.spacing = 8

        container.addSubview(hStack)
        hStack.translatesAutoresizingMaskIntoConstraints = false
        container.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            hStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            hStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            hStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14),

            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 52)
        ])

        container.addTarget(self, action: #selector(didTapCompany(_:)), for: .touchUpInside)
        return container
    }

    // MARK: - Actions

    @objc private func didTapCreate() {
        self.navigationController?.pushViewController(CreateGroupAssembly.assembly(), animated: true)
    }

    @objc private func didTapJoin() {
        // TODO: Вызвать интерактор/роутер при необходимости
        print("Присоединиться к компании tapped")
    }

    @objc private func didTapCompany(_ sender: UIControl) {
        guard let index = companiesStack.arrangedSubviews.firstIndex(of: sender),
              companies.indices.contains(index) else { return }
        let company = companies[index]

        if index == 0 {
            // Navigate to SwiftUI Main Screen assembled via MainScreenAssembly.build()
            let rootView = MainScreenAssembly.build()
            let hosting = UIHostingController(rootView: rootView)
            if let nav = self.navigationController {
                nav.setViewControllers([hosting], animated: true)
            } else {
                hosting.modalPresentationStyle = .fullScreen
                self.present(hosting, animated: true)
            }
        } else {
            // TODO: Handle selection of other companies as needed
            print("Selected company: \(company)")
        }
    }
}

