#!/bin/bash
set -uxo pipefail

# Set environment variables
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH
export GRADLE_OPTS="-Dlog4j2.disableJmx=true -Xmx2g -XX:MaxMetaspaceSize=256m -XX:+HeapDumpOnOutOfMemoryError -Duser.language=en -Duser.country=US -Duser.timezone=UTC -Dfile.encoding=UTF-8"

# Navigate to testbed
cd /testbed

# Checkout the original test files to ensure clean state
git checkout 05b8d0dbe92fc8e70d32d55a41f7af82f9882130 "hibernate-core/src/test/java/org/hibernate/orm/test/entitygraph/parser/EntityGraphParserTest.java" "hibernate-core/src/test/java/org/hibernate/orm/test/jpa/graphs/EntityGraphTest.java"

echo "=========================================="
echo "Applying test patch"
echo "=========================================="
# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/hibernate-core/src/test/java/org/hibernate/orm/test/entitygraph/parser/EntityGraphParserTest.java b/hibernate-core/src/test/java/org/hibernate/orm/test/entitygraph/parser/EntityGraphParserTest.java
--- a/hibernate-core/src/test/java/org/hibernate/orm/test/entitygraph/parser/EntityGraphParserTest.java
+++ b/hibernate-core/src/test/java/org/hibernate/orm/test/entitygraph/parser/EntityGraphParserTest.java
@@ -176,7 +176,7 @@ public void testLinkSubtypeParsing() {
 		RootGraphImplementor<GraphParsingTestEntity> graph = parseGraph( "linkToOne(name, description), linkToOne(GraphParsingTestSubEntity: sub)" );
 		assertNotNull( graph );
 
-		List<AttributeNodeImplementor<?>> attrs = graph.getAttributeNodeImplementors();
+		List<? extends AttributeNodeImplementor<?>> attrs = graph.getAttributeNodeList();
 		assertNotNull( attrs );
 		assertEquals( 1, attrs.size() );
 
diff --git a/hibernate-core/src/test/java/org/hibernate/orm/test/jpa/graphs/EntityGraphTest.java b/hibernate-core/src/test/java/org/hibernate/orm/test/jpa/graphs/EntityGraphTest.java
--- a/hibernate-core/src/test/java/org/hibernate/orm/test/jpa/graphs/EntityGraphTest.java
+++ b/hibernate-core/src/test/java/org/hibernate/orm/test/jpa/graphs/EntityGraphTest.java
@@ -4,6 +4,7 @@
  */
 package org.hibernate.orm.test.jpa.graphs;
 
+import jakarta.persistence.ManyToMany;
 import jakarta.persistence.MapKey;
 import java.util.HashMap;
 import java.util.HashSet;
@@ -34,6 +35,8 @@
 import jakarta.persistence.criteria.Expression;
 import jakarta.persistence.criteria.Root;
 
+import jakarta.persistence.metamodel.Attribute;
+import jakarta.persistence.metamodel.PluralAttribute;
 import org.hibernate.Hibernate;
 import org.hibernate.testing.util.uuid.SafeRandomUUIDGenerator;
 import org.hibernate.orm.test.jpa.BaseEntityManagerFunctionalTestCase;
@@ -519,6 +522,127 @@ public void testTreatedSubgraph() {
 		em.close();
 	}
 
+	@Test
+	public void testElementSubgraph() {
+		EntityManager em = getOrCreateEntityManager();
+		em.getTransaction().begin();
+		Bar bar = new Bar();
+		Foo foo = new Foo();
+		Baz baz = new Baz();
+		foo.baz = baz;
+		foo.bar = bar;
+		bar.foos.add( foo );
+		baz.foos.add( foo );
+		em.persist( bar );
+		em.persist( baz );
+		em.persist( foo );
+		em.flush();
+		em.clear();
+
+		EntityGraph<Bar> graph = em.createEntityGraph( Bar.class );
+		Subgraph<Foo> subgraph = graph.addElementSubgraph( "foos", Foo.class );
+		subgraph.addAttributeNode( "baz" );
+		Bar b = em.find( graph, bar.id );
+		assertTrue( Hibernate.isInitialized( b.foos ) );
+		assertTrue( Hibernate.isInitialized( b.foos.iterator().next().baz ) );
+
+		em.getTransaction().rollback();
+		em.close();
+	}
+
+	@Test
+	public void testTreatedElementSubgraph() {
+		EntityManager em = getOrCreateEntityManager();
+		em.getTransaction().begin();
+		AnimalOwner animalOwner = new AnimalOwner();
+		Dog dog = new Dog();
+		Cat cat = new Cat();
+		Kennel kennel = new Kennel();
+		dog.kennel = kennel;
+		animalOwner.animals.add( dog );
+		animalOwner.animals.add( cat );
+		em.persist( animalOwner );
+		em.persist( kennel );
+		em.persist( dog );
+		em.persist( cat );
+		em.flush();
+		em.clear();
+
+		PluralAttribute<? super AnimalOwner, ?, Animal> animalsAttribute =
+				(PluralAttribute<? super AnimalOwner, ?, Animal>)
+						em.getEntityManagerFactory().getMetamodel()
+								.entity( AnimalOwner.class )
+								.getAttribute( "animals" );
+
+		EntityGraph<AnimalOwner> graph = em.createEntityGraph( AnimalOwner.class );
+		Subgraph<Animal> subgraph = graph.addElementSubgraph( animalsAttribute );
+		AnimalOwner owner = em.find( graph, animalOwner.id );
+		assertTrue( Hibernate.isInitialized( owner.animals ) );
+		assertEquals( 2, owner.animals.size() );
+		owner.animals.forEach( animal -> {
+			if (animal instanceof Dog d ) {
+				assertFalse( Hibernate.isInitialized( d.kennel ) );
+			}
+		} );
+
+		em.clear();
+
+		graph = em.createEntityGraph( AnimalOwner.class );
+		subgraph = graph.addElementSubgraph( animalsAttribute );
+		Subgraph<Dog> treated = graph.addTreatedElementSubgraph( animalsAttribute, Dog.class );
+		treated.addAttributeNode( "kennel" );
+		owner = em.find( graph, animalOwner.id );
+		assertTrue( Hibernate.isInitialized( owner.animals ) );
+		assertEquals( 2, owner.animals.size() );
+		owner.animals.forEach( animal -> {
+			if (animal instanceof Dog d ) {
+				assertTrue( Hibernate.isInitialized( d.kennel ) );
+			}
+		} );
+
+		em.getTransaction().rollback();
+		em.close();
+	}
+
+	@Test
+	public void testTreatedElementSubgraph2() {
+		EntityManager em = getOrCreateEntityManager();
+		em.getTransaction().begin();
+		AnimalOwner animalOwner = new AnimalOwner();
+		Dog dog = new Dog();
+		Cat cat = new Cat();
+		Kennel kennel = new Kennel();
+		dog.kennel = kennel;
+		animalOwner.animals.add( dog );
+		animalOwner.animals.add( cat );
+		em.persist( animalOwner );
+		em.persist( kennel );
+		em.persist( dog );
+		em.persist( cat );
+		em.flush();
+		em.clear();
+
+		Attribute<? super Dog, Kennel> kennelAttribute =
+				(Attribute<? super Dog, Kennel>)
+						em.getEntityManagerFactory().getMetamodel()
+								.entity( Dog.class )
+								.getAttribute( "kennel" );
+
+		EntityGraph<Animal> graph = em.createEntityGraph( Animal.class );
+		Animal animal = em.find( graph, dog.id );
+		assertFalse( Hibernate.isInitialized( ((Dog) animal).kennel ) );
+
+		em.clear();
+
+		graph = em.createEntityGraph( Animal.class );
+		graph.addTreatedSubgraph( Dog.class ).addAttributeNode( kennelAttribute );
+		animal = em.find( graph, dog.id );
+		assertTrue( Hibernate.isInitialized( ((Dog) animal).kennel ) );
+
+		em.getTransaction().rollback();
+		em.close();
+	}
+
 	@Entity(name = "Foo")
 	@Table(name = "foo")
 	public static class Foo {
@@ -637,6 +761,9 @@ public static class AnimalOwner {
 
 		@ManyToOne(fetch = FetchType.LAZY)
 		public Animal animal;
+
+		@ManyToMany
+		public Set<Animal> animals = new HashSet<>();
 	}
 
 	@Entity(name = "Animal")
EOF_114329324912

echo "=========================================="
echo "Compiling test classes"
echo "=========================================="
./gradlew --no-daemon --no-build-cache hibernate-core:compileTestJava --console=plain

echo "=========================================="
echo "Running tests"
echo "=========================================="
# Execute the target tests using Gradle with --no-build-cache to avoid remote cache issues
./gradlew --no-daemon --no-build-cache hibernate-core:test \
    --tests org.hibernate.orm.test.entitygraph.parser.EntityGraphParserTest \
    --tests org.hibernate.orm.test.jpa.graphs.EntityGraphTest \
    --console=plain

# Capture the exit code
rc=$?

echo "=========================================="
echo "Test Execution Summary"
echo "=========================================="

# Determine the correct test results directory
TEST_RESULTS_DIR=""
if [ -d "/testbed/hibernate-core/target/test-results/test" ]; then
    TEST_RESULTS_DIR="/testbed/hibernate-core/target/test-results/test"
    echo "Found test results in target/ directory"
elif [ -d "/testbed/hibernate-core/build/test-results/test" ]; then
    TEST_RESULTS_DIR="/testbed/hibernate-core/build/test-results/test"
    echo "Found test results in build/ directory"
fi

# Display test results
if [ -n "$TEST_RESULTS_DIR" ]; then
    echo "Test result files in $TEST_RESULTS_DIR:"
    ls -la "$TEST_RESULTS_DIR/" || true
    
    # Display XML test results
    for xml_file in "$TEST_RESULTS_DIR"/*.xml; do
        if [ -f "$xml_file" ]; then
            echo "=========================================="
            echo "Content of $xml_file:"
            cat "$xml_file"
            echo ""
        fi
    done
else
    echo "No test results directory found"
    # Search for test results anywhere
    find /testbed/hibernate-core -name "TEST-*.xml" -type f 2>/dev/null || echo "No XML test results found"
fi

# Echo exit code for judge
echo "=========================================="
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files
git checkout 05b8d0dbe92fc8e70d32d55a41f7af82f9882130 "hibernate-core/src/test/java/org/hibernate/orm/test/entitygraph/parser/EntityGraphParserTest.java" "hibernate-core/src/test/java/org/hibernate/orm/test/jpa/graphs/EntityGraphTest.java"