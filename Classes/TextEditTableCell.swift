//
//  TextEditTableCell.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 03.05.15.
//
//

import UIKit

final class TextEditTableCell: EditablePageCell {
	static let DefaultMaximumTextFieldLength = 15

	private var maximumTextFieldLength = 0

	required init() {
		super.init()

		self.textField.keyboardType  = .Default
		self.textField.returnKeyType = .Next
		self.textField.allowCut      = true
		self.textField.allowPaste    = true
	}

	required init(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}

	override func configureForData(dictionary: [NSObject:AnyObject], viewController: UIViewController, tableView: UITableView, indexPath: NSIndexPath) {
		super.configureForData(dictionary, viewController:viewController, tableView:tableView, indexPath:indexPath)

		if let autocapitalizeAll = dictionary["autocapitalizeAll"] where autocapitalizeAll.boolValue == true {
			self.textField.autocapitalizationType = .AllCharacters
		} else {
			self.textField.autocapitalizationType = .Words
		}
		if let maximumTextFieldLength = dictionary["maximumTextFieldLength"] as? Int {
			self.maximumTextFieldLength = maximumTextFieldLength
		} else {
			self.maximumTextFieldLength = TextEditTableCell.DefaultMaximumTextFieldLength
		}

		self.textField.text = self.delegate.valueForIdentifier(self.valueIdentifier) as? String
	}

	//MARK: - UITextFieldDelegate

	func textFieldShouldReturn(textField: UITextField) -> Bool {
		// Let the focus handler handle switching to next textfield
		if let focusHandler = self.delegate as? EditablePageCellFocusHandler {
			focusHandler.focusNextFieldForValueIdentifier(self.valueIdentifier)
		}

		return false
	}

	func textFieldShouldClear(textField: UITextField) -> Bool {
		// Propagate cleared value to the delegate
		self.delegate.valueChanged("", identifier:self.valueIdentifier)

		return true
	}

	func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
		let newValue = (textField.text! as NSString).stringByReplacingCharactersInRange(range, withString:string)

		// Don't allow too large strings
		if maximumTextFieldLength > 0 && newValue.characters.count > maximumTextFieldLength {
			return false
		}

		// Do the update here and propagate the new value back to the delegate
		textField.text = newValue

		self.delegate.valueChanged(newValue, identifier:self.valueIdentifier)
		return false
	}

}
