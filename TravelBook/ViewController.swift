import UIKit
import MapKit
import CoreData

class ViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {

    @IBOutlet weak var commentText: UITextField!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var nameText: UITextField!
    
    var locationManager = CLLocationManager()
    var userLocation: CLLocationCoordinate2D?
    var chosenLatitude = Double()
    var chosenLongitude = Double()
    var selectedTitle = ""
    var selectedTitleID : UUID?
    var annotationTitle = ""
    var annotationSubtitle = ""
    var annotationLatitude = Double()
    var annotationLongitude = Double()
    var isLocationSet = false
    var isAddingNewPlace = false

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Klavyeyi kapatmak için dokunma algılayıcı ekleyin
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(hideKeyboard))
        view.addGestureRecognizer(tapGesture)
        
        // Geri butonunu ayarla
        let backButton = UIBarButtonItem()
        backButton.title = "Geri"
        navigationItem.backBarButtonItem = backButton

        mapView.delegate = self
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()

        // Konum güncellemeleri
        if selectedTitle == "" {
            locationManager.startUpdatingLocation()
        }

        // Gesture recognizer ekleyin
        let gestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(chooseLocation(gestureRecognizer:)))
        gestureRecognizer.minimumPressDuration = 2
        mapView.addGestureRecognizer(gestureRecognizer)

        let saveButton = UIBarButtonItem(title: "Kaydet", style: .plain, target: self, action: #selector(saveButtonClicked))
        navigationItem.rightBarButtonItem = saveButton

        if selectedTitle != "" {
            // Seçilen yer varsa, verileri CoreData'dan çek
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let context = appDelegate.persistentContainer.viewContext
            
            saveButton.isHidden = true
            
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Places")
            let idString = selectedTitleID!.uuidString
            fetchRequest.predicate = NSPredicate(format: "id = %@", idString)
            fetchRequest.returnsObjectsAsFaults = false
            
            do {
                let results = try context.fetch(fetchRequest)
                if results.count > 0 {
                    for result in results as! [NSManagedObject] {
                        if let title = result.value(forKey: "title") as? String {
                            annotationTitle = title
                        }
                        if let subtitle = result.value(forKey: "subtitle") as? String {
                            annotationSubtitle = subtitle
                        }
                        if let latitude = result.value(forKey: "latitude") as? Double {
                            annotationLatitude = latitude
                        }
                        if let longitude = result.value(forKey: "longitude") as? Double {
                            annotationLongitude = longitude
                        }

                        let annotation = MKPointAnnotation()
                        annotation.title = annotationTitle
                        annotation.subtitle = annotationSubtitle
                        let coordinate = CLLocationCoordinate2D(latitude: annotationLatitude, longitude: annotationLongitude)
                        annotation.coordinate = coordinate
                        
                        mapView.addAnnotation(annotation)
                        nameText.text = annotationTitle
                        commentText.text = annotationSubtitle
                        
                        // Seçilen yerin konumunu ekranın ortasına al
                        let span = MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                        let region = MKCoordinateRegion(center: coordinate, span: span)
                        mapView.setRegion(region, animated: true)
                        
                        // Kullanıcı konumunu güncellemeyi durdur
                        locationManager.stopUpdatingLocation()
                        isLocationSet = true
                    }
                }
            } catch {
                print("Error")
            }
        } else {
            // Yeni veri ekleniyor
            isAddingNewPlace = true
            locationManager.stopUpdatingLocation()
        }
    }

    @objc func hideKeyboard() {
        view.endEditing(true)
    }
    
    @objc func chooseLocation(gestureRecognizer: UILongPressGestureRecognizer) {
        if gestureRecognizer.state == .began {
            // Önce nameText ve commentText alanlarının dolu olup olmadığını kontrol et
            guard let name = nameText.text, !name.isEmpty,
                  let comment = commentText.text, !comment.isEmpty else {
                // Eğer boşsa, kullanıcıya bir uyarı göster
                let alert = UIAlertController(title: "Eksik Bilgi", message: "Lütfen önce yerin ismini ve yorumunu giriniz.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Tamam", style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
                return
            }

            // Eğer alanlar doluysa, haritada işaretlemeyi yap
            let touchedPoint = gestureRecognizer.location(in: self.mapView)
            let touchCoordinates = self.mapView.convert(touchedPoint, toCoordinateFrom: self.mapView)
            
            chosenLatitude = touchCoordinates.latitude
            chosenLongitude = touchCoordinates.longitude
            
            let annotation = MKPointAnnotation()
            annotation.coordinate = touchCoordinates
            annotation.title = name
            annotation.subtitle = comment
            self.mapView.addAnnotation(annotation)
        }
    }
    
    @IBAction func saveButtonClicked(_ sender: Any) {
        // Kaydet butonuna basıldığında yapılacak işlemler
        guard let name = nameText.text, !name.isEmpty,
              !mapView.annotations.isEmpty,
              let comment = commentText.text, !comment.isEmpty else {
            // Eğer alanlar boşsa, kullanıcıya bir uyarı göster
            let alert = UIAlertController(title: "Eksik Bilgi", message: "Lütfen önce tüm bilgileri doldurun.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Tamam", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
            return
        }
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let context = appDelegate.persistentContainer.viewContext
        
        let newPalace = NSEntityDescription.insertNewObject(forEntityName: "Places", into: context)
        
        newPalace.setValue(nameText.text, forKey: "title")
        newPalace.setValue(commentText.text, forKey: "subtitle")
        newPalace.setValue(chosenLatitude, forKey: "latitude")
        newPalace.setValue(chosenLongitude, forKey: "longitude")
        newPalace.setValue(UUID(), forKey: "id")
        do {
            try context.save()
            print("Başarılı")
        } catch {
            print("Error")
        }
        
        NotificationCenter.default.post(name: NSNotification.Name("newPlace"), object: nil)
        navigationController?.popViewController(animated: true)

    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if isAddingNewPlace {
            if let location = locations.last {
                userLocation = location.coordinate
                let span = MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                let region = MKCoordinateRegion(center: userLocation!, span: span)
                mapView.setRegion(region, animated: true)
                mapView.showsUserLocation = true
            }
        }
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            return nil
        }
        
        let reuseId = "myAnnotation"
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKMarkerAnnotationView
        
        if pinView == nil {
            pinView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView?.canShowCallout = true
            pinView?.tintColor = UIColor.black
            
            let button = UIButton(type: UIButton.ButtonType.detailDisclosure)
            pinView?.rightCalloutAccessoryView = button
            
        } else {
            pinView?.annotation = annotation
        }
        
        return pinView
    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        if selectedTitle != "" {
            let requestLocation = CLLocation(latitude: annotationLatitude, longitude: annotationLongitude)
            CLGeocoder().reverseGeocodeLocation(requestLocation) { (placemarks, error) in
                if let placemark = placemarks {
                    if placemark.count > 0 {
                        let newPlacemark = MKPlacemark(placemark: placemark[0])
                        let item = MKMapItem(placemark: newPlacemark)
                        item.name = self.annotationTitle
                        let launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
                        item.openInMaps(launchOptions: launchOptions)
                    }
                }
            }
        }
    }
}
