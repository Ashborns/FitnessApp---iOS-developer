import CoreData

@objc(CalorieEntry)
public class CalorieEntry: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var date: Date?
    @NSManaged public var amount: Double
    @NSManaged public var source: String?
    @NSManaged public var label: String?
    @NSManaged public var userProfile: NSManagedObject?
}

extension CalorieEntry: Identifiable {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CalorieEntry> {
        return NSFetchRequest<CalorieEntry>(entityName: "CalorieEntry")
    }

    static func create(
        in context: NSManagedObjectContext,
        amount: Double,
        label: String,
        source: String = "manual"
    ) -> CalorieEntry {
        let entry = CalorieEntry(context: context)
        entry.id = UUID()
        entry.date = Date()
        entry.amount = amount
        entry.label = label
        entry.source = source
        return entry
    }

    static func todayFetchRequest() -> NSFetchRequest<CalorieEntry> {
        let request = NSFetchRequest<CalorieEntry>(entityName: "CalorieEntry")
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        request.predicate = NSPredicate(
            format: "date >= %@ AND date < %@",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CalorieEntry.date, ascending: false)]
        return request
    }

    var wrappedLabel: String {
        label ?? ""
    }

    var wrappedSource: String {
        source ?? "manual"
    }

    var wrappedDate: Date {
        date ?? Date()
    }
}
