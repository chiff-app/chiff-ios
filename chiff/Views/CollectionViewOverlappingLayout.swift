//
//  CollectionViewCell.swift
//  keyn
//
//  Created by Bas Doorn on 25/07/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import UIKit

class CollectionViewOverlappingLayout: UICollectionViewFlowLayout {

    var overlap: CGFloat = 1.0

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.scrollDirection = .vertical
        self.minimumInteritemSpacing = 0
    }

    override var collectionViewContentSize: CGSize {
        let xSize = CGFloat(self.collectionView!.numberOfItems(inSection: 0)) * self.itemSize.width
        let ySize = CGFloat(self.collectionView!.numberOfSections) * self.itemSize.height

        var contentSize = CGSize(width: xSize, height: ySize)

        if self.collectionView!.bounds.size.width > contentSize.width {
            contentSize.width = self.collectionView!.bounds.size.width
        }

        if self.collectionView!.bounds.size.height > contentSize.height {
            contentSize.height = self.collectionView!.bounds.size.height
        }

        return contentSize
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {

        let attributesArray = super.layoutAttributesForElements(in: rect)
        let numberOfItems = self.collectionView!.numberOfItems(inSection: 0)

        for attributes in attributesArray! {
            var xPosition = attributes.center.x
            let yPosition = attributes.center.y

            xPosition -= self.overlap * CGFloat(attributes.indexPath.row)
            attributes.zIndex = numberOfItems - attributes.indexPath.row //Other cells below the first one

            attributes.center = CGPoint(x: xPosition, y: yPosition)
        }

        return attributesArray
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return UICollectionViewLayoutAttributes(forCellWith: indexPath)
    }
}
