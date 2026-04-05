#!/bin/bash
set -uxo pipefail

cd /testbed

# Checkout the target test files to ensure clean state
git checkout 60132ab0cf04c01b7e9e445f15bf2f9e7487be48 "nomad/leader_test.go" "nomad/state/paginator/filter_test.go" "nomad/state/paginator/paginator_test.go" "nomad/state/paginator/tokenizer_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/nomad/leader_test.go b/nomad/leader_test.go
--- a/nomad/leader_test.go
+++ b/nomad/leader_test.go
@@ -1033,17 +1033,18 @@ func TestLeader_DiffACLTokens(t *testing.T) {
 	assert.Nil(t, state.UpsertACLTokens(structs.MsgTypeTestSetup, 100, []*structs.ACLToken{p0, p1, p2, p3}))
 
 	// Simulate a remote list
-	p2Stub := p2.Stub()
+	p2Stub, _ := p2.Stub()
 	p2Stub.ModifyIndex = 50 // Ignored, same index
-	p3Stub := p3.Stub()
+	p3Stub, _ := p3.Stub()
 	p3Stub.ModifyIndex = 100 // Updated, higher index
 	p3Stub.Hash = []byte{0, 1, 2, 3}
 	p4 := mock.ACLToken()
 	p4.Global = true
+	p4Stub, _ := p4.Stub()
 	remoteList := []*structs.ACLTokenListStub{
 		p2Stub,
 		p3Stub,
-		p4.Stub(),
+		p4Stub,
 	}
 	delete, update := diffACLTokens(state, 50, remoteList)
 
diff --git a/nomad/state/paginator/filter_test.go b/nomad/state/paginator/filter_test.go
--- a/nomad/state/paginator/filter_test.go
+++ b/nomad/state/paginator/filter_test.go
@@ -12,40 +12,33 @@ import (
 	"github.com/hashicorp/nomad/helper/uuid"
 	"github.com/hashicorp/nomad/nomad/state"
 	"github.com/hashicorp/nomad/nomad/structs"
-	"github.com/stretchr/testify/require"
+	"github.com/shoenig/test/must"
 )
 
 func TestGenericFilter(t *testing.T) {
 	ci.Parallel(t)
 	ids := []string{"0", "1", "2", "3", "4", "5", "6", "7", "8", "9"}
 
-	filters := []Filter{GenericFilter{
-		Allow: func(raw interface{}) (bool, error) {
-			result := raw.(*mockObject)
-			return result.id > "5", nil
-		},
-	}}
+	selector := func(obj *mockObject) bool {
+		return obj.id > "5"
+	}
+
 	iter := newTestIterator(ids)
-	tokenizer := testTokenizer{}
 	opts := structs.QueryOptions{
 		PerPage: 3,
 	}
 	results := []string{}
-	paginator, err := NewPaginator(iter, tokenizer, filters, opts,
-		func(raw interface{}) error {
-			result := raw.(*mockObject)
-			results = append(results, result.id)
-			return nil
-		},
-	)
-	require.NoError(t, err)
+	pager, err := NewPaginator(iter, opts, selector, IDTokenizer[*mockObject](""),
+		func(result *mockObject) (string, error) { return result.id, nil })
 
-	nextToken, err := paginator.Page()
-	require.NoError(t, err)
+	must.NoError(t, err)
+
+	results, nextToken, err := pager.Page()
+	must.NoError(t, err)
 
 	expected := []string{"6", "7", "8"}
-	require.Equal(t, "9", nextToken)
-	require.Equal(t, expected, results)
+	must.Eq(t, "9", nextToken)
+	must.Eq(t, expected, results)
 }
 
 func TestNamespaceFilter(t *testing.T) {
@@ -81,29 +74,21 @@ func TestNamespaceFilter(t *testing.T) {
 
 	for _, tc := range cases {
 		t.Run(tc.name, func(t *testing.T) {
-			filters := []Filter{NamespaceFilter{
-				AllowableNamespaces: tc.allowable,
-			}}
 			iter := newTestIteratorWithMocks(mocks)
-			tokenizer := testTokenizer{}
 			opts := structs.QueryOptions{
 				PerPage: int32(len(mocks)),
 			}
 
-			results := []string{}
-			paginator, err := NewPaginator(iter, tokenizer, filters, opts,
-				func(raw interface{}) error {
-					result := raw.(*mockObject)
-					results = append(results, result.namespace)
-					return nil
-				},
-			)
-			require.NoError(t, err)
-
-			nextToken, err := paginator.Page()
-			require.NoError(t, err)
-			require.Equal(t, "", nextToken)
-			require.Equal(t, tc.expected, results)
+			pager, err := NewPaginator(iter, opts,
+				NamespaceSelectorFunc[*mockObject](tc.allowable),
+				IDTokenizer[*mockObject](""),
+				func(result *mockObject) (string, error) { return result.namespace, nil })
+			must.NoError(t, err)
+
+			results, nextToken, err := pager.Page()
+			must.NoError(t, err)
+			must.Eq(t, "", nextToken)
+			must.Eq(t, tc.expected, results)
 		})
 	}
 }
@@ -174,14 +159,8 @@ func BenchmarkEvalListFilter(b *testing.B) {
 
 		for i := 0; i < b.N; i++ {
 			iter, _ := state.EvalsByNamespace(nil, structs.DefaultNamespace)
-			tokenizer := NewStructsTokenizer(iter, StructsTokenizerOptions{WithID: true})
-
-			var evals []*structs.Evaluation
-			paginator, err := NewPaginator(iter, tokenizer, nil, opts, func(raw interface{}) error {
-				eval := raw.(*structs.Evaluation)
-				evals = append(evals, eval)
-				return nil
-			})
+			paginator, err := NewPaginator(iter, opts, nil, IDTokenizer[*structs.Evaluation](""),
+				func(eval *structs.Evaluation) (*structs.Evaluation, error) { return eval, nil })
 			if err != nil {
 				b.Fatalf("failed: %v", err)
 			}
@@ -199,14 +178,8 @@ func BenchmarkEvalListFilter(b *testing.B) {
 
 		for i := 0; i < b.N; i++ {
 			iter, _ := state.Evals(nil, false)
-			tokenizer := NewStructsTokenizer(iter, StructsTokenizerOptions{WithID: true})
-
-			var evals []*structs.Evaluation
-			paginator, err := NewPaginator(iter, tokenizer, nil, opts, func(raw interface{}) error {
-				eval := raw.(*structs.Evaluation)
-				evals = append(evals, eval)
-				return nil
-			})
+			paginator, err := NewPaginator(iter, opts, nil, IDTokenizer[*structs.Evaluation](""),
+				func(eval *structs.Evaluation) (*structs.Evaluation, error) { return eval, nil })
 			if err != nil {
 				b.Fatalf("failed: %v", err)
 			}
@@ -237,14 +210,10 @@ func BenchmarkEvalListFilter(b *testing.B) {
 
 		for i := 0; i < b.N; i++ {
 			iter, _ := state.EvalsByNamespace(nil, structs.DefaultNamespace)
-			tokenizer := NewStructsTokenizer(iter, StructsTokenizerOptions{WithID: true})
 
-			var evals []*structs.Evaluation
-			paginator, err := NewPaginator(iter, tokenizer, nil, opts, func(raw interface{}) error {
-				eval := raw.(*structs.Evaluation)
-				evals = append(evals, eval)
-				return nil
-			})
+			paginator, err := NewPaginator(iter, opts, nil,
+				IDTokenizer[*structs.Evaluation](opts.NextToken),
+				func(eval *structs.Evaluation) (*structs.Evaluation, error) { return eval, nil })
 			if err != nil {
 				b.Fatalf("failed: %v", err)
 			}
@@ -276,14 +245,9 @@ func BenchmarkEvalListFilter(b *testing.B) {
 
 		for i := 0; i < b.N; i++ {
 			iter, _ := state.Evals(nil, false)
-			tokenizer := NewStructsTokenizer(iter, StructsTokenizerOptions{WithID: true})
-
-			var evals []*structs.Evaluation
-			paginator, err := NewPaginator(iter, tokenizer, nil, opts, func(raw interface{}) error {
-				eval := raw.(*structs.Evaluation)
-				evals = append(evals, eval)
-				return nil
-			})
+			paginator, err := NewPaginator(iter, opts, nil,
+				IDTokenizer[*structs.Evaluation](opts.NextToken),
+				func(eval *structs.Evaluation) (*structs.Evaluation, error) { return eval, nil })
 			if err != nil {
 				b.Fatalf("failed: %v", err)
 			}
diff --git a/nomad/state/paginator/paginator_test.go b/nomad/state/paginator/paginator_test.go
--- a/nomad/state/paginator/paginator_test.go
+++ b/nomad/state/paginator/paginator_test.go
@@ -20,27 +20,30 @@ func TestPaginator(t *testing.T) {
 		name              string
 		perPage           int32
 		nextToken         string
-		tokenizer         testTokenizer
+		tokenizer         Tokenizer[*mockObject]
 		expected          []string
 		expectedNextToken string
 		expectedError     string
 	}{
 		{
 			name:              "size-3 page-1",
 			perPage:           3,
+			tokenizer:         IDTokenizer[*mockObject](""),
 			expected:          []string{"0", "1", "2"},
 			expectedNextToken: "3",
 		},
 		{
 			name:              "size-5 page-2 stop before end",
 			perPage:           5,
+			tokenizer:         IDTokenizer[*mockObject]("3"),
 			nextToken:         "3",
 			expected:          []string{"3", "4", "5", "6", "7"},
 			expectedNextToken: "8",
 		},
 		{
 			name:              "page-2 reading off the end",
 			perPage:           10,
+			tokenizer:         IDTokenizer[*mockObject]("5"),
 			nextToken:         "5",
 			expected:          []string{"5", "6", "7", "8", "9", "10", "11"},
 			expectedNextToken: "",
@@ -50,6 +53,7 @@ func TestPaginator(t *testing.T) {
 			perPage: 2,
 			// lexicographically, "10" < "2"
 			nextToken:         "10",
+			tokenizer:         IDTokenizer[*mockObject]("10"),
 			expected:          []string{"2", "3"},
 			expectedNextToken: "4",
 		},
@@ -58,7 +62,7 @@ func TestPaginator(t *testing.T) {
 			perPage: 2,
 			// "10" is converted to uint64(10) and compared with uint64 index
 			nextToken:         "10",
-			tokenizer:         testTokenizer{field: "index"},
+			tokenizer:         ModifyIndexTokenizer[*mockObject]("10"),
 			expected:          []string{"10", "11"},
 			expectedNextToken: "",
 		},
@@ -67,20 +71,22 @@ func TestPaginator(t *testing.T) {
 			perPage: 2,
 			// "" is converted to uint64(0) and compared with uint64 index
 			nextToken:         "",
-			tokenizer:         testTokenizer{field: "index"},
+			tokenizer:         ModifyIndexTokenizer[*mockObject](""),
 			expected:          []string{"0", "1"},
 			expectedNextToken: "2",
 		},
 		{
 			name:              "starting off the end",
 			perPage:           5,
 			nextToken:         "a",
+			tokenizer:         IDTokenizer[*mockObject]("a"),
 			expected:          []string{},
 			expectedNextToken: "",
 		},
 		{
 			name:          "error during append",
 			expectedError: "failed to append",
+			tokenizer:     IDTokenizer[*mockObject](""),
 		},
 	}
 
@@ -93,21 +99,17 @@ func TestPaginator(t *testing.T) {
 				NextToken: tc.nextToken,
 			}
 
-			results := []string{}
-			paginator, err := NewPaginator(iter, tc.tokenizer, nil, opts,
-				func(raw interface{}) error {
+			paginator, err := NewPaginator(iter, opts, nil, tc.tokenizer,
+				func(result *mockObject) (string, error) {
 					if tc.expectedError != "" {
-						return errors.New(tc.expectedError)
+						return "", errors.New(tc.expectedError)
 					}
-
-					result := raw.(*mockObject)
-					results = append(results, result.id)
-					return nil
+					return result.id, nil
 				},
 			)
 			must.NoError(t, err)
 
-			nextToken, err := paginator.Page()
+			results, nextToken, err := paginator.Page()
 			if tc.expectedError == "" {
 				must.NoError(t, err)
 				must.Eq(t, tc.expected, results)
@@ -152,6 +154,14 @@ func (m *mockObject) GetNamespace() string {
 	return m.namespace
 }
 
+func (m *mockObject) GetModifyIndex() uint64 {
+	return m.index
+}
+
+func (m *mockObject) GetID() string {
+	return m.id
+}
+
 func newTestIterator(ids []string) testResultIterator {
 	iter := testResultIterator{results: make(chan interface{}, 20)}
 	for x, id := range ids {
@@ -170,18 +180,3 @@ func newTestIteratorWithMocks(mocks []*mockObject) testResultIterator {
 	}
 	return iter
 }
-
-// implements Tokenizer interface
-type testTokenizer struct {
-	field string
-}
-
-func (t testTokenizer) GetToken(raw interface{}) any {
-	obj := raw.(*mockObject)
-	switch t.field {
-	case "index":
-		return obj.index
-	default:
-	}
-	return obj.id
-}
diff --git a/nomad/state/paginator/tokenizer_test.go b/nomad/state/paginator/tokenizer_test.go
--- a/nomad/state/paginator/tokenizer_test.go
+++ b/nomad/state/paginator/tokenizer_test.go
@@ -9,74 +9,46 @@ import (
 
 	"github.com/hashicorp/nomad/ci"
 	"github.com/hashicorp/nomad/nomad/mock"
+	"github.com/hashicorp/nomad/nomad/structs"
 	"github.com/shoenig/test/must"
 )
 
-func TestStructsTokenizer(t *testing.T) {
+func TestTokenizer(t *testing.T) {
 	ci.Parallel(t)
 
 	j := mock.Job()
 
 	cases := []struct {
-		name     string
-		opts     StructsTokenizerOptions
-		expected any
+		name      string
+		tokenizer Tokenizer[*structs.Job]
+		expected  string
 	}{
 		{
-			name: "ID",
-			opts: StructsTokenizerOptions{
-				WithID: true,
-			},
-			expected: fmt.Sprintf("%v", j.ID),
+			name:      "ID",
+			tokenizer: IDTokenizer[*structs.Job](""),
+			expected:  fmt.Sprintf("%v", j.ID),
 		},
 		{
-			name: "Namespace.ID",
-			opts: StructsTokenizerOptions{
-				WithNamespace: true,
-				WithID:        true,
-			},
-			expected: fmt.Sprintf("%v.%v", j.Namespace, j.ID),
+			name:      "Namespace.ID",
+			tokenizer: NamespaceIDTokenizer[*structs.Job](""),
+			expected:  fmt.Sprintf("%v.%v", j.Namespace, j.ID),
 		},
 		{
-			name: "CreateIndex.Namespace.ID",
-			opts: StructsTokenizerOptions{
-				WithCreateIndex: true,
-				WithNamespace:   true,
-				WithID:          true,
-			},
-			expected: fmt.Sprintf("%v.%v.%v", j.CreateIndex, j.Namespace, j.ID),
+			name:      "CreateIndex.ID",
+			tokenizer: CreateIndexAndIDTokenizer[*structs.Job](""),
+			expected:  fmt.Sprintf("%v.%v", j.CreateIndex, j.ID),
 		},
 		{
-			name: "CreateIndex.ID",
-			opts: StructsTokenizerOptions{
-				WithCreateIndex: true,
-				WithID:          true,
-			},
-			expected: fmt.Sprintf("%v.%v", j.CreateIndex, j.ID),
-		},
-		{
-			name: "CreateIndex.Namespace",
-			opts: StructsTokenizerOptions{
-				WithCreateIndex: true,
-				WithNamespace:   true,
-			},
-			expected: fmt.Sprintf("%v.%v", j.CreateIndex, j.Namespace),
-		},
-		{
-			name: "ModifyIndex",
-			opts: StructsTokenizerOptions{
-				OnlyModifyIndex: true,
-				// note: all others options will be ignored
-				WithNamespace: true,
-			},
-			expected: j.ModifyIndex,
+			name:      "ModifyIndex",
+			tokenizer: ModifyIndexTokenizer[*structs.Job](""),
+			expected:  fmt.Sprintf("%d", j.ModifyIndex),
 		},
 	}
 
 	for _, tc := range cases {
 		t.Run(tc.name, func(t *testing.T) {
-			tokenizer := StructsTokenizer{opts: tc.opts}
-			must.Eq(t, tc.expected, tokenizer.GetToken(j))
+			token, _ := tc.tokenizer(j)
+			must.Eq(t, tc.expected, token)
 		})
 	}
 }
EOF_114329324912

# Ensure CGO is enabled
export CGO_ENABLED=1

# Run the target tests
# Combining tests into minimal commands for efficiency:
# 1. Run leader tests from nomad package
# 2. Run all paginator tests from nomad/state/paginator package

echo "=== Running nomad/leader_test.go tests ==="
gotestsum --format=testname -- -timeout=20m -count=1 -tags hashicorpmetrics ./nomad -run TestLeader

echo "=== Running nomad/state/paginator tests ==="
gotestsum --format=testname -- -timeout=20m -count=1 -tags hashicorpmetrics ./nomad/state/paginator/...

# Capture exit code
rc=$?

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test files
git checkout 60132ab0cf04c01b7e9e445f15bf2f9e7487be48 "nomad/leader_test.go" "nomad/state/paginator/filter_test.go" "nomad/state/paginator/paginator_test.go" "nomad/state/paginator/tokenizer_test.go"