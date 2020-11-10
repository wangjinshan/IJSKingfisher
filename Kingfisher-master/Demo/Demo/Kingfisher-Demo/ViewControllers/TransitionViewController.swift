
import UIKit
import Kingfisher

class TransitionViewController: UIViewController {
    
    enum PickerComponent: Int, CaseIterable {
        case transitionType
        case duration
    }
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var transitionPickerView: UIPickerView!
    
    let durations: [TimeInterval] = [0.5, 1, 2, 4, 10]
    let transitions: [String] = ["none", "fade", "flip - left", "flip - right", "flip - top", "flip - bottom"]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Transition"
        setupOperationNavigationBar()
        imageView.kf.indicatorType = .activity
    }
    
    func makeTransition(type: String, duration: TimeInterval) -> ImageTransition {
        switch type {
        case "none": return .none
        case "fade": return .fade(duration)
        case "flip - left": return .flipFromLeft(duration)
        case "flip - right": return .flipFromRight(duration)
        case "flip - top": return .flipFromTop(duration)
        case "flip - bottom": return .flipFromBottom(duration)
        default: return .none
        }
    }
    
    func reloadImageView() {
    
        let typeIndex = transitionPickerView.selectedRow(inComponent: PickerComponent.transitionType.rawValue)
        let transitionType = transitions[typeIndex]
        
        let durationIndex = transitionPickerView.selectedRow(inComponent: PickerComponent.duration.rawValue)
        let duration = durations[durationIndex]
        
        let t = makeTransition(type: transitionType, duration: duration)
        let url = ImageLoader.sampleImageURLs[0]
        imageView.kf.setImage(with: url, options: [.forceTransition, .transition(t)])
    }
}

extension TransitionViewController: UIPickerViewDelegate {
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        switch PickerComponent(rawValue: component)!  {
        case .transitionType: return transitions[row]
        case .duration: return String(durations[row])
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        reloadImageView()
    }
}

extension TransitionViewController: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return PickerComponent.allCases.count
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch PickerComponent(rawValue: component)!  {
        case .transitionType: return transitions.count
        case .duration: return durations.count
        }
    }
}
