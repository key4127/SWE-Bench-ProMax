#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file before applying patch
git checkout b9951ded37ba48d3fdcd1f2b484973b40b3d245e "utilities/option_change_migration/option_change_migration_test.cc"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/utilities/option_change_migration/option_change_migration_test.cc b/utilities/option_change_migration/option_change_migration_test.cc
--- a/utilities/option_change_migration/option_change_migration_test.cc
+++ b/utilities/option_change_migration/option_change_migration_test.cc
@@ -556,6 +556,385 @@ TEST_F(DBOptionChangeMigrationTest, CompactedSrcToUniversal) {
   }
 }
 
+class DBOptionChangeMigrationMultiCFTest : public DBTestBase {
+ public:
+  DBOptionChangeMigrationMultiCFTest()
+      : DBTestBase("db_option_change_migration_multi_cf_test",
+                   /*env_do_fsync=*/true) {}
+};
+
+TEST_F(DBOptionChangeMigrationMultiCFTest, BasicMultiCF) {
+  Options options = CurrentOptions();
+  options.compaction_style = CompactionStyle::kCompactionStyleLevel;
+  options.level_compaction_dynamic_level_bytes = false;
+  options.num_levels = 4;
+  options.write_buffer_size = 64 * 1024;
+  options.target_file_size_base = 128 * 1024;
+
+  // Create DB with default CF
+  Reopen(options);
+
+  // Create additional CF
+  ColumnFamilyHandle* cf_handle;
+  ASSERT_OK(db_->CreateColumnFamily(options, "cf1", &cf_handle));
+
+  // Write data to both CFs
+  Random rnd(301);
+  for (int i = 0; i < 100; i++) {
+    ASSERT_OK(Put("key" + std::to_string(i), rnd.RandomString(900)));
+    ASSERT_OK(db_->Put(WriteOptions(), cf_handle, "key" + std::to_string(i),
+                       rnd.RandomString(900)));
+  }
+  ASSERT_OK(Flush());
+  ASSERT_OK(db_->Flush(FlushOptions(), cf_handle));
+  ASSERT_OK(dbfull()->TEST_WaitForCompact());
+
+  // Collect keys from both CFs
+  std::set<std::string> keys_default;
+  std::set<std::string> keys_cf1;
+  {
+    std::unique_ptr<Iterator> it(db_->NewIterator(ReadOptions()));
+    for (it->SeekToFirst(); it->Valid(); it->Next()) {
+      keys_default.insert(it->key().ToString());
+    }
+    ASSERT_OK(it->status());
+  }
+  {
+    std::unique_ptr<Iterator> it(db_->NewIterator(ReadOptions(), cf_handle));
+    for (it->SeekToFirst(); it->Valid(); it->Next()) {
+      keys_cf1.insert(it->key().ToString());
+    }
+    ASSERT_OK(it->status());
+  }
+
+  delete cf_handle;
+  Close();
+
+  // Prepare old and new options
+  DBOptions old_db_opts(options);
+  ColumnFamilyOptions old_cf_opts(options);
+
+  std::vector<ColumnFamilyDescriptor> old_cf_descs = {
+      {kDefaultColumnFamilyName, old_cf_opts}, {"cf1", old_cf_opts}};
+
+  // New options: migrate to Universal compaction
+  Options new_options = options;
+  new_options.compaction_style = CompactionStyle::kCompactionStyleUniversal;
+  new_options.num_levels = 5;
+  new_options.target_file_size_base = 256 * 1024;
+
+  DBOptions new_db_opts(new_options);
+  ColumnFamilyOptions new_cf_opts(new_options);
+
+  std::vector<ColumnFamilyDescriptor> new_cf_descs = {
+      {kDefaultColumnFamilyName, new_cf_opts}, {"cf1", new_cf_opts}};
+
+  // Perform multi-CF migration
+  ASSERT_OK(OptionChangeMigration(dbname_, old_db_opts, old_cf_descs,
+                                  new_db_opts, new_cf_descs));
+
+  // Reopen with new options
+  std::vector<ColumnFamilyHandle*> handles;
+  ASSERT_OK(DB::Open(new_db_opts, dbname_, new_cf_descs, &handles, &db_));
+  ASSERT_EQ(handles.size(), 2);
+
+  // Verify data in default CF
+  {
+    std::unique_ptr<Iterator> it(db_->NewIterator(ReadOptions()));
+    it->SeekToFirst();
+    for (const std::string& key : keys_default) {
+      ASSERT_TRUE(it->Valid());
+      ASSERT_EQ(key, it->key().ToString());
+      it->Next();
+    }
+    ASSERT_TRUE(!it->Valid());
+    ASSERT_OK(it->status());
+  }
+
+  // Verify data in cf1
+  {
+    std::unique_ptr<Iterator> it(db_->NewIterator(ReadOptions(), handles[1]));
+    it->SeekToFirst();
+    for (const std::string& key : keys_cf1) {
+      ASSERT_TRUE(it->Valid());
+      ASSERT_EQ(key, it->key().ToString());
+      it->Next();
+    }
+    ASSERT_TRUE(!it->Valid());
+    ASSERT_OK(it->status());
+  }
+
+  // Cleanup
+  for (auto* handle : handles) {
+    if (handle != db_->DefaultColumnFamily()) {
+      ASSERT_OK(db_->DestroyColumnFamilyHandle(handle));
+    }
+  }
+}
+
+TEST_F(DBOptionChangeMigrationMultiCFTest, DifferentStylesPerCF) {
+  // Create DB with 2 CFs, both using Level compaction
+  Options options1 = CurrentOptions();
+  options1.compaction_style = CompactionStyle::kCompactionStyleLevel;
+  options1.num_levels = 4;
+  options1.write_buffer_size = 64 * 1024;
+
+  Reopen(options1);
+
+  ColumnFamilyHandle* cf_handle;
+  ASSERT_OK(db_->CreateColumnFamily(options1, "cf1", &cf_handle));
+
+  // Write data
+  Random rnd(301);
+  for (int i = 0; i < 50; i++) {
+    ASSERT_OK(Put("key" + std::to_string(i), rnd.RandomString(900)));
+    ASSERT_OK(db_->Put(WriteOptions(), cf_handle, "key" + std::to_string(i),
+                       rnd.RandomString(900)));
+  }
+  ASSERT_OK(Flush());
+  ASSERT_OK(db_->Flush(FlushOptions(), cf_handle));
+
+  // Collect keys from both CFs
+  std::set<std::string> keys_default;
+  std::set<std::string> keys_cf1;
+  {
+    std::unique_ptr<Iterator> it(db_->NewIterator(ReadOptions()));
+    for (it->SeekToFirst(); it->Valid(); it->Next()) {
+      keys_default.insert(it->key().ToString());
+    }
+    ASSERT_OK(it->status());
+  }
+  {
+    std::unique_ptr<Iterator> it(db_->NewIterator(ReadOptions(), cf_handle));
+    for (it->SeekToFirst(); it->Valid(); it->Next()) {
+      keys_cf1.insert(it->key().ToString());
+    }
+    ASSERT_OK(it->status());
+  }
+
+  delete cf_handle;
+  Close();
+
+  // Old descriptors
+  DBOptions old_db_opts(options1);
+  ColumnFamilyOptions old_cf_opts(options1);
+
+  std::vector<ColumnFamilyDescriptor> old_cf_descs = {
+      {kDefaultColumnFamilyName, old_cf_opts}, {"cf1", old_cf_opts}};
+
+  // New descriptors: default CF to Universal, cf1 to Level with dynamic
+  Options new_opts_default = options1;
+  new_opts_default.compaction_style =
+      CompactionStyle::kCompactionStyleUniversal;
+  new_opts_default.num_levels = 5;
+
+  Options new_opts_cf1 = options1;
+  new_opts_cf1.compaction_style = CompactionStyle::kCompactionStyleLevel;
+  new_opts_cf1.level_compaction_dynamic_level_bytes = true;
+  new_opts_cf1.num_levels = 5;
+
+  DBOptions new_db_opts(new_opts_default);
+
+  std::vector<ColumnFamilyDescriptor> new_cf_descs = {
+      {kDefaultColumnFamilyName, ColumnFamilyOptions(new_opts_default)},
+      {"cf1", ColumnFamilyOptions(new_opts_cf1)}};
+
+  // Perform migration
+  ASSERT_OK(OptionChangeMigration(dbname_, old_db_opts, old_cf_descs,
+                                  new_db_opts, new_cf_descs));
+
+  // Reopen and verify
+  std::vector<ColumnFamilyHandle*> handles;
+  ASSERT_OK(DB::Open(new_db_opts, dbname_, new_cf_descs, &handles, &db_));
+  ASSERT_EQ(handles.size(), 2);
+
+  // Verify data in default CF
+  {
+    std::unique_ptr<Iterator> it(db_->NewIterator(ReadOptions()));
+    it->SeekToFirst();
+    for (const std::string& key : keys_default) {
+      ASSERT_TRUE(it->Valid());
+      ASSERT_EQ(key, it->key().ToString());
+      it->Next();
+    }
+    ASSERT_TRUE(!it->Valid());
+    ASSERT_OK(it->status());
+  }
+
+  // Verify data in cf1
+  {
+    std::unique_ptr<Iterator> it(db_->NewIterator(ReadOptions(), handles[1]));
+    it->SeekToFirst();
+    for (const std::string& key : keys_cf1) {
+      ASSERT_TRUE(it->Valid());
+      ASSERT_EQ(key, it->key().ToString());
+      it->Next();
+    }
+    ASSERT_TRUE(!it->Valid());
+    ASSERT_OK(it->status());
+  }
+
+  // Cleanup
+  for (auto* handle : handles) {
+    if (handle != db_->DefaultColumnFamily()) {
+      ASSERT_OK(db_->DestroyColumnFamilyHandle(handle));
+    }
+  }
+}
+
+TEST_F(DBOptionChangeMigrationMultiCFTest, ValidationMismatched) {
+  Options options = CurrentOptions();
+  DBOptions db_opts(options);
+  ColumnFamilyOptions cf_opts(options);
+
+  // Test 1: Mismatched CF count (missing cf1)
+  {
+    std::vector<ColumnFamilyDescriptor> old_cf_descs = {
+        {kDefaultColumnFamilyName, cf_opts}, {"cf1", cf_opts}};
+
+    std::vector<ColumnFamilyDescriptor> new_cf_descs = {
+        {kDefaultColumnFamilyName, cf_opts}};  // Missing cf1
+
+    Status s = OptionChangeMigration(dbname_, db_opts, old_cf_descs, db_opts,
+                                     new_cf_descs);
+    ASSERT_TRUE(s.IsInvalidArgument());
+    ASSERT_TRUE(s.ToString().find("same number") != std::string::npos);
+  }
+
+  // Test 2: Mismatched CF names (cf2 instead of cf1)
+  {
+    std::vector<ColumnFamilyDescriptor> old_cf_descs = {
+        {kDefaultColumnFamilyName, cf_opts}, {"cf1", cf_opts}};
+
+    std::vector<ColumnFamilyDescriptor> new_cf_descs = {
+        {kDefaultColumnFamilyName, cf_opts},
+        {"cf2", cf_opts}};  // Different name
+
+    Status s = OptionChangeMigration(dbname_, db_opts, old_cf_descs, db_opts,
+                                     new_cf_descs);
+    ASSERT_TRUE(s.IsInvalidArgument());
+    ASSERT_TRUE(s.ToString().find("mismatch") != std::string::npos);
+  }
+
+  // Test 3: Mismatched CF order (swapped)
+  {
+    std::vector<ColumnFamilyDescriptor> old_cf_descs = {
+        {kDefaultColumnFamilyName, cf_opts}, {"cf1", cf_opts}};
+
+    std::vector<ColumnFamilyDescriptor> new_cf_descs = {
+        {"cf1", cf_opts},  // Swapped order
+        {kDefaultColumnFamilyName, cf_opts}};
+
+    Status s = OptionChangeMigration(dbname_, db_opts, old_cf_descs, db_opts,
+                                     new_cf_descs);
+    ASSERT_TRUE(s.IsInvalidArgument());
+    ASSERT_TRUE(s.ToString().find("mismatch") != std::string::npos);
+  }
+}
+
+TEST_F(DBOptionChangeMigrationMultiCFTest, FromFIFOMultiCF) {
+  Options options = CurrentOptions();
+  options.compaction_style = CompactionStyle::kCompactionStyleFIFO;
+  options.num_levels = 1;
+  options.max_open_files = -1;
+
+  Reopen(options);
+
+  ColumnFamilyHandle* cf_handle;
+  ASSERT_OK(db_->CreateColumnFamily(options, "cf1", &cf_handle));
+
+  // Write some data
+  Random rnd(301);
+  for (int i = 0; i < 50; i++) {
+    ASSERT_OK(Put("key" + std::to_string(i), rnd.RandomString(900)));
+    ASSERT_OK(db_->Put(WriteOptions(), cf_handle, "key" + std::to_string(i),
+                       rnd.RandomString(900)));
+  }
+  ASSERT_OK(Flush());
+  ASSERT_OK(db_->Flush(FlushOptions(), cf_handle));
+
+  // Collect keys from both CFs
+  std::set<std::string> keys_default;
+  std::set<std::string> keys_cf1;
+  {
+    std::unique_ptr<Iterator> it(db_->NewIterator(ReadOptions()));
+    for (it->SeekToFirst(); it->Valid(); it->Next()) {
+      keys_default.insert(it->key().ToString());
+    }
+    ASSERT_OK(it->status());
+  }
+  {
+    std::unique_ptr<Iterator> it(db_->NewIterator(ReadOptions(), cf_handle));
+    for (it->SeekToFirst(); it->Valid(); it->Next()) {
+      keys_cf1.insert(it->key().ToString());
+    }
+    ASSERT_OK(it->status());
+  }
+
+  delete cf_handle;
+  Close();
+
+  // Migrate from FIFO to Level
+  DBOptions old_db_opts(options);
+  ColumnFamilyOptions old_cf_opts(options);
+
+  std::vector<ColumnFamilyDescriptor> old_cf_descs = {
+      {kDefaultColumnFamilyName, old_cf_opts}, {"cf1", old_cf_opts}};
+
+  Options new_options = options;
+  new_options.compaction_style = CompactionStyle::kCompactionStyleLevel;
+  new_options.num_levels = 4;
+  new_options.max_open_files = 1000;
+
+  DBOptions new_db_opts(new_options);
+  ColumnFamilyOptions new_cf_opts(new_options);
+
+  std::vector<ColumnFamilyDescriptor> new_cf_descs = {
+      {kDefaultColumnFamilyName, new_cf_opts}, {"cf1", new_cf_opts}};
+
+  // Migration should succeed (FIFO is special case)
+  ASSERT_OK(OptionChangeMigration(dbname_, old_db_opts, old_cf_descs,
+                                  new_db_opts, new_cf_descs));
+
+  // Reopen and verify
+  std::vector<ColumnFamilyHandle*> handles;
+  ASSERT_OK(DB::Open(new_db_opts, dbname_, new_cf_descs, &handles, &db_));
+  ASSERT_EQ(handles.size(), 2);
+
+  // Verify data in default CF
+  {
+    std::unique_ptr<Iterator> it(db_->NewIterator(ReadOptions()));
+    it->SeekToFirst();
+    for (const std::string& key : keys_default) {
+      ASSERT_TRUE(it->Valid());
+      ASSERT_EQ(key, it->key().ToString());
+      it->Next();
+    }
+    ASSERT_TRUE(!it->Valid());
+    ASSERT_OK(it->status());
+  }
+
+  // Verify data in cf1
+  {
+    std::unique_ptr<Iterator> it(db_->NewIterator(ReadOptions(), handles[1]));
+    it->SeekToFirst();
+    for (const std::string& key : keys_cf1) {
+      ASSERT_TRUE(it->Valid());
+      ASSERT_EQ(key, it->key().ToString());
+      it->Next();
+    }
+    ASSERT_TRUE(!it->Valid());
+    ASSERT_OK(it->status());
+  }
+
+  // Cleanup
+  for (auto* handle : handles) {
+    if (handle != db_->DefaultColumnFamily()) {
+      ASSERT_OK(db_->DestroyColumnFamilyHandle(handle));
+    }
+  }
+}
+
 }  // namespace ROCKSDB_NAMESPACE
 
 int main(int argc, char** argv) {
EOF_114329324912

# Build the test binary
make option_change_migration_test

# Run the test
./option_change_migration_test
rc=$?

# Echo exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: revert the test file to original state
git checkout b9951ded37ba48d3fdcd1f2b484973b40b3d245e "utilities/option_change_migration/option_change_migration_test.cc"