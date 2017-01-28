//
//  CoreDataManager.swift
//  Kraftstoff
//
//  Created by Ingmar Stein on 21.05.15.
//
//

import UIKit
import CoreData
import CloudKit

final class CoreDataManager {
	// CoreData support
	static let managedObjectContext: NSManagedObjectContext = {
		let context = persistentContainer.viewContext
		context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
		return context
	}()

	static let persistentContainer: NSPersistentContainer = {
		return NSPersistentContainer(name: "Fuel")
	}()

	private static let applicationDocumentsDirectory: String = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).last!

	static let sharedInstance = CoreDataManager()

	// MARK: - Core Data Support

	@discardableResult static func saveContext(_ context: NSManagedObjectContext = managedObjectContext) -> Bool {
		if context.hasChanges {
			do {
				let modifiedManagedObjects = context.insertedObjects.union(context.updatedObjects)
				let modifiedRecords = modifiedManagedObjects.flatMap { (managedObject) -> CKRecord? in
					if let ckManagedObject = managedObject as? CloudKitManagedObject {
						return ckManagedObject.asCloudKitRecord()
					}
					return nil
				}

				let deletedRecordIDs = context.deletedObjects.flatMap { ($0 as? CloudKitManagedObject)?.cloudKitRecordID }

				try context.save()

				CloudKitManager.save(modifiedRecords: modifiedRecords, deletedRecordIDs: deletedRecordIDs)
			} catch let error {
				let alertController = UIAlertController(title: NSLocalizedString("Can't Save Database", comment: ""),
					message: NSLocalizedString("Sorry, the application database cannot be saved. Please quit the application with the Home button.", comment: ""),
					preferredStyle: .alert)
				let defaultAction = UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default) { _ in
					fatalError(error.localizedDescription)
				}
				alertController.addAction(defaultAction)
				UIApplication.kraftstoffAppDelegate.window?.rootViewController?.present(alertController, animated: true, completion: nil)
			}

			return true
		}

		return false
	}

	static func modelIdentifierForManagedObject(_ object: NSManagedObject) -> String? {
		if object.objectID.isTemporaryID {
			do {
				try managedObjectContext.obtainPermanentIDs(for: [object])
			} catch {
				return nil
			}
		}
		return object.objectID.uriRepresentation().absoluteString
	}

	static func managedObjectForModelIdentifier<ResultType: NSManagedObject>(_ identifier: String) -> ResultType? {
		if let objectURL = URL(string: identifier), objectURL.scheme == "x-coredata" {
			if let objectID = persistentContainer.persistentStoreCoordinator.managedObjectID(forURIRepresentation: objectURL) {
				if let existingObject = try? managedObjectContext.existingObject(with: objectID) {
					return existingObject as? ResultType
				}
			}
		}

		return nil
	}

	static func existingObject(_ object: NSManagedObject, inManagedObjectContext moc: NSManagedObjectContext) -> NSManagedObject? {
		if object.isDeleted {
			return nil
		} else {
			return try? moc.existingObject(with: object.objectID)
		}
	}

	static func load() {
		persistentContainer.loadPersistentStores { (_, error) in
			if let error = error {
				let alertController = UIAlertController(title: NSLocalizedString("Can't Open Database", comment: ""),
				                                        message: NSLocalizedString("Sorry, the application database cannot be opened. Please quit the application with the Home button.", comment: ""),
				                                        preferredStyle: .alert)
				let defaultAction = UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default) { _ in
					fatalError(error.localizedDescription)
				}
				alertController.addAction(defaultAction)
				UIApplication.shared.keyWindow?.rootViewController?.present(alertController, animated: true, completion: nil)
			}
		}
	}

	// MARK: - Preconfigured Core Data Fetches

	static func fetchRequestForCars() -> NSFetchRequest<Car> {
		let fetchRequest: NSFetchRequest<Car> = Car.fetchRequest()
		fetchRequest.fetchBatchSize = 32

		// Sorting keys
		let sortDescriptor = NSSortDescriptor(key: "order", ascending: true)
		fetchRequest.sortDescriptors = [sortDescriptor]

		return fetchRequest
	}

	static func fetchRequestForEvents(car: Car,
	                                  andDate date: Date?,
	                                  dateComparator dateCompare: String,
	                                  fetchSize: Int) -> NSFetchRequest<FuelEvent> {
		let fetchRequest: NSFetchRequest<FuelEvent> = FuelEvent.fetchRequest()
		fetchRequest.fetchBatchSize = fetchSize

		// Predicates
		let parentPredicate = NSPredicate(format: "car == %@", car)

		if let date = date {
			let datePredicate = NSPredicate(format: "timestamp \(dateCompare) %@", date as NSDate)
			fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [parentPredicate, datePredicate])
		} else {
			fetchRequest.predicate = parentPredicate
		}

		// Sorting keys
		let sortDescriptor = NSSortDescriptor(key: "timestamp", ascending: false)
		fetchRequest.sortDescriptors = [sortDescriptor]

		return fetchRequest
	}

	static func fetchRequestForEvents(car: Car,
	                                  afterDate date: Date?,
	                                  dateMatches: Bool) -> NSFetchRequest<FuelEvent> {
		return fetchRequestForEvents(car: car,
		                             andDate: date,
		                             dateComparator: dateMatches ? ">=" : ">",
		                             fetchSize: 128)
	}

	static func fetchRequestForEvents(car: Car,
	                                  beforeDate date: Date?,
	                                  dateMatches: Bool) -> NSFetchRequest<FuelEvent> {
		return fetchRequestForEvents(car: car,
		                             andDate: date,
		                             dateComparator: dateMatches ? "<=" : "<",
		                             fetchSize: 8)
	}

	static func fetchedResultsControllerForCars(inContext moc: NSManagedObjectContext = managedObjectContext) -> NSFetchedResultsController<Car> {
		let fetchRequest = fetchRequestForCars()

		// No section names; perform fetch without cache
		let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
		                                                          managedObjectContext: moc,
		                                                          sectionNameKeyPath: nil,
		                                                          cacheName: nil)

		// Perform the Core Data fetch
		do {
			try fetchedResultsController.performFetch()
		} catch let error {
			fatalError(error.localizedDescription)
		}

		return fetchedResultsController
	}

	static func objectsForFetchRequest<ResultType>(_ fetchRequest: NSFetchRequest<ResultType>, inManagedObjectContext moc: NSManagedObjectContext = managedObjectContext) -> [ResultType] {
		let fetchedObjects: [ResultType]?
		do {
			fetchedObjects = try moc.fetch(fetchRequest)
		} catch let error {
			fatalError(error.localizedDescription)
		}

		return fetchedObjects!
	}

	static func containsEventWithCar(_ car: Car, andDate date: Date, inManagedObjectContext moc: NSManagedObjectContext = managedObjectContext) -> Bool {
		let fetchRequest: NSFetchRequest<FuelEvent> = FuelEvent.fetchRequest()
		fetchRequest.fetchBatchSize = 2

		// Predicates
		let parentPredicate = NSPredicate(format: "car == %@", car)
		let datePredicate = NSPredicate(format: "timestamp == %@", date as NSDate)

		fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [parentPredicate, datePredicate])

		// Check whether fetch would reveal any event objects
		do {
			return try moc.count(for: fetchRequest) > 0
		} catch let error {
			fatalError(error.localizedDescription)
		}
	}

	// MARK: - Core Data Updates

	@discardableResult static func addToArchive(car: Car, date: Date, distance: NSDecimalNumber, price: NSDecimalNumber, fuelVolume: NSDecimalNumber, filledUp: Bool, inManagedObjectContext moc: NSManagedObjectContext = managedObjectContext, comment: String?, forceOdometerUpdate odometerUpdate: Bool) -> FuelEvent {
		// Convert distance and fuelvolume to SI units
		let fuelUnit     = car.ksFuelUnit
		let odometerUnit = car.ksOdometerUnit

		let liters        = Units.litersForVolume(fuelVolume, withUnit: fuelUnit)
		let kilometers    = Units.kilometersForDistance(distance, withUnit: odometerUnit)
		let pricePerLiter = Units.pricePerLiter(price, withUnit: fuelUnit)

		var inheritedCost: NSDecimalNumber       = .zero
		var inheritedDistance: NSDecimalNumber   = .zero
		var inheritedFuelVolume: NSDecimalNumber = .zero

		var forceOdometerUpdate = odometerUpdate

		// Compute inherited data from older element

		// Fetch older events
		let olderEvents = objectsForFetchRequest(fetchRequestForEvents(car: car,
		                                                               beforeDate: date,
		                                                               dateMatches: false),
		                                         inManagedObjectContext: moc)

        if olderEvents.count > 0 {
			let olderEvent = olderEvents.first!

			if !olderEvent.filledUp {
				let cost = olderEvent.cost

				inheritedCost       = cost + olderEvent.inheritedCost
				inheritedDistance   = olderEvent.distance + olderEvent.inheritedDistance
				inheritedFuelVolume = olderEvent.fuelVolume + olderEvent.inheritedFuelVolume
			}
		}

		// Update inherited distance/volume for younger events, probably mark the car odometer for an update
		// Fetch younger events
		let youngerEvents = objectsForFetchRequest(fetchRequestForEvents(car: car,
		                                                                 afterDate: date,
		                                                                 dateMatches: false),
		                                           inManagedObjectContext: moc)

        if youngerEvents.count > 0 {

			let deltaCost = filledUp
				? -inheritedCost
				: liters * pricePerLiter

			let deltaDistance = filledUp
				? -inheritedDistance
				: kilometers

			let deltaFuelVolume = filledUp
				? -inheritedFuelVolume
				: liters

			for youngerEvent in youngerEvents.reversed() {
				youngerEvent.inheritedCost = max(youngerEvent.inheritedCost + deltaCost, .zero)
				youngerEvent.inheritedDistance = max(youngerEvent.inheritedDistance + deltaDistance, .zero)
				youngerEvent.inheritedFuelVolume = max(youngerEvent.inheritedFuelVolume + deltaFuelVolume, .zero)

				if youngerEvent.filledUp {
					break
				}
			}
		} else {
			// New event will be the youngest one => update odometer too
            forceOdometerUpdate = true
		}

		// Create new managed object for this event
		let newEvent = FuelEvent(context: moc)

		newEvent.lastUpdate = Date()
		newEvent.car = car
		newEvent.timestamp = date
		newEvent.distance = kilometers
		newEvent.price = pricePerLiter
		newEvent.fuelVolume = liters
		newEvent.comment = comment

		if !filledUp {
			newEvent.filledUp = filledUp
		}

		if inheritedCost != .zero {
			newEvent.inheritedCost = inheritedCost
		}

		if inheritedDistance != .zero {
			newEvent.inheritedDistance = inheritedDistance
		}

		if inheritedFuelVolume != .zero {
			newEvent.inheritedFuelVolume = inheritedFuelVolume
		}

		// Conditions for update of global odometer:
		// - when the new event is the youngest one
		// - when sum of all events equals the odometer value
		// - when forced to do so
		if !forceOdometerUpdate {
			if car.odometer <= car.distanceTotalSum {
				forceOdometerUpdate = true
			}
		}

		// Update total car statistics
		car.distanceTotalSum += kilometers
		car.fuelVolumeTotalSum += liters

		if forceOdometerUpdate {
			// Update global odometer
			car.odometer = max(car.odometer + kilometers, car.distanceTotalSum)
		}

		return newEvent
	}

	static func removeEventFromArchive(_ event: FuelEvent!, inManagedObjectContext moc: NSManagedObjectContext = managedObjectContext, forceOdometerUpdate odometerUpdate: Bool) {
		// catch nil events
		if event == nil {
			return
		}

		var forceOdometerUpdate = odometerUpdate
		let car = event.car
		let distance = event.distance
		let fuelVolume = event.fuelVolume

		// Event will be deleted: update inherited distance/fuelVolume for younger events
		let youngerEvents = objectsForFetchRequest(fetchRequestForEvents(car: car,
		                                                                 afterDate: event.timestamp,
		                                                                 dateMatches: false),
		                                           inManagedObjectContext: moc)

		var row = youngerEvents.count
		if row > 0 {
			// Fill-up event deleted => propagate its inherited distance/volume
			if event.filledUp {
				let inheritedCost       = event.inheritedCost
				let inheritedDistance   = event.inheritedDistance
				let inheritedFuelVolume = event.inheritedFuelVolume

				if inheritedCost > .zero || inheritedDistance > .zero || inheritedFuelVolume > .zero {
					while row > 0 {
						row -= 1
						let youngerEvent = youngerEvents[row]

						youngerEvent.inheritedCost += inheritedCost
						youngerEvent.inheritedDistance += inheritedDistance
						youngerEvent.inheritedFuelVolume += inheritedFuelVolume

						if youngerEvent.filledUp {
							break
						}
					}
				}
			} else {
				// Intermediate event deleted => remove distance/volume from inherited data

				while row > 0 {
					row -= 1
					let youngerEvent = youngerEvents[row]
					let cost = event.price

					youngerEvent.inheritedCost = max(youngerEvent.inheritedCost - cost, .zero)
					youngerEvent.inheritedDistance = max(youngerEvent.inheritedDistance - distance, .zero)
					youngerEvent.inheritedFuelVolume = max(youngerEvent.inheritedFuelVolume - fuelVolume, .zero)

					if youngerEvent.filledUp {
						break
					}
				}
			}
		} else {
			forceOdometerUpdate = true
		}

		// Conditions for update of global odometer:
		// - when youngest element gets deleted
		// - when sum of all events equals the odometer value
		// - when forced to do so
		if !forceOdometerUpdate {
			if car.odometer <= car.distanceTotalSum {
				forceOdometerUpdate = true
			}
		}

		// Update total car statistics
		car.distanceTotalSum = max(car.distanceTotalSum - distance, .zero)
		car.fuelVolumeTotalSum = max(car.fuelVolumeTotalSum - fuelVolume, .zero)

		// Update global odometer
		if forceOdometerUpdate {
			car.odometer = max(car.odometer - distance, .zero)
		}

		// Delete the managed event object
		moc.delete(event)
	}

	static func deleteAllObjects() {
		for entity in persistentContainer.managedObjectModel.entitiesByName.keys {
			let deleteRequest = NSBatchDeleteRequest(fetchRequest: NSFetchRequest(entityName: entity))

			do {
				try persistentContainer.persistentStoreCoordinator.execute(deleteRequest, with: managedObjectContext)
			} catch let error {
				print(error)
			}
		}
	}

}
