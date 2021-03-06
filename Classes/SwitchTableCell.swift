//
//  SwitchTableCell.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 03.05.15.
//
//

import UIKit

final class SwitchTableCell: PageCell {
	private let margin: CGFloat = 8.0

	var keyLabel: UILabel
	var valueSwitch: UISwitch
	var valueLabel: UILabel
	var valueIdentifier: String!

	weak var delegate: EditablePageCellDelegate?

	required init() {
		self.keyLabel = UILabel(frame: .zero)
		self.valueSwitch = UISwitch(frame: .zero)
		self.valueLabel = UILabel(frame: .zero)

		super.init()

		// No highlight on touch
		self.selectionStyle = .none

		// Create switch
		valueSwitch.addTarget(self, action: #selector(SwitchTableCell.switchToggledAction(_:)), for: UIControl.Event.valueChanged)
		valueSwitch.translatesAutoresizingMaskIntoConstraints = false

		self.contentView.addSubview(self.valueSwitch)

		// Configure the alternate textlabel

		valueLabel.textAlignment            = .right
		valueLabel.backgroundColor          = .clear
		valueLabel.textColor                = .label
		valueLabel.isHidden                 = true
		valueLabel.isUserInteractionEnabled = false
		valueLabel.translatesAutoresizingMaskIntoConstraints = false
		valueLabel.adjustsFontForContentSizeCategory = true
		valueLabel.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.body)

		self.contentView.addSubview(self.valueLabel)

		// Configure the default textlabel
		keyLabel.textAlignment        = .left
		keyLabel.highlightedTextColor = .label
		keyLabel.textColor            = .label
		keyLabel.translatesAutoresizingMaskIntoConstraints = false
		keyLabel.adjustsFontForContentSizeCategory = true
		keyLabel.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.body)

		self.contentView.addSubview(keyLabel)

		let constraints = Array([
			[
				NSLayoutConstraint(item: valueSwitch, attribute: .centerY, relatedBy: .equal, toItem: contentView, attribute: .centerY, multiplier: 1.0, constant: 0.0),
				NSLayoutConstraint(item: valueLabel, attribute: .centerY, relatedBy: .equal, toItem: contentView, attribute: .centerY, multiplier: 1.0, constant: 0.0)
			],
			NSLayoutConstraint.constraints(withVisualFormat: "|-[keyLabel]-[valueSwitch]-|", options: [], metrics: nil, views: ["keyLabel": keyLabel, "valueSwitch": valueSwitch]),
			NSLayoutConstraint.constraints(withVisualFormat: "|-[keyLabel]-[valueLabel]-|", options: [], metrics: nil, views: ["keyLabel": keyLabel, "valueLabel": valueLabel]),
			NSLayoutConstraint.constraints(withVisualFormat: "V:|-[keyLabel]-|", options: [], metrics: nil, views: ["keyLabel": keyLabel]),
			NSLayoutConstraint.constraints(withVisualFormat: "V:|-(>=4)-[valueSwitch]-(>=4)-|", options: [], metrics: nil, views: ["valueSwitch": valueSwitch])
		].joined())
		NSLayoutConstraint.activate(constraints)
	}

	required init(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}

	override func configureForData(_ dictionary: [String: Any], viewController: UIViewController, tableView: UITableView, indexPath: IndexPath) {
		super.configureForData(dictionary, viewController: viewController, tableView: tableView, indexPath: indexPath)

		self.keyLabel.text   = dictionary["label"] as? String
		self.delegate        = viewController as? EditablePageCellDelegate
		self.valueIdentifier = dictionary["valueIdentifier"] as? String

		let isOn = self.delegate?.valueForIdentifier(self.valueIdentifier) as? Bool ?? false

		self.valueSwitch.isOn = isOn
		self.valueLabel.text = NSLocalizedString(isOn ? "Yes" : "No", comment: "")

		let showAlternate = self.delegate?.valueForIdentifier("showValueLabel") as? Bool ?? false

		self.valueSwitch.isHidden =  showAlternate
		self.valueLabel.isHidden  = !showAlternate
	}

	@objc func switchToggledAction(_ sender: UISwitch) {
		let isOn = sender.isOn

		self.delegate?.valueChanged(isOn, identifier: self.valueIdentifier)
		self.valueLabel.text = NSLocalizedString(isOn ? "Yes" : "No", comment: "")
	}

	override func reset() {
		super.reset()

		keyLabel.text = ""
		valueLabel.text = ""
	}

}
