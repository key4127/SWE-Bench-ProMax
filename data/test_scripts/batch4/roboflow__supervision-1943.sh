#!/bin/bash
set -uxo pipefail

# Activate the conda environment
source /opt/miniconda3/etc/profile.d/conda.sh
conda activate testbed

# Navigate to the testbed directory
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 005cdbd37abec947301ed005d34d07a4c97f80bc "test/utils/test_conversion.py" "test/utils/test_image.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/test/utils/test_conversion.py b/test/utils/test_conversion.py
--- a/test/utils/test_conversion.py
+++ b/test/utils/test_conversion.py
@@ -3,7 +3,7 @@
 
 from supervision.utils.conversion import (
     cv2_to_pillow,
-    ensure_cv2_image_for_processing,
+    ensure_cv2_image_for_standalone_function,
     images_to_cv2,
     pillow_to_cv2,
 )
@@ -16,7 +16,7 @@ def test_ensure_cv2_image_for_processing_when_pillow_image_submitted(
     param_a_value = 3
     param_b_value = "some"
 
-    @ensure_cv2_image_for_processing
+    @ensure_cv2_image_for_standalone_function
     def my_custom_processing_function(
         image: np.ndarray,
         param_a: int,
@@ -55,7 +55,7 @@ def test_ensure_cv2_image_for_processing_when_cv2_image_submitted(
     param_a_value = 3
     param_b_value = "some"
 
-    @ensure_cv2_image_for_processing
+    @ensure_cv2_image_for_standalone_function
     def my_custom_processing_function(
         image: np.ndarray,
         param_a: int,
diff --git a/test/utils/test_image.py b/test/utils/test_image.py
--- a/test/utils/test_image.py
+++ b/test/utils/test_image.py
@@ -1,9 +1,7 @@
 import numpy as np
-import pytest
 from PIL import Image, ImageChops
 
-from supervision import Color, Point
-from supervision.utils.image import create_tiles, letterbox_image, resize_image
+from supervision.utils.image import letterbox_image, resize_image
 
 
 def test_resize_image_for_opencv_image() -> None:
@@ -96,147 +94,3 @@ def test_letterbox_image_for_pillow_image() -> None:
     assert difference.getbbox() is None, (
         "Expected padding to be added top and bottom with padding added top and bottom"
     )
-
-
-def test_create_tiles_with_one_image(
-    one_image: np.ndarray, single_image_tile: np.ndarray
-) -> None:
-    # when
-    result = create_tiles(images=[one_image], single_tile_size=(240, 240))
-
-    # # then
-    assert np.allclose(result, single_image_tile, atol=5.0)
-
-
-def test_create_tiles_with_one_image_and_enforced_grid(
-    one_image: np.ndarray, single_image_tile_enforced_grid: np.ndarray
-) -> None:
-    # when
-    result = create_tiles(
-        images=[one_image],
-        grid_size=(None, 3),
-        single_tile_size=(240, 240),
-    )
-
-    # then
-    assert np.allclose(result, single_image_tile_enforced_grid, atol=5.0)
-
-
-def test_create_tiles_with_two_images(
-    two_images: list[np.ndarray], two_images_tile: np.ndarray
-) -> None:
-    # when
-    result = create_tiles(images=two_images, single_tile_size=(240, 240))
-
-    # then
-    assert np.allclose(result, two_images_tile, atol=5.0)
-
-
-def test_create_tiles_with_three_images(
-    three_images: list[np.ndarray], three_images_tile: np.ndarray
-) -> None:
-    # when
-    result = create_tiles(images=three_images, single_tile_size=(240, 240))
-
-    # then
-    assert np.allclose(result, three_images_tile, atol=5.0)
-
-
-def test_create_tiles_with_four_images(
-    four_images: list[np.ndarray],
-    four_images_tile: np.ndarray,
-) -> None:
-    # when
-    result = create_tiles(images=four_images, single_tile_size=(240, 240))
-
-    # then
-    assert np.allclose(result, four_images_tile, atol=5.0)
-
-
-def test_create_tiles_with_all_images(
-    all_images: list[np.ndarray],
-    all_images_tile: np.ndarray,
-) -> None:
-    # when
-    result = create_tiles(images=all_images, single_tile_size=(240, 240))
-
-    # then
-    assert np.allclose(result, all_images_tile, atol=5.0)
-
-
-def test_create_tiles_with_all_images_and_custom_grid(
-    all_images: list[np.ndarray], all_images_tile_and_custom_grid: np.ndarray
-) -> None:
-    # when
-    result = create_tiles(
-        images=all_images,
-        grid_size=(3, 3),
-        single_tile_size=(240, 240),
-    )
-
-    # then
-    assert np.allclose(result, all_images_tile_and_custom_grid, atol=5.0)
-
-
-def test_create_tiles_with_all_images_and_custom_colors(
-    all_images: list[np.ndarray], all_images_tile_and_custom_colors: np.ndarray
-) -> None:
-    # when
-    result = create_tiles(
-        images=all_images,
-        tile_margin_color=(127, 127, 127),
-        tile_padding_color=(224, 224, 224),
-        single_tile_size=(240, 240),
-    )
-
-    # then
-    assert np.allclose(result, all_images_tile_and_custom_colors, atol=5.0)
-
-
-def test_create_tiles_with_all_images_and_titles(
-    all_images: list[np.ndarray],
-    all_images_tile_and_custom_colors_and_titles: np.ndarray,
-) -> None:
-    # when
-    result = create_tiles(
-        images=all_images,
-        titles=["Image 1", None, "Image 3", "Image 4"],
-        single_tile_size=(240, 240),
-    )
-
-    # then
-    assert np.allclose(result, all_images_tile_and_custom_colors_and_titles, atol=5.0)
-
-
-def test_create_tiles_with_all_images_and_titles_with_custom_configs(
-    all_images: list[np.ndarray],
-    all_images_tile_and_titles_with_custom_configs: np.ndarray,
-) -> None:
-    # when
-    result = create_tiles(
-        images=all_images,
-        titles=["Image 1", None, "Image 3", "Image 4"],
-        single_tile_size=(240, 240),
-        titles_anchors=[
-            Point(x=200, y=300),
-            Point(x=300, y=400),
-            None,
-            Point(x=300, y=400),
-        ],
-        titles_color=Color.RED,
-        titles_scale=1.5,
-        titles_thickness=3,
-        titles_padding=20,
-        titles_background_color=Color.BLACK,
-        default_title_placement="bottom",
-    )
-
-    # then
-    assert np.allclose(result, all_images_tile_and_titles_with_custom_configs, atol=5.0)
-
-
-def test_create_tiles_with_all_images_and_custom_grid_to_small_to_fit_images(
-    all_images: list[np.ndarray],
-) -> None:
-    with pytest.raises(ValueError):
-        _ = create_tiles(images=all_images, grid_size=(2, 2))
EOF_114329324912

# Run the target test files using pytest
# Using single-process mode for stability in virtualized environment
pytest --no-header -rA --tb=short -p no:cacheprovider test/utils/test_conversion.py test/utils/test_image.py

# Capture the exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 005cdbd37abec947301ed005d34d07a4c97f80bc "test/utils/test_conversion.py" "test/utils/test_image.py"