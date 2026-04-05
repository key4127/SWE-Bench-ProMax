#!/bin/bash
set -xo pipefail

# Checkout the original test files
cd /testbed
git checkout b235b7fd6eaed8a76abcdb23a35ddc98337eb087 "test/src/test_beam_likelihood.cpp" "test/src/test_point_cloud_random_sampler_with_normal.cpp"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/test/src/test_beam_likelihood.cpp b/test/src/test_beam_likelihood.cpp
--- a/test/src/test_beam_likelihood.cpp
+++ b/test/src/test_beam_likelihood.cpp
@@ -29,6 +29,7 @@
 
 #include <cmath>
 #include <cstddef>
+#include <memory>
 #include <vector>
 
 #include <gtest/gtest.h>
@@ -37,6 +38,7 @@
 
 #include <mcl_3dl/chunked_kdtree.h>
 #include <mcl_3dl/lidar_measurement_models/lidar_measurement_model_beam.h>
+#include <mcl_3dl/parameters.h>
 #include <mcl_3dl/point_cloud_random_sampler.h>
 #include <mcl_3dl/vec3.h>
 
@@ -121,18 +123,20 @@ TEST(BeamModel, LikelihoodFunc)
     {
       for (double hr = 0.0; hr <= 1.0; hr += 0.2)
       {
-        ros::NodeHandle pnh("~");
-        pnh.setParam("beam/num_points", static_cast<int>(raw_pc.size()));
-        pnh.setParam("beam/beam_likelihood", 0.2);
-        pnh.setParam("beam/hit_range", hr);
-        pnh.setParam("beam/use_raycast_using_dda", method == 1);
-        pnh.setParam("beam/add_penalty_short_only_mode", mode == 1);
-        pnh.setParam("beam/dda_grid_size", 0.1);
-        pnh.setParam("beam/clip_z_min", -0.3);
-        pnh.setParam("beam/clip_z_max", 4.1);
-
-        mcl_3dl::LidarMeasurementModelBeam model(0.1, 0.1, 0.1);
-        model.loadConfig(pnh, "beam");
+        auto params = std::make_shared<mcl_3dl::LidarMeasurementModelBeamParameters>();
+        params->map_grid_x_ = 0.1;
+        params->map_grid_y_ = 0.1;
+        params->map_grid_z_ = 0.1;
+        params->num_points_default_ = static_cast<int>(raw_pc.size());
+        params->beam_likelihood_min_ = 0.2;
+        params->hit_range_ = hr;
+        params->use_raycast_using_dda_ = method == 1;
+        params->add_penalty_short_only_mode_ = mode == 1;
+        params->dda_grid_size_ = 0.1;
+        params->clip_z_min_ = -0.3;
+        params->clip_z_max_ = 4.1;
+
+        mcl_3dl::LidarMeasurementModelBeam model(params);
         const auto pc = model.filter(raw_pc.makeShared(), sampler);
         ASSERT_EQ(pc->points.size(), raw_pc.points.size() - 2);
         for (const auto& p : pc->points)
diff --git a/test/src/test_point_cloud_random_sampler_with_normal.cpp b/test/src/test_point_cloud_random_sampler_with_normal.cpp
--- a/test/src/test_point_cloud_random_sampler_with_normal.cpp
+++ b/test/src/test_point_cloud_random_sampler_with_normal.cpp
@@ -10,8 +10,8 @@
  *     * Redistributions in binary form must reproduce the above copyright
  *       notice, this list of conditions and the following disclaimer in the
  *       documentation and/or other materials provided with the distribution.
- *     * Neither the name of the copyright holder nor the names of its 
- *       contributors may be used to endorse or promote products derived from 
+ *     * Neither the name of the copyright holder nor the names of its
+ *       contributors may be used to endorse or promote products derived from
  *       this software without specific prior written permission.
  *
  * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
@@ -30,10 +30,12 @@
 #include <gtest/gtest.h>
 
 #include <algorithm>
+#include <memory>
 #include <vector>
 
 #include <pcl/point_types.h>
 
+#include <mcl_3dl/parameters.h>
 #include <mcl_3dl/point_cloud_random_samplers/point_cloud_sampler_with_normal.h>
 #include <mcl_3dl/point_types.h>
 
@@ -136,12 +138,18 @@ TEST(PointCloudSamplerWithNormal, Sampling)
 
   for (const unsigned int seed : seeds)
   {
-    PointCloudSamplerWithNormal<PointXYZIL> sampler(seed);
+    auto sampler_params = std::make_shared<PointCloudSamplerWithNormalParameters>();
+    sampler_params->normal_search_range_ = 0.4;
+    PointCloudSamplerWithNormal<PointXYZIL> sampler(sampler_params, seed);
     sampler.setParticleStatistics(mean, cov_matrix);
     const int sample_num = 100;
     for (const ParameterSet& parameter : parameters)
     {
-      sampler.setParameters(parameter.perform_weighting_ratio, parameter.max_weight_ratio, parameter.max_weight, 0.4);
+      sampler_params->perform_weighting_ratio_ = parameter.perform_weighting_ratio;
+      sampler_params->max_weight_ratio_ = parameter.max_weight_ratio;
+      sampler_params->max_weight_ = parameter.max_weight;
+      sampler.refreshParameters();
+
       const pcl::PointCloud<PointXYZIL>::Ptr extracted_cloud = sampler.sample(pc, sample_num);
       EXPECT_EQ(sample_num, static_cast<int>(extracted_cloud->size()));
       // count[0] : numbers of points chosen from the wall at right angles
@@ -162,7 +170,7 @@ TEST(PointCloudSamplerWithNormal, Sampling)
     }
   }
 
-  PointCloudSamplerWithNormal<PointXYZIL> sampler;
+  PointCloudSamplerWithNormal<PointXYZIL> sampler(std::make_shared<PointCloudSamplerWithNormalParameters>());
   sampler.setParticleStatistics(mean, cov_matrix);
   pcl::PointCloud<PointXYZIL>::Ptr invalid_cloud(new pcl::PointCloud<PointXYZIL>());
   // Empty cloud
EOF_114329324912

# Rebuild the workspace with the patched test files, enabling testing
cd /catkin_ws

# Temporarily disable unbound variable checking for ROS setup
set +u
source /opt/ros/noetic/setup.bash
set -u

# Build with testing enabled
catkin_make -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_STANDARD=14 -DCATKIN_ENABLE_TESTING=ON

# Build the test targets explicitly
catkin_make tests

# Source the workspace environment (disable -u again for sourcing)
set +u
source /catkin_ws/devel/setup.bash
set -u

# Run Test 1: Unit test (gtest) - using catkin_make run_tests command
catkin_make run_tests_mcl_3dl_gtest_test_point_cloud_random_sampler_with_normal
rc1=$?

# Run Test 2: ROS integration test (rostest) - using rostest command directly
rostest mcl_3dl beam_likelihood_rostest.test
rc2=$?

# Combine exit codes (non-zero if any test failed)
rc=$((rc1 + rc2))

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files
cd /testbed
git checkout b235b7fd6eaed8a76abcdb23a35ddc98337eb087 "test/src/test_beam_likelihood.cpp" "test/src/test_point_cloud_random_sampler_with_normal.cpp"