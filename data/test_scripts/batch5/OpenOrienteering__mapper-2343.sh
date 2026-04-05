#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target test file to ensure clean state
git checkout de663f973488615a03ce9e1d960d77a8b8ec6812 "test/CMakeLists.txt"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/test/CMakeLists.txt b/test/CMakeLists.txt
--- a/test/CMakeLists.txt
+++ b/test/CMakeLists.txt
@@ -194,6 +194,7 @@ add_system_test(file_format_t)
 add_system_test(duplicate_equals_t)
 add_system_test(map_t)
 add_system_test(map_printer_t)
+add_system_test(object_t)
 add_system_test(object_query_t)
 add_system_test(path_object_t)
 add_system_test(style_t)
diff --git a/test/object_t.cpp b/test/object_t.cpp
new file mode 100644
--- /dev/null
+++ b/test/object_t.cpp
@@ -0,0 +1,159 @@
+/*
+ *    Copyright 2025 Matthias Kühlewein
+ *
+ *    This file is part of OpenOrienteering.
+ *
+ *    OpenOrienteering is free software: you can redistribute it and/or modify
+ *    it under the terms of the GNU General Public License as published by
+ *    the Free Software Foundation, either version 3 of the License, or
+ *    (at your option) any later version.
+ *
+ *    OpenOrienteering is distributed in the hope that it will be useful,
+ *    but WITHOUT ANY WARRANTY; without even the implied warranty of
+ *    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
+ *    GNU General Public License for more details.
+ *
+ *    You should have received a copy of the GNU General Public License
+ *    along with OpenOrienteering.  If not, see <http://www.gnu.org/licenses/>.
+ */
+
+#include <QtTest>
+#include <QObject>
+
+#include "core/map.h"
+#include "core/map_coord.h"
+#include "core/objects/object.h"
+#include "core/symbols/area_symbol.h"
+#include "core/symbols/line_symbol.h"
+#include "core/symbols/symbol.h"
+
+
+using namespace OpenOrienteering;
+
+Q_DECLARE_METATYPE(MapCoordVector)
+
+/**
+ * @test Tests object functions.
+ */
+class ObjectTest : public QObject
+{
+	Q_OBJECT
+	
+private slots:
+	void ObjectLengthTest_data()
+	{
+		QTest::addColumn<int>("map_scale");
+		QTest::addColumn<MapCoordVector>("coords");
+		QTest::addColumn<float>("paper_length");
+		QTest::addColumn<float>("paper_area");
+		
+		auto coords = MapCoordVector{
+		    MapCoord{0.0, 0.0}, MapCoord{0.0, 5.0}, MapCoord{10.0, 5.0}, MapCoord{10.0, 0.0}, MapCoord{0.0, 0.0, MapCoord::ClosePoint}
+		};
+		
+		QTest::newRow("Line object 1 at 1:10000") << 10000 << coords << 30.0f << 50.0f;
+		QTest::newRow("Line object 1 at 1:15000") << 15000 << coords << 30.0f << 50.0f;
+	}
+	
+	void ObjectLengthTest()
+	{
+		QFETCH(int, map_scale);
+		QFETCH(MapCoordVector, coords);
+		QFETCH(float, paper_length);
+		QFETCH(float, paper_area);
+		
+		Map map;
+		map.setScaleDenominator(map_scale);
+		
+		PathObject obj;
+		QCOMPARE(obj.getPaperLength(), 0.0f);
+		QCOMPARE(obj.calculatePaperArea(), 0.0f);
+		QVERIFY(obj.isAreaTooSmall() == false);
+		QVERIFY(obj.isLineTooShort() == false);
+		
+		auto line_symbol = new LineSymbol();
+		map.addSymbol(line_symbol, 0);
+		PathObject rectangle{line_symbol, coords, &map};
+		rectangle.updatePathCoords();
+		
+		QCOMPARE(rectangle.getPaperLength(), paper_length);
+		QCOMPARE(rectangle.getRealLength(), paper_length*map_scale/1000.0f);
+		
+		line_symbol->setMinimumLength(paper_length*1000 - 1);
+		QVERIFY(rectangle.isLineTooShort() == false);
+		
+		line_symbol->setMinimumLength(paper_length*1000 + 1);
+		QVERIFY(rectangle.isLineTooShort() == true);
+		
+		QCOMPARE(rectangle.calculatePaperArea(), paper_area);
+		QCOMPARE(rectangle.calcuateRealArea(), paper_area*(map_scale/1000.0f)*(map_scale/1000.0f));
+	}
+	
+	
+	void ObjectAreaTest_data()
+	{
+		QTest::addColumn<int>("map_scale");
+		QTest::addColumn<MapCoordVector>("coords");
+		QTest::addColumn<float>("paper_length");
+		QTest::addColumn<float>("paper_area");
+		
+		auto coords1 = MapCoordVector{
+		    MapCoord{0.0, 0.0}, MapCoord{0.0, 5.0}, MapCoord{10.0, 5.0}, MapCoord{10.0, 0.0}, MapCoord{0.0, 0.0, MapCoord::ClosePoint}
+		};
+		
+		QTest::newRow("Area object 1 at 1:10000") << 10000 << coords1 << 30.0f << 50.0f;
+		QTest::newRow("Area object 1 at 1:15000") << 15000 << coords1 << 30.0f << 50.0f;
+		
+		auto coords2 = MapCoordVector{
+		    MapCoord{0.0, 0.0}, MapCoord{0.0, 5.0}, MapCoord{10.0, 5.0}, MapCoord{10.0, 0.0}, MapCoord{0.0, 0.0, MapCoord::ClosePoint|MapCoord::HolePoint},
+		    MapCoord{5.0, 2.0}, MapCoord{5.0, 4.0}, MapCoord{8.0, 4.0}, MapCoord{8.0, 2.0}, MapCoord{5.0, 2.0, MapCoord::ClosePoint}
+		};
+		
+		QTest::newRow("Area object 2 at 1:10000") << 10000 << coords2 << 30.0f << 44.0f;
+	}
+	
+	void ObjectAreaTest()
+	{
+		QFETCH(int, map_scale);
+		QFETCH(MapCoordVector, coords);
+		QFETCH(float, paper_length);
+		QFETCH(float, paper_area);
+		
+		Map map;
+		map.setScaleDenominator(map_scale);
+		
+		PathObject obj;
+		QCOMPARE(obj.getPaperLength(), 0.0f);
+		QCOMPARE(obj.calculatePaperArea(), 0.0f);
+		QVERIFY(obj.isAreaTooSmall() == false);
+		QVERIFY(obj.isLineTooShort() == false);
+		
+		auto area_symbol = new AreaSymbol();
+		map.addSymbol(area_symbol, 0);
+		PathObject rectangle_area{area_symbol, coords, &map};
+		rectangle_area.updatePathCoords();
+		
+		QCOMPARE(rectangle_area.getPaperLength(), paper_length);
+		QCOMPARE(rectangle_area.getRealLength(), paper_length*map_scale/1000.0f);
+		
+		QCOMPARE(rectangle_area.calculatePaperArea(), paper_area);
+		QCOMPARE(rectangle_area.calcuateRealArea(), paper_area*(map_scale/1000.0f)*(map_scale/1000.0f));
+		
+		area_symbol->setMinimumArea(paper_area*1000 - 1);
+		QVERIFY(rectangle_area.isAreaTooSmall() == false);
+		
+		area_symbol->setMinimumArea(paper_area*1000 + 1);
+		QVERIFY(rectangle_area.isAreaTooSmall() == true);
+	}
+	
+};  // class ObjectTest
+
+/*
+ * We don't need a real GUI window.
+ */
+namespace {
+	auto Q_DECL_UNUSED qpa_selected = qputenv("QT_QPA_PLATFORM", "minimal");  // clazy:exclude=non-pod-global-static
+}
+
+QTEST_MAIN(ObjectTest)
+#include "object_t.moc"  // IWYU pragma: keep
EOF_114329324912

# Reconfigure CMake to pick up any changes in test/CMakeLists.txt
cd /testbed
cmake -S . -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DBUILD_SHARED_LIBS=0 \
    -DMapper_AUTORUN_SYSTEM_TESTS=0 \
    -DMapper_USE_GDAL=ON \
    -DMapper_BUILD_CLIPPER=auto \
    -DMapper_CI_ENABLE_CODECHECKS=0 \
    -DCMAKE_CXX_STANDARD=14

# Rebuild the project to incorporate test changes
cmake --build build -j4

# Navigate to build directory and run tests
cd /testbed/build

# Run only the object_t test (the one modified by the patch)
# Using -R to filter tests by regex pattern, -j1 to avoid parallel execution issues
ctest --output-on-failure -R 'object_t' -j1
rc=$?

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test file
cd /testbed
git checkout de663f973488615a03ce9e1d960d77a8b8ec6812 "test/CMakeLists.txt"