//
//  InvitationCell.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 11.03.2026.
//

import UIKit

final class InvitationCell: UITableViewCell {
    // UI
    private let shadowView = UIView()
    private let container = UIView()
    private let messageLabel = UILabel()
    private let acceptButton = UIButton(type: .system)
    private let declineButton = UIButton(type: .system)

    var onAccept: (() -> Void)?
    var onDecline: (() -> Void)?

    static let reuseID = "InvitationCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        clipsToBounds = false
        contentView.clipsToBounds = false

        // Shadow wrapper
        shadowView.backgroundColor = .clear
        shadowView.layer.shadowColor = UIColor.black.cgColor
        shadowView.layer.shadowOpacity = 0.1 // 10%
        shadowView.layer.shadowRadius = 10
        shadowView.layer.shadowOffset = .zero // X=0, Y=0

        contentView.addSubview(shadowView)
        shadowView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            shadowView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            shadowView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            shadowView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            shadowView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])

        // Container (card)
        container.backgroundColor = .white
        container.layer.cornerRadius = 16
        container.layer.masksToBounds = true

        shadowView.addSubview(container)
        container.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: shadowView.topAnchor),
            container.leadingAnchor.constraint(equalTo: shadowView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: shadowView.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: shadowView.bottomAnchor)
        ])

        // Message label (bold/semibold 17)
        messageLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        messageLabel.textColor = .label
        messageLabel.numberOfLines = 0

        // Buttons with icons and bold titles
        var acceptConfig = UIButton.Configuration.plain()
        acceptConfig.title = "Принять"
        acceptConfig.baseForegroundColor = UIColor(hex: "#7079FB")
        acceptConfig.image = UIImage(systemName: "checkmark.circle.fill")
        acceptConfig.imagePlacement = .leading
        acceptConfig.imagePadding = 6
        acceptConfig.contentInsets = .init(top: 4, leading: 0, bottom: 4, trailing: 0)
        acceptConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
            return out
        }
        acceptButton.configuration = acceptConfig
        let acceptSymbolConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        acceptButton.setPreferredSymbolConfiguration(acceptSymbolConfig, forImageIn: .normal)
        acceptButton.addTarget(self, action: #selector(didTapAccept), for: .touchUpInside)

        var declineConfig = UIButton.Configuration.plain()
        declineConfig.title = "Отказать"
        declineConfig.baseForegroundColor = .secondaryLabel
        declineConfig.image = UIImage(systemName: "xmark.circle")
        declineConfig.imagePlacement = .leading
        declineConfig.imagePadding = 6
        declineConfig.contentInsets = .init(top: 4, leading: 0, bottom: 4, trailing: 0)
        declineConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
            return out
        }
        declineButton.configuration = declineConfig
        let declineSymbolConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        declineButton.setPreferredSymbolConfiguration(declineSymbolConfig, forImageIn: .normal)
        declineButton.addTarget(self, action: #selector(didTapDecline), for: .touchUpInside)

        // Layout inside container
        let buttonsStack = UIStackView(arrangedSubviews: [acceptButton, UIView(), declineButton])
        buttonsStack.axis = .horizontal
        buttonsStack.alignment = .center
        buttonsStack.spacing = 8

        let vStack = UIStackView(arrangedSubviews: [messageLabel, buttonsStack])
        vStack.axis = .vertical
        vStack.alignment = .fill
        vStack.spacing = 12

        container.addSubview(vStack)
        vStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            vStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            vStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            vStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            vStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Rounded shadow matching the card radius
        shadowView.layer.shadowPath = UIBezierPath(roundedRect: shadowView.bounds, cornerRadius: 16).cgPath
    }

    func configure(with invitation: Invitation) {
        messageLabel.text = "@\(invitation.invitedByUsername) приглашает вас в компанию \"\(invitation.companyName)\""
    }

    @objc private func didTapAccept() {
        onAccept?()
    }

    @objc private func didTapDecline() {
        onDecline?()
    }
}

