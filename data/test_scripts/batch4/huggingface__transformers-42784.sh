#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout to the target commit and ensure test files are at the correct state
git checkout 1dc69bd6f7f5dcc1a32467be505dd873d573846e "tests/models/lfm2_vl/test_image_processing_lfm2_vl.py" "tests/models/lfm2_vl/test_processing_lfm2_vl.py"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/models/lfm2_vl/test_image_processing_lfm2_vl.py b/tests/models/lfm2_vl/test_image_processing_lfm2_vl.py
--- a/tests/models/lfm2_vl/test_image_processing_lfm2_vl.py
+++ b/tests/models/lfm2_vl/test_image_processing_lfm2_vl.py
@@ -33,7 +33,10 @@
 
     if is_torchvision_available():
         from transformers import Lfm2VlImageProcessorFast
-        from transformers.models.lfm2_vl.image_processing_lfm2_vl_fast import find_closest_aspect_ratio
+        from transformers.models.lfm2_vl.image_processing_lfm2_vl_fast import (
+            find_closest_aspect_ratio,
+            round_by_factor,
+        )
 
 
 class Lfm2VlImageProcessingTester:
@@ -287,3 +290,545 @@ def test_call_pytorch(self):
                 3 * image_processing.encoder_patch_size**2,
             ),
         )
+
+    def test_small_image_no_tiling_no_thumbnail(self):
+        """Small image with tiling disabled should use smart resize, no thumbnail."""
+        image_processing = self.fast_image_processing_class(
+            do_image_splitting=False,
+            use_thumbnail=True,  # even if enabled, should not be used for small/non-tiled images
+        )
+        # Create a small image (256x256)
+        small_image = Image.new("RGB", (256, 256), color="red")
+        result = image_processing([[small_image]], return_tensors="pt", return_row_col_info=True)
+
+        # With tiling disabled, should be 1 tile (no thumbnail)
+        self.assertEqual(result.image_rows[0].item(), 1)
+        self.assertEqual(result.image_cols[0].item(), 1)
+        # Should have exactly 1 image in batch (no thumbnail)
+        self.assertEqual(result.pixel_values.shape[0], 1)
+
+    def test_small_image_tiling_enabled_no_thumbnail(self):
+        """Small image with tiling enabled should not be tiled (too small), no thumbnail."""
+        image_processing = self.fast_image_processing_class(
+            do_image_splitting=True,
+            use_thumbnail=True,
+            min_tiles=2,
+            max_tiles=10,
+        )
+        # Create a small image that won't exceed the max_image_tokens threshold
+        small_image = Image.new("RGB", (256, 256), color="blue")
+        result = image_processing([[small_image]], return_tensors="pt", return_row_col_info=True)
+
+        # Small image should not be tiled (1x1 grid), no thumbnail added
+        self.assertEqual(result.image_rows[0].item(), 1)
+        self.assertEqual(result.image_cols[0].item(), 1)
+        # Should have exactly 1 image in batch (no thumbnail)
+        self.assertEqual(result.pixel_values.shape[0], 1)
+
+    def test_large_image_no_tiling_smart_resize(self):
+        """Large image with tiling disabled should use smart resize, no thumbnail."""
+        image_processing = self.fast_image_processing_class(
+            do_image_splitting=False,
+            use_thumbnail=True,  # even if enabled, should not be used
+        )
+        # Create a large image (2048x2048)
+        large_image = Image.new("RGB", (2048, 2048), color="green")
+        result = image_processing([[large_image]], return_tensors="pt", return_row_col_info=True)
+
+        # With tiling disabled, should be 1 tile even for large images
+        self.assertEqual(result.image_rows[0].item(), 1)
+        self.assertEqual(result.image_cols[0].item(), 1)
+        # Should have exactly 1 image in batch (no thumbnail, smart resize only)
+        self.assertEqual(result.pixel_values.shape[0], 1)
+
+    def test_large_image_tiling_enabled_thumbnail_disabled(self):
+        """Large image with tiling enabled but thumbnail disabled should tile without thumbnail."""
+        image_processing = self.fast_image_processing_class(
+            do_image_splitting=True,
+            use_thumbnail=False,
+            min_tiles=2,
+            max_tiles=10,
+            tile_size=512,
+        )
+        # Create a large image that will require tiling
+        large_image = Image.new("RGB", (2048, 2048), color="yellow")
+        result = image_processing([[large_image]], return_tensors="pt", return_row_col_info=True)
+
+        # Large image should be tiled into multiple tiles
+        num_rows = result.image_rows[0].item()
+        num_cols = result.image_cols[0].item()
+        num_tiles = num_rows * num_cols
+        self.assertGreater(num_tiles, 1, "Large image should be tiled into multiple tiles")
+
+        # Count actual patches - with thumbnail disabled, should equal number of tiles
+        num_images_in_batch = result.pixel_values.shape[0]
+        self.assertEqual(
+            num_images_in_batch, num_tiles, "Number of patches should equal number of tiles (no thumbnail)"
+        )
+
+    def test_large_image_tiling_enabled_thumbnail_enabled(self):
+        """Large image with tiling and thumbnail enabled should tile AND add thumbnail."""
+        image_processing = self.fast_image_processing_class(
+            do_image_splitting=True,
+            use_thumbnail=True,
+            min_tiles=2,
+            max_tiles=10,
+            tile_size=512,
+        )
+        # Create a large image that will require tiling
+        large_image = Image.new("RGB", (2048, 2048), color="purple")
+        result = image_processing([[large_image]], return_tensors="pt", return_row_col_info=True)
+
+        # Large image should be tiled into multiple tiles
+        num_rows = result.image_rows[0].item()
+        num_cols = result.image_cols[0].item()
+        num_tiles = num_rows * num_cols
+        self.assertGreater(num_tiles, 1, "Large image should be tiled into multiple tiles")
+
+        # With thumbnail enabled, we should have tiles + 1 thumbnail
+        num_images_in_batch = result.pixel_values.shape[0]
+        self.assertEqual(num_images_in_batch, num_tiles + 1, "Number of patches should equal tiles + 1 (thumbnail)")
+
+    # ==================== Non-Square Aspect Ratio Tests ====================
+
+    def test_landscape_image_aspect_ratio(self):
+        """Test that landscape images (wider than tall) are processed correctly."""
+        image_processing = self.fast_image_processing_class(
+            do_image_splitting=True,
+            use_thumbnail=True,
+            min_tiles=2,
+            max_tiles=10,
+            tile_size=512,
+        )
+        # Create a landscape image (1920x1080, ~16:9 aspect ratio)
+        landscape_image = Image.new("RGB", (1920, 1080), color="blue")
+        result = image_processing([[landscape_image]], return_tensors="pt", return_row_col_info=True)
+
+        num_rows = result.image_rows[0].item()
+        num_cols = result.image_cols[0].item()
+
+        # Landscape image should have more columns than rows
+        self.assertGreaterEqual(num_cols, num_rows, "Landscape image should have cols >= rows")
+
+    def test_extreme_aspect_ratio_wide(self):
+        """Test extremely wide image (panorama-like)."""
+        image_processing = self.fast_image_processing_class(
+            do_image_splitting=True,
+            use_thumbnail=True,
+            min_tiles=2,
+            max_tiles=10,
+            tile_size=512,
+        )
+        # Create an extremely wide image (3000x500)
+        wide_image = Image.new("RGB", (3000, 500), color="red")
+        result = image_processing([[wide_image]], return_tensors="pt", return_row_col_info=True)
+
+        num_rows = result.image_rows[0].item()
+        num_cols = result.image_cols[0].item()
+
+        # Very wide image should have significantly more cols than rows
+        self.assertGreater(num_cols, num_rows, "Very wide image should have cols > rows")
+
+    def test_extreme_aspect_ratio_tall(self):
+        """Test extremely tall image."""
+        image_processing = self.fast_image_processing_class(
+            do_image_splitting=True,
+            use_thumbnail=True,
+            min_tiles=2,
+            max_tiles=10,
+            tile_size=512,
+        )
+        # Create an extremely tall image (500x3000)
+        tall_image = Image.new("RGB", (500, 3000), color="yellow")
+        result = image_processing([[tall_image]], return_tensors="pt", return_row_col_info=True)
+
+        num_rows = result.image_rows[0].item()
+        num_cols = result.image_cols[0].item()
+
+        # Very tall image should have significantly more rows than cols
+        self.assertGreater(num_rows, num_cols, "Very tall image should have rows > cols")
+
+    # ==================== Output Validation Tests ====================
+
+    def test_image_sizes_returned_with_row_col_info(self):
+        """Test that image_sizes is returned when return_row_col_info=True."""
+        image_processing = self.fast_image_processing_class(do_image_splitting=False)
+        image = Image.new("RGB", (512, 256), color="green")
+        result = image_processing([[image]], return_tensors="pt", return_row_col_info=True)
+
+        # Check all row/col info is returned
+        self.assertIn("image_rows", result)
+        self.assertIn("image_cols", result)
+        self.assertIn("image_sizes", result)
+
+        # image_sizes should contain [height, width] for the resized image
+        image_sizes = result.image_sizes
+        self.assertIsInstance(image_sizes, torch.Tensor)
+        self.assertEqual(image_sizes.shape[0], 1)  # one sample
+        self.assertEqual(image_sizes.shape[1], 2)  # [height, width]
+
+    def test_output_consistency_across_formats(self):
+        """Test that outputs are consistent regardless of input format (PIL, numpy, torch)."""
+        image_processing = self.fast_image_processing_class(do_image_splitting=False)
+
+        # Create same image in different formats
+        pil_image = Image.new("RGB", (256, 256), color="white")
+        np_image = np.array(pil_image)
+        torch_image = torch.from_numpy(np_image).permute(2, 0, 1)
+
+        result_pil = image_processing([[pil_image]], return_tensors="pt")
+        result_np = image_processing([[np_image]], return_tensors="pt")
+        result_torch = image_processing([[torch_image]], return_tensors="pt")
+
+        # All should produce same shapes
+        self.assertEqual(result_pil.pixel_values.shape, result_np.pixel_values.shape)
+        self.assertEqual(result_pil.pixel_values.shape, result_torch.pixel_values.shape)
+        self.assertEqual(result_pil.spatial_shapes.tolist(), result_np.spatial_shapes.tolist())
+        self.assertEqual(result_pil.spatial_shapes.tolist(), result_torch.spatial_shapes.tolist())
+
+    # ==================== Multiple Images Per Sample Tests ====================
+
+    def test_multiple_images_per_sample(self):
+        """Test processing multiple images in a single sample: [[img1, img2, img3]]."""
+        image_processing = self.fast_image_processing_class(do_image_splitting=False)
+
+        img1 = Image.new("RGB", (256, 256), color="red")
+        img2 = Image.new("RGB", (256, 256), color="green")
+        img3 = Image.new("RGB", (256, 256), color="blue")
+
+        result = image_processing([[img1, img2, img3]], return_tensors="pt")
+
+        # Should have 3 images processed
+        self.assertEqual(result.pixel_values.shape[0], 3)
+        self.assertEqual(result.spatial_shapes.shape[0], 3)
+        self.assertEqual(result.pixel_attention_mask.shape[0], 3)
+
+    def test_mixed_image_counts_across_batch(self):
+        """Test batch with different number of images per sample: [[img1], [img2, img3]]."""
+        image_processing = self.fast_image_processing_class(do_image_splitting=False)
+
+        img1 = Image.new("RGB", (256, 256), color="red")
+        img2 = Image.new("RGB", (256, 256), color="green")
+        img3 = Image.new("RGB", (256, 256), color="blue")
+
+        # First sample has 1 image, second sample has 2 images
+        result = image_processing([[img1], [img2, img3]], return_tensors="pt")
+
+        # Total should be 3 images (1 + 2)
+        self.assertEqual(result.pixel_values.shape[0], 3)
+        self.assertEqual(result.spatial_shapes.shape[0], 3)
+
+    def test_multiple_images_different_sizes(self):
+        """Test multiple images per sample with different sizes."""
+        image_processing = self.fast_image_processing_class(do_image_splitting=False)
+
+        img_small = Image.new("RGB", (256, 256), color="red")
+        img_medium = Image.new("RGB", (512, 512), color="green")
+        img_large = Image.new("RGB", (768, 768), color="blue")
+
+        result = image_processing([[img_small, img_medium, img_large]], return_tensors="pt")
+
+        # Should have 3 images processed
+        self.assertEqual(result.pixel_values.shape[0], 3)
+        # All should have same max_num_patches due to padding
+        self.assertEqual(result.pixel_values.shape[1], image_processing.max_num_patches)
+
+    # ==================== Parameter Variations Tests ====================
+
+    def test_forced_grid_config_min_equals_max(self):
+        """Test forcing a specific grid configuration with min_tiles == max_tiles."""
+        image_processing = self.fast_image_processing_class(
+            do_image_splitting=True,
+            min_tiles=4,
+            max_tiles=4,  # Force exactly 4 tiles
+            tile_size=512,
+            use_thumbnail=False,
+        )
+        # Large image that would normally get more tiles
+        wide_image = Image.new("RGB", (3000, 500), color="red")
+        result = image_processing([[wide_image]], return_tensors="pt", return_row_col_info=True)
+
+        num_rows = result.image_rows[0].item()
+        num_cols = result.image_cols[0].item()
+        num_tiles = num_rows * num_cols
+
+        # Should be exactly 4 tiles
+        self.assertEqual(num_tiles, 4, "Should have exactly 4 tiles when min_tiles == max_tiles == 4")
+
+    # ==================== Input Validation Tests ====================
+
+    def test_min_tiles_greater_than_max_tiles_raises_error(self):
+        """Test that min_tiles > max_tiles raises ValueError."""
+        image_processing = self.fast_image_processing_class(
+            do_image_splitting=True,
+            min_tiles=10,
+            max_tiles=2,  # Invalid: min > max
+        )
+        image = Image.new("RGB", (1024, 1024), color="red")
+
+        with self.assertRaises(ValueError) as context:
+            image_processing([[image]], return_tensors="pt")
+
+        self.assertIn("min_tiles", str(context.exception).lower())
+
+    # ==================== Edge Case Images Tests ====================
+
+    def test_very_small_image(self):
+        """Test image smaller than encoder_patch_size."""
+        image_processing = self.fast_image_processing_class(
+            do_image_splitting=False,
+            encoder_patch_size=16,
+        )
+        # Image smaller than patch size
+        tiny_image = Image.new("RGB", (8, 8), color="red")
+        result = image_processing([[tiny_image]], return_tensors="pt")
+
+        # Should still process without error
+        self.assertIn("pixel_values", result)
+        self.assertEqual(result.pixel_values.dim(), 3)
+
+    def test_grayscale_image(self):
+        """Test that grayscale (1-channel) images are converted to RGB."""
+        image_processing = self.fast_image_processing_class(do_image_splitting=False)
+
+        # Create grayscale image
+        grayscale_image = Image.new("L", (256, 256), color=128)
+        result = image_processing([[grayscale_image]], return_tensors="pt")
+
+        # Should process and output 3 channels (converted to RGB)
+        self.assertIn("pixel_values", result)
+        # pixel_values shape is (batch, num_patches, patch_size^2 * 3)
+        expected_patch_dim = 3 * image_processing.encoder_patch_size**2
+        self.assertEqual(result.pixel_values.shape[2], expected_patch_dim)
+
+    def test_rgba_4_channel_image(self):
+        """Test that RGBA (4-channel) images are converted to RGB."""
+        image_processing = self.fast_image_processing_class(do_image_splitting=False)
+
+        # Create RGBA image with alpha channel
+        rgba_image = Image.new("RGBA", (256, 256), color=(255, 0, 0, 128))
+        result = image_processing([[rgba_image]], return_tensors="pt", do_convert_rgb=True)
+
+        # Should process and output 3 channels (alpha dropped)
+        self.assertIn("pixel_values", result)
+        expected_patch_dim = 3 * image_processing.encoder_patch_size**2
+        self.assertEqual(result.pixel_values.shape[2], expected_patch_dim)
+
+    def test_numpy_4_channel_rgba(self):
+        """Test actual 4-channel numpy array input - convert to PIL for RGB conversion."""
+        image_processing = self.fast_image_processing_class(do_image_splitting=False)
+
+        # Create 4-channel numpy array (RGBA) and convert to PIL Image for RGB conversion
+        rgba_np = np.random.randint(0, 255, (256, 256, 4), dtype=np.uint8)
+        rgba_pil = Image.fromarray(rgba_np, mode="RGBA")
+        result = image_processing([[rgba_pil]], return_tensors="pt", do_convert_rgb=True)
+
+        # Should convert to 3 channels
+        self.assertIn("pixel_values", result)
+        expected_patch_dim = 3 * image_processing.encoder_patch_size**2
+        self.assertEqual(result.pixel_values.shape[2], expected_patch_dim)
+
+    def test_single_pixel_image(self):
+        """Test 1x1 pixel image (extreme edge case)."""
+        image_processing = self.fast_image_processing_class(do_image_splitting=False)
+
+        single_pixel = Image.new("RGB", (1, 1), color="blue")
+        result = image_processing([[single_pixel]], return_tensors="pt")
+
+        # Should process without error
+        self.assertIn("pixel_values", result)
+
+    # ==================== Helper Function Unit Tests ====================
+
+    def test_round_by_factor(self):
+        """Test round_by_factor function."""
+        # Exact multiples should return themselves
+        self.assertEqual(round_by_factor(32, 16), 32)
+        self.assertEqual(round_by_factor(64, 16), 64)
+
+        # Values should round to nearest multiple
+        self.assertEqual(round_by_factor(30, 16), 32)  # 30 -> 32 (closer to 32 than 16)
+        self.assertEqual(round_by_factor(20, 16), 16)  # 20 -> 16 (closer to 16 than 32)
+        self.assertEqual(round_by_factor(24, 16), 32)  # 24 -> 32 (equidistant, rounds up)
+
+        # Test with different factors
+        self.assertEqual(round_by_factor(100, 32), 96)  # 100 -> 96
+        self.assertEqual(round_by_factor(50, 32), 64)  # 50 -> 64
+
+        # Test with factor of 1
+        self.assertEqual(round_by_factor(17, 1), 17)
+
+    def test_is_image_too_large_small_image(self):
+        """Test _is_image_too_large with small image."""
+        image_processing = self.fast_image_processing_class(
+            max_image_tokens=256,
+            encoder_patch_size=16,
+            downsample_factor=2,
+            max_pixels_tolerance=2.0,
+        )
+
+        is_large = image_processing._is_image_too_large(
+            height=512,
+            width=512,
+            max_image_tokens=256,
+            encoder_patch_size=16,
+            downsample_factor=2,
+            max_pixels_tolerance=2.0,
+        )
+        self.assertFalse(is_large)
+
+    def test_is_image_too_large_large_image(self):
+        """Test _is_image_too_large with large image."""
+        image_processing = self.fast_image_processing_class(
+            max_image_tokens=256,
+            encoder_patch_size=16,
+            downsample_factor=2,
+            max_pixels_tolerance=1.0,
+        )
+
+        is_large = image_processing._is_image_too_large(
+            height=565,
+            width=565,
+            max_image_tokens=256,
+            encoder_patch_size=16,
+            downsample_factor=2,
+            max_pixels_tolerance=1.0,
+        )
+        self.assertTrue(is_large)
+
+    # ==================== Batch Processing Tests ====================
+
+    def test_batch_mixed_image_sizes(self):
+        """Test batch processing with different image sizes requiring different processing paths."""
+        image_processing = self.fast_image_processing_class(do_image_splitting=False)
+
+        # Create images with significantly different sizes
+        small_image = Image.new("RGB", (256, 256), color="red")
+        medium_image = Image.new("RGB", (512, 512), color="green")
+        large_image = Image.new("RGB", (1024, 1024), color="blue")
+
+        # Process as batch
+        result = image_processing([[small_image], [medium_image], [large_image]], return_tensors="pt")
+
+        # All should be processed and padded to same size
+        self.assertEqual(result.pixel_values.shape[0], 3)
+        # All should have same max_num_patches
+        self.assertEqual(result.pixel_values.shape[1], image_processing.max_num_patches)
+        # Patch dimension should be patch_size^2 * 3 channels
+        expected_patch_dim = 3 * image_processing.encoder_patch_size**2
+        self.assertEqual(result.pixel_values.shape[2], expected_patch_dim)
+
+        # Spatial shapes should all be square (equal height and width)
+        shapes = result.spatial_shapes.tolist()
+        for shape in shapes:
+            self.assertEqual(shape[0], shape[1], "Square images should have equal height and width")
+
+        # pixel_attention_mask should have correct shape
+        self.assertEqual(result.pixel_attention_mask.shape[0], 3)
+        self.assertEqual(result.pixel_attention_mask.shape[1], image_processing.max_num_patches)
+
+    def test_batch_mixed_aspect_ratios(self):
+        """Test batch with mixed aspect ratios."""
+        image_processing = self.fast_image_processing_class(do_image_splitting=False)
+
+        square = Image.new("RGB", (512, 512), color="red")
+        landscape = Image.new("RGB", (1024, 512), color="green")
+        portrait = Image.new("RGB", (512, 1024), color="blue")
+
+        result = image_processing([[square], [landscape], [portrait]], return_tensors="pt")
+
+        # All should be processed
+        self.assertEqual(result.pixel_values.shape[0], 3)
+        self.assertEqual(result.spatial_shapes.shape[0], 3)
+
+        # Spatial shapes should reflect aspect ratios: [height, width]
+        shapes = result.spatial_shapes.tolist()
+        square_shape, landscape_shape, portrait_shape = shapes
+
+        # Square: height == width
+        self.assertEqual(square_shape[0], square_shape[1], "Square image should have equal spatial dimensions")
+
+        # Landscape: width > height
+        self.assertGreater(landscape_shape[1], landscape_shape[0], "Landscape image should have width > height")
+
+        # Portrait: height > width
+        self.assertGreater(portrait_shape[0], portrait_shape[1], "Portrait image should have height > width")
+
+        # pixel_attention_mask should match batch size and max_num_patches
+        self.assertEqual(result.pixel_attention_mask.shape[0], 3)
+        self.assertEqual(result.pixel_attention_mask.shape[1], image_processing.max_num_patches)
+
+    def test_disable_grouping_single_image(self):
+        """Test disable_grouping parameter with single image."""
+        image_processing = self.fast_image_processing_class(do_image_splitting=False)
+
+        image = Image.new("RGB", (512, 512), color="purple")
+
+        # Process with and without disable_grouping
+        result_grouped = image_processing([[image]], return_tensors="pt", disable_grouping=False)
+        result_ungrouped = image_processing([[image]], return_tensors="pt", disable_grouping=True)
+
+        # Both should produce all expected output keys
+        for result in [result_grouped, result_ungrouped]:
+            self.assertIn("pixel_values", result)
+            self.assertIn("spatial_shapes", result)
+            self.assertIn("pixel_attention_mask", result)
+
+        # Both should have same output shapes for single image
+        self.assertEqual(result_grouped.pixel_values.shape, result_ungrouped.pixel_values.shape)
+        self.assertEqual(result_grouped.spatial_shapes.shape, result_ungrouped.spatial_shapes.shape)
+        self.assertEqual(result_grouped.pixel_attention_mask.shape, result_ungrouped.pixel_attention_mask.shape)
+
+        # Verify specific shapes
+        self.assertEqual(result_ungrouped.pixel_values.shape[0], 1)
+        self.assertEqual(result_ungrouped.pixel_values.shape[1], image_processing.max_num_patches)
+        expected_patch_dim = 3 * image_processing.encoder_patch_size**2
+        self.assertEqual(result_ungrouped.pixel_values.shape[2], expected_patch_dim)
+
+    def test_disable_grouping_batch(self):
+        """Test disable_grouping parameter with batch of images."""
+        image_processing = self.fast_image_processing_class(do_image_splitting=False)
+
+        # Images of same size - normally would be grouped
+        img1 = Image.new("RGB", (256, 256), color="red")
+        img2 = Image.new("RGB", (256, 256), color="green")
+        img3 = Image.new("RGB", (256, 256), color="blue")
+
+        # Process with disable_grouping=True
+        result = image_processing([[img1], [img2], [img3]], return_tensors="pt", disable_grouping=True)
+
+        # Should produce valid output for all images
+        self.assertEqual(result.pixel_values.shape[0], 3)
+
+    def test_batch_with_tiling(self):
+        """Test batch processing when some images need tiling."""
+        image_processing = self.fast_image_processing_class(
+            do_image_splitting=True,
+            use_thumbnail=True,
+            min_tiles=2,
+            max_tiles=4,
+            tile_size=512,
+        )
+
+        # Small image (no tiling needed) and large image (will be tiled)
+        small = Image.new("RGB", (256, 256), color="red")
+        large = Image.new("RGB", (1024, 1024), color="blue")  # 2x2 tiles at 512
+
+        result = image_processing([[small], [large]], return_tensors="pt", return_row_col_info=True)
+
+        # Calculate tiles for each image
+        small_tiles = result.image_rows[0].item() * result.image_cols[0].item()
+        large_tiles = result.image_rows[1].item() * result.image_cols[1].item()
+
+        # Small image: single tile (no splitting needed)
+        self.assertEqual(small_tiles, 1, "Small 256x256 image should have 1 tile (no splitting)")
+
+        # Large image: 2x2 = 4 tiles for 1024x1024 with tile_size=512
+        self.assertEqual(large_tiles, 4, "Large 1536x1536 image should have 4 tiles (2x2)")
+
+        # Total images: small (1) + large tiles (4) + thumbnail for large (1) = 6
+        # Thumbnail is only added when there's more than 1 tile
+        expected_total = 1 + 4 + 1  # small + large_tiles + large_thumbnail
+        self.assertEqual(result.pixel_values.shape[0], expected_total)
+        self.assertEqual(result.spatial_shapes.shape[0], expected_total)
+        self.assertEqual(result.pixel_attention_mask.shape[0], expected_total)
diff --git a/tests/models/lfm2_vl/test_processing_lfm2_vl.py b/tests/models/lfm2_vl/test_processing_lfm2_vl.py
--- a/tests/models/lfm2_vl/test_processing_lfm2_vl.py
+++ b/tests/models/lfm2_vl/test_processing_lfm2_vl.py
@@ -456,3 +456,144 @@ def test_missing_images_error(self):
         with self.assertRaises(ValueError) as context:
             processor(text=texts, images=None)
         self.assertTrue("We detected 2 tokens in the text but no images were passed" in str(context.exception))
+
+    def test_single_tile_image_with_thumbnail_disabled(self):
+        """Test that single-tile images work correctly when use_thumbnail=False."""
+        processor_components = self.prepare_components()
+        processor_components["tokenizer"] = self.get_component("tokenizer", padding_side="left")
+        processor_components["image_processor"] = self.get_component("image_processor", do_image_splitting=False)
+        processor_kwargs = self.prepare_processor_dict()
+
+        processor = self.processor_class(**processor_components, **processor_kwargs)
+
+        image_str = "<image>"
+        text_str = "Describe this image."
+        text = image_str + text_str
+
+        # Test with use_thumbnail=False - this should still generate correct tokens
+        inputs = processor(text=text, images=self.small_image, use_thumbnail=False)
+
+        # Count image tokens in input_ids
+        num_image_tokens = sum(1 for token_id in inputs["input_ids"][0] if token_id == self.image_token_id)
+
+        # Verify we have image tokens (the bug caused 0 tokens)
+        self.assertGreater(num_image_tokens, 0, "Single-tile image with use_thumbnail=False should have image tokens")
+
+        # Verify the number of image tokens matches expected based on spatial_shapes
+        spatial_shape = inputs["spatial_shapes"][0].tolist()
+        expected_tokens = math.ceil(spatial_shape[0] / processor.image_processor.downsample_factor) * math.ceil(
+            spatial_shape[1] / processor.image_processor.downsample_factor
+        )
+        self.assertEqual(
+            num_image_tokens,
+            expected_tokens,
+            f"Image tokens ({num_image_tokens}) should match expected ({expected_tokens}) based on spatial shapes",
+        )
+
+        # Verify pixel_values shape is correct
+        encoder_feature_dims = (
+            3 * processor.image_processor.encoder_patch_size * processor.image_processor.encoder_patch_size
+        )
+        self.assertEqual(
+            np.array(inputs["pixel_values"]).shape,
+            (1, processor.image_processor.max_num_patches, encoder_feature_dims),
+        )
+
+    def test_multi_image(self):
+        """Test that text is correctly processed when multiple images are present."""
+        processor_components = self.prepare_components()
+        processor_components["tokenizer"] = self.get_component("tokenizer", padding_side="left")
+        processor_components["image_processor"] = self.get_component("image_processor", do_image_splitting=False)
+        processor_kwargs = self.prepare_processor_dict()
+
+        processor = self.processor_class(**processor_components, **processor_kwargs)
+
+        # Text with multiple images and text segments between them
+        text_1 = "First: "
+        text_2 = " Middle: "
+        text_3 = " End."
+        text = text_1 + "<image>" + text_2 + "<image>" + text_3
+        images = [[self.small_image, self.small_image]]
+
+        inputs = processor(text=text, images=images)
+
+        # Construct expected input_ids
+        tokenized_1 = processor.tokenizer(text_1, add_special_tokens=False)["input_ids"]
+        tokenized_2 = processor.tokenizer(text_2, add_special_tokens=False)["input_ids"]
+        tokenized_3 = processor.tokenizer(text_3, add_special_tokens=False)["input_ids"]
+        image_tokens = [self.image_start_token_id] + [self.image_token_id] * 9 + [self.image_end_token_id]
+
+        expected_input_ids = tokenized_1 + image_tokens + tokenized_2 + image_tokens + tokenized_3
+        self.assertEqual(inputs["input_ids"], [expected_input_ids])
+        self.assertEqual(inputs["attention_mask"], [[1] * len(expected_input_ids)])
+
+    def test_multi_turn_multi_image(self):
+        """Test that text is correctly processed when multiple images are present in a multi-turn conversation."""
+        processor_components = self.prepare_components()
+        processor_components["tokenizer"] = self.get_component("tokenizer", padding_side="left")
+        processor_components["image_processor"] = self.get_component("image_processor", do_image_splitting=False)
+        processor_kwargs = self.prepare_processor_dict()
+
+        processor = self.processor_class(**processor_components, **processor_kwargs)
+
+        # Simulate a multi-turn conversation with images
+        messages = [
+            {
+                "role": "user",
+                "content": [
+                    {"type": "text", "text": "What is in image A?"},
+                    {"type": "image"},
+                    {"type": "text", "text": "And image B?"},
+                    {"type": "image"},
+                ],
+            },
+            {
+                "role": "assistant",
+                "content": [{"type": "text", "text": "Image A shows X. Image B shows Y."}],
+            },
+            {
+                "role": "user",
+                "content": [{"type": "text", "text": "Tell me more about image A."}],
+            },
+        ]
+
+        text = processor.apply_chat_template(messages, add_generation_prompt=True)
+        images = [[self.small_image, self.small_image]]
+
+        inputs = processor(text=text, images=images, do_image_splitting=False)
+
+        # Construct expected input_ids based on the chat template structure
+        image_tokens = [self.image_start_token_id] + [self.image_token_id] * 9 + [self.image_end_token_id]
+
+        # Build expected sequence from chat template parts
+        bos = processor.tokenizer(self.bos_token, add_special_tokens=False)["input_ids"]
+        user_start = processor.tokenizer("<|im_start|>user\n", add_special_tokens=False)["input_ids"]
+        assistant_start = processor.tokenizer("<|im_start|>assistant\n", add_special_tokens=False)["input_ids"]
+        im_end = processor.tokenizer("<|im_end|>\n", add_special_tokens=False)["input_ids"]
+
+        text_a = processor.tokenizer("What is in image A?", add_special_tokens=False)["input_ids"]
+        text_b = processor.tokenizer("And image B?", add_special_tokens=False)["input_ids"]
+        assistant_response = processor.tokenizer("Image A shows X. Image B shows Y.", add_special_tokens=False)[
+            "input_ids"
+        ]
+        followup = processor.tokenizer("Tell me more about image A.", add_special_tokens=False)["input_ids"]
+
+        expected_input_ids = (
+            bos
+            + user_start
+            + text_a
+            + image_tokens
+            + text_b
+            + image_tokens
+            + im_end
+            + assistant_start
+            + assistant_response
+            + im_end
+            + user_start
+            + followup
+            + im_end
+            + assistant_start
+        )
+
+        self.assertEqual(inputs["input_ids"], [expected_input_ids])
+        self.assertEqual(inputs["attention_mask"], [[1] * len(expected_input_ids)])
EOF_114329324912

# Verify environment is ready
echo "=== Environment Verification ==="
echo "Python version:"
python --version
echo "Transformers location:"
python -c "import transformers; print(transformers.__file__)"
echo "PyTorch version:"
python -c "import torch; print(torch.__version__)"
echo "Pillow version:"
python -c "import PIL; print(PIL.__version__)"

# Set environment variables for test execution
export PYTHONPATH=/testbed/src:/testbed:$PYTHONPATH
export TRANSFORMERS_CACHE=/tmp/transformers_cache
export HF_HOME=/tmp/hf_home
export TOKENIZERS_PARALLELISM=false
export DISABLE_SAFETENSORS_CONVERSION=true
export TRANSFORMERS_VERBOSITY=info
export PYTEST_TIMEOUT=600

# Create cache directories if they don't exist
mkdir -p /tmp/transformers_cache /tmp/hf_home
chmod -R 777 /tmp/transformers_cache /tmp/hf_home

# Run the target test files
echo "=== Running Target Tests ==="
python -m pytest -xvs tests/models/lfm2_vl/test_image_processing_lfm2_vl.py tests/models/lfm2_vl/test_processing_lfm2_vl.py

# Capture exit code
rc=$?

# Echo exit code for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: reset test files to original state
git checkout 1dc69bd6f7f5dcc1a32467be505dd873d573846e "tests/models/lfm2_vl/test_image_processing_lfm2_vl.py" "tests/models/lfm2_vl/test_processing_lfm2_vl.py"