//
//  MeetingCell.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 11.03.2026.
//

import UIKit

final class MeetingCell: UITableViewCell {
    static let identifier = "MeetingCell"
    
    private let titleLabel = UILabel()
    private let dateLabel = UILabel()
    private let addressLabel = UILabel()
    private let actionButton = UIButton(type: .system)
    private var buttonAction: (() -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        dateLabel.font = UIFont.systemFont(ofSize: 14)
        dateLabel.textColor = .secondaryLabel
        addressLabel.font = UIFont.systemFont(ofSize: 14)
        addressLabel.textColor = .secondaryLabel
        
        actionButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        addressLabel.translatesAutoresizingMaskIntoConstraints = false
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(dateLabel)
        contentView.addSubview(addressLabel)
        contentView.addSubview(actionButton)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: actionButton.leadingAnchor, constant: -8),
            
            dateLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            dateLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            dateLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            
            addressLabel.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 4),
            addressLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            addressLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            addressLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            
            actionButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            actionButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            actionButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 60),
            actionButton.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        actionButton.layer.cornerRadius = 6
        actionButton.layer.borderWidth = 1
        actionButton.layer.borderColor = UIColor.systemBlue.cgColor
        actionButton.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
    }
    
    @objc private func buttonTapped() {
        buttonAction?()
    }
    
    func configure(with meeting: Meeting) {
        titleLabel.text = meeting.title
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        dateLabel.text = formatter.string(from: meeting.date)
        
        addressLabel.text = meeting.address
        
        if meeting.isPast {
            actionButton.isHidden = true
        } else {
            actionButton.isHidden = false
            if meeting.isAttending {
                actionButton.setTitle("Отменить", for: .normal)
                actionButton.setTitleColor(.systemRed, for: .normal)
                actionButton.layer.borderColor = UIColor.systemRed.cgColor
                buttonAction = {
                    // Cancel action
                }
            } else {
                actionButton.setTitle("Иду", for: .normal)
                actionButton.setTitleColor(.systemBlue, for: .normal)
                actionButton.layer.borderColor = UIColor.systemBlue.cgColor
                buttonAction = {
                    // Attend action
                }
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
