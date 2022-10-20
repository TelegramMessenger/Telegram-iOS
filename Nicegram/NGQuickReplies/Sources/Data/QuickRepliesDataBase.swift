import CoreData

protocol QuickRepliesDatabase {
    func getQuickRepliesWith(telegramUserId: Int64) throws -> [QuickReply]
    func getItemWith(id: String) throws -> QuickReply?
    func insertOrUpdate(quickReply: QuickReply) throws
    func delete(ids: [String]) throws
}

class QuickRepliesDatabaseMock: QuickRepliesDatabase {
    func getQuickRepliesWith(telegramUserId: Int64) throws -> [QuickReply] {
        return []
    }
    
    func getItemWith(id: String) throws -> QuickReply? {
        return nil
    }
    
    func insertOrUpdate(quickReply: QuickReply) throws {
        
    }
    
    func delete(ids: [String]) throws {
        
    }
}


@available(iOS 10.0, *)
class QuickRepliesDatabaseImpl: QuickRepliesDatabase {
    
    //  MARK: - Internal logic
    
    private lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "QuickReplies", managedObjectModel: makeManagedObjectModel())
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                debugPrint("Unresolved error \(error), \(error.userInfo)")
            }
        })
        
        return container
    }()
    
    private lazy var context: NSManagedObjectContext = persistentContainer.viewContext
    
    //  MARK: - Public Functions

    func getQuickRepliesWith(telegramUserId: Int64) throws -> [QuickReply] {
        let request = QuickReplyManagedObject._fetchRequest()
        
        let predicate = NSPredicate(format: "%K == %lld", #keyPath(QuickReplyManagedObject.telegramUserId), telegramUserId)
        
        request.predicate = predicate
        
        let dtos = try context.fetch(request)
        let result = dtos.compactMap({ self.mapToDomain($0) })
        return result
    }
    
    func getItemWith(id: String) throws -> QuickReply? {
        let dto = try getDtoWith(id: id)
        return mapToDomain(dto)
    }
    
    func insertOrUpdate(quickReply: QuickReply) throws {
        let dto = mapToDto(quickReply)
        
        let object: QuickReplyManagedObject
        if let _object = try getDtoWith(id: quickReply.id) {
            object = _object
        } else {
            object = QuickReplyManagedObject(context: context)
        }
        
        update(managedObject: object, with: dto)
        try object.managedObjectContext?.saveIfChanged()
    }
    
    func delete(ids: [String]) throws {
        for id in ids {
            if let object = try getDtoWith(id: id) {
                context.delete(object)
            }
        }
        try context.saveIfChanged()
    }
    
    //  MARK: - Private Functions

    private func getDtoWith(id: String) throws -> QuickReplyManagedObject? {
        let request = QuickReplyManagedObject._fetchRequest()
        
        let predicate = NSPredicate(format: "%K == %@", #keyPath(QuickReplyManagedObject.id), id)
        
        request.predicate = predicate
        request.fetchLimit = 1
        
        return (try context.fetch(request)).first
    }
    
    private func update(managedObject: QuickReplyManagedObject, with dto: QuickReplyDTO) {
        if managedObject.id != dto.id {
            managedObject.id = dto.id
        }
        
        if managedObject.telegramUserId != dto.telegramUserId {
            managedObject.telegramUserId = dto.telegramUserId
        }
        
        if managedObject.text != dto.text {
            managedObject.text = dto.text
        }
        
        if managedObject.createdAt != dto.createdAt {
            managedObject.createdAt = dto.createdAt
        }
        
        if managedObject.updatedAt != dto.updatedAt {
            managedObject.updatedAt = dto.updatedAt
        }
    }
    
}

extension NSManagedObjectContext {
    func saveIfChanged() throws {
        if hasChanges {
            try save()
        }
    }
}

//  MARK: - Mapping

@available(iOS 10.0, *)
private extension QuickRepliesDatabaseImpl {
    func mapToDomain(_ dto: QuickReplyManagedObject?) -> QuickReply? {
        if let dto = dto {
            return QuickReply(id: dto.id, telegramUserId: dto.telegramUserId, text: dto.text, createdAt: mapTimeIntervalToDate(dto.createdAt), updatedAt: mapTimeIntervalToDate(dto.updatedAt))
        } else {
            return nil
        }
    }
    
    func mapToDto(_ domain: QuickReply) -> QuickReplyDTO {
        return QuickReplyDTO(id: domain.id, telegramUserId: domain.telegramUserId, text: domain.text, createdAt: mapDateToTimeInterval(domain.createdAt), updatedAt: mapDateToTimeInterval(domain.updatedAt))
    }
    
    func mapTimeIntervalToDate(_ timeInteval: Double) -> Date {
        return Date(timeIntervalSince1970: timeInteval)
    }
    
    func mapDateToTimeInterval(_ date: Date) -> Double {
        return date.timeIntervalSince1970
    }
}

//  MARK: - DTO

private struct QuickReplyDTO {
    let id: String
    let telegramUserId: Int64
    let text: String
    let createdAt: Double
    let updatedAt: Double
}

private class QuickReplyManagedObject: NSManagedObject {
    @NSManaged var id: String
    @NSManaged var telegramUserId: Int64
    @NSManaged var text: String
    @NSManaged var createdAt: Double
    @NSManaged var updatedAt: Double
}

extension QuickReplyManagedObject {
    class func _fetchRequest() -> NSFetchRequest<QuickReplyManagedObject> {
        return NSFetchRequest<QuickReplyManagedObject>(entityName: "QuickReply")
    }
}

//  MARK: - Private Functions

private func makeManagedObjectModel() -> NSManagedObjectModel {
    let model = NSManagedObjectModel()
    
    model.entities = [makeQuickReplyEntityDescription()]
    
    return model
}

private func makeQuickReplyEntityDescription() -> NSEntityDescription {
    let entity = NSEntityDescription()
    entity.name = "QuickReply"
    entity.managedObjectClassName = NSStringFromClass(QuickReplyManagedObject.self)
    
    let idAttr = NSAttributeDescription()
    idAttr.name = "id"
    idAttr.attributeType = .stringAttributeType
    
    let telegramUserIdAttr = NSAttributeDescription()
    telegramUserIdAttr.name = "telegramUserId"
    telegramUserIdAttr.attributeType = .integer64AttributeType
    
    let textAttr = NSAttributeDescription()
    textAttr.name = "text"
    textAttr.attributeType = .stringAttributeType
    
    let createdAtAttr = NSAttributeDescription()
    createdAtAttr.name = "createdAt"
    createdAtAttr.attributeType = .doubleAttributeType
    
    let updatedAtAttr = NSAttributeDescription()
    updatedAtAttr.name = "updatedAt"
    updatedAtAttr.attributeType = .doubleAttributeType
    
    entity.properties = [idAttr, telegramUserIdAttr, textAttr, createdAtAttr, updatedAtAttr]
    
    return entity
}

