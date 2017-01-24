//
//  FuelStatisticsTextViewController.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 05.05.15.
//
//  Textual Statistics View Controller

import UIKit
import CoreData

private let gridLines = 16
private let gridMargin: CGFloat = 16.0
private let gridTextXMargin: CGFloat = 10.0
private let gridTextHeight: CGFloat = 23.0

// MARK: - Disposable Sampling Data Objects for ContentCache

private final class FuelStatisticsData: DiscardableDataObject {
	var car: Car!

	var firstDate: Date!
	var lastDate: Date!

	var totalCost = NSDecimalNumber.zero
	var totalFuelVolume = NSDecimalNumber.zero
	var totalDistance = NSDecimalNumber.zero

	var avgConsumption = NSDecimalNumber.zero
	var bestConsumption: NSDecimalNumber!
	var worstConsumption: NSDecimalNumber!

	var numberOfFillups = 0
	var numberOfFullFillups = 0

	var contentImage: UIImage?

	func discardContent() {
		self.contentImage = nil
	}

}

final class FuelStatisticsTextViewController: FuelStatisticsViewController {

	private var gridLeftBorder: CGFloat!
	private var gridRightBorder: CGFloat!
	private var gridDesColumnWidth: CGFloat!

	override func noteStatisticsPageBecomesVisible() {
		self.scrollView.flashScrollIndicators()
	}

	// MARK: - Graph Computation

	private func resampleFetchedObjects(_ fetchedObjects: [FuelEvent], forCar car: Car, andState state: FuelStatisticsData, inManagedObjectContext moc: NSManagedObjectContext) {
		state.car = car
		state.firstDate = nil
		state.lastDate = nil

		let zero = NSDecimalNumber.zero

		state.totalCost = zero
		state.totalFuelVolume = zero
		state.totalDistance = zero

		state.avgConsumption = zero
		state.bestConsumption = nil
		state.worstConsumption = nil

		state.numberOfFillups = 0
		state.numberOfFullFillups = 0

		let consumptionUnit = car.ksFuelConsumptionUnit

		for fetchedObject in fetchedObjects.lazy.reversed() {
			let managedObject: FuelEvent! = CoreDataManager.existingObject(fetchedObject, inManagedObjectContext: moc) as? FuelEvent

			if managedObject == nil {
				continue
			}

			let distance = managedObject.distance
			let fuelVolume = managedObject.fuelVolume
			let cost = managedObject.cost

			// Collect dates of events
			let timestamp = managedObject.timestamp

			if state.firstDate == nil || timestamp <= state.firstDate! {
				state.firstDate = timestamp
			}

			if state.lastDate == nil || timestamp >= state.lastDate! {
				state.lastDate = timestamp
			}

			// Summarize all amounts
			state.totalCost += cost
			state.totalFuelVolume += fuelVolume
			state.totalDistance += distance

			// Track consumption
			if managedObject.filledUp {

				let inheritedDistance = managedObject.inheritedDistance
				let inheritedFuelVolume = managedObject.inheritedFuelVolume

				let consumption = Units.consumptionForKilometers(distance + inheritedDistance,
                                                                          liters: fuelVolume + inheritedFuelVolume,
                                                                          inUnit: consumptionUnit)

				state.avgConsumption += consumption

				if consumptionUnit.isEfficiency {
					state.bestConsumption  = max(consumption, state.bestConsumption ?? consumption)
					state.worstConsumption = min(consumption, state.worstConsumption ?? consumption)
				} else {
					state.bestConsumption  = min(consumption, state.bestConsumption ?? consumption)
					state.worstConsumption = max(consumption, state.worstConsumption ?? consumption)
				}

				state.numberOfFullFillups += 1
			}

			state.numberOfFillups += 1
		}

		// Compute average consumption
		if state.totalDistance != .zero && state.totalFuelVolume != .zero {
			state.avgConsumption = Units.consumptionForKilometers(state.totalDistance,
                                                               liters: state.totalFuelVolume,
                                                               inUnit: consumptionUnit)
		}
	}

	override func computeStatisticsForRecentMonths(_ numberOfMonths: Int, forCar car: Car, withObjects fetchedObjects: [FuelEvent], inManagedObjectContext moc: NSManagedObjectContext) -> DiscardableDataObject {

		// No cache cell exists => resample data and compute average value
		var state: FuelStatisticsData! = self.contentCache[numberOfMonths] as? FuelStatisticsData

		if state == nil {
			state = FuelStatisticsData()
			resampleFetchedObjects(fetchedObjects, forCar: car, andState: state, inManagedObjectContext: moc)
		}

		// Create image data from resampled data
		if state.contentImage == nil {
			let height = (state.numberOfFillups == 0) ? statisticsHeight : gridTextHeight*CGFloat(gridLines) + 10.0

			let renderer = UIGraphicsImageRenderer(size: CGSize(width: self.view.bounds.size.width, height: height))
			state.contentImage = renderer.image { context in
				drawStatisticsForState(state, withHeight: height, context: context.cgContext)
			}
		}

		return state
	}

	// MARK: - Graph Display

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()

		self.gridLeftBorder = gridMargin
		self.gridRightBorder = self.view.bounds.size.width - gridMargin
		self.gridDesColumnWidth = (self.view.bounds.size.width - gridMargin - gridMargin) / 2.0

		// Initialize contents of background view
		if let imageView = self.view as? UIImageView {
			let format = UIGraphicsImageRendererFormat.default()
			format.opaque = true
			let renderer = UIGraphicsImageRenderer(bounds: self.view.bounds, format: format)
			imageView.image = renderer.image { context in
				drawBackground(context.cgContext)
			}
		}
	}

	private func drawBackground(_ context: CGContext) {
		// Background colors
		#colorLiteral(red: 0.08235294118, green: 0.08235294118, blue: 0.08235294118, alpha: 1).setFill()
		context.fill(self.view.bounds)

		#colorLiteral(red: 0, green: 0, blue: 0, alpha: 1).setFill()
		context.fill(CGRect(x: 0, y: 0, width: self.view.bounds.size.width, height: 28))
	}

	private func drawStatisticsForState(_ state: FuelStatisticsData, withHeight height: CGFloat, context: CGContext) {
		#colorLiteral(red: 0, green: 0, blue: 0, alpha: 0).setFill()
		context.fill(CGRect(x: 0, y: 0, width: self.view.bounds.size.width, height: height))

		let font = UIFont.preferredFont(forTextStyle: .body)
		let labelAttributes: [String: AnyObject] = [ NSFontAttributeName: font, NSForegroundColorAttributeName: #colorLiteral(red: 0.7799999714, green: 0.7799999714, blue: 0.7799999714, alpha: 1) ]
		let valueAttributes: [String: AnyObject] = [ NSFontAttributeName: font, NSForegroundColorAttributeName: #colorLiteral(red: 1, green: 0.99997437, blue: 0.9999912977, alpha: 1) ]

		var x: CGFloat
		var y: CGFloat

		if state.numberOfFillups == 0 {

			context.saveGState()

			#colorLiteral(red: 1, green: 0.99997437, blue: 0.9999912977, alpha: 1).setFill()

			let text = NSLocalizedString("Not enough data to display statistics", comment: "")
			let size = text.size(attributes: valueAttributes)

            x = floor ((self.view.bounds.size.width -  size.width)/2.0)
            y = floor ((self.view.bounds.size.height - (size.height - font.descender))/2.0)

			text.draw(at: CGPoint(x: x, y: y), withAttributes: valueAttributes)

			context.restoreGState()

		} else {

			// Horizontal grid backgrounds
			let path = UIBezierPath()

			path.lineWidth = gridTextHeight - 1
			#colorLiteral(red: 0.2235294118, green: 0.2235294118, blue: 0.2235294118, alpha: 1).setStroke()

			context.saveGState()

			path.removeAllPoints()
			path.move(to: CGPoint(x: self.gridLeftBorder, y: 1.0))
			path.addLine(to: CGPoint(x: self.gridRightBorder, y: 1.0))

			var y = CGFloat(0.0)
			for i in stride(from: 1, to: gridLines, by: 2) {
                let lastY = y
                y = rint (gridTextHeight*0.5 + gridTextHeight*CGFloat(i))

				context.translateBy(x: 0.0, y: y - lastY)
                path.stroke()
            }

			context.restoreGState()

			#colorLiteral(red: 0.4499999881, green: 0.4499999881, blue: 0.4499999881, alpha: 0.5).setStroke()

			// Horizontal grid lines
			let dashDotPattern: [CGFloat] = [ 0.5, 0.5 ]
			let dashDotPatternLength = 1
			path.lineWidth = 1.0 / UIScreen.main.scale

			path.setLineDash(dashDotPattern, count: dashDotPatternLength, phase: 0.0)

			context.saveGState()

			path.removeAllPoints()
			path.move(to: CGPoint(x: self.gridLeftBorder, y: 0.25))
			path.addLine(to: CGPoint(x: self.gridRightBorder, y: 0.25))

			y = CGFloat(0.0)
            for i in 1...gridLines {
                let lastY = y
                y = rint(gridTextHeight * CGFloat(i))

				context.translateBy(x: 0.0, y: y - lastY)
                path.stroke()
            }

			context.restoreGState()

			// Vertical grid line
			path.lineWidth = 0.5
			path.setLineDash(nil, count: 0, phase: 0.0)

			context.saveGState()

			path.removeAllPoints()
			path.move(to: CGPoint(x: self.gridLeftBorder + self.gridDesColumnWidth + 0.25, y: 0.0))
			path.addLine(to: CGPoint(x: self.gridLeftBorder + self.gridDesColumnWidth + 0.25, y: gridTextHeight*CGFloat(gridLines)))
            path.stroke()

			context.restoreGState()

			// Textual information
			context.saveGState()

			context.setShadow(offset: CGSize(width: 0.0, height: -1.0), blur: 0.0, color: #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1).cgColor)

            let nf = Formatters.fuelVolumeFormatter
            let cf = Formatters.currencyFormatter
            let pcf = Formatters.preciseCurrencyFormatter
            let zero = NSDecimalNumber.zero

            let consumptionUnit = state.car.ksFuelConsumptionUnit
            let consumptionUnitString = Formatters.shortMeasurementFormatter.string(from: consumptionUnit)

            let odometerUnit = state.car.ksOdometerUnit
            let odometerUnitString = Formatters.shortMeasurementFormatter.string(from: odometerUnit)

			let fuelUnit = state.car.ksFuelUnit
            let fuelUnitString = Formatters.shortMeasurementFormatter.string(from: fuelUnit)

            let numberOfDays = Date.numberOfCalendarDaysFrom(state.firstDate, to: state.lastDate)

			y = (gridTextHeight - font.lineHeight) / 2.0

			func drawEntry(label: String, value: String) {
				let size = label.size(attributes: labelAttributes)
				let x1 = self.gridLeftBorder + self.gridDesColumnWidth - size.width - gridTextXMargin
				label.draw(at: CGPoint(x: x1, y: y), withAttributes: labelAttributes)

				let x2 = self.gridLeftBorder + self.gridDesColumnWidth + gridTextXMargin
				value.draw(at: CGPoint(x: x2, y: y), withAttributes: valueAttributes)

				y += gridTextHeight
			}

            // number of days
			drawEntry(
				label: NSLocalizedString("days", comment: ""),
				value: "\(Date.numberOfCalendarDaysFrom(state.firstDate, to: state.lastDate))")

            // avg consumption
            drawEntry(
				label: NSLocalizedString(consumptionUnit.isEfficiency ? "avg_efficiency" : "avg_consumption", comment: ""),
				value: "\(nf.string(from: state.avgConsumption)!) \(consumptionUnitString)")

            // best consumption
			drawEntry(
				label: NSLocalizedString(consumptionUnit.isEfficiency ? "max_efficiency" : "min_consumption", comment: ""),
				value: "\(nf.string(from: state.bestConsumption)!) \(consumptionUnitString)")

            // worst consumption
			drawEntry(
				label: NSLocalizedString(consumptionUnit.isEfficiency ? "min_efficiency" : "max_consumption", comment: ""),
				value: "\(nf.string(from: state.worstConsumption)!) \(consumptionUnitString)")

            // total cost
			drawEntry(label: NSLocalizedString("ttl_cost", comment: ""), value: cf.string(from: state.totalCost)!)

            // total distance
			let totalDistance = Units.distanceForKilometers(state.totalDistance, withUnit: odometerUnit)
			drawEntry(
				label: NSLocalizedString("ttl_distance", comment: ""),
                value: "\(Formatters.distanceFormatter.string(from: totalDistance)!) \(odometerUnitString)")

            // total volume
			let totalVolume = Units.volumeForLiters(state.totalFuelVolume, withUnit: fuelUnit)
			drawEntry(
				label: NSLocalizedString("ttl_volume", comment: ""),
				value: "\(nf.string(from: totalVolume)!) \(fuelUnitString)")

            // total events
			drawEntry(label: NSLocalizedString("ttl_events", comment: ""), value: "\(state.numberOfFillups)")

            // volume per event
			let volumePerEventLabel = NSLocalizedString("volume_event", comment: "")
			if state.numberOfFillups > 0 {
				let val = Units.volumeForLiters(state.totalFuelVolume, withUnit: fuelUnit) / NSDecimalNumber(value: state.numberOfFillups)
				drawEntry(label: volumePerEventLabel, value: "\(nf.string(from: val)!) \(fuelUnitString)")
			} else {
				drawEntry(label: volumePerEventLabel, value: NSLocalizedString("-", comment: ""))
			}

            // cost per distance
			let costPerDistanceLabel = String(format: NSLocalizedString("cost_per_x", comment: ""), Units.odometerUnitDescription(odometerUnit, pluralization: false))
			if zero < state.totalDistance {
				let val = state.totalCost / Units.distanceForKilometers(state.totalDistance, withUnit: odometerUnit)
				drawEntry(label: costPerDistanceLabel, value: "\(pcf.string(from: val)!)/\(odometerUnitString)")
			} else {
				drawEntry(label: costPerDistanceLabel, value: NSLocalizedString("-", comment: ""))
			}

            // cost per volume
			let costPerVolumeLabel = String(format: NSLocalizedString("cost_per_x", comment: ""), Units.fuelUnitDescription(fuelUnit, discernGallons: true, pluralization: false))
			if zero < state.totalFuelVolume {
				let val = state.totalCost / Units.volumeForLiters(state.totalFuelVolume, withUnit: fuelUnit)
				drawEntry(label: costPerVolumeLabel, value: "\(pcf.string(from: val)!)/\(fuelUnitString)")
			} else {
				drawEntry(label: costPerVolumeLabel, value: NSLocalizedString("-", comment: ""))
			}

            // cost per day
			let costPerDayLabel = String(format: NSLocalizedString("cost_per_x", comment: ""), NSLocalizedString("day", comment: ""))
			if numberOfDays > 0 {
				let val = state.totalCost / NSDecimalNumber(value: numberOfDays)
				drawEntry(label: costPerDayLabel, value: cf.string(from: val)!)
			} else {
				drawEntry(label: costPerDayLabel, value: NSLocalizedString("-", comment: ""))
			}

            // cost per event
			let costPerEventLabel = String(format: NSLocalizedString("cost_per_x", comment: ""), NSLocalizedString("event", comment: ""))
			if state.numberOfFillups > 0 {
				let val = state.totalCost / NSDecimalNumber(value: state.numberOfFillups)
				drawEntry(label: costPerEventLabel, value: cf.string(from: val)!)
			} else {
				drawEntry(label: costPerEventLabel, value: NSLocalizedString("-", comment: ""))
			}

            // distance per event
			let distancePerEventLabel = String(format: NSLocalizedString("x_per_y", comment: ""), Units.odometerUnitDescription(odometerUnit, pluralization: true), NSLocalizedString("event", comment: ""))
			if state.numberOfFillups > 0 {
				let val = Units.distanceForKilometers(state.totalDistance, withUnit: odometerUnit) / NSDecimalNumber(value: state.numberOfFillups)
				drawEntry(label: distancePerEventLabel, value: "\(nf.string(from: val)!) \(odometerUnitString)")
			} else {
				drawEntry(label: distancePerEventLabel, value: NSLocalizedString("-", comment: ""))
			}

            // distance per day
			let distancePerDayLabel = String(format: NSLocalizedString("x_per_y", comment: ""), Units.odometerUnitDescription(odometerUnit, pluralization: true), NSLocalizedString("day", comment: ""))
			if numberOfDays > 0 {
				let val = Units.distanceForKilometers(state.totalDistance, withUnit: odometerUnit) / NSDecimalNumber(value: numberOfDays)
				drawEntry(label: distancePerDayLabel, value: "\(nf.string(from: val)!) \(odometerUnitString)")
			} else {
				drawEntry(label: distancePerDayLabel, value: NSLocalizedString("-", comment: ""))
			}

            // distance per money
			let distancePerMoneyLabel = String(format: NSLocalizedString("x_per_y", comment: ""), Units.odometerUnitDescription(odometerUnit, pluralization: true), cf.currencySymbol!)
			if zero < state.totalCost {
				let val = Units.distanceForKilometers(state.totalDistance, withUnit: odometerUnit) / state.totalCost
				drawEntry(label: distancePerMoneyLabel, value: "\(nf.string(from: val)!) \(odometerUnitString)")
			} else {
				drawEntry(label: distancePerMoneyLabel, value: NSLocalizedString("-", comment: ""))
			}

			context.restoreGState()
		}
	}

	override func displayCachedStatisticsForRecentMonths(_ numberOfMonths: Int) -> Bool {
		let cell = self.contentCache[numberOfMonths] as? FuelStatisticsData

		// Cache Hit => Update image contents
		if let contentImage = cell?.contentImage {
			self.activityView.stopAnimating()

			let imageFrame = CGRect(x: 0, y: 0, width: contentImage.size.width, height: contentImage.size.height)

			var imageView: UIImageView! = self.scrollView.viewWithTag(1) as? UIImageView

			if imageView == nil {
				imageView = UIImageView(frame: imageFrame)
				imageView.tag = 1
				imageView.isOpaque = false
				imageView.backgroundColor = .clear

				self.scrollView.isHidden = false
				self.scrollView.addSubview(imageView)
			}

			if imageView.frame.isEmpty {
				imageView.image = contentImage
				imageView.frame = imageFrame
			} else {
				UIView.transition(with: imageView,
                              duration: statisticTransitionDuration,
                               options: .transitionCrossDissolve,
                            animations: {
                                imageView.image = contentImage
                                imageView.frame = imageFrame
							},
                            completion: nil)
			}

			self.scrollView.contentSize = imageView.image!.size

			UIView.animate(withDuration: statisticTransitionDuration,
                         animations: { self.scrollView.alpha = 1.0 },
                         completion: { finished in
							if finished {
								self.scrollView.flashScrollIndicators()
							}
                         })

			return true
		} else {
			// Cache Miss => draw preliminary contents

			UIView.animate(withDuration: statisticTransitionDuration,
                         animations: { self.scrollView.alpha = 0.0 },
                         completion: { finished in
                             if finished {
								self.activityView.startAnimating()
								let imageView: UIImageView! = self.scrollView.viewWithTag(1) as? UIImageView
								if imageView != nil {
                                     imageView.image = nil
                                     imageView.frame = .zero
                                     self.scrollView.contentSize = .zero
                                 }
                             }
                         })

			return false
		}
	}

}
