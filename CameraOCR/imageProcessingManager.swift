//
//  imageFilterManager.swift
//  AVFoundationSample
//
//  Created by Katsutoshi Kuroya on 2015/07/30.
//  Copyright © 2015 Katsutoshi Kuroya. All rights reserved.
//

import Foundation
import CoreImage
class ImageProcessingManager
{
    let filterNames = [ "CIToneCurve"
                        ,"CIColorMonochrome"
                        ,"CISepiaTone"
                        ,"CIColorInvert"
                        ,"CIColorPosterize"
                        ,"CIMaximumComponent"
                        ,"CIMinimumComponent"
                        ,"CIPhotoEffectChrome"
                        ,"CIPhotoEffectInstant"
                        ,"CIGlassLozenge"
                        ,"CIHoleDistortion"
                        ,"CITwirlDistortion"
                        ,"CIVortexDistortion"
                        ,"CIComicEffect"
                        ,"CICrystallize"
                        ,"CIEdges"
                        ,"CIEdgeWork"
                        ,"CIHexagonalPixellate"
                        ,"CILineOverlay"
    ];
    let filters: [CIFilter]
    let detector: CIDetector?
    init(){
        // Generating filters by filter names
        self.filters = filterNames.map{
            let filter = CIFilter(name: $0, withInputParameters: nil)
            filter?.setDefaults()
            return filter
        }.filter{$0! != nil}.map{$0!}
        
        // Text region detector
        self.detector = CIDetector(ofType: CIDetectorTypeText, context: nil, options: nil)
    }
}
