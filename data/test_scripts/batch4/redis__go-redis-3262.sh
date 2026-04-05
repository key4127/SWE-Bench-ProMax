#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the original test files that will be modified by the patch
git checkout 3d4310ae9696cadc8eaeab747158abe1d03d8b7a "commands_test.go" "acl_commands_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/acl_commands_test.go b/acl_commands_test.go
new file mode 100644
--- /dev/null
+++ b/acl_commands_test.go
@@ -0,0 +1,449 @@
+package redis_test
+
+import (
+	"context"
+
+	"github.com/redis/go-redis/v9"
+
+	. "github.com/bsm/ginkgo/v2"
+	. "github.com/bsm/gomega"
+)
+
+var TestUserName string = "goredis"
+var _ = Describe("ACL", func() {
+	var client *redis.Client
+	var ctx context.Context
+
+	BeforeEach(func() {
+		ctx = context.Background()
+		opt := redisOptions()
+		client = redis.NewClient(opt)
+	})
+
+	It("should ACL LOG", Label("NonRedisEnterprise"), func() {
+		Expect(client.ACLLogReset(ctx).Err()).NotTo(HaveOccurred())
+		err := client.Do(ctx, "acl", "setuser", "test", ">test", "on", "allkeys", "+get").Err()
+		Expect(err).NotTo(HaveOccurred())
+
+		clientAcl := redis.NewClient(redisOptions())
+		clientAcl.Options().Username = "test"
+		clientAcl.Options().Password = "test"
+		clientAcl.Options().DB = 0
+		_ = clientAcl.Set(ctx, "mystring", "foo", 0).Err()
+		_ = clientAcl.HSet(ctx, "myhash", "foo", "bar").Err()
+		_ = clientAcl.SAdd(ctx, "myset", "foo", "bar").Err()
+
+		logEntries, err := client.ACLLog(ctx, 10).Result()
+		Expect(err).NotTo(HaveOccurred())
+		Expect(len(logEntries)).To(Equal(4))
+
+		for _, entry := range logEntries {
+			Expect(entry.Reason).To(Equal("command"))
+			Expect(entry.Context).To(Equal("toplevel"))
+			Expect(entry.Object).NotTo(BeEmpty())
+			Expect(entry.Username).To(Equal("test"))
+			Expect(entry.AgeSeconds).To(BeNumerically(">=", 0))
+			Expect(entry.ClientInfo).NotTo(BeNil())
+			Expect(entry.EntryID).To(BeNumerically(">=", 0))
+			Expect(entry.TimestampCreated).To(BeNumerically(">=", 0))
+			Expect(entry.TimestampLastUpdated).To(BeNumerically(">=", 0))
+		}
+
+		limitedLogEntries, err := client.ACLLog(ctx, 2).Result()
+		Expect(err).NotTo(HaveOccurred())
+		Expect(len(limitedLogEntries)).To(Equal(2))
+
+		// cleanup after creating the user
+		err = client.Do(ctx, "acl", "deluser", "test").Err()
+		Expect(err).NotTo(HaveOccurred())
+	})
+
+	It("should ACL LOG RESET", Label("NonRedisEnterprise"), func() {
+		// Call ACL LOG RESET
+		resetCmd := client.ACLLogReset(ctx)
+		Expect(resetCmd.Err()).NotTo(HaveOccurred())
+		Expect(resetCmd.Val()).To(Equal("OK"))
+
+		// Verify that the log is empty after the reset
+		logEntries, err := client.ACLLog(ctx, 10).Result()
+		Expect(err).NotTo(HaveOccurred())
+		Expect(len(logEntries)).To(Equal(0))
+	})
+
+})
+var _ = Describe("ACL user commands", Label("NonRedisEnterprise"), func() {
+	var client *redis.Client
+	var ctx context.Context
+
+	BeforeEach(func() {
+		ctx = context.Background()
+		opt := redisOptions()
+		client = redis.NewClient(opt)
+	})
+
+	AfterEach(func() {
+		_, err := client.ACLDelUser(context.Background(), TestUserName).Result()
+		Expect(err).NotTo(HaveOccurred())
+		Expect(client.Close()).NotTo(HaveOccurred())
+	})
+
+	It("list only default user", func() {
+		res, err := client.ACLList(ctx).Result()
+		Expect(err).NotTo(HaveOccurred())
+		Expect(res).To(HaveLen(1))
+		Expect(res[0]).To(ContainSubstring("default"))
+	})
+
+	It("setuser and deluser", func() {
+		res, err := client.ACLList(ctx).Result()
+		Expect(err).NotTo(HaveOccurred())
+		Expect(res).To(HaveLen(1))
+		Expect(res[0]).To(ContainSubstring("default"))
+
+		add, err := client.ACLSetUser(ctx, TestUserName, "nopass", "on", "allkeys", "+set", "+get").Result()
+		Expect(err).NotTo(HaveOccurred())
+		Expect(add).To(Equal("OK"))
+
+		resAfter, err := client.ACLList(ctx).Result()
+		Expect(err).NotTo(HaveOccurred())
+		Expect(resAfter).To(HaveLen(2))
+		Expect(resAfter[1]).To(ContainSubstring(TestUserName))
+
+		deletedN, err := client.ACLDelUser(ctx, TestUserName).Result()
+		Expect(err).NotTo(HaveOccurred())
+		Expect(deletedN).To(BeNumerically("==", 1))
+
+		resAfterDeletion, err := client.ACLList(ctx).Result()
+		Expect(err).NotTo(HaveOccurred())
+		Expect(resAfterDeletion).To(HaveLen(1))
+		Expect(resAfterDeletion[0]).To(BeEquivalentTo(res[0]))
+	})
+
+	It("should acl dryrun", func() {
+		dryRun := client.ACLDryRun(ctx, "default", "get", "randomKey")
+		Expect(dryRun.Err()).NotTo(HaveOccurred())
+		Expect(dryRun.Val()).To(Equal("OK"))
+	})
+})
+
+var _ = Describe("ACL permissions", Label("NonRedisEnterprise"), func() {
+	var client *redis.Client
+	var ctx context.Context
+
+	BeforeEach(func() {
+		ctx = context.Background()
+		opt := redisOptions()
+		opt.UnstableResp3 = true
+		client = redis.NewClient(opt)
+	})
+
+	AfterEach(func() {
+		_, err := client.ACLDelUser(context.Background(), TestUserName).Result()
+		Expect(err).NotTo(HaveOccurred())
+		Expect(client.Close()).NotTo(HaveOccurred())
+	})
+
+	It("reset permissions", func() {
+		add, err := client.ACLSetUser(ctx,
+			TestUserName,
+			"reset",
+			"nopass",
+			"on",
+		).Result()
+		Expect(err).NotTo(HaveOccurred())
+		Expect(add).To(Equal("OK"))
+
+		connection := client.Conn()
+		authed, err := connection.AuthACL(ctx, TestUserName, "").Result()
+		Expect(err).NotTo(HaveOccurred())
+		Expect(authed).To(Equal("OK"))
+
+		_, err = connection.Get(ctx, "anykey").Result()
+		Expect(err).To(HaveOccurred())
+	})
+
+	It("add write permissions", func() {
+		add, err := client.ACLSetUser(ctx,
+			TestUserName,
+			"reset",
+			"nopass",
+			"on",
+			"~*",
+			"+SET",
+		).Result()
+		Expect(err).NotTo(HaveOccurred())
+		Expect(add).To(Equal("OK"))
+
+		connection := client.Conn()
+		authed, err := connection.AuthACL(ctx, TestUserName, "").Result()
+		Expect(err).NotTo(HaveOccurred())
+		Expect(authed).To(Equal("OK"))
+
+		// can write
+		v, err := connection.Set(ctx, "anykey", "anyvalue", 0).Result()
+		Expect(err).ToNot(HaveOccurred())
+		Expect(v).To(Equal("OK"))
+
+		// but can't read
+		value, err := connection.Get(ctx, "anykey").Result()
+		Expect(err).To(HaveOccurred())
+		Expect(value).To(BeEmpty())
+	})
+
+	It("add read permissions", func() {
+		add, err := client.ACLSetUser(ctx,
+			TestUserName,
+			"reset",
+			"nopass",
+			"on",
+			"~*",
+			"+GET",
+		).Result()
+		Expect(err).NotTo(HaveOccurred())
+		Expect(add).To(Equal("OK"))
+
+		connection := client.Conn()
+		authed, err := connection.AuthACL(ctx, TestUserName, "").Result()
+		Expect(err).NotTo(HaveOccurred())
+		Expect(authed).To(Equal("OK"))
+
+		// can read
+		value, err := connection.Get(ctx, "anykey").Result()
+		Expect(err).ToNot(HaveOccurred())
+		Expect(value).To(Equal("anyvalue"))
+
+		// but can't delete
+		del, err := connection.Del(ctx, "anykey").Result()
+		Expect(err).To(HaveOccurred())
+		Expect(del).ToNot(Equal(1))
+	})
+
+	It("add del permissions", func() {
+		add, err := client.ACLSetUser(ctx,
+			TestUserName,
+			"reset",
+			"nopass",
+			"on",
+			"~*",
+			"+DEL",
+		).Result()
+		Expect(err).NotTo(HaveOccurred())
+		Expect(add).To(Equal("OK"))
+
+		connection := client.Conn()
+		authed, err := connection.AuthACL(ctx, TestUserName, "").Result()
+		Expect(err).NotTo(HaveOccurred())
+		Expect(authed).To(Equal("OK"))
+
+		// can read
+		del, err := connection.Del(ctx, "anykey").Result()
+		Expect(err).ToNot(HaveOccurred())
+		Expect(del).To(BeEquivalentTo(1))
+	})
+
+	It("set permissions for module commands", func() {
+		SkipBeforeRedisMajor(8, "permissions for modules are supported for Redis Version >=8")
+		Expect(client.FlushDB(ctx).Err()).NotTo(HaveOccurred())
+		val, err := client.FTCreate(ctx, "txt", &redis.FTCreateOptions{}, &redis.FieldSchema{FieldName: "txt", FieldType: redis.SearchFieldTypeText}).Result()
+		Expect(err).NotTo(HaveOccurred())
+		Expect(val).To(BeEquivalentTo("OK"))
+		WaitForIndexing(client, "txt")
+		client.HSet(ctx, "doc1", "txt", "foo baz")
+		client.HSet(ctx, "doc2", "txt", "foo bar")
+		add, err := client.ACLSetUser(ctx,
+			TestUserName,
+			"reset",
+			"nopass",
+			"on",
+			"~*",
+			"+FT.SEARCH",
+			"-FT.DROPINDEX",
+			"+json.set",
+			"+json.get",
+			"-json.clear",
+			"+bf.reserve",
+			"-bf.info",
+			"+cf.reserve",
+			"+cms.initbydim",
+			"+topk.reserve",
+			"+tdigest.create",
+			"+ts.create",
+			"-ts.info",
+		).Result()
+		Expect(err).NotTo(HaveOccurred())
+		Expect(add).To(Equal("OK"))
+
+		c := client.Conn()
+		authed, err := c.AuthACL(ctx, TestUserName, "").Result()
+		Expect(err).NotTo(HaveOccurred())
+		Expect(authed).To(Equal("OK"))
+
+		// has perm for search
+		Expect(c.FTSearch(ctx, "txt", "foo ~bar").Err()).NotTo(HaveOccurred())
+
+		// no perm for dropindex
+		err = c.FTDropIndex(ctx, "txt").Err()
+		Expect(err).ToNot(BeEmpty())
+		Expect(err.Error()).To(ContainSubstring("NOPERM"))
+
+		// json set and get have perm
+		Expect(c.JSONSet(ctx, "foo", "$", "\"bar\"").Err()).NotTo(HaveOccurred())
+		Expect(c.JSONGet(ctx, "foo", "$").Val()).To(BeEquivalentTo("[\"bar\"]"))
+
+		// no perm for json clear
+		err = c.JSONClear(ctx, "foo", "$").Err()
+		Expect(err).ToNot(BeEmpty())
+		Expect(err.Error()).To(ContainSubstring("NOPERM"))
+
+		// perm for reserve
+		Expect(c.BFReserve(ctx, "bloom", 0.01, 100).Err()).NotTo(HaveOccurred())
+
+		// no perm for info
+		err = c.BFInfo(ctx, "bloom").Err()
+		Expect(err).ToNot(BeEmpty())
+		Expect(err.Error()).To(ContainSubstring("NOPERM"))
+
+		// perm for cf.reserve
+		Expect(c.CFReserve(ctx, "cfres", 100).Err()).NotTo(HaveOccurred())
+		// perm for cms.initbydim
+		Expect(c.CMSInitByDim(ctx, "cmsdim", 100, 5).Err()).NotTo(HaveOccurred())
+		// perm for topk.reserve
+		Expect(c.TopKReserve(ctx, "topk", 10).Err()).NotTo(HaveOccurred())
+		// perm for tdigest.create
+		Expect(c.TDigestCreate(ctx, "tdc").Err()).NotTo(HaveOccurred())
+		// perm for ts.create
+		Expect(c.TSCreate(ctx, "tsts").Err()).NotTo(HaveOccurred())
+		// noperm for ts.info
+		err = c.TSInfo(ctx, "tsts").Err()
+		Expect(err).ToNot(BeEmpty())
+		Expect(err.Error()).To(ContainSubstring("NOPERM"))
+
+		Expect(client.FlushDB(ctx).Err()).NotTo(HaveOccurred())
+	})
+
+	It("set permissions for module categories", func() {
+		SkipBeforeRedisMajor(8, "permissions for modules are supported for Redis Version >=8")
+		Expect(client.FlushDB(ctx).Err()).NotTo(HaveOccurred())
+		val, err := client.FTCreate(ctx, "txt", &redis.FTCreateOptions{}, &redis.FieldSchema{FieldName: "txt", FieldType: redis.SearchFieldTypeText}).Result()
+		Expect(err).NotTo(HaveOccurred())
+		Expect(val).To(BeEquivalentTo("OK"))
+		WaitForIndexing(client, "txt")
+		client.HSet(ctx, "doc1", "txt", "foo baz")
+		client.HSet(ctx, "doc2", "txt", "foo bar")
+		add, err := client.ACLSetUser(ctx,
+			TestUserName,
+			"reset",
+			"nopass",
+			"on",
+			"~*",
+			"+@search",
+			"+@json",
+			"+@bloom",
+			"+@cuckoo",
+			"+@topk",
+			"+@cms",
+			"+@timeseries",
+			"+@tdigest",
+		).Result()
+		Expect(err).NotTo(HaveOccurred())
+		Expect(add).To(Equal("OK"))
+
+		c := client.Conn()
+		authed, err := c.AuthACL(ctx, TestUserName, "").Result()
+		Expect(err).NotTo(HaveOccurred())
+		Expect(authed).To(Equal("OK"))
+
+		// has perm for search
+		Expect(c.FTSearch(ctx, "txt", "foo ~bar").Err()).NotTo(HaveOccurred())
+		// perm for dropindex
+		Expect(c.FTDropIndex(ctx, "txt").Err()).NotTo(HaveOccurred())
+		// json set and get have perm
+		Expect(c.JSONSet(ctx, "foo", "$", "\"bar\"").Err()).NotTo(HaveOccurred())
+		Expect(c.JSONGet(ctx, "foo", "$").Val()).To(BeEquivalentTo("[\"bar\"]"))
+		// perm for json clear
+		Expect(c.JSONClear(ctx, "foo", "$").Err()).NotTo(HaveOccurred())
+		// perm for reserve
+		Expect(c.BFReserve(ctx, "bloom", 0.01, 100).Err()).NotTo(HaveOccurred())
+		// perm for info
+		Expect(c.BFInfo(ctx, "bloom").Err()).NotTo(HaveOccurred())
+		// perm for cf.reserve
+		Expect(c.CFReserve(ctx, "cfres", 100).Err()).NotTo(HaveOccurred())
+		// perm for cms.initbydim
+		Expect(c.CMSInitByDim(ctx, "cmsdim", 100, 5).Err()).NotTo(HaveOccurred())
+		// perm for topk.reserve
+		Expect(c.TopKReserve(ctx, "topk", 10).Err()).NotTo(HaveOccurred())
+		// perm for tdigest.create
+		Expect(c.TDigestCreate(ctx, "tdc").Err()).NotTo(HaveOccurred())
+		// perm for ts.create
+		Expect(c.TSCreate(ctx, "tsts").Err()).NotTo(HaveOccurred())
+		// perm for ts.info
+		Expect(c.TSInfo(ctx, "tsts").Err()).NotTo(HaveOccurred())
+
+		Expect(client.FlushDB(ctx).Err()).NotTo(HaveOccurred())
+	})
+})
+
+var _ = Describe("ACL Categories", func() {
+	var client *redis.Client
+	var ctx context.Context
+
+	BeforeEach(func() {
+		ctx = context.Background()
+		opt := redisOptions()
+		client = redis.NewClient(opt)
+	})
+
+	AfterEach(func() {
+		Expect(client.Close()).NotTo(HaveOccurred())
+	})
+
+	It("lists acl categories and subcategories", func() {
+		res, err := client.ACLCat(ctx).Result()
+		Expect(err).NotTo(HaveOccurred())
+		Expect(len(res)).To(BeNumerically(">", 20))
+		Expect(res).To(ContainElements(
+			"read",
+			"write",
+			"keyspace",
+			"dangerous",
+			"slow",
+			"set",
+			"sortedset",
+			"list",
+			"hash",
+		))
+
+		res, err = client.ACLCatArgs(ctx, &redis.ACLCatArgs{Category: "read"}).Result()
+		Expect(err).NotTo(HaveOccurred())
+		Expect(res).To(ContainElement("get"))
+	})
+
+	It("lists acl categories and subcategories with Modules", func() {
+		SkipBeforeRedisMajor(8, "modules are included in acl for redis version >= 8")
+		aclTestCase := map[string]string{
+			"search":     "FT.CREATE",
+			"bloom":      "bf.add",
+			"json":       "json.get",
+			"cuckoo":     "cf.insert",
+			"cms":        "cms.query",
+			"topk":       "topk.list",
+			"tdigest":    "tdigest.rank",
+			"timeseries": "ts.range",
+		}
+		var cats []interface{}
+
+		for cat, subitem := range aclTestCase {
+			cats = append(cats, cat)
+
+			res, err := client.ACLCatArgs(ctx, &redis.ACLCatArgs{
+				Category: cat,
+			}).Result()
+			Expect(err).NotTo(HaveOccurred())
+			Expect(res).To(ContainElement(subitem))
+		}
+
+		res, err := client.ACLCat(ctx).Result()
+		Expect(err).NotTo(HaveOccurred())
+		Expect(res).To(ContainElements(cats...))
+	})
+})
diff --git a/commands_test.go b/commands_test.go
--- a/commands_test.go
+++ b/commands_test.go
@@ -211,13 +211,13 @@ var _ = Describe("Commands", func() {
 			select {
 			case <-done:
 				Fail("BLPOP is not blocked.")
-			case <-time.After(2 * time.Second):
+			case <-time.After(1 * time.Second):
 				// ok
 			}
 
 			killed := client.ClientKillByFilter(ctx, "MAXAGE", "1")
 			Expect(killed.Err()).NotTo(HaveOccurred())
-			Expect(killed.Val()).To(SatisfyAny(Equal(int64(2)), Equal(int64(3))))
+			Expect(killed.Val()).To(SatisfyAny(Equal(int64(2)), Equal(int64(3)), Equal(int64(4))))
 
 			select {
 			case <-done:
@@ -2228,12 +2228,6 @@ var _ = Describe("Commands", func() {
 			Expect(replace.Val()).To(Equal(int64(1)))
 		})
 
-		It("should acl dryrun", func() {
-			dryRun := client.ACLDryRun(ctx, "default", "get", "randomKey")
-			Expect(dryRun.Err()).NotTo(HaveOccurred())
-			Expect(dryRun.Val()).To(Equal("OK"))
-		})
-
 		It("should fail module loadex", Label("NonRedisEnterprise"), func() {
 			dryRun := client.ModuleLoadex(ctx, &redis.ModuleLoadexConfig{
 				Path: "/path/to/non-existent-library.so",
@@ -2281,51 +2275,6 @@ var _ = Describe("Commands", func() {
 
 			Expect(args).To(Equal(expectedArgs))
 		})
-
-		It("should ACL LOG", Label("NonRedisEnterprise"), func() {
-			err := client.Do(ctx, "acl", "setuser", "test", ">test", "on", "allkeys", "+get").Err()
-			Expect(err).NotTo(HaveOccurred())
-
-			clientAcl := redis.NewClient(redisOptions())
-			clientAcl.Options().Username = "test"
-			clientAcl.Options().Password = "test"
-			clientAcl.Options().DB = 0
-			_ = clientAcl.Set(ctx, "mystring", "foo", 0).Err()
-			_ = clientAcl.HSet(ctx, "myhash", "foo", "bar").Err()
-			_ = clientAcl.SAdd(ctx, "myset", "foo", "bar").Err()
-
-			logEntries, err := client.ACLLog(ctx, 10).Result()
-			Expect(err).NotTo(HaveOccurred())
-			Expect(len(logEntries)).To(Equal(4))
-
-			for _, entry := range logEntries {
-				Expect(entry.Reason).To(Equal("command"))
-				Expect(entry.Context).To(Equal("toplevel"))
-				Expect(entry.Object).NotTo(BeEmpty())
-				Expect(entry.Username).To(Equal("test"))
-				Expect(entry.AgeSeconds).To(BeNumerically(">=", 0))
-				Expect(entry.ClientInfo).NotTo(BeNil())
-				Expect(entry.EntryID).To(BeNumerically(">=", 0))
-				Expect(entry.TimestampCreated).To(BeNumerically(">=", 0))
-				Expect(entry.TimestampLastUpdated).To(BeNumerically(">=", 0))
-			}
-
-			limitedLogEntries, err := client.ACLLog(ctx, 2).Result()
-			Expect(err).NotTo(HaveOccurred())
-			Expect(len(limitedLogEntries)).To(Equal(2))
-		})
-
-		It("should ACL LOG RESET", Label("NonRedisEnterprise"), func() {
-			// Call ACL LOG RESET
-			resetCmd := client.ACLLogReset(ctx)
-			Expect(resetCmd.Err()).NotTo(HaveOccurred())
-			Expect(resetCmd.Val()).To(Equal("OK"))
-
-			// Verify that the log is empty after the reset
-			logEntries, err := client.ACLLog(ctx, 10).Result()
-			Expect(err).NotTo(HaveOccurred())
-			Expect(len(logEntries)).To(Equal(0))
-		})
 	})
 
 	Describe("hashes", func() {
EOF_114329324912

# Set environment variables for native Redis setup (NOT Docker mode)
# When Docker is not available, the test suite uses locally built Redis
export REDIS_PORT=6380
export REDIS_MAJOR_VERSION=7
export GO111MODULE=on
# Unset Docker-related variables since Docker is not available
unset RCE_DOCKER
unset RE_CLUSTER

echo "Setting up Redis from source..."

# Download and build Redis 7.4.2 from source
cd /tmp
if [ ! -f redis-7.4.2.tar.gz ]; then
    echo "Downloading Redis 7.4.2..."
    wget -q https://download.redis.io/releases/redis-7.4.2.tar.gz
fi

echo "Extracting Redis..."
tar xzf redis-7.4.2.tar.gz
cd redis-7.4.2

echo "Building Redis (this may take a few minutes)..."
make all -j$(nproc) > /dev/null 2>&1

# Create testdata directory structure and copy Redis binaries
echo "Setting up Redis binaries in testdata..."
cd /testbed
mkdir -p testdata/redis/src
cp /tmp/redis-7.4.2/src/redis-server testdata/redis/src/
cp /tmp/redis-7.4.2/src/redis-cli testdata/redis/src/
chmod +x testdata/redis/src/redis-server
chmod +x testdata/redis/src/redis-cli

# Verify Redis binary is in place
if [ ! -f testdata/redis/src/redis-server ]; then
    echo "ERROR: redis-server binary not found at testdata/redis/src/redis-server"
    exit 1
fi

echo "Redis binary setup complete"
testdata/redis/src/redis-server --version

# Create Redis configuration files if they don't exist
echo "Creating Redis configuration files..."

mkdir -p testdata/redis

# Main Redis configuration
cat > testdata/redis/redis.conf <<'REDISCONF'
bind 0.0.0.0
protected-mode no
port 6380
tcp-backlog 511
timeout 0
tcp-keepalive 300
daemonize no
supervised no
pidfile /var/run/redis_6380.pid
loglevel notice
logfile ""
databases 16
always-show-logo no
save ""
stop-writes-on-bgsave-error yes
rdbcompression yes
rdbchecksum yes
dbfilename dump.rdb
dir ./
replica-serve-stale-data yes
replica-read-only yes
repl-diskless-sync no
repl-diskless-sync-delay 5
repl-disable-tcp-nodelay no
replica-priority 100
lazyfree-lazy-eviction no
lazyfree-lazy-expire no
lazyfree-lazy-server-del no
replica-lazy-flush no
appendonly no
appendfilename "appendonly.aof"
appendfsync everysec
no-appendfsync-on-rewrite no
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb
aof-load-truncated yes
aof-use-rdb-preamble yes
lua-time-limit 5000
slowlog-log-slower-than 10000
slowlog-max-len 128
latency-monitor-threshold 0
notify-keyspace-events ""
hash-max-ziplist-entries 512
hash-max-ziplist-value 64
list-max-ziplist-size -2
list-compress-depth 0
set-max-intset-entries 512
zset-max-ziplist-entries 128
zset-max-ziplist-value 64
hll-sparse-max-bytes 3000
stream-node-max-bytes 4096
stream-node-max-entries 100
activerehashing yes
client-output-buffer-limit normal 0 0 0
client-output-buffer-limit replica 256mb 64mb 60
client-output-buffer-limit pubsub 32mb 8mb 60
hz 10
dynamic-hz yes
aof-rewrite-incremental-fsync yes
rdb-save-incremental-fsync yes
enable-debug-command yes
enable-module-command yes
REDISCONF

# Sentinel configuration
cat > testdata/redis/sentinel.conf <<'SENTINELCONF'
port 26379
dir /tmp
sentinel monitor mymaster 127.0.0.1 6380 2
sentinel down-after-milliseconds mymaster 5000
sentinel parallel-syncs mymaster 1
sentinel failover-timeout mymaster 10000
SENTINELCONF

echo "Configuration files created"

# Run the tests
# The BeforeSuite in main_test.go will automatically start Redis instances using the binary in testdata/redis/src/
echo "Running tests..."
cd /testbed

# Run tests with focus on commands_test.go and explicitly skip other test files
# Use -run flag to exclude Example tests which try to connect to port 6379
go test -v \
    --ginkgo.focus-file="commands_test.go" \
    --ginkgo.skip-file="timeseries_commands_test.go" \
    --ginkgo.skip-file="gears_commands_test.go" \
    --ginkgo.skip-file="ring_test.go" \
    --ginkgo.skip-file="sentinel_test.go" \
    --ginkgo.skip-file="pubsub_test.go" \
    --ginkgo.skip-file="osscluster_test.go" \
    --ginkgo.skip-file="cluster_test.go" \
    -run '^Test' \
    -timeout 30m \
    2>&1

# Capture exit code
rc=$?

# Cleanup any leftover Redis processes
echo "Cleaning up Redis processes..."
pkill -9 redis-server 2>/dev/null || true
pkill -9 redis-sentinel 2>/dev/null || true

# Echo exit code for test result verification
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files
git checkout 3d4310ae9696cadc8eaeab747158abe1d03d8b7a "commands_test.go" "acl_commands_test.go"

# Exit with the test result code
exit $rc