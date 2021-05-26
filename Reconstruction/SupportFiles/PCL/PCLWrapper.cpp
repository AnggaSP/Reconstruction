#include "PCLWrapper.hpp"

#include <iostream>
#include <pcl/common/common.h>
#include <pcl/features/integral_image_normal.h>
#include <pcl/features/normal_3d_omp.h>
#include <pcl/filters/passthrough.h>
#include <pcl/filters/statistical_outlier_removal.h>
#include <pcl/io/pcd_io.h>
#include <pcl/io/ply_io.h>
#include <pcl/point_types.h>
#include <pcl/search/kdtree.h>
#include <pcl/surface/mls.h>
#include <pcl/surface/poisson.h>

pcl::PointCloud<pcl::Normal>::Ptr computeNormals(pcl::PointCloud<pcl::PointXYZ>::Ptr pointCloudPtr, PCLPoint3D viewpoint) {
    pcl::search::KdTree<pcl::PointXYZ>::Ptr tree(new pcl::search::KdTree<pcl::PointXYZ>());
    pcl::NormalEstimationOMP<pcl::PointXYZ, pcl::Normal> normalEstimation;
    normalEstimation.setSearchMethod(tree);
    normalEstimation.setNumberOfThreads(8);
    normalEstimation.setInputCloud(pointCloudPtr);
    normalEstimation.setKSearch(10);
    normalEstimation.setViewPoint(viewpoint.x, viewpoint.y, viewpoint.z);

    // Compute normals
    pcl::PointCloud<pcl::Normal>::Ptr cloudNormalsPtr(new pcl::PointCloud<pcl::Normal>());
    normalEstimation.compute(*cloudNormalsPtr);
    return cloudNormalsPtr;
}

pcl::PointCloud<pcl::PointXYZ>::Ptr filterPointCloudPerFrame(pcl::PointCloud<pcl::PointXYZ>::Ptr pointCloudPtr) {
    // Filtering Statistically
    pcl::StatisticalOutlierRemoval<pcl::PointXYZ> statFilter;
    statFilter.setInputCloud(pointCloudPtr);
    statFilter.setMeanK(((int) pointCloudPtr->size() - 1));
    statFilter.setStddevMulThresh(50 / pointCloudPtr->size());
    pcl::PointCloud<pcl::PointXYZ>::Ptr filteredPointCloudPtr(new pcl::PointCloud<pcl::PointXYZ>);
    statFilter.filter(*filteredPointCloudPtr);
    return filteredPointCloudPtr;
}

pcl::PointCloud<pcl::PointNormal>::Ptr constructPointNormalCloud(PCLPointCloud inputPCLPointCloud) {
    std::cout << "Constructing Point Cloud with normals" << std::endl;

    // Initalize Empty Point Cloud
    pcl::PointCloud<pcl::PointNormal>::Ptr pointCloudPtr(new pcl::PointCloud<pcl::PointNormal>);
    pointCloudPtr->width    = 0;
    pointCloudPtr->height   = 1;
    pointCloudPtr->is_dense = false;
    pointCloudPtr->points.resize (pointCloudPtr->width * pointCloudPtr->height);

    int currentPointsIdx = 0;
    for (size_t frameIdx = 0; frameIdx < inputPCLPointCloud.numFrames; frameIdx++) {
        int framePointCloudSize = inputPCLPointCloud.pointFrameLengths[frameIdx];

        pcl::PointCloud<pcl::PointXYZ>::Ptr tempPointCloudPtr(new pcl::PointCloud<pcl::PointXYZ>);
        tempPointCloudPtr->width    = framePointCloudSize;
        tempPointCloudPtr->height   = 1;
        tempPointCloudPtr->is_dense = false;
        tempPointCloudPtr->points.resize (tempPointCloudPtr->width * tempPointCloudPtr->height);

        for (size_t i = 0; i < framePointCloudSize; i++, currentPointsIdx++) {
            tempPointCloudPtr->points[i].x = inputPCLPointCloud.points[currentPointsIdx].x;
            tempPointCloudPtr->points[i].y = inputPCLPointCloud.points[currentPointsIdx].y;
            tempPointCloudPtr->points[i].z = inputPCLPointCloud.points[currentPointsIdx].z;
        }

        pcl::PointCloud<pcl::PointXYZ>::Ptr tempFilteredPointCloudPtr = filterPointCloudPerFrame(tempPointCloudPtr);

        pcl::PointCloud<pcl::Normal>::Ptr tempPointCloudNormalsPtr = computeNormals(tempFilteredPointCloudPtr, inputPCLPointCloud.viewpoints[frameIdx]);

        // Combine Points and Normals
        pcl::PointCloud<pcl::PointNormal>::Ptr tempCloudSmoothedNormalsPtr(new pcl::PointCloud<pcl::PointNormal>());
        concatenateFields(*tempFilteredPointCloudPtr, *tempPointCloudNormalsPtr, *tempCloudSmoothedNormalsPtr);

        // Append temp cloud to full cloud
        *pointCloudPtr += *tempCloudSmoothedNormalsPtr;
    }
    std::cout << "Num points = " << inputPCLPointCloud.numPoints << ", Last Current Points Index = " << currentPointsIdx << std::endl;

    return pointCloudPtr;
}

PCLPointNormalCloud constructPointCloudWithNormalsForTesting(PCLPointCloud inputPCLPointCloud) {
    pcl::PointCloud<pcl::PointNormal>::Ptr pointNormalCloud = constructPointNormalCloud(inputPCLPointCloud);
    long int numPoints = pointNormalCloud->size();

    PCLPoint3D *pointsPtr;
    pointsPtr = (PCLPoint3D *) calloc(numPoints, sizeof(*pointsPtr));
    PCLPoint3D *normalsPtr;
    normalsPtr = (PCLPoint3D *) calloc(numPoints, sizeof(*normalsPtr));
    for (size_t i = 0; i < numPoints; i++) {
        pointsPtr[i].x = pointNormalCloud->points[i].x;
        pointsPtr[i].y = pointNormalCloud->points[i].y;
        pointsPtr[i].z = pointNormalCloud->points[i].z;
        normalsPtr[i].x = pointNormalCloud->points[i].normal_x;
        normalsPtr[i].y = pointNormalCloud->points[i].normal_y;
        normalsPtr[i].z = pointNormalCloud->points[i].normal_z;
    }

    PCLPointNormalCloud pclPointNormalCloud;
    pclPointNormalCloud.numPoints = (int)numPoints;
    pclPointNormalCloud.points = pointsPtr;
    pclPointNormalCloud.normals = normalsPtr;
    pclPointNormalCloud.numFrames = inputPCLPointCloud.numFrames;
    pclPointNormalCloud.pointFrameLengths = inputPCLPointCloud.pointFrameLengths;
    pclPointNormalCloud.viewpoints = inputPCLPointCloud.viewpoints;

    return pclPointNormalCloud;
}

PCLMesh performSurfaceReconstruction(PCLPointCloud inputPCLPointCloud) {
    pcl::PointCloud<pcl::PointNormal>::Ptr pointNormalCloud = constructPointNormalCloud(inputPCLPointCloud);
    std::cout << "Loaded Point Cloud with normals" << std::endl;

    std::cout << "Statistically Filtering points" << std::endl;
    pcl::StatisticalOutlierRemoval<pcl::PointNormal> statFilter;
    statFilter.setInputCloud(pointNormalCloud);
    statFilter.setMeanK(50);
    statFilter.setStddevMulThresh(3);

    pcl::PointCloud<pcl::PointNormal>::Ptr filteredPointCloudPtr(new pcl::PointCloud<pcl::PointNormal>);
    statFilter.filter(*filteredPointCloudPtr);
    std::cout << "Statistical points filtering complete" << std::endl;

    std::cout << "Begin poisson reconstruction" << std::endl;
    pcl::Poisson<pcl::PointNormal> poisson;
    poisson.setDepth(5);
    poisson.setInputCloud(filteredPointCloudPtr);
    poisson.setPointWeight(4);
    poisson.setSamplesPerNode(1.5);

    pcl::PolygonMesh mesh;
    poisson.reconstruct(mesh);
    std::cout << "Mesh number of polygons: " << mesh.polygons.size() << std::endl;
    std::cout << "Poisson reconstruction complete" << std::endl;

    // Need mesh cloud in PointCloud<PointXYZ> format instead of PointCloud2
    pcl::PointCloud<pcl::PointXYZ> meshXYZPointCloud;
    fromPCLPointCloud2(mesh.cloud, meshXYZPointCloud);

    long int meshNumPoints = meshXYZPointCloud.size();
    long int meshNumFaces = mesh.polygons.size();

    PCLPoint3D *meshPointsPtr;
    meshPointsPtr = (PCLPoint3D *) calloc(meshNumPoints, sizeof(*meshPointsPtr));
    for (size_t i = 0; i < meshNumPoints; i++) {
        meshPointsPtr[i].x = meshXYZPointCloud.points[i].x;
        meshPointsPtr[i].y = meshXYZPointCloud.points[i].y;
        meshPointsPtr[i].z = meshXYZPointCloud.points[i].z;
    }

    PCLPolygon *meshPolygonsPtr;
    meshPolygonsPtr = (PCLPolygon *) calloc(meshNumFaces, sizeof(*meshPolygonsPtr));
    for (size_t i = 0; i < meshNumFaces; i++) {
        PCLPolygon pclPolygon;
        pclPolygon.v1 = mesh.polygons[i].vertices[0];
        pclPolygon.v2 = mesh.polygons[i].vertices[1];
        pclPolygon.v3 = mesh.polygons[i].vertices[2];
        meshPolygonsPtr[i] = pclPolygon;
    }

    PCLMesh pclMesh;
    pclMesh.numPoints = meshNumPoints;
    pclMesh.numFaces = meshNumFaces;
    pclMesh.points = meshPointsPtr;
    pclMesh.polygons = meshPolygonsPtr;
    return pclMesh;
}

