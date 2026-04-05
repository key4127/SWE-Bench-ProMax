#!/bin/bash
set -uxo pipefail

# Activate the Python virtual environment
source /opt/testbed_env/bin/activate

# Navigate to testbed
cd /testbed

# Checkout the target test files to ensure clean state
git checkout ca0650e88c34c11619a43c9d084c99c359c2e7a5 "benchmark/pymupdf_test.py" "benchmark/tesseract_test.py" "tests/conftest.py" "tests/test_layout.py" "tests/test_ocr_errors.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/benchmark/pymupdf_test.py b/benchmark/pymupdf_test.py
deleted file mode 100644
--- a/benchmark/pymupdf_test.py
+++ /dev/null
@@ -1,39 +0,0 @@
-import argparse
-import os
-
-from surya.benchmark.bbox import get_pdf_lines
-from surya.postprocessing.heatmap import draw_bboxes_on_image
-
-from surya.input.processing import open_pdf, get_page_images
-from surya.settings import settings
-
-
-def main():
-    parser = argparse.ArgumentParser(description="Draw pymupdf line bboxes on images.")
-    parser.add_argument("pdf_path", type=str, help="Path to PDF to detect bboxes in.")
-    parser.add_argument("--results_dir", type=str, help="Path to JSON file with OCR results.", default=os.path.join(settings.RESULT_DIR, "pymupdf"))
-    args = parser.parse_args()
-
-    doc = open_pdf(args.pdf_path)
-    page_count = len(doc)
-    page_indices = list(range(page_count))
-
-    images = get_page_images(doc, page_indices)
-    doc.close()
-
-    image_sizes = [img.size for img in images]
-    pdf_lines = get_pdf_lines(args.pdf_path, image_sizes)
-
-    folder_name = os.path.basename(args.pdf_path).split(".")[0]
-    result_path = os.path.join(args.results_dir, folder_name)
-    os.makedirs(result_path, exist_ok=True)
-
-    for idx, (img, bboxes) in enumerate(zip(images, pdf_lines)):
-        bbox_image = draw_bboxes_on_image(bboxes, img)
-        bbox_image.save(os.path.join(result_path, f"{idx}_bbox.png"))
-
-    print(f"Wrote results to {result_path}")
-
-if __name__ == "__main__":
-    main()
-
diff --git a/benchmark/tesseract_test.py b/benchmark/tesseract_test.py
deleted file mode 100644
--- a/benchmark/tesseract_test.py
+++ /dev/null
@@ -1,38 +0,0 @@
-import argparse
-import os
-
-from surya.benchmark.tesseract import tesseract_bboxes
-from surya.postprocessing.heatmap import draw_bboxes_on_image
-
-from surya.input.processing import open_pdf, get_page_images
-from surya.settings import settings
-
-
-def main():
-    parser = argparse.ArgumentParser(description="Draw tesseract bboxes on imagese.")
-    parser.add_argument("pdf_path", type=str, help="Path to PDF to detect bboxes in.")
-    parser.add_argument("--results_dir", type=str, help="Path to JSON file with OCR results.", default=os.path.join(settings.RESULT_DIR, "tesseract"))
-    args = parser.parse_args()
-
-    doc = open_pdf(args.pdf_path)
-    page_count = len(doc)
-    page_indices = list(range(page_count))
-
-    images = get_page_images(doc, page_indices)
-    doc.close()
-
-    img_boxes = [tesseract_bboxes(img) for img in images]
-
-    folder_name = os.path.basename(args.pdf_path).split(".")[0]
-    result_path = os.path.join(args.results_dir, folder_name)
-    os.makedirs(result_path, exist_ok=True)
-
-    for idx, (img, bboxes) in enumerate(zip(images, img_boxes)):
-        bbox_image = draw_bboxes_on_image(bboxes, img)
-        bbox_image.save(os.path.join(result_path, f"{idx}_bbox.png"))
-
-    print(f"Wrote results to {result_path}")
-
-if __name__ == "__main__":
-    main()
-
diff --git a/tests/conftest.py b/tests/conftest.py
--- a/tests/conftest.py
+++ b/tests/conftest.py
@@ -1,22 +1,53 @@
+import os
+os.environ["PYTORCH_ENABLE_MPS_FALLBACK"] = "1"
+
 import pytest
-from surya.model.ocr_error.model import load_model as load_ocr_error_model, load_tokenizer as load_ocr_error_processor
-from surya.model.layout.model import load_model as load_layout_model
-from surya.model.layout.processor import load_processor as load_layout_processor
+from PIL import Image, ImageDraw
+
+from surya.detection import DetectionPredictor
+from surya.ocr_error import OCRErrorPredictor
+from surya.layout import LayoutPredictor
+from surya.recognition import RecognitionPredictor
+from surya.table_rec import TableRecPredictor
+
+
+@pytest.fixture(scope="session")
+def ocr_error_predictor() -> OCRErrorPredictor:
+    ocr_error_predictor = OCRErrorPredictor()
+    yield ocr_error_predictor
+    del ocr_error_predictor
+
 
 @pytest.fixture(scope="session")
-def ocr_error_model():
-    ocr_error_m = load_ocr_error_model()
-    ocr_error_p = load_ocr_error_processor()
-    ocr_error_m.processor = ocr_error_p
-    yield ocr_error_m
-    del ocr_error_m
+def layout_predictor() -> LayoutPredictor:
+    layout_predictor = LayoutPredictor()
+    yield layout_predictor
+    del layout_predictor
 
+@pytest.fixture(scope="session")
+def detection_predictor() -> DetectionPredictor:
+    detection_predictor = DetectionPredictor()
+    yield detection_predictor
+    del detection_predictor
 
 @pytest.fixture(scope="session")
-def layout_model():
-    layout_m = load_layout_model()
-    layout_p = load_layout_processor()
-    layout_m.processor = layout_p
-    yield layout_m
-    del layout_m
+def recognition_predictor() -> RecognitionPredictor:
+    recognition_predictor = RecognitionPredictor()
+    yield recognition_predictor
+    del recognition_predictor
+
+@pytest.fixture(scope="session")
+def table_rec_predictor() -> TableRecPredictor:
+    table_rec_predictor = TableRecPredictor()
+    yield table_rec_predictor
+    del table_rec_predictor
+
+@pytest.fixture()
+def test_image():
+    image = Image.new("RGB", (1024, 1024), "white")
+    draw = ImageDraw.Draw(image)
+    draw.text((10, 10), "Hello World", fill="black", font_size=72)
+    draw.text((10, 200), "This is a sentence of text.\nNow it is a paragraph.\nA three-line one.", fill="black",
+              font_size=24)
+    return image
 
diff --git a/tests/test_detection.py b/tests/test_detection.py
new file mode 100644
--- /dev/null
+++ b/tests/test_detection.py
@@ -0,0 +1,8 @@
+def test_detection(detection_predictor, test_image):
+    detection_results = detection_predictor([test_image])
+
+    assert len(detection_results) == 1
+    assert detection_results[0].image_bbox == [0, 0, 1024, 1024]
+
+    bboxes = detection_results[0].bboxes
+    assert len(bboxes) == 4
\ No newline at end of file
diff --git a/tests/test_layout.py b/tests/test_layout.py
--- a/tests/test_layout.py
+++ b/tests/test_layout.py
@@ -1,17 +1,5 @@
-import os
-os.environ["PYTORCH_ENABLE_MPS_FALLBACK"] = "1"
-
-from surya.layout import batch_layout_detection
-from PIL import Image, ImageDraw
-
-def test_layout_topk(layout_model):
-    image = Image.new("RGB", (1024, 1024), "white")
-    draw = ImageDraw.Draw(image)
-    draw.text((10, 10), "Hello World", fill="black", font_size=72)
-    draw.text((10, 200), "This is a sentence of text.\nNow it is a paragraph.\nA three-line one.", fill="black",
-              font_size=24)
-
-    layout_results = batch_layout_detection([image], layout_model, layout_model.processor)
+def test_layout_topk(layout_predictor, test_image):
+    layout_results = layout_predictor([test_image])
 
     assert len(layout_results) == 1
     assert layout_results[0].image_bbox == [0, 0, 1024, 1024]
diff --git a/tests/test_ocr_errors.py b/tests/test_ocr_errors.py
--- a/tests/test_ocr_errors.py
+++ b/tests/test_ocr_errors.py
@@ -1,18 +1,15 @@
-from surya.ocr_error import batch_ocr_error_detection
-
-
-def test_garbled_text(ocr_error_model):
+def test_garbled_text(ocr_error_predictor):
     text = """"
     ; dh vksj ls mifLFkr vf/koDrk % Jh vfuy dqekj
     2. vfHk;qDr dh vksj ls mifLFkr vf/koDrk % Jh iznhi d
     """.strip()
-    results = batch_ocr_error_detection([text], ocr_error_model, ocr_error_model.processor)
+    results = ocr_error_predictor([text])
     assert results.labels[0] == "bad"
 
 
-def test_good_text(ocr_error_model):
+def test_good_text(ocr_error_predictor):
     text = """"
     There are professions more harmful than industrial design, but only a very few of them.
     """.strip()
-    results = batch_ocr_error_detection([text], ocr_error_model, ocr_error_model.processor)
+    results = ocr_error_predictor([text])
     assert results.labels[0] == "good"
\ No newline at end of file
diff --git a/tests/test_recognition.py b/tests/test_recognition.py
new file mode 100644
--- /dev/null
+++ b/tests/test_recognition.py
@@ -0,0 +1,9 @@
+def test_recognition(recognition_predictor, detection_predictor, test_image):
+    recognition_results = recognition_predictor([test_image], [None], detection_predictor)
+
+    assert len(recognition_results) == 1
+    assert recognition_results[0].image_bbox == [0, 0, 1024, 1024]
+
+    text_lines = recognition_results[0].text_lines
+    assert len(text_lines) == 4
+    assert text_lines[0].text == "Hello World"
\ No newline at end of file
diff --git a/tests/test_table_rec.py b/tests/test_table_rec.py
new file mode 100644
--- /dev/null
+++ b/tests/test_table_rec.py
@@ -0,0 +1,52 @@
+from PIL import Image, ImageDraw
+
+def test_table_rec(table_rec_predictor):
+    data = [
+        ["Name", "Age", "City"],
+        ["Alice", 25, "New York"],
+        ["Bob", 30, "Los Angeles"],
+        ["Charlie", 35, "Chicago"],
+    ]
+    test_image = draw_table(data)
+
+    results = table_rec_predictor([test_image])
+    assert len(results) == 1
+    assert results[0].image_bbox == [0, 0, test_image.size[0], test_image.size[1]]
+
+    cells = results[0].cells
+    assert len(cells) == 12
+    for row_id in range(4):
+        for col_id in range(3):
+            cell = [c for c in cells if c.row_id == row_id and c.col_id == col_id]
+            assert len(cell) == 1, f"Missing cell at row {row_id}, col {col_id}"
+
+def draw_table(data, cell_width=100, cell_height=40):
+    rows = len(data)
+    cols = len(data[0])
+    width = cols * cell_width
+    height = rows * cell_height
+
+    image = Image.new('RGB', (width, height), 'white')
+    draw = ImageDraw.Draw(image)
+
+    for i in range(rows + 1):
+        y = i * cell_height
+        draw.line([(0, y), (width, y)], fill='black', width=1)
+
+    for i in range(cols + 1):
+        x = i * cell_width
+        draw.line([(x, 0), (x, height)], fill='black', width=1)
+
+    for i in range(rows):
+        for j in range(cols):
+            text = str(data[i][j])
+            text_bbox = draw.textbbox((0, 0), text)
+            text_width = text_bbox[2] - text_bbox[0]
+            text_height = text_bbox[3] - text_bbox[1]
+
+            x = j * cell_width + (cell_width - text_width) // 2
+            y = i * cell_height + (cell_height - text_height) // 2
+
+            draw.text((x, y), text, fill='black')
+
+    return image
\ No newline at end of file
EOF_114329324912

# Run the target pytest tests (not benchmark scripts as they require PDF inputs)
# Using -v for verbose output, single process for stability
pytest tests/test_layout.py tests/test_ocr_errors.py -v --tb=short

# Capture exit code
rc=$?

# Echo exit code for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: reset the test files to original state
git checkout ca0650e88c34c11619a43c9d084c99c359c2e7a5 "benchmark/pymupdf_test.py" "benchmark/tesseract_test.py" "tests/conftest.py" "tests/test_layout.py" "tests/test_ocr_errors.py"