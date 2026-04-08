//
//  MemberCell.swift
//  Sovpalo
//
//  Created by Jovana on 24.3.26.
//

//  MemberCell.swift
//  Sovpalo

import UIKit

final class MemberCell: UITableViewCell {
    static let reuseID = "MemberCell"

    private let avatarView: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 20
        v.backgroundColor = UIColor.systemGray5
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let avatarLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 15, weight: .semibold)
        l.textColor = .label
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 16, weight: .regular)
        l.textColor = .label
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let ownerImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "star.fill"))
        imageView.tintColor = .systemYellow
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        avatarView.addSubview(avatarLabel)
        contentView.addSubview(avatarView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(ownerImageView)

        NSLayoutConstraint.activate([
            avatarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            avatarView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 40),
            avatarView.heightAnchor.constraint(equalToConstant: 40),

            avatarLabel.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            avatarLabel.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),

            nameLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: ownerImageView.leadingAnchor, constant: -12),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            ownerImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            ownerImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            ownerImageView.widthAnchor.constraint(equalToConstant: 16),
            ownerImageView.heightAnchor.constraint(equalToConstant: 16)
        ])
    }

    func configure(with member: GroupMembersModels.MemberViewModel) {
        nameLabel.text = member.name
        avatarLabel.text = member.avatarLetter
        ownerImageView.isHidden = !member.isOwner
    }
}
