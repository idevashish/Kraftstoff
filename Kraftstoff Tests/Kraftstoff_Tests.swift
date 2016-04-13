//
//  Kraftstoff_Tests.swift
//  Kraftstoff Tests
//
//  Created by Ingmar Stein on 07.05.15.
//
//

import XCTest
import UIKit
import CoreData
@testable import kraftstoff

class Kraftstoff_Tests: XCTestCase {
	private var managedObjectContext: NSManagedObjectContext!

	private func setUpInMemoryManagedObjectContext() -> NSManagedObjectContext {
		let managedObjectModel = NSManagedObjectModel.mergedModel(from: [NSBundle.main()])!

		let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
		do {
			try persistentStoreCoordinator.addPersistentStore(withType: NSInMemoryStoreType, configuration: nil, url: nil, options: nil)
		} catch _ {
		}

		let managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
		managedObjectContext.persistentStoreCoordinator = persistentStoreCoordinator

		return managedObjectContext
	}

	override func setUp() {
        super.setUp()

		managedObjectContext = setUpInMemoryManagedObjectContext()
	}
    
    override func tearDown() {
        super.tearDown()
    }

	private func testRoundtrip(language: String) {
		let car = NSEntityDescription.insertNewObjectForEntity(forName: "car", in:managedObjectContext) as! Car

		car.order = 0
		car.timestamp = NSDate()
		car.name = "Lightning McQueen"
		car.numberPlate = "95"
		car.ksOdometerUnit = .kilometer
		car.odometer = 1000
		car.ksFuelUnit = .liter
		car.ksFuelConsumptionUnit = .litersPer100km

		DemoData.addDemoEventsForCar(car, inContext: managedObjectContext)

		let fuelEvents = CoreDataManager.objectsForFetchRequest(CoreDataManager.fetchRequestForEventsForCar(car,
			beforeDate:nil,
			dateMatches:true,
			inManagedObjectContext:managedObjectContext),
			inManagedObjectContext:managedObjectContext) as! [FuelEvent]

		let csvString = CSVExporter.exportFuelEvents(fuelEvents, forCar:car, language:language)

		var numCars   = 0
		var numEvents = 0
		let url = NSURL(fileURLWithPath: "LightningMcQueen__95.csv")

		let importer = CSVImporter()
		let success = importer.importFromCSVString(csvString,
			detectedCars:&numCars,
			detectedEvents:&numEvents,
			sourceURL:url,
			inContext:managedObjectContext)

		XCTAssert(success, "import should finish successfully")
		XCTAssert(numCars == 1, "should import one car")
		XCTAssert(numEvents == car.fuelEvents.count, "should import all fuel events")
	}

	func testLanguages() {
		for language in ["en", "de", "fr"] {
			testRoundtrip(language)
		}
	}

    func testCSVExport() {
		let car = NSEntityDescription.insertNewObjectForEntity(forName: "car", in: managedObjectContext) as! Car

		car.order = 0
		car.timestamp = NSDate()
		car.name = "Lightning McQueen"
		car.numberPlate = "95"
		car.ksOdometerUnit = .kilometer
		car.odometer = 1000
		car.ksFuelUnit = .liter
		car.ksFuelConsumptionUnit = .litersPer100km

		DemoData.addDemoEventsForCar(car, inContext: managedObjectContext)

		let fuelEvents = CoreDataManager.objectsForFetchRequest(CoreDataManager.fetchRequestForEventsForCar(car,
			beforeDate:nil,
			dateMatches:true,
			inManagedObjectContext:managedObjectContext),
			inManagedObjectContext:managedObjectContext) as! [FuelEvent]

		let csvString = CSVExporter.exportFuelEvents(fuelEvents, forCar:car)

		XCTAssert(csvString.hasPrefix("yyyy-MM-dd;HH:mm;Kilometers;Liters;Full Fill-Up;Price per Liter;Liters per 100 Kilometers;Comment\n2013-07-16;16:10;\"626.00\";\"28.43\";Yes;\"1.389\";\"4.54\";\"\"\n"), "CSV data should have the expected prefix")
		XCTAssert(csvString.characters.count == 5473, "CSV data should have the expected size")
    }

    func testCSVImport() {
		let importer = CSVImporter()
		var numCars   = 0
		var numEvents = 0
		let url = NSURL(fileURLWithPath: "LightningMcQueen__95.csv")

		let CSVString = "yyyy-MM-dd;HH:mm;Kilometers;Liters;Full Fill-Up;Price per Liter;Liters per 100 Kilometers\n2013-07-16;18:10;\"626.00\";\"28.43\";Yes;\"1.389\";\"4.54\"\n"
		let success = importer.importFromCSVString(CSVString,
			detectedCars:&numCars,
			detectedEvents:&numEvents,
			sourceURL:url,
			inContext:managedObjectContext)

		XCTAssert(success, "import should finish successfully")
		XCTAssert(numCars == 1, "should import one car")
		XCTAssert(numEvents == 1, "should import one fuel event")
    }

}
