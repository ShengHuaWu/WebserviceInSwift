import Foundation
import PlaygroundSupport

enum SerializationError: Error {
    case missing(String)
}

struct Acronym {
    let id: Int
    let short: String
    let long: String
}

typealias JSONDictionary = [String : Any]

extension Acronym {
    init(json: JSONDictionary) throws {
        guard let id = json["id"] as? Int else {
            throw SerializationError.missing("id")
        }
        
        guard let short = json["short"] as? String else {
            throw SerializationError.missing("short")
        }
        
        guard let long = json["long"] as? String else {
            throw SerializationError.missing("long")
        }
        
        self.id = id
        self.short = short
        self.long = long
    }
}

struct Resource<Model> {
    let url: URL
    let parse: (Data) throws -> Model
}

extension Resource {
    init(url: URL, parseJSON: @escaping (Any) throws -> Model) {
        self.url = url
        self.parse = { data in
            let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
            return try parseJSON(json)
        }
    }
}

extension Acronym {
    static let all = Resource<[Acronym]>(url: URL(string: "http://localhost:8080/acronyms")!, parseJSON: { json in
        guard let dictionaries = json as? [JSONDictionary] else { throw SerializationError.missing("acronyms") }
        return try dictionaries.map(Acronym.init)
    })
}

enum Result<Model> {
    case success(Model)
    case failure(Error)
}

final class Webservice {
    func load<Model>(resource: Resource<Model>, completion: @escaping (Result<Model>) -> Void) {
        URLSession.shared.dataTask(with: resource.url) { (data, _, error) in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            } else {
                if let data = data {
                    do {
                        let result = try resource.parse(data)
                        DispatchQueue.main.async {
                            completion(.success(result))
                        }
                    } catch let error {
                        DispatchQueue.main.async {
                            completion(.failure(error))
                        }
                    }
                }
            }
        }.resume()
    }
}

let webservice = Webservice()
webservice.load(resource: Acronym.all) { result in
    debugPrint(result)
    PlaygroundPage.current.finishExecution()
}

PlaygroundPage.current.needsIndefiniteExecution = true
