//  ViewController.swift
import UIKit
import MapsIndoorsCore
import MapsIndoorsMapbox
import MapboxMaps

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {
    
    // Add the renderer property and origin point(static for demo purpose)
    var directionsRenderer: MPDirectionsRenderer?
    var origin: MPLocation?
    
    // Add this property to hold a reference to the MPMapControl object
    var mpMapControl: MPMapControl?
    
    var searchResult: [MPLocation]?
    lazy var destinationSearch = UISearchBar(frame: CGRect(x: 0, y: 40, width: 0, height: 0))
    var tableView = UITableView(frame: CGRect(x: 0, y: 90, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
    
    // Buttons for Live Data
    lazy var livePositionButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle("Toggle Live Position", for: .normal)
        button.backgroundColor = UIColor(red: 35/255, green: 85/255, blue: 84/255, alpha: 1)
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(toggleLivePosition), for: .touchUpInside)
        return button
    }()
    
    lazy var liveOccupancyButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle("Toggle Live Occupancy", for: .normal)
        button.backgroundColor = UIColor(red: 35/255, green: 85/255, blue: 84/255, alpha: 1)
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(toggleLiveOccupancy), for: .touchUpInside)
        return button
    }()
    
    var isLivePositionEnabled = false
    var isLiveOccupancyEnabled = false
    
    var mapView: MapView!
    var mapConfig: MPMapConfig?
    var mapControl: MPMapControl?
    let peabodyLocation: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 41.31603475309376, longitude: -72.92123894810422)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up the Mapbox map view
        let mapInitOptions = MapInitOptions(resourceOptions: ResourceOptions(accessToken: AppDelegate.mapBoxApiKey), styleURI: StyleURI.light)
        mapView = MapView(frame: view.bounds, mapInitOptions: mapInitOptions)
        view.addSubview(mapView)
        
        // Set up the autoresizing mask to keep the map's frame synced with the view controller's frame.
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Initialize the MPMapConfig with the Mapbox map view. A MPMapConfig is needed to initialise MPMapsIndoors.
        mapConfig = MPMapConfig(mapBoxView: mapView, accessToken: AppDelegate.mapBoxApiKey)
        
        // set camera over venue
        setCamera(coordinates: peabodyLocation, zoom: 18)
        
        Task {
            do {
                // Load MapsIndoors with the MapsIndoors API key.
                try await MPMapsIndoors.shared.load(apiKey: AppDelegate.mApiKey)
                
                if let mapConfig = mapConfig {
                    if let mapControl = MPMapsIndoors.createMapControl(mapConfig: mapConfig) {
                        
                        // Retain the mapControl object
                        self.mpMapControl = mapControl
                        
                        let query = MPQuery()
                        let filter = MPFilter()
                        
                        query.query = "Elevator"
                        filter.take = 1
                        
                        let locations = await MPMapsIndoors.shared.locationsWith(query: query, filter: filter)
                        if let firstLocation = locations.first {
                            mapControl.select(location: firstLocation, behavior: .default)
                            mapControl.select(floorIndex: firstLocation.floorIndex.intValue)
                            // set the origin as Family Dining room
                            origin = firstLocation
                        }
                    }
                }
                
            } catch {
                print("Error loading MapsIndoors: \(error.localizedDescription)")
            }
        }
        
        destinationSearch.sizeToFit()
        destinationSearch.delegate = self
        destinationSearch.barTintColor = UIColor(red: 35/255, green: 85/255, blue: 84/255, alpha: 1)
        destinationSearch.searchTextField.textColor = .white
        destinationSearch.searchTextField.backgroundColor = UIColor(red: 75/255, green: 125/255, blue: 124/255, alpha: 0.3)
        destinationSearch.searchTextField.layer.cornerRadius = 8
        destinationSearch.searchTextField.clipsToBounds = true
        view.addSubview(destinationSearch)
        
        tableView.dataSource = self
        tableView.delegate = self
        
        // Add the buttons to the view and set their constraints
        view.addSubview(livePositionButton)
        view.addSubview(liveOccupancyButton)
        
        livePositionButton.translatesAutoresizingMaskIntoConstraints = false
        liveOccupancyButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            livePositionButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            livePositionButton.topAnchor.constraint(equalTo: destinationSearch.bottomAnchor, constant: 8),
            
            liveOccupancyButton.leadingAnchor.constraint(equalTo: livePositionButton.trailingAnchor, constant: 16),
            liveOccupancyButton.centerYAnchor.constraint(equalTo: livePositionButton.centerYAnchor)
        ])
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResult?.count ?? 0
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        let location = searchResult?[indexPath.row]
        cell.textLabel?.text = location?.name ?? ""
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let location = searchResult?[indexPath.row] else { return }
        mpMapControl?.goTo(entity: location) // Use the retained mpMapControl object
        tableView.removeFromSuperview()
        
        // Call the directions(to:) function
        directions(to: location)
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        view.addSubview(tableView)
        let query = MPQuery()
        let filter = MPFilter()
        query.query = searchText
        filter.take = 100
        Task {
            searchResult = await MPMapsIndoors.shared.locationsWith(query: query, filter: filter)
            tableView.reloadData()
        }
    }
    
    func directions(to destination: MPLocation) {
        guard let mapControl = mpMapControl else { return }
        
        if directionsRenderer == nil {
            directionsRenderer = mapControl.newDirectionsRenderer()
        }
        
        let directionsQuery = MPDirectionsQuery(origin: origin!, destination: destination)
        
        Task {
            do {
                let route = try await MPMapsIndoors.shared.directionsService.routingWith(query: directionsQuery)
                directionsRenderer?.route = route
                directionsRenderer?.routeLegIndex = 0
                directionsRenderer?.animate(duration: 5)
            } catch {
                print("Error getting directions: \(error.localizedDescription)")
            }
        }
    }
    
    // Functions for Live Data
    @objc func toggleLivePosition() {
        isLivePositionEnabled.toggle()
        if isLivePositionEnabled {
            mpMapControl?.enableLiveData(domain: MPLiveDomainType.position) { liveUpdate in
                // Handle the live position updates here
                print("Position live update: \(liveUpdate)")
            }
        } else {
            mpMapControl?.disableLiveData(domain: MPLiveDomainType.position)
        }
    }

    @objc func toggleLiveOccupancy() {
        isLiveOccupancyEnabled.toggle()
        if isLiveOccupancyEnabled {
            mpMapControl?.enableLiveData(domain: MPLiveDomainType.occupancy) { liveUpdate in
                // Handle the live occupancy updates here
                print("Occupancy live update: \(liveUpdate)")
            }
        } else {
            mpMapControl?.disableLiveData(domain: MPLiveDomainType.occupancy)
        }
    }
    
    func setCamera(coordinates: CLLocationCoordinate2D, zoom: Float) {
        mapView.mapboxMap.onNext(event: .mapLoaded) { _ in
            self.mapView.camera.fly(to: CameraOptions(center: coordinates, padding: UIEdgeInsets(), anchor: nil, zoom: CGFloat(zoom), bearing: CLLocationDirection(0), pitch: CGFloat(0)), duration: TimeInterval(0.5)) { _ in }
        }
    }
}
