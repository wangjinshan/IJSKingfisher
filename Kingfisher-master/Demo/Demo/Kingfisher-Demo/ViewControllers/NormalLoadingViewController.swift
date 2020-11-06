
import UIKit
import Kingfisher

class NormalLoadingViewController: UICollectionViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Loading"
        setupOperationNavigationBar()
        collectionView?.prefetchDataSource = self
    }
}

extension NormalLoadingViewController {
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return ImageLoader.sampleImageURLs.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        (cell as! ImageCollectionViewCell).cellImageView.kf.cancelDownloadTask()
    }
    
    override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let imageView = (cell as! ImageCollectionViewCell).cellImageView!
        imageView.kf.setImage(with: ImageLoader.sampleImageURLs[indexPath.row],
                              placeholder: nil,
                              options: [.transition(.fade(1)), .loadDiskFileSynchronously],
                              progressBlock: { receivedSize, totalSize in
                                print("\(indexPath.row + 1): \(receivedSize)/\(totalSize)")
                              },
                              completionHandler: { result in
                                print(result)
                                print("\(indexPath.row + 1): Finished")
                              }
        )
    }
    
    override func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
    {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "collectionViewCell",
            for: indexPath) as! ImageCollectionViewCell
        cell.cellImageView.kf.indicatorType = .activity
        return cell
    }
}

extension NormalLoadingViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let urls = indexPaths.compactMap { ImageLoader.sampleImageURLs[$0.row] }
        ImagePrefetcher(urls: urls).start()
    }
}
