#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test files
git checkout 48394f2b674b8c5e4c55a4eb1f9ccc9303fe8831 "tests/test_core/test_optimization/test_mutations/test_prompt_rewriter.py" "tests/test_core/test_optimization/test_utils.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_core/test_optimization/test_mutations/test_prompt_rewriter.py b/tests/test_core/test_optimization/test_mutations/test_prompt_rewriter.py
--- a/tests/test_core/test_optimization/test_mutations/test_prompt_rewriter.py
+++ b/tests/test_core/test_optimization/test_mutations/test_prompt_rewriter.py
@@ -187,10 +187,10 @@ def model_callback(**kwargs):
     assert new is old
 
 
-def test_prompt_rewriter_list_default_mutates_first_message():
+def test_prompt_rewriter_list_default_mutates_random_message():
     """
-    With default PromptListMutationConfig (FIRST, no role),
-    the first message is rewritten.
+    With default PromptListMutationConfig (RANDOM, no role),
+    exactly one message in the list is rewritten and roles are preserved.
     """
     rewriter = PromptRewriter()
     old = Prompt(
@@ -213,51 +213,23 @@ def model_callback(**kwargs):
 
     assert isinstance(new, Prompt)
     assert new.messages_template is not None
-    msgs = new.messages_template
 
-    # First message content is replaced, others are unchanged.
-    assert msgs[0].content == "rewritten list"
-    assert msgs[1].content == "m1"
-    assert msgs[2].content == "m2"
+    old_msgs = old.messages_template
+    new_msgs = new.messages_template
 
-    # Roles are preserved.
-    assert msgs[0].role == "user"
-    assert msgs[1].role == "system"
-    assert msgs[2].role == "assistant"
+    # Exactly one message’s content should change.
+    changed_indices = [
+        i
+        for i, (old_msg, new_msg) in enumerate(zip(old_msgs, new_msgs))
+        if old_msg.content != new_msg.content
+    ]
 
+    assert changed_indices, "At least one message should be rewritten"
+    assert len(changed_indices) == 1
 
-def test_prompt_rewriter_list_respects_target_role_first():
-    """
-    When target_role is set and target_type == FIRST,
-    we rewrite the first message whose role matches.
-    """
-    cfg = PromptListMutationConfig(
-        target_type=PromptListMutationTargetType.FIRST,
-        target_role="system",
-    )
-    rewriter = PromptRewriter(list_mutation_config=cfg)
-    old = Prompt(
-        messages_template=[
-            PromptMessage(role="user", content="u0"),
-            PromptMessage(role="system", content="s0"),
-            PromptMessage(role="system", content="s1"),
-        ]
-    )
-
-    def model_callback(**kwargs):
-        return "rewrite-system"
-
-    new = rewriter.rewrite(
-        module_id="__module__",
-        old_prompt=old,
-        feedback_text="feedback",
-        model_callback=model_callback,
-    )
-
-    msgs = new.messages_template
-    assert msgs[0].content == "u0"
-    assert msgs[1].content == "rewrite-system"
-    assert msgs[2].content == "s1"
+    # Roles should be preserved for all messages.
+    for old_msg, new_msg in zip(old_msgs, new_msgs):
+        assert old_msg.role == new_msg.role
 
 
 def test_prompt_rewriter_list_random_uses_random_state_and_role_filter():
@@ -300,6 +272,76 @@ def model_callback(**kwargs):
     assert msgs[2].content == "rewrite"
 
 
+@pytest.mark.parametrize("target_index", [0, 1, 2])
+def test_prompt_rewriter_list_fixed_index_mutates_selected_message(
+    target_index: int,
+):
+    """
+    When target_type == FIXED_INDEX, the message at target_index is rewritten
+    and all other messages remain unchanged. Roles are preserved.
+    """
+    cfg = PromptListMutationConfig(
+        target_type=PromptListMutationTargetType.FIXED_INDEX,
+        target_index=target_index,
+    )
+    rewriter = PromptRewriter(list_mutation_config=cfg)
+
+    old = Prompt(
+        messages_template=[
+            PromptMessage(role="user", content="m0"),
+            PromptMessage(role="system", content="m1"),
+            PromptMessage(role="assistant", content="m2"),
+        ]
+    )
+
+    def model_callback(**kwargs):
+        # Mark which index we expected to rewrite to make debugging easier
+        return f"rewritten-{target_index}"
+
+    new = rewriter.rewrite(
+        module_id="__module__",
+        old_prompt=old,
+        feedback_text="feedback",
+        model_callback=model_callback,
+    )
+
+    assert isinstance(new, Prompt)
+    assert new.messages_template is not None
+
+    old_msgs = old.messages_template
+    new_msgs = new.messages_template
+
+    for idx, (old_msg, new_msg) in enumerate(zip(old_msgs, new_msgs)):
+        # Roles are always preserved
+        assert new_msg.role == old_msg.role
+
+        if idx == target_index:
+            # Only the selected index is rewritten
+            assert new_msg.content == f"rewritten-{target_index}"
+        else:
+            assert new_msg.content == old_msg.content
+
+
+def test_prompt_rewriter_fixed_index_out_of_range_raises():
+    cfg = PromptListMutationConfig(
+        target_type=PromptListMutationTargetType.FIXED_INDEX,
+        target_index=10,
+    )
+    rewriter = PromptRewriter(list_mutation_config=cfg)
+    old = Prompt(messages_template=[PromptMessage(role="user", content="m0")])
+
+    def model_callback(**kwargs):
+        return "rewrite"
+
+    with pytest.raises(DeepEvalError):
+        rewriter.rewrite(
+            module_id="__module__",
+            old_prompt=old,
+            feedback_text="feedback",
+            model_callback=model_callback,
+        )
+
+
 def test_prompt_rewriter_accepts_int_random_seed_and_converts_to_random():
     """
     Passing an int seed for random_state should be accepted and
diff --git a/tests/test_core/test_optimization/test_utils.py b/tests/test_core/test_optimization/test_utils.py
--- a/tests/test_core/test_optimization/test_utils.py
+++ b/tests/test_core/test_optimization/test_utils.py
@@ -227,29 +227,25 @@ def test_build_model_callback_kwargs_populates_all_fields() -> None:
     prompt = StubPrompt(alias="alias")
     golden = object()
     feedback_text = "feedback"
-    prompt_type = "LIST"
     prompt_text = "pt"
     prompt_messages = ["m1", "m2"]
 
     kwargs = build_model_callback_kwargs(
         prompt=prompt,
-        prompt_type=prompt_type,
         prompt_text=prompt_text,
         prompt_messages=prompt_messages,
         golden=golden,
         feedback_text=feedback_text,
     )
 
     assert kwargs["prompt"] is prompt
-    assert kwargs["prompt_type"] == prompt_type
     assert kwargs["prompt_text"] == prompt_text
     assert kwargs["prompt_messages"] == prompt_messages
     assert kwargs["golden"] is golden
     assert kwargs["feedback_text"] == feedback_text
 
     assert set(kwargs.keys()) == {
         "prompt",
-        "prompt_type",
         "prompt_text",
         "prompt_messages",
         "golden",
@@ -261,7 +257,6 @@ def test_build_model_callback_kwargs_defaults_missing_fields_to_none() -> None:
     kwargs = build_model_callback_kwargs()
 
     assert kwargs["prompt"] is None
-    assert kwargs["prompt_type"] is None
     assert kwargs["prompt_text"] is None
     assert kwargs["prompt_messages"] is None
     assert kwargs["golden"] is None
EOF_114329324912

# Run the target test files using Poetry
# Using pytest directly as specified in the context retrieval agent
# Running in single-process mode for stability in virtualized environment
poetry run pytest -vv -rA --maxfail=1 --capture=tee-sys \
    tests/test_core/test_optimization/test_mutations/test_prompt_rewriter.py \
    tests/test_core/test_optimization/test_utils.py

# Capture exit code
rc=$?

# Echo exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 48394f2b674b8c5e4c55a4eb1f9ccc9303fe8831 "tests/test_core/test_optimization/test_mutations/test_prompt_rewriter.py" "tests/test_core/test_optimization/test_utils.py"