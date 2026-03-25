// InviteStatusCell.swift
// Sovpalo

import UIKit

final class InviteStatusCell: UITableViewCell {
    static let reuseID = "InviteStatusCell"
    
    private let iconView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hex: "#7079FB")
        view.layer.cornerRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "person")
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 18),
            imageView.heightAnchor.constraint(equalToConstant: 18)
        ])
        return view
    }()
    
    private let usernameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .regular)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let statusChip: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textAlignment = .center
        label.layer.cornerRadius = 12
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        selectionStyle = .none
        contentView.addSubview(iconView)
        contentView.addSubview(usernameLabel)
        contentView.addSubview(statusChip)
        
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),

            usernameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 16),
            usernameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            usernameLabel.trailingAnchor.constraint(lessThanOrEqualTo: statusChip.leadingAnchor, constant: -16),

            statusChip.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            statusChip.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            statusChip.heightAnchor.constraint(equalToConstant: 28),
            statusChip.widthAnchor.constraint(greaterThanOrEqualToConstant: 72)
        ])
    }
    
    func configure(username: String, status: String) {
        usernameLabel.text = username
        
        if status == "sent" {
            statusChip.text = "отправлена"
            statusChip.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.18)
            statusChip.textColor = .systemGreen
        } else if status == "error" {
            statusChip.text = "ошибка"
            statusChip.backgroundColor = UIColor.systemRed.withAlphaComponent(0.15)
            statusChip.textColor = .systemRed
        } else if status == "pending" {
            statusChip.text = "в ожидании"
            statusChip.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.18)
            statusChip.textColor = .systemOrange
        } else {
            statusChip.text = "неизвестно"
            statusChip.backgroundColor = UIColor.systemGray.withAlphaComponent(0.15)
            statusChip.textColor = .systemGray
        }
    }
}
