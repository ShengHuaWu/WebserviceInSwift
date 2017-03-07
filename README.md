## Web Service in Swift
One day I watched [Vapor's tutorial series on raywenderlich.com website](https://videos.raywenderlich.com/screencasts/server-side-swift-with-vapor-getting-started) and followed them to implement a very simple RESTful server. 
Those tutorials have been very great and they taught me how to build up a server step by step. 
After finishing my simple server, I suddenly thought it's time to make a simple iOS web service as well for testing my server because I could adopt the networking concept that I grabbed from [objc.io's Swift talk #1](https://talk.objc.io/episodes/S01E01-networking). 
(If you haven't watched those fantastic videos yet, I highly recommend that you should watch them!)

### Implementation
In Swift talk #1, Chris and Florian showed how to create a web service from scratch and how to parse JSON data into a model instance as well. 
There have been three major types: _Resource_, _Webservice_ and their model type --- _Episode_. I did little tweaks from their original version.
First, I replaced the model type with _Acronym_ which is the model of my simple server and wrote a failable initializer which has been related to [Apple's suggestion](https://developer.apple.com/swift/blog/?id=37).
```
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
```
Because _Acronym_'s failable initializer could throw an error, I had to modify the implementation of _Resource_'s parse closure and its customized initializer as well.
```
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
```
In addition, I edited _Acronym_'s static property to return a _Resource_.
```
extension Acronym {
    static let all = Resource<[Acronym]>(url: URL(string: "http://localhost:8080/acronyms")!, parseJSON: { json in
        guard let dictionaries = json as? [JSONDictionary] else { throw SerializationError.missing("acronyms") }
        return try dictionaries.map(Acronym.init)
    })
}
```
Finally, I created a _Result_ enum to wrap the response from my server and put the completion closure in _Webservice_'s load method back to the main thread.
```
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
```
Then, I could get all my acronyms from my own server!
```
let webservice = Webservice()
webservice.load(resource: Acronym.all) { result in
    debugPrint(result)
}
```
The source code playground is [here](https://github.com/ShengHuaWu/WebserviceInSwift).

### Conclusion
The networking request inside _Webservice_'s load method is the only asynchronous invocation in this implementation and the rest of codes are all synchronous. 
Thus, we are able to write unit tests against them more conveniently, instead of generating a lot of _XCTestExpectation_ instances. 
Furthermore, it's also very straightforward to add another API endpoint or another Model struct. 
Any comment and feedback are welcome, so please share your thoughts. Thank you!
