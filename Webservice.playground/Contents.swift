import Foundation
import PlaygroundSupport

struct Person: Decodable {
    enum CodingKeys: String, CodingKey {
        case name
        case gender
        case birth = "birth_year"
    }
    
    let name: String
    let gender: String
    let birth: String
}

struct PeopleResponse: Decodable {
    let results: [Person]
}

enum HTTPMethod<Parameters> {
    case get(Parameters)
    case post(Parameters)
}

extension HTTPMethod {
    var name: String {
        switch self {
        case .get: return "GET"
        case .post: return "POST"
        }
    }
}

extension HTTPMethod where Parameters: Encodable {
    var body: Data? {
        switch self {
        case .get:
            return nil
        case .post(let parameters):
            return try? JSONEncoder().encode(parameters)
        }
    }
}

struct Resource<Model> {
    var urlRequest: URLRequest
    let parse: (Data) throws -> Model
}

extension Resource where Model: Decodable {
    init<Parameters>(url: URL, method: HTTPMethod<Parameters>) where Parameters: Encodable {
        self.urlRequest = URLRequest(url: url)
        self.urlRequest.httpMethod = method.name
        self.urlRequest.httpBody = method.body
        self.parse = { data in
            try JSONDecoder().decode(Model.self, from: data)
        }
    }
    
    init(get url: URL, method: HTTPMethod<[String: Any]>)  {
        guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            preconditionFailure("Invalid url")
        }
        
        switch method {
        case .get(let parameters):
            urlComponents.queryItems = parameters.map { key, value in
                return URLQueryItem(name: key, value: "\(value)")
            }
        default: break
        }
        
        self.urlRequest = URLRequest(url: urlComponents.url!)
        self.urlRequest.httpMethod = method.name
        self.parse = { data in
            try JSONDecoder().decode(Model.self, from: data)
        }
    }
    
    init(url: URL, method: HTTPMethod<Void> = .get(())) {
        self.urlRequest = URLRequest(url: url)
        self.urlRequest.httpMethod = method.name
        self.parse = { data in
            try JSONDecoder().decode(Model.self, from: data)
        }
    }
}

//let m = HTTPMethod.get(["id": 109876, "name": "%(*!/"])
//let r = Resource<PeopleResponse>(get: URL(string: "https://apple.com")!, method: m)
//print(r.urlRequest.url?.absoluteString ?? "")

extension PeopleResponse {
    static let people = Resource<PeopleResponse>(url: URL(string: "https://swapi.co/api/people")!)
}

enum Result<Model> {
    case success(Model)
    case failure(Error)
}

extension URLSession {
    func load<Model>(resource: Resource<Model>, completion: @escaping (Result<Model>) -> Void) {
        dataTask(with: resource.urlRequest) { [weak self] (data, _, error) in
            defer { self?.finishTasksAndInvalidate() }
            
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

URLSession.shared.load(resource: PeopleResponse.people) { result in
    debugPrint(result)
    PlaygroundPage.current.finishExecution()
}

PlaygroundPage.current.needsIndefiniteExecution = true
