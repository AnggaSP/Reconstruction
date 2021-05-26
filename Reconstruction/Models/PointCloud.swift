import Foundation
import SceneKit

internal struct PointCloud {
    internal var points: [vector_float3] = []
    internal var framePointSizes: [Int32] = []
    internal var frameViewpoint: [SCNVector3] = []
}
