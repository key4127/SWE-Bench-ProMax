#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test files to ensure clean state
git checkout 8f754a56815a6065cf5841baccd3b5b9158ac387 "hibernate-core/src/test/java/org/hibernate/orm/test/idprops/IdPropertyInSubclassIdInMappedSuperclassTest.java" "hibernate-core/src/test/java/org/hibernate/orm/test/jpa/graphs/EntityGraphTest.java"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/hibernate-core/src/test/java/org/hibernate/orm/test/idprops/IdPropertyInSubclassIdInMappedSuperclassTest.java b/hibernate-core/src/test/java/org/hibernate/orm/test/idprops/IdPropertyInSubclassIdInMappedSuperclassTest.java
--- a/hibernate-core/src/test/java/org/hibernate/orm/test/idprops/IdPropertyInSubclassIdInMappedSuperclassTest.java
+++ b/hibernate-core/src/test/java/org/hibernate/orm/test/idprops/IdPropertyInSubclassIdInMappedSuperclassTest.java
@@ -75,14 +75,22 @@ public void testHql(SessionFactoryScope scope) {
 
 			assertEquals(
 					2,
-					session.createQuery( "from Human h where h.id = :id", Human.class )
+					session.createQuery( "from Genius g where g.id = :id", Human.class )
 							.setParameter( "id", 1L )
 							.list()
 							.size()
 			);
 
 			assertEquals(
 					1,
+					session.createQuery( "from Human h where h.id = :id", Human.class )
+							.setParameter( "id", 1L )
+							.list()
+							.size()
+			);
+
+			assertEquals(
+					0,
 					session.createQuery( "from Human h where h.id is null", Human.class )
 							.list()
 							.size()
diff --git a/hibernate-core/src/test/java/org/hibernate/orm/test/jpa/graphs/EntityGraphTest.java b/hibernate-core/src/test/java/org/hibernate/orm/test/jpa/graphs/EntityGraphTest.java
--- a/hibernate-core/src/test/java/org/hibernate/orm/test/jpa/graphs/EntityGraphTest.java
+++ b/hibernate-core/src/test/java/org/hibernate/orm/test/jpa/graphs/EntityGraphTest.java
@@ -10,6 +10,7 @@
 import java.util.List;
 import java.util.Map;
 import java.util.Set;
+import java.util.UUID;
 import java.util.stream.Collectors;
 import java.util.stream.IntStream;
 
@@ -37,7 +38,6 @@
 import org.hibernate.testing.util.uuid.SafeRandomUUIDGenerator;
 import org.hibernate.orm.test.jpa.BaseEntityManagerFunctionalTestCase;
 
-import org.hibernate.testing.orm.junit.JiraKey;
 import org.hibernate.testing.orm.junit.JiraKey;
 import org.junit.Test;
 
@@ -55,7 +55,8 @@ public class EntityGraphTest extends BaseEntityManagerFunctionalTestCase {
 	protected Class<?>[] getAnnotatedClasses() {
 		return new Class[] {
 				Foo.class, Bar.class, Baz.class, Author.class, Book.class, Prize.class, Company.class,
-				Employee.class, Manager.class, Location.class, AnimalOwner.class, Animal.class, Dog.class, Cat.class
+				Employee.class, Manager.class, Location.class, AnimalOwner.class, Animal.class, Dog.class, Cat.class,
+				Kennel.class
 		};
 	}
 
@@ -216,7 +217,7 @@ public void inheritanceTest() {
 
 		assertTrue( Hibernate.isInitialized( result ) );
 		assertTrue( Hibernate.isInitialized( result.employees ) );
-		assertEquals( result.employees.size(), 2 );
+		assertEquals( 2, result.employees.size() );
 		for (Employee resultEmployee : result.employees) {
 			assertTrue( Hibernate.isInitialized( resultEmployee.managers ) );
 			assertTrue( Hibernate.isInitialized( resultEmployee.friends ) );
@@ -256,17 +257,17 @@ public void attributeNodeInheritanceTest() {
 
 		assertTrue( Hibernate.isInitialized( result ) );
 		assertTrue( Hibernate.isInitialized( result.friends ) );
-		assertEquals( result.friends.size(), 1 );
+		assertEquals( 1, result.friends.size() );
 		assertTrue( Hibernate.isInitialized( result.managers) );
-		assertEquals( result.managers.size(), 1 );
+		assertEquals( 1, result.managers.size() );
 
 		em.getTransaction().commit();
 		em.close();
 	}
 
 	@Test
 	@JiraKey(value = "HHH-9735")
-	public void loadIsMemeberQueriedCollection() {
+	public void loadIsMemberQueriedCollection() {
 
 		EntityManager em = getOrCreateEntityManager();
 		em.getTransaction().begin();
@@ -484,6 +485,40 @@ public void joinedInheritanceWithSubEntityAttributeFiltering() {
 		em.close();
 	}
 
+	@Test
+	public void testTreatedSubgraph() {
+		EntityManager em = getOrCreateEntityManager();
+		em.getTransaction().begin();
+		Kennel kennel = new Kennel();
+		em.persist( kennel );
+		Dog dog = new Dog();
+		dog.kennel = kennel;
+		em.persist( dog );
+		em.flush();
+		em.clear();
+
+		EntityGraph<Dog> graph = em.createEntityGraph( Dog.class );
+		graph.addAttributeNode( "kennel" );
+		Dog doggie = em.find( graph, dog.id );
+		assertTrue( Hibernate.isInitialized( doggie.kennel ) );
+
+		em.clear();
+
+		EntityGraph<Animal> withKennel = em.createEntityGraph( Animal.class );
+		withKennel.addTreatedSubgraph( Dog.class ).addAttributeNode( "kennel" );
+		Animal animal = em.find( withKennel, doggie.id );
+		assertTrue( Hibernate.isInitialized( ( (Dog) animal ).kennel ) );
+
+		em.clear();
+
+		EntityGraph<Animal> withoutKennel = em.createEntityGraph( Animal.class );
+		animal = em.find( withoutKennel, doggie.id );
+		assertFalse( Hibernate.isInitialized( ( (Dog) animal ).kennel ) );
+
+		em.getTransaction().rollback();
+		em.close();
+	}
+
 	@Entity(name = "Foo")
 	@Table(name = "foo")
 	public static class Foo {
@@ -508,7 +543,7 @@ public static class Bar {
 		public Integer id;
 
 		@OneToMany(mappedBy = "bar")
-		public Set<Foo> foos = new HashSet<Foo>();
+		public Set<Foo> foos = new HashSet<>();
 
 		public Set<Foo> getFoos() {
 			return foos;
@@ -524,7 +559,7 @@ public static class Baz {
 		public Integer id;
 
 		@OneToMany(mappedBy = "baz")
-		public Set<Foo> foos = new HashSet<Foo>();
+		public Set<Foo> foos = new HashSet<>();
 
 		public Set<Foo> getFoos() {
 			return foos;
@@ -620,6 +655,9 @@ public static class Dog extends Animal {
 
 		public Integer numberOfLegs;
 
+		@ManyToOne(fetch = FetchType.LAZY)
+		Kennel kennel;
+
 		public Dog() {
 			dtype = "DOG";
 		}
@@ -635,4 +673,10 @@ public Cat() {
 			dtype = "CAT";
 		}
 	}
+
+	@Entity(name = "Kennel")
+	public static class Kennel {
+		@Id @GeneratedValue
+		UUID uuid;
+	}
 }
EOF_114329324912

# Execute the target tests using Gradle
# Using --no-daemon for container environment
# Using --no-build-cache to disable the build cache (avoids remote cache issues)
# Using --rerun-tasks to force re-execution of tasks
# Using --console=plain for better output
# Running both test classes in a single command for efficiency
./gradlew :hibernate-core:test \
    --tests "org.hibernate.orm.test.idprops.IdPropertyInSubclassIdInMappedSuperclassTest" \
    --tests "org.hibernate.orm.test.jpa.graphs.EntityGraphTest" \
    --no-daemon \
    --no-build-cache \
    --rerun-tasks \
    --console=plain

# Capture exit code
rc=$?

# Echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files
git checkout 8f754a56815a6065cf5841baccd3b5b9158ac387 "hibernate-core/src/test/java/org/hibernate/orm/test/idprops/IdPropertyInSubclassIdInMappedSuperclassTest.java" "hibernate-core/src/test/java/org/hibernate/orm/test/jpa/graphs/EntityGraphTest.java"