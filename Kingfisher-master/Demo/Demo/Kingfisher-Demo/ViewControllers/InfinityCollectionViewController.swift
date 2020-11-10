
import UIKit
import Kingfisher

private let reuseIdentifier = "InfinityCell"

class InfinityCollectionViewController: UICollectionViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Infinity"
        setupOperationNavigationBar()
    }

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 10000000
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView
            .dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! ImageCollectionViewCell
        let urls = ImageLoader.sampleImageURLs
        let url = urls[indexPath.row % urls.count]

        // Mark each row as a new image.
        let resource = ImageResource(downloadURL: url, cacheKey: "key-\(indexPath.row)")
        cell.cellImageView.kf.setImage(with: resource)

        return cell
    }
}
