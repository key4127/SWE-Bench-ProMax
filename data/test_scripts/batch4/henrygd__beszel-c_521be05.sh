#!/bin/bash
set -uxo pipefail

# Navigate to testbed root
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 6b766b2653114836009ba174768333535c68f442 "beszel/internal/agent/gpu_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/beszel/internal/agent/gpu_test.go b/beszel/internal/agent/gpu_test.go
--- a/beszel/internal/agent/gpu_test.go
+++ b/beszel/internal/agent/gpu_test.go
@@ -1,3 +1,6 @@
+//go:build testing
+// +build testing
+
 package agent
 
 import (
@@ -43,6 +46,52 @@ func TestParseNvidiaData(t *testing.T) {
 			},
 			wantValid: true,
 		},
+		{
+			name: "more valid multi-gpu data",
+			input: `0, NVIDIA A10, 45, 19676, 23028, 0, 58.98
+1, NVIDIA A10, 45, 19638, 23028, 0, 62.35
+2, NVIDIA A10, 44, 21700, 23028, 0, 59.57
+3, NVIDIA A10, 45, 18222, 23028, 0, 61.76`,
+			wantData: map[string]system.GPUData{
+				"0": {
+					Name:        "A10",
+					Temperature: 45.0,
+					MemoryUsed:  19676.0 / 1.024,
+					MemoryTotal: 23028.0 / 1.024,
+					Usage:       0.0,
+					Power:       58.98,
+					Count:       1,
+				},
+				"1": {
+					Name:        "A10",
+					Temperature: 45.0,
+					MemoryUsed:  19638.0 / 1.024,
+					MemoryTotal: 23028.0 / 1.024,
+					Usage:       0.0,
+					Power:       62.35,
+					Count:       1,
+				},
+				"2": {
+					Name:        "A10",
+					Temperature: 44.0,
+					MemoryUsed:  21700.0 / 1.024,
+					MemoryTotal: 23028.0 / 1.024,
+					Usage:       0.0,
+					Power:       59.57,
+					Count:       1,
+				},
+				"3": {
+					Name:        "A10",
+					Temperature: 45.0,
+					MemoryUsed:  18222.0 / 1.024,
+					MemoryTotal: 23028.0 / 1.024,
+					Usage:       0.0,
+					Power:       61.76,
+					Count:       1,
+				},
+			},
+			wantValid: true,
+		},
 		{
 			name:      "empty input",
 			input:     "",
@@ -207,7 +256,7 @@ func TestParseJetsonData(t *testing.T) {
 	}{
 		{
 			name:  "valid data",
-			input: "RAM 4300/30698MB GR3D_FREQ 45% tj@52.468C VDD_GPU_SOC 2171mW",
+			input: "11-14-2024 22:54:33 RAM 4300/30698MB GR3D_FREQ 45% tj@52.468C VDD_GPU_SOC 2171mW",
 			wantMetrics: &system.GPUData{
 				Name:        "Jetson",
 				MemoryUsed:  4300.0,
@@ -218,9 +267,22 @@ func TestParseJetsonData(t *testing.T) {
 				Count:       1,
 			},
 		},
+		{
+			name:  "more valid data",
+			input: "11-15-2024 08:38:09 RAM 6185/7620MB (lfb 8x2MB) SWAP 851/3810MB (cached 1MB) CPU [15%@729,11%@729,14%@729,13%@729,11%@729,8%@729] EMC_FREQ 43%@2133 GR3D_FREQ 63%@[621] NVDEC off NVJPG off NVJPG1 off VIC off OFA off APE 200 cpu@53.968C soc2@52.437C soc0@50.75C gpu@53.343C tj@53.968C soc1@51.656C VDD_IN 12479mW/12479mW VDD_CPU_GPU_CV 4667mW/4667mW VDD_SOC 2817mW/2817mW",
+			wantMetrics: &system.GPUData{
+				Name:        "Jetson",
+				MemoryUsed:  6185.0,
+				MemoryTotal: 7620.0,
+				Usage:       63.0,
+				Temperature: 53.968,
+				Power:       4.667,
+				Count:       1,
+			},
+		},
 		{
 			name:  "missing temperature",
-			input: "RAM 4300/30698MB GR3D_FREQ 45% VDD_GPU_SOC 2171mW",
+			input: "11-14-2024 22:54:33 RAM 4300/30698MB GR3D_FREQ 45% VDD_GPU_SOC 2171mW",
 			wantMetrics: &system.GPUData{
 				Name:        "Jetson",
 				MemoryUsed:  4300.0,
@@ -232,7 +294,7 @@ func TestParseJetsonData(t *testing.T) {
 		},
 		{
 			name:  "no gpu defined by nvidia-smi",
-			input: "RAM 4300/30698MB GR3D_FREQ 45% VDD_GPU_SOC 2171mW",
+			input: "11-14-2024 22:54:33 RAM 4300/30698MB GR3D_FREQ 45% VDD_GPU_SOC 2171mW",
 			gm: &GPUManager{
 				GpuDataMap: map[string]*system.GPUData{},
 			},
@@ -486,7 +548,7 @@ echo '{"card0": {"Temperature (Sensor edge) (C)": "49.0", "Current Socket Graphi
 			setup: func(t *testing.T) error {
 				path := filepath.Join(dir, "tegrastats")
 				script := `#!/bin/sh
-echo "RAM 1024/4096MB GR3D_FREQ 80% tj@70C VDD_GPU_SOC 1000mW"`
+echo "11-14-2024 22:54:33 RAM 1024/4096MB GR3D_FREQ 80% tj@70C VDD_GPU_SOC 1000mW"`
 				if err := os.WriteFile(path, []byte(script), 0755); err != nil {
 					return err
 				}
@@ -523,3 +585,158 @@ echo "RAM 1024/4096MB GR3D_FREQ 80% tj@70C VDD_GPU_SOC 1000mW"`
 		})
 	}
 }
+
+// TestAccumulationTableDriven tests the accumulation behavior for all three GPU types
+func TestAccumulation(t *testing.T) {
+	type expectedGPUValues struct {
+		temperature float64
+		memoryUsed  float64
+		memoryTotal float64
+		usage       float64
+		power       float64
+		count       float64
+		avgUsage    float64
+		avgPower    float64
+	}
+
+	tests := []struct {
+		name           string
+		initialGPUData map[string]*system.GPUData
+		dataSamples    [][]byte
+		parser         func(*GPUManager) func([]byte) bool
+		expectedValues map[string]expectedGPUValues
+	}{
+		{
+			name: "Jetson GPU accumulation",
+			initialGPUData: map[string]*system.GPUData{
+				"0": {
+					Name:        "Jetson",
+					Temperature: 0,
+					Usage:       0,
+					Power:       0,
+					Count:       0,
+				},
+			},
+			dataSamples: [][]byte{
+				[]byte("11-14-2024 22:54:33 RAM 1024/4096MB GR3D_FREQ 30% tj@50.5C VDD_GPU_SOC 1000mW"),
+				[]byte("11-14-2024 22:54:33 RAM 1024/4096MB GR3D_FREQ 40% tj@60.5C VDD_GPU_SOC 1200mW"),
+				[]byte("11-14-2024 22:54:33 RAM 1024/4096MB GR3D_FREQ 50% tj@70.5C VDD_GPU_SOC 1400mW"),
+			},
+			parser: func(gm *GPUManager) func([]byte) bool {
+				return gm.getJetsonParser()
+			},
+			expectedValues: map[string]expectedGPUValues{
+				"0": {
+					temperature: 70.5,  // Last value
+					memoryUsed:  1024,  // Last value
+					memoryTotal: 4096,  // Last value
+					usage:       120.0, // Accumulated: 30 + 40 + 50
+					power:       3.6,   // Accumulated: 1.0 + 1.2 + 1.4
+					count:       3,
+					avgUsage:    40.0, // 120 / 3
+					avgPower:    1.2,  // 3.6 / 3
+				},
+			},
+		},
+		{
+			name:           "NVIDIA GPU accumulation",
+			initialGPUData: map[string]*system.GPUData{
+				// NVIDIA parser will create the GPU data entries
+			},
+			dataSamples: [][]byte{
+				[]byte("0, NVIDIA GeForce RTX 3080, 50, 5000, 10000, 30, 200"),
+				[]byte("0, NVIDIA GeForce RTX 3080, 60, 6000, 10000, 40, 250"),
+				[]byte("0, NVIDIA GeForce RTX 3080, 70, 7000, 10000, 50, 300"),
+			},
+			parser: func(gm *GPUManager) func([]byte) bool {
+				return gm.parseNvidiaData
+			},
+			expectedValues: map[string]expectedGPUValues{
+				"0": {
+					temperature: 70.0,            // Last value
+					memoryUsed:  7000.0 / 1.024,  // Last value
+					memoryTotal: 10000.0 / 1.024, // Last value
+					usage:       120.0,           // Accumulated: 30 + 40 + 50
+					power:       750.0,           // Accumulated: 200 + 250 + 300
+					count:       3,
+					avgUsage:    40.0,  // 120 / 3
+					avgPower:    250.0, // 750 / 3
+				},
+			},
+		},
+		{
+			name:           "AMD GPU accumulation",
+			initialGPUData: map[string]*system.GPUData{
+				// AMD parser will create the GPU data entries
+			},
+			dataSamples: [][]byte{
+				[]byte(`{"card0": {"GUID": "34756", "Temperature (Sensor edge) (C)": "50.0", "Current Socket Graphics Package Power (W)": "100.0", "GPU use (%)": "30", "VRAM Total Memory (B)": "10737418240", "VRAM Total Used Memory (B)": "1073741824", "Card Series": "Radeon RX 6800"}}`),
+				[]byte(`{"card0": {"GUID": "34756", "Temperature (Sensor edge) (C)": "60.0", "Current Socket Graphics Package Power (W)": "150.0", "GPU use (%)": "40", "VRAM Total Memory (B)": "10737418240", "VRAM Total Used Memory (B)": "2147483648", "Card Series": "Radeon RX 6800"}}`),
+				[]byte(`{"card0": {"GUID": "34756", "Temperature (Sensor edge) (C)": "70.0", "Current Socket Graphics Package Power (W)": "200.0", "GPU use (%)": "50", "VRAM Total Memory (B)": "10737418240", "VRAM Total Used Memory (B)": "3221225472", "Card Series": "Radeon RX 6800"}}`),
+			},
+			parser: func(gm *GPUManager) func([]byte) bool {
+				return gm.parseAmdData
+			},
+			expectedValues: map[string]expectedGPUValues{
+				"34756": {
+					temperature: 70.0,                          // Last value
+					memoryUsed:  3221225472.0 / (1024 * 1024),  // Last value
+					memoryTotal: 10737418240.0 / (1024 * 1024), // Last value
+					usage:       120.0,                         // Accumulated: 30 + 40 + 50
+					power:       450.0,                         // Accumulated: 100 + 150 + 200
+					count:       3,
+					avgUsage:    40.0,  // 120 / 3
+					avgPower:    150.0, // 450 / 3
+				},
+			},
+		},
+	}
+
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			// Create a new GPUManager for each test
+			gm := &GPUManager{
+				GpuDataMap: tt.initialGPUData,
+			}
+
+			// Get the parser function
+			parser := tt.parser(gm)
+
+			// Process each data sample
+			for i, sample := range tt.dataSamples {
+				valid := parser(sample)
+				assert.True(t, valid, "Sample %d should be valid", i)
+			}
+
+			// Check accumulated values
+			for id, expected := range tt.expectedValues {
+				gpu, exists := gm.GpuDataMap[id]
+				assert.True(t, exists, "GPU with ID %s should exist", id)
+				if !exists {
+					continue
+				}
+
+				assert.InDelta(t, expected.temperature, gpu.Temperature, 0.01, "Temperature should match")
+				assert.InDelta(t, expected.memoryUsed, gpu.MemoryUsed, 0.01, "Memory used should match")
+				assert.InDelta(t, expected.memoryTotal, gpu.MemoryTotal, 0.01, "Memory total should match")
+				assert.InDelta(t, expected.usage, gpu.Usage, 0.01, "Usage should match")
+				assert.InDelta(t, expected.power, gpu.Power, 0.01, "Power should match")
+				assert.Equal(t, expected.count, gpu.Count, "Count should match")
+			}
+
+			// Verify average calculation in GetCurrentData
+			result := gm.GetCurrentData()
+			for id, expected := range tt.expectedValues {
+				gpu, exists := result[id]
+				assert.True(t, exists, "GPU with ID %s should exist in GetCurrentData result", id)
+				if !exists {
+					continue
+				}
+
+				assert.InDelta(t, expected.temperature, gpu.Temperature, 0.01, "Temperature in GetCurrentData should match")
+				assert.InDelta(t, expected.avgUsage, gpu.Usage, 0.01, "Average usage in GetCurrentData should match")
+				assert.InDelta(t, expected.avgPower, gpu.Power, 0.01, "Average power in GetCurrentData should match")
+			}
+		})
+	}
+}
EOF_114329324912

# Navigate to the Go module root
cd /testbed/beszel

# Set required environment variables
export GOEXPERIMENT=synctest
export CGO_ENABLED=0

# Run the target test file with verbose output
# Using -v flag for verbose output to help with debugging
# Using -tags=testing as specified in the collected information
go test -v -tags=testing ./internal/agent/
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test file
cd /testbed
git checkout 6b766b2653114836009ba174768333535c68f442 "beszel/internal/agent/gpu_test.go"