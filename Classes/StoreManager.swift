//
//  StoreManager.swift
//  Kraftstoff
//
//  Created by Ingmar Stein on 01.09.15.
//
//

import Foundation
import StoreKit
import Security

final class StoreManager : NSObject, SKProductsRequestDelegate, SKPaymentTransactionObserver {
	static let sharedInstance = StoreManager()

	private let twoCarsProductId = "com.github.ingmarstein.kraftstoff.2cars"
	private let fiveCarsProductId = "com.github.ingmarstein.kraftstoff.5cars"
	private let unlimitedCarsProductId = "com.github.ingmarstein.kraftstoff.unlimitedCars"
	private let purchasedProductsKey = "purchasedProducts"

	override init() {
		super.init()

		migratePurchases()

		SKPaymentQueue.defaultQueue().addTransactionObserver(self)
	}

	private var maxCarCount : Int {
		return fiveCars ? 5 : (twoCars ? 2 : 1)
	}

	func checkCarCount() -> Bool {
		let moc = CoreDataManager.managedObjectContext
		let carsFetchRequest = CoreDataManager.fetchRequestForCarsInManagedObjectContext(moc)
		let count = moc.countForFetchRequest(carsFetchRequest, error: nil)
		return count == NSNotFound || unlimitedCars || count < maxCarCount
	}

	func showBuyOptions(parent: UIViewController) {
		let alert = UIAlertController(title: NSLocalizedString("Car limit reached", comment: ""),
			message: NSLocalizedString("Would you like to buy more cars?", comment: ""), preferredStyle: .ActionSheet)

		if maxCarCount < 2 {
			let twoCarsAction = UIAlertAction(title: NSLocalizedString("2 Cars", comment: ""), style: .Default) { _ in
				self.buyProduct(self.twoCarsProductId)
			}
			alert.addAction(twoCarsAction)
		}

		if maxCarCount < 5 {
			let fiveCarsAction = UIAlertAction(title: NSLocalizedString("5 Cars", comment: ""), style: .Default) { _ in
				self.buyProduct(self.fiveCarsProductId)
			}
			alert.addAction(fiveCarsAction)
		}

		let unlimitedCarsAction = UIAlertAction(title: NSLocalizedString("Unlimited Cars", comment: ""), style: .Default) { _ in
			self.buyProduct(self.unlimitedCarsProductId)
		}
		alert.addAction(unlimitedCarsAction)

		let restoreAction = UIAlertAction(title: NSLocalizedString("Restore Purchases", comment: ""), style: .Default) { _ in
			SKPaymentQueue.defaultQueue().restoreCompletedTransactions()
		}
		alert.addAction(restoreAction)

		let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .Cancel, handler: nil)
		alert.addAction(cancelAction)

		alert.popoverPresentationController?.sourceView = parent.view
		alert.popoverPresentationController?.sourceRect = parent.view.bounds
		alert.popoverPresentationController?.permittedArrowDirections = []
		parent.presentViewController(alert, animated: true, completion: nil)
	}

	// migrate purchases from NSUserDefaults to Keychain
	private func migratePurchases() {
		let userDefaults = NSUserDefaults.standardUserDefaults()
		if let purchasedProducts = userDefaults.arrayForKey(purchasedProductsKey) as? [String] {
			for product in purchasedProducts {
				setProductPurchased(product, purchased: true)
			}
		}
		userDefaults.removeObjectForKey(purchasedProductsKey)
		userDefaults.synchronize()
	}

	private func keychainItemForProduct(product: String) -> [String:AnyObject] {
		return [
			String(kSecClass) : kSecClassGenericPassword,
			String(kSecAttrService) : "com.github.ingmarstein.kraftstoff",
			String(kSecAttrAccount) : product,
			String(kSecAttrAccessible) : kSecAttrAccessibleWhenUnlocked
		]
	}

	private func isProductPurchased(product: String) -> Bool {
		return SecItemCopyMatching(keychainItemForProduct(product), nil) == 0
	}

	private func setProductPurchased(product: String, purchased: Bool) {
		let keychainItem = keychainItemForProduct(product)
		if purchased {
			SecItemAdd(keychainItem, nil)
		} else {
			SecItemDelete(keychainItem)
		}
	}

	var twoCars : Bool {
		return isProductPurchased(twoCarsProductId)
	}

	var fiveCars : Bool {
		return isProductPurchased(fiveCarsProductId)
	}

	var unlimitedCars : Bool {
		return isProductPurchased(unlimitedCarsProductId)
	}

	private func buyProduct(productIdentifier: String) {
		if SKPaymentQueue.canMakePayments() {
			let productsRequest = SKProductsRequest(productIdentifiers: [productIdentifier])
			productsRequest.delegate = self
			productsRequest.start()
		}
	}

	func productsRequest(request: SKProductsRequest, didReceiveResponse response: SKProductsResponse) {
		if let product = response.products.first where response.products.count == 1 {
			let payment = SKPayment(product: product)
			SKPaymentQueue.defaultQueue().addPayment(payment)
		}
	}

	func paymentQueue(queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
		for transaction in transactions {
			switch transaction.transactionState {
			case .Purchased, .Restored:
				setProductPurchased(transaction.payment.productIdentifier, purchased: true)
				SKPaymentQueue.defaultQueue().finishTransaction(transaction)
			case .Failed:
				SKPaymentQueue.defaultQueue().finishTransaction(transaction)
				print("Transaction failed: \(transaction.error)")
			default: ()
			}
		}
	}
}
