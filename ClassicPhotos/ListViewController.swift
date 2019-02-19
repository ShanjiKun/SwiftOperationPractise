import UIKit
import CoreImage

let dataSourceURL = URL(string:"http://www.raywenderlich.com/downloads/ClassicPhotosDictionary.plist")!

class ListViewController: UITableViewController {

    var photos: [PhotoRecord] = []
    let pendingOperations = PendingOperations()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Classic Photos"
        fetchPhotoDetails()
    }

    // MARK: Table view data source

    override func tableView(_ tableView: UITableView?, numberOfRowsInSection section: Int) -> Int {
        return photos.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CellIdentifier", for: indexPath)
        
        if cell.accessoryView == nil {
            let indicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
            cell.accessoryView = indicator
        }
        
        let indicator = cell.accessoryView as! UIActivityIndicatorView
        
        let photoDetails = photos[indexPath.row]
        
        cell.textLabel?.text = photoDetails.name
        cell.imageView?.image = photoDetails.image
        
        switch photoDetails.state {
        case .filtered:
            indicator.stopAnimating()
            
        case .failed:
            indicator.stopAnimating()
            cell.textLabel?.text = "Failed to load"
            
        default:
            indicator.startAnimating()
            if !tableView.isDragging && !tableView.isDecelerating {
                startOperations(for: photoDetails, at: indexPath)
            }
        }

        return cell
    }
    
    //  MARK: UIScrollView Delegate
    override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        suspendAllOperations()
    }
    
    override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            loadImagesForOnscreenCells()
            resumeAllOperations()
        }
    }
    
    override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        loadImagesForOnscreenCells()
        resumeAllOperations()
    }
}

// MARK: Operations
extension ListViewController {
    
    func startOperations(for photoRecord: PhotoRecord, at indexPath: IndexPath) {
        switch photoRecord.state {
        case .new:
            startDownload(for: photoRecord, at: indexPath)
            
        case .downloaded:
            startFiltration(for: photoRecord, at: indexPath)
            
        default:
            print("Do nothing")
        }
    }
    
    func startDownload(for photoRecord: PhotoRecord, at indexPath: IndexPath) {
        guard pendingOperations.downloadsInProgress[indexPath] == nil else { return }
        
        let downloader = ImageDownloader(photoRecord: photoRecord)
        
        downloader.completionBlock = {
            if downloader.isCancelled { return }
            
            DispatchQueue.main.async {
                self.pendingOperations.downloadsInProgress.removeValue(forKey: indexPath)
                self.tableView.reloadRows(at: [indexPath], with: .fade)
            }
        }
        
        pendingOperations.downloadsInProgress[indexPath] = downloader
        
        pendingOperations.downloadQueue.addOperation(downloader)
    }
    
    func startFiltration(for photoRecord: PhotoRecord, at indexPath: IndexPath) {
        guard pendingOperations.filtrationInProgress[indexPath] == nil else { return }
        
        let filterer = ImageFiltration(photoRecord: photoRecord)
        filterer.completionBlock = {
            if filterer.isCancelled { return }
            
            DispatchQueue.main.async {
                self.pendingOperations.filtrationInProgress.removeValue(forKey: indexPath)
                self.tableView.reloadRows(at: [indexPath], with: .fade)
            }
        }
        
        pendingOperations.filtrationInProgress[indexPath] = filterer
        
        pendingOperations.filtrationQueue.addOperation(filterer)
    }
    
    func suspendAllOperations() {
        pendingOperations.downloadQueue.isSuspended = true
        pendingOperations.filtrationQueue.isSuspended = true
    }
    
    func resumeAllOperations() {
        pendingOperations.downloadQueue.isSuspended = false
        pendingOperations.filtrationQueue.isSuspended = false
    }
    
    func loadImagesForOnscreenCells() {
        guard let visibleRows = tableView.indexPathsForVisibleRows else { return }
        
        var allPendingsOperations = Set(pendingOperations.downloadsInProgress.keys)
        allPendingsOperations.formUnion(pendingOperations.filtrationInProgress.keys)
        
        let visiblePaths = Set(visibleRows)
        
        var toBeCancelled = allPendingsOperations
        toBeCancelled.subtract(visiblePaths)
        
        var toBeStarted = visiblePaths
        toBeStarted.subtract(allPendingsOperations)
        
        /// Cancel operations that do not visible on-screen
        for indexPath in toBeCancelled {
            if let pendingDownload = pendingOperations.downloadsInProgress[indexPath] {
                pendingDownload.cancel()
            }
            
            pendingOperations.downloadsInProgress.removeValue(forKey: indexPath)
            
            if let pendingFiltration = pendingOperations.downloadsInProgress[indexPath] {
                pendingFiltration.cancel()
            }
            
            pendingOperations.filtrationInProgress.removeValue(forKey: indexPath)
        }
        
        /// Start operations that visible on-screen
        for indexPath in toBeStarted {
            let photoRecord = photos[indexPath.row]
            startOperations(for: photoRecord, at: indexPath)
        }
    }
}

//  MARK: Fetching
extension ListViewController {
    
    func fetchPhotoDetails() {
        let request = URLRequest(url: dataSourceURL)
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        
        let task = URLSession(configuration: .default).dataTask(with: request) { (data, response, error) in
            
            let alertController = UIAlertController(title: "Oops!", message: "There was an error fetching photo details.", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default)
            alertController.addAction(okAction)
            
            if let data = data {
                do {
                    let datasourceDictionary = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as! [String: String]
                    
                    for (name, value) in datasourceDictionary {
                        let url = URL(string: value)
                        if let url = url {
                            let photoRecord = PhotoRecord(name: name, url: url)
                            self.photos.append(photoRecord)
                        }
                    }
                    
                    DispatchQueue.main.async {
                        UIApplication.shared.isNetworkActivityIndicatorVisible = false
                        self.tableView.reloadData()
                    }
                    
                } catch {
                    DispatchQueue.main.async {
                        self.present(alertController, animated: true, completion: nil)
                    }
                }
            }
            
            if error != nil {
                DispatchQueue.main.async {
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }
        
        task.resume()
    }
}
