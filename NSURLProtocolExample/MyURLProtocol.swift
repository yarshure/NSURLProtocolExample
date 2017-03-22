import UIKit
import CoreData

var requestCount = 0

class MyURLProtocol: URLProtocol {
  
  var connection: NSURLConnection!
  var mutableData: NSMutableData!
  var response: URLResponse!
  
  override class func canInit(with request: URLRequest) -> Bool {
    print("Request #\(requestCount): URL = \(request.url!.absoluteString)")
    requestCount += 1
    if URLProtocol.property(forKey: "MyURLProtocolHandledKey", in: request) != nil {
      return false
    }
    
    return true
  }
  
  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    return request
  }
  
  override class func requestIsCacheEquivalent(_ aRequest: URLRequest,
    to bRequest: URLRequest) -> Bool {
      return super.requestIsCacheEquivalent(aRequest, to:bRequest)
  }
  
  override func startLoading() {
    // 1
    let possibleCachedResponse = self.cachedResponseForCurrentRequest()
    if let cachedResponse = possibleCachedResponse {
      print("Serving response from cache")
      
      // 2
      let data = cachedResponse.value(forKey: "data") as! Data!
      let mimeType = cachedResponse.value(forKey: "mimeType") as! String!
      let encoding = cachedResponse.value(forKey: "encoding") as! String!
      
      // 3
      let response = URLResponse(url: self.request.url!, mimeType: mimeType, expectedContentLength: (data?.count)!, textEncodingName: encoding)
      
      // 4
      self.client!.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      self.client!.urlProtocol(self, didLoad: data!)
      self.client!.urlProtocolDidFinishLoading(self)
    } else {
      // 5
      print("Serving response from NSURLConnection")
      
      let newRequest = (self.request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
      URLProtocol.setProperty(true, forKey: "MyURLProtocolHandledKey", in: newRequest)
      self.connection = NSURLConnection(request: newRequest as URLRequest, delegate: self)
    }
  }
  
  override func stopLoading() {
    if self.connection != nil {
      self.connection.cancel()
    }
    self.connection = nil
  }
  
  func connection(_ connection: NSURLConnection!, didReceiveResponse response: URLResponse!) {
    self.client!.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    
    self.response = response
    self.mutableData = NSMutableData()
  }
  
  func connection(_ connection: NSURLConnection!, didReceiveData data: Data!) {
    self.client!.urlProtocol(self, didLoad: data)
    self.mutableData.append(data)
  }
  
  func connectionDidFinishLoading(_ connection: NSURLConnection!) {
    self.client!.urlProtocolDidFinishLoading(self)
    self.saveCachedResponse()
  }
  
  func connection(_ connection: NSURLConnection!, didFailWithError error: NSError!) {
    self.client!.urlProtocol(self, didFailWithError: error)
  }
  
  func saveCachedResponse () {
    print("Saving cached response")
    
    // 1
    let delegate = UIApplication.shared.delegate as! AppDelegate
    let context = delegate.managedObjectContext!
    
    // 2
    let cachedResponse = NSEntityDescription.insertNewObject(forEntityName: "CachedURLResponse", into: context) as NSManagedObject
    
    cachedResponse.setValue(self.mutableData, forKey: "data")
    cachedResponse.setValue(self.request.url!.absoluteString, forKey: "url")
    cachedResponse.setValue(Date(), forKey: "timestamp")
    cachedResponse.setValue(self.response.mimeType, forKey: "mimeType")
    cachedResponse.setValue(self.response.textEncodingName, forKey: "encoding")
    
    // 3
    //var error: NSError?
    do {
        try context.save()
    }catch let e {
        print("\(e)")
    }
    
  }
  
  func cachedResponseForCurrentRequest() -> NSManagedObject? {
    // 1
    let delegate = UIApplication.shared.delegate as! AppDelegate
    let context = delegate.managedObjectContext!
    
    // 2
    let fetchRequest = NSFetchRequest<NSFetchRequestResult>()
    let entity = NSEntityDescription.entity(forEntityName: "CachedURLResponse", in: context)
    fetchRequest.entity = entity
    
    // 3
    let predicate = NSPredicate(format:"url == %@", self.request.url!.absoluteString)
    fetchRequest.predicate = predicate
    
    // 4
    
    do {
        let possibleResult = try context.fetch(fetchRequest)
        //let possibleResult =  possibleResultOrg    as Array<NSManagedObject>?
    
    // 5
    //if let result = possibleResult {
      if !possibleResult.isEmpty {
        return possibleResult[0] as? NSManagedObject
      }
    //}
    }catch let e {
        print(e)
    }
    
    
    return nil
  }
}
