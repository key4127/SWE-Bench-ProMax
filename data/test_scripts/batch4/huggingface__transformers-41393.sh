#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout to the target commit and ensure test files are at the correct state
git checkout f028e9340cca466a64592dbea542d3bdd2c89d5e "tests/models/mask2former/test_image_processing_mask2former.py" "tests/models/maskformer/test_image_processing_maskformer.py"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/models/mask2former/test_image_processing_mask2former.py b/tests/models/mask2former/test_image_processing_mask2former.py
--- a/tests/models/mask2former/test_image_processing_mask2former.py
+++ b/tests/models/mask2former/test_image_processing_mask2former.py
@@ -194,13 +194,14 @@ def test_image_processor_properties(self):
     def comm_get_image_processing_inputs(
         self,
         image_processor_tester,
+        image_processing_class,
         with_segmentation_maps=False,
         is_instance_map=False,
         segmentation_type="np",
         numpify=False,
         input_data_format=None,
     ):
-        image_processing = self.image_processing_class(**image_processor_tester.prepare_image_processor_dict())
+        image_processing = image_processing_class(**image_processor_tester.prepare_image_processor_dict())
         # prepare image and target
         num_labels = image_processor_tester.num_labels
         annotations = None
@@ -228,7 +229,6 @@ def comm_get_image_processing_inputs(
             annotations,
             return_tensors="pt",
             instance_id_to_semantic_id=instance_id_to_semantic_id,
-            pad_and_return_pixel_mask=True,
             input_data_format=input_data_format,
         )
 
@@ -264,25 +264,26 @@ def common(
                 image_mean=[0.5] * num_channels,
                 image_std=[0.5] * num_channels,
             )
+            for image_processing_class in self.image_processor_list:
+                inputs = self.comm_get_image_processing_inputs(
+                    image_processor_tester=image_processor_tester,
+                    image_processing_class=image_processing_class,
+                    with_segmentation_maps=True,
+                    is_instance_map=is_instance_map,
+                    segmentation_type=segmentation_type,
+                    numpify=numpify,
+                    input_data_format=input_data_format,
+                )
 
-            inputs = self.comm_get_image_processing_inputs(
-                image_processor_tester=image_processor_tester,
-                with_segmentation_maps=True,
-                is_instance_map=is_instance_map,
-                segmentation_type=segmentation_type,
-                numpify=numpify,
-                input_data_format=input_data_format,
-            )
-
-            mask_labels = inputs["mask_labels"]
-            class_labels = inputs["class_labels"]
-            pixel_values = inputs["pixel_values"]
+                mask_labels = inputs["mask_labels"]
+                class_labels = inputs["class_labels"]
+                pixel_values = inputs["pixel_values"]
 
-            # check the batch_size
-            for mask_label, class_label in zip(mask_labels, class_labels):
-                self.assertEqual(mask_label.shape[0], class_label.shape[0])
-                # this ensure padding has happened
-                self.assertEqual(mask_label.shape[1:], pixel_values.shape[2:])
+                # check the batch_size
+                for mask_label, class_label in zip(mask_labels, class_labels):
+                    self.assertEqual(mask_label.shape[0], class_label.shape[0])
+                    # this ensure padding has happened
+                    self.assertEqual(mask_label.shape[1:], pixel_values.shape[2:])
 
         common()
         common(is_instance_map=True)
@@ -335,31 +336,32 @@ def get_instance_segmentation_and_mapping(annotation):
         instance_seg2, inst2class2 = get_instance_segmentation_and_mapping(annotation2)
 
         # create a image processor
-        image_processing = Mask2FormerImageProcessor(do_reduce_labels=True, ignore_index=255, size=(512, 512))
-
-        # prepare the images and annotations
-        inputs = image_processing(
-            [image1, image2],
-            [instance_seg1, instance_seg2],
-            instance_id_to_semantic_id=[inst2class1, inst2class2],
-            return_tensors="pt",
-        )
+        for image_processing_class in self.image_processor_list:
+            image_processing = image_processing_class(do_reduce_labels=True, ignore_index=255, size=(512, 512))
+
+            # prepare the images and annotations
+            inputs = image_processing(
+                [image1, image2],
+                [instance_seg1, instance_seg2],
+                instance_id_to_semantic_id=[inst2class1, inst2class2],
+                return_tensors="pt",
+            )
 
-        # verify the pixel values and pixel mask
-        self.assertEqual(inputs["pixel_values"].shape, (2, 3, 512, 512))
-        self.assertEqual(inputs["pixel_mask"].shape, (2, 512, 512))
+            # verify the pixel values and pixel mask
+            self.assertEqual(inputs["pixel_values"].shape, (2, 3, 512, 512))
+            self.assertEqual(inputs["pixel_mask"].shape, (2, 512, 512))
 
-        # verify the class labels
-        self.assertEqual(len(inputs["class_labels"]), 2)
-        torch.testing.assert_close(inputs["class_labels"][0], torch.tensor([30, 55]))
-        torch.testing.assert_close(inputs["class_labels"][1], torch.tensor([4, 4, 23, 55]))
+            # verify the class labels
+            self.assertEqual(len(inputs["class_labels"]), 2)
+            torch.testing.assert_close(inputs["class_labels"][0], torch.tensor([30, 55]))
+            torch.testing.assert_close(inputs["class_labels"][1], torch.tensor([4, 4, 23, 55]))
 
-        # verify the mask labels
-        self.assertEqual(len(inputs["mask_labels"]), 2)
-        self.assertEqual(inputs["mask_labels"][0].shape, (2, 512, 512))
-        self.assertEqual(inputs["mask_labels"][1].shape, (4, 512, 512))
-        self.assertEqual(inputs["mask_labels"][0].sum().item(), 41527.0)
-        self.assertEqual(inputs["mask_labels"][1].sum().item(), 26259.0)
+            # verify the mask labels
+            self.assertEqual(len(inputs["mask_labels"]), 2)
+            self.assertEqual(inputs["mask_labels"][0].shape, (2, 512, 512))
+            self.assertEqual(inputs["mask_labels"][1].shape, (4, 512, 512))
+            self.assertEqual(inputs["mask_labels"][0].sum().item(), 41527.0)
+            self.assertEqual(inputs["mask_labels"][1].sum().item(), 26259.0)
 
     def test_integration_semantic_segmentation(self):
         # load 2 images and corresponding semantic annotations from the hub
@@ -378,30 +380,31 @@ def test_integration_semantic_segmentation(self):
         )
 
         # create a image processor
-        image_processing = Mask2FormerImageProcessor(do_reduce_labels=True, ignore_index=255, size=(512, 512))
+        for image_processing_class in self.image_processor_list:
+            image_processing = image_processing_class(do_reduce_labels=True, ignore_index=255, size=(512, 512))
 
-        # prepare the images and annotations
-        inputs = image_processing(
-            [image1, image2],
-            [annotation1, annotation2],
-            return_tensors="pt",
-        )
+            # prepare the images and annotations
+            inputs = image_processing(
+                [image1, image2],
+                [annotation1, annotation2],
+                return_tensors="pt",
+            )
 
-        # verify the pixel values and pixel mask
-        self.assertEqual(inputs["pixel_values"].shape, (2, 3, 512, 512))
-        self.assertEqual(inputs["pixel_mask"].shape, (2, 512, 512))
+            # verify the pixel values and pixel mask
+            self.assertEqual(inputs["pixel_values"].shape, (2, 3, 512, 512))
+            self.assertEqual(inputs["pixel_mask"].shape, (2, 512, 512))
 
-        # verify the class labels
-        self.assertEqual(len(inputs["class_labels"]), 2)
-        torch.testing.assert_close(inputs["class_labels"][0], torch.tensor([2, 4, 60]))
-        torch.testing.assert_close(inputs["class_labels"][1], torch.tensor([0, 3, 7, 8, 15, 28, 30, 143]))
+            # verify the class labels
+            self.assertEqual(len(inputs["class_labels"]), 2)
+            torch.testing.assert_close(inputs["class_labels"][0], torch.tensor([2, 4, 60]))
+            torch.testing.assert_close(inputs["class_labels"][1], torch.tensor([0, 3, 7, 8, 15, 28, 30, 143]))
 
-        # verify the mask labels
-        self.assertEqual(len(inputs["mask_labels"]), 2)
-        self.assertEqual(inputs["mask_labels"][0].shape, (3, 512, 512))
-        self.assertEqual(inputs["mask_labels"][1].shape, (8, 512, 512))
-        self.assertEqual(inputs["mask_labels"][0].sum().item(), 170200.0)
-        self.assertEqual(inputs["mask_labels"][1].sum().item(), 257036.0)
+            # verify the mask labels
+            self.assertEqual(len(inputs["mask_labels"]), 2)
+            self.assertEqual(inputs["mask_labels"][0].shape, (3, 512, 512))
+            self.assertEqual(inputs["mask_labels"][1].shape, (8, 512, 512))
+            self.assertEqual(inputs["mask_labels"][0].sum().item(), 170200.0)
+            self.assertEqual(inputs["mask_labels"][1].sum().item(), 257036.0)
 
     def test_integration_panoptic_segmentation(self):
         # load 2 images and corresponding panoptic annotations from the hub
@@ -435,34 +438,35 @@ def create_panoptic_map(annotation, segments_info):
         panoptic_map2, inst2class2 = create_panoptic_map(annotation2, segments_info2)
 
         # create a image processor
-        image_processing = Mask2FormerImageProcessor(ignore_index=0, do_resize=False)
-
-        # prepare the images and annotations
-        pixel_values_list = [np.moveaxis(np.array(image1), -1, 0), np.moveaxis(np.array(image2), -1, 0)]
-        inputs = image_processing.encode_inputs(
-            pixel_values_list,
-            [panoptic_map1, panoptic_map2],
-            instance_id_to_semantic_id=[inst2class1, inst2class2],
-            return_tensors="pt",
-        )
+        for image_processing_class in self.image_processor_list:
+            image_processing = image_processing_class(ignore_index=0, do_resize=False)
+
+            # prepare the images and annotations
+            pixel_values_list = [np.moveaxis(np.array(image1), -1, 0), np.moveaxis(np.array(image2), -1, 0)]
+            inputs = image_processing(
+                pixel_values_list,
+                [panoptic_map1, panoptic_map2],
+                instance_id_to_semantic_id=[inst2class1, inst2class2],
+                return_tensors="pt",
+            )
 
-        # verify the pixel values and pixel mask
-        self.assertEqual(inputs["pixel_values"].shape, (2, 3, 512, 711))
-        self.assertEqual(inputs["pixel_mask"].shape, (2, 512, 711))
-
-        # verify the class labels
-        self.assertEqual(len(inputs["class_labels"]), 2)
-        expected_class_labels = torch.tensor([4, 17, 32, 42, 42, 42, 42, 42, 42, 42, 32, 12, 12, 12, 12, 12, 42, 42, 12, 12, 12, 42, 12, 12, 12, 12, 12, 3, 12, 12, 12, 12, 42, 42, 42, 12, 42, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 5, 12, 12, 12, 12, 12, 12, 12, 0, 43, 43, 43, 96, 43, 104, 43, 31, 125, 31, 125, 138, 87, 125, 149, 138, 125, 87, 87])  # fmt: skip
-        torch.testing.assert_close(inputs["class_labels"][0], torch.tensor(expected_class_labels))
-        expected_class_labels = torch.tensor([19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 67, 82, 19, 19, 17, 19, 19, 19, 19, 19, 19, 19, 19, 19, 12, 12, 42, 12, 12, 12, 12, 3, 14, 12, 12, 12, 12, 12, 12, 12, 12, 14, 5, 12, 12, 0, 115, 43, 43, 115, 43, 43, 43, 8, 8, 8, 138, 138, 125, 143])  # fmt: skip
-        torch.testing.assert_close(inputs["class_labels"][1], expected_class_labels)
-
-        # verify the mask labels
-        self.assertEqual(len(inputs["mask_labels"]), 2)
-        self.assertEqual(inputs["mask_labels"][0].shape, (79, 512, 711))
-        self.assertEqual(inputs["mask_labels"][1].shape, (61, 512, 711))
-        self.assertEqual(inputs["mask_labels"][0].sum().item(), 315193.0)
-        self.assertEqual(inputs["mask_labels"][1].sum().item(), 350747.0)
+            # verify the pixel values and pixel mask
+            self.assertEqual(inputs["pixel_values"].shape, (2, 3, 512, 711))
+            self.assertEqual(inputs["pixel_mask"].shape, (2, 512, 711))
+
+            # verify the class labels
+            self.assertEqual(len(inputs["class_labels"]), 2)
+            expected_class_labels = torch.tensor([4, 17, 32, 42, 42, 42, 42, 42, 42, 42, 32, 12, 12, 12, 12, 12, 42, 42, 12, 12, 12, 42, 12, 12, 12, 12, 12, 3, 12, 12, 12, 12, 42, 42, 42, 12, 42, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 5, 12, 12, 12, 12, 12, 12, 12, 0, 43, 43, 43, 96, 43, 104, 43, 31, 125, 31, 125, 138, 87, 125, 149, 138, 125, 87, 87])  # fmt: skip
+            torch.testing.assert_close(inputs["class_labels"][0], torch.tensor(expected_class_labels))
+            expected_class_labels = torch.tensor([19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 67, 82, 19, 19, 17, 19, 19, 19, 19, 19, 19, 19, 19, 19, 12, 12, 42, 12, 12, 12, 12, 3, 14, 12, 12, 12, 12, 12, 12, 12, 12, 14, 5, 12, 12, 0, 115, 43, 43, 115, 43, 43, 43, 8, 8, 8, 138, 138, 125, 143])  # fmt: skip
+            torch.testing.assert_close(inputs["class_labels"][1], expected_class_labels)
+
+            # verify the mask labels
+            self.assertEqual(len(inputs["mask_labels"]), 2)
+            self.assertEqual(inputs["mask_labels"][0].shape, (79, 512, 711))
+            self.assertEqual(inputs["mask_labels"][1].shape, (61, 512, 711))
+            self.assertEqual(inputs["mask_labels"][0].sum().item(), 315193.0)
+            self.assertEqual(inputs["mask_labels"][1].sum().item(), 350747.0)
 
     def test_binary_mask_to_rle(self):
         fake_binary_mask = np.zeros((20, 50))
diff --git a/tests/models/maskformer/test_image_processing_maskformer.py b/tests/models/maskformer/test_image_processing_maskformer.py
--- a/tests/models/maskformer/test_image_processing_maskformer.py
+++ b/tests/models/maskformer/test_image_processing_maskformer.py
@@ -188,9 +188,9 @@ def test_image_processor_properties(self):
             self.assertTrue(hasattr(image_processing, "num_labels"))
 
     def comm_get_image_processing_inputs(
-        self, with_segmentation_maps=False, is_instance_map=False, segmentation_type="np"
+        self, image_processing_class, with_segmentation_maps=False, is_instance_map=False, segmentation_type="np"
     ):
-        image_processing = self.image_processing_class(**self.image_processor_dict)
+        image_processing = image_processing_class(**self.image_processor_dict)
         # prepare image and target
         num_labels = self.image_processor_tester.num_labels
         annotations = None
@@ -212,7 +212,6 @@ def comm_get_image_processing_inputs(
             annotations,
             return_tensors="pt",
             instance_id_to_semantic_id=instance_id_to_semantic_id,
-            pad_and_return_pixel_mask=True,
         )
 
         return inputs
@@ -233,19 +232,23 @@ def test_with_size_divisor(self):
 
     def test_call_with_segmentation_maps(self):
         def common(is_instance_map=False, segmentation_type=None):
-            inputs = self.comm_get_image_processing_inputs(
-                with_segmentation_maps=True, is_instance_map=is_instance_map, segmentation_type=segmentation_type
-            )
+            for image_processing_class in self.image_processor_list:
+                inputs = self.comm_get_image_processing_inputs(
+                    image_processing_class=image_processing_class,
+                    with_segmentation_maps=True,
+                    is_instance_map=is_instance_map,
+                    segmentation_type=segmentation_type,
+                )
 
-            mask_labels = inputs["mask_labels"]
-            class_labels = inputs["class_labels"]
-            pixel_values = inputs["pixel_values"]
+                mask_labels = inputs["mask_labels"]
+                class_labels = inputs["class_labels"]
+                pixel_values = inputs["pixel_values"]
 
-            # check the batch_size
-            for mask_label, class_label in zip(mask_labels, class_labels):
-                self.assertEqual(mask_label.shape[0], class_label.shape[0])
-                # this ensure padding has happened
-                self.assertEqual(mask_label.shape[1:], pixel_values.shape[2:])
+                # check the batch_size
+                for mask_label, class_label in zip(mask_labels, class_labels):
+                    self.assertEqual(mask_label.shape[0], class_label.shape[0])
+                    # this ensure padding has happened
+                    self.assertEqual(mask_label.shape[1:], pixel_values.shape[2:])
 
         common()
         common(is_instance_map=True)
@@ -286,31 +289,32 @@ def get_instance_segmentation_and_mapping(annotation):
         instance_seg2, inst2class2 = get_instance_segmentation_and_mapping(annotation2)
 
         # create a image processor
-        image_processing = MaskFormerImageProcessor(do_reduce_labels=True, ignore_index=255, size=(512, 512))
-
-        # prepare the images and annotations
-        inputs = image_processing(
-            [image1, image2],
-            [instance_seg1, instance_seg2],
-            instance_id_to_semantic_id=[inst2class1, inst2class2],
-            return_tensors="pt",
-        )
+        for image_processing_class in self.image_processor_list:
+            image_processing = image_processing_class(do_reduce_labels=True, ignore_index=255, size=(512, 512))
+
+            # prepare the images and annotations
+            inputs = image_processing(
+                [image1, image2],
+                [instance_seg1, instance_seg2],
+                instance_id_to_semantic_id=[inst2class1, inst2class2],
+                return_tensors="pt",
+            )
 
-        # verify the pixel values and pixel mask
-        self.assertEqual(inputs["pixel_values"].shape, (2, 3, 512, 512))
-        self.assertEqual(inputs["pixel_mask"].shape, (2, 512, 512))
+            # verify the pixel values and pixel mask
+            self.assertEqual(inputs["pixel_values"].shape, (2, 3, 512, 512))
+            self.assertEqual(inputs["pixel_mask"].shape, (2, 512, 512))
 
-        # verify the class labels
-        self.assertEqual(len(inputs["class_labels"]), 2)
-        torch.testing.assert_close(inputs["class_labels"][0], torch.tensor([30, 55]))
-        torch.testing.assert_close(inputs["class_labels"][1], torch.tensor([4, 4, 23, 55]))
+            # verify the class labels
+            self.assertEqual(len(inputs["class_labels"]), 2)
+            torch.testing.assert_close(inputs["class_labels"][0], torch.tensor([30, 55]))
+            torch.testing.assert_close(inputs["class_labels"][1], torch.tensor([4, 4, 23, 55]))
 
-        # verify the mask labels
-        self.assertEqual(len(inputs["mask_labels"]), 2)
-        self.assertEqual(inputs["mask_labels"][0].shape, (2, 512, 512))
-        self.assertEqual(inputs["mask_labels"][1].shape, (4, 512, 512))
-        self.assertEqual(inputs["mask_labels"][0].sum().item(), 41527.0)
-        self.assertEqual(inputs["mask_labels"][1].sum().item(), 26259.0)
+            # verify the mask labels
+            self.assertEqual(len(inputs["mask_labels"]), 2)
+            self.assertEqual(inputs["mask_labels"][0].shape, (2, 512, 512))
+            self.assertEqual(inputs["mask_labels"][1].shape, (4, 512, 512))
+            self.assertEqual(inputs["mask_labels"][0].sum().item(), 41527.0)
+            self.assertEqual(inputs["mask_labels"][1].sum().item(), 26259.0)
 
     def test_integration_semantic_segmentation(self):
         # load 2 images and corresponding semantic annotations from the hub
@@ -329,30 +333,31 @@ def test_integration_semantic_segmentation(self):
         )
 
         # create a image processor
-        image_processing = MaskFormerImageProcessor(do_reduce_labels=True, ignore_index=255, size=(512, 512))
+        for image_processing_class in self.image_processor_list:
+            image_processing = image_processing_class(do_reduce_labels=True, ignore_index=255, size=(512, 512))
 
-        # prepare the images and annotations
-        inputs = image_processing(
-            [image1, image2],
-            [annotation1, annotation2],
-            return_tensors="pt",
-        )
+            # prepare the images and annotations
+            inputs = image_processing(
+                [image1, image2],
+                [annotation1, annotation2],
+                return_tensors="pt",
+            )
 
-        # verify the pixel values and pixel mask
-        self.assertEqual(inputs["pixel_values"].shape, (2, 3, 512, 512))
-        self.assertEqual(inputs["pixel_mask"].shape, (2, 512, 512))
+            # verify the pixel values and pixel mask
+            self.assertEqual(inputs["pixel_values"].shape, (2, 3, 512, 512))
+            self.assertEqual(inputs["pixel_mask"].shape, (2, 512, 512))
 
-        # verify the class labels
-        self.assertEqual(len(inputs["class_labels"]), 2)
-        torch.testing.assert_close(inputs["class_labels"][0], torch.tensor([2, 4, 60]))
-        torch.testing.assert_close(inputs["class_labels"][1], torch.tensor([0, 3, 7, 8, 15, 28, 30, 143]))
+            # verify the class labels
+            self.assertEqual(len(inputs["class_labels"]), 2)
+            torch.testing.assert_close(inputs["class_labels"][0], torch.tensor([2, 4, 60]))
+            torch.testing.assert_close(inputs["class_labels"][1], torch.tensor([0, 3, 7, 8, 15, 28, 30, 143]))
 
-        # verify the mask labels
-        self.assertEqual(len(inputs["mask_labels"]), 2)
-        self.assertEqual(inputs["mask_labels"][0].shape, (3, 512, 512))
-        self.assertEqual(inputs["mask_labels"][1].shape, (8, 512, 512))
-        self.assertEqual(inputs["mask_labels"][0].sum().item(), 170200.0)
-        self.assertEqual(inputs["mask_labels"][1].sum().item(), 257036.0)
+            # verify the mask labels
+            self.assertEqual(len(inputs["mask_labels"]), 2)
+            self.assertEqual(inputs["mask_labels"][0].shape, (3, 512, 512))
+            self.assertEqual(inputs["mask_labels"][1].shape, (8, 512, 512))
+            self.assertEqual(inputs["mask_labels"][0].sum().item(), 170200.0)
+            self.assertEqual(inputs["mask_labels"][1].sum().item(), 257036.0)
 
     def test_integration_panoptic_segmentation(self):
         # load 2 images and corresponding panoptic annotations from the hub
@@ -386,34 +391,35 @@ def create_panoptic_map(annotation, segments_info):
         panoptic_map2, inst2class2 = create_panoptic_map(annotation2, segments_info2)
 
         # create a image processor
-        image_processing = MaskFormerImageProcessor(ignore_index=0, do_resize=False)
-
-        # prepare the images and annotations
-        pixel_values_list = [np.moveaxis(np.array(image1), -1, 0), np.moveaxis(np.array(image2), -1, 0)]
-        inputs = image_processing.encode_inputs(
-            pixel_values_list,
-            [panoptic_map1, panoptic_map2],
-            instance_id_to_semantic_id=[inst2class1, inst2class2],
-            return_tensors="pt",
-        )
+        for image_processing_class in self.image_processor_list:
+            image_processing = image_processing_class(ignore_index=0, do_resize=False)
+
+            # prepare the images and annotations
+            pixel_values_list = [np.moveaxis(np.array(image1), -1, 0), np.moveaxis(np.array(image2), -1, 0)]
+            inputs = image_processing(
+                pixel_values_list,
+                [panoptic_map1, panoptic_map2],
+                instance_id_to_semantic_id=[inst2class1, inst2class2],
+                return_tensors="pt",
+            )
 
-        # verify the pixel values and pixel mask
-        self.assertEqual(inputs["pixel_values"].shape, (2, 3, 512, 711))
-        self.assertEqual(inputs["pixel_mask"].shape, (2, 512, 711))
-
-        # verify the class labels
-        self.assertEqual(len(inputs["class_labels"]), 2)
-        expected_class_labels = torch.tensor([4, 17, 32, 42, 42, 42, 42, 42, 42, 42, 32, 12, 12, 12, 12, 12, 42, 42, 12, 12, 12, 42, 12, 12, 12, 12, 12, 3, 12, 12, 12, 12, 42, 42, 42, 12, 42, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 5, 12, 12, 12, 12, 12, 12, 12, 0, 43, 43, 43, 96, 43, 104, 43, 31, 125, 31, 125, 138, 87, 125, 149, 138, 125, 87, 87])  # fmt: skip
-        torch.testing.assert_close(inputs["class_labels"][0], torch.tensor(expected_class_labels))
-        expected_class_labels = torch.tensor([19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 67, 82, 19, 19, 17, 19, 19, 19, 19, 19, 19, 19, 19, 19, 12, 12, 42, 12, 12, 12, 12, 3, 14, 12, 12, 12, 12, 12, 12, 12, 12, 14, 5, 12, 12, 0, 115, 43, 43, 115, 43, 43, 43, 8, 8, 8, 138, 138, 125, 143])  # fmt: skip
-        torch.testing.assert_close(inputs["class_labels"][1], expected_class_labels)
-
-        # verify the mask labels
-        self.assertEqual(len(inputs["mask_labels"]), 2)
-        self.assertEqual(inputs["mask_labels"][0].shape, (79, 512, 711))
-        self.assertEqual(inputs["mask_labels"][1].shape, (61, 512, 711))
-        self.assertEqual(inputs["mask_labels"][0].sum().item(), 315193.0)
-        self.assertEqual(inputs["mask_labels"][1].sum().item(), 350747.0)
+            # verify the pixel values and pixel mask
+            self.assertEqual(inputs["pixel_values"].shape, (2, 3, 512, 711))
+            self.assertEqual(inputs["pixel_mask"].shape, (2, 512, 711))
+
+            # verify the class labels
+            self.assertEqual(len(inputs["class_labels"]), 2)
+            expected_class_labels = torch.tensor([4, 17, 32, 42, 42, 42, 42, 42, 42, 42, 32, 12, 12, 12, 12, 12, 42, 42, 12, 12, 12, 42, 12, 12, 12, 12, 12, 3, 12, 12, 12, 12, 42, 42, 42, 12, 42, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 5, 12, 12, 12, 12, 12, 12, 12, 0, 43, 43, 43, 96, 43, 104, 43, 31, 125, 31, 125, 138, 87, 125, 149, 138, 125, 87, 87])  # fmt: skip
+            torch.testing.assert_close(inputs["class_labels"][0], torch.tensor(expected_class_labels))
+            expected_class_labels = torch.tensor([19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 67, 82, 19, 19, 17, 19, 19, 19, 19, 19, 19, 19, 19, 19, 12, 12, 42, 12, 12, 12, 12, 3, 14, 12, 12, 12, 12, 12, 12, 12, 12, 14, 5, 12, 12, 0, 115, 43, 43, 115, 43, 43, 43, 8, 8, 8, 138, 138, 125, 143])  # fmt: skip
+            torch.testing.assert_close(inputs["class_labels"][1], expected_class_labels)
+
+            # verify the mask labels
+            self.assertEqual(len(inputs["mask_labels"]), 2)
+            self.assertEqual(inputs["mask_labels"][0].shape, (79, 512, 711))
+            self.assertEqual(inputs["mask_labels"][1].shape, (61, 512, 711))
+            self.assertEqual(inputs["mask_labels"][0].sum().item(), 315193.0)
+            self.assertEqual(inputs["mask_labels"][1].sum().item(), 350747.0)
 
     def test_binary_mask_to_rle(self):
         fake_binary_mask = np.zeros((20, 50))
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

# Create cache directories if they don't exist
mkdir -p /tmp/transformers_cache /tmp/hf_home
chmod -R 777 /tmp/transformers_cache /tmp/hf_home

# Run the target test files
echo "=== Running Target Tests ==="
python -m pytest -xvs tests/models/mask2former/test_image_processing_mask2former.py tests/models/maskformer/test_image_processing_maskformer.py

# Capture exit code
rc=$?

# Echo exit code for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: reset test files to original state
git checkout f028e9340cca466a64592dbea542d3bdd2c89d5e "tests/models/mask2former/test_image_processing_mask2former.py" "tests/models/maskformer/test_image_processing_maskformer.py"