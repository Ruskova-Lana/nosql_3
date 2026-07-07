// ===============================
// Частина 5 — Graph Data Science
// ===============================


// =====================================================
// 5.1 PageRank на графі фільмів
// =====================================================

// Крок 1: матеріалізуємо ребра фільм-фільм
MATCH (m1:Movie)<-[r1:RATED]-(u:User)-[r2:RATED]->(m2:Movie)
WHERE r1.rating >= 4 AND r2.rating >= 4 AND id(m1) < id(m2)
WITH m1, m2, count(u) AS weight
WHERE size([(m1)<-[:RATED]-() | 1]) > 20
  AND size([(m2)<-[:RATED]-() | 1]) > 20
WITH m1, m2, weight
ORDER BY weight DESC
LIMIT 50000
MERGE (m1)-[co:CO_RATED]-(m2)
SET co.weight = weight;


// Крок 2: створюємо проєкцію
CALL gds.graph.project(
  'movieGraph',
  'Movie',
  {
    CO_RATED: {
      orientation: 'UNDIRECTED',
      properties: 'weight'
    }
  }
)
YIELD graphName, nodeCount, relationshipCount;


// Крок 3: PageRank
CALL gds.pageRank.stream(
  'movieGraph',
  {
    relationshipWeightProperty: 'weight'
  }
)
YIELD nodeId, score
RETURN gds.util.asNode(nodeId).movieId AS movieId,
       gds.util.asNode(nodeId).title AS title,
       score
ORDER BY score DESC
LIMIT 20;


// Крок 4: видаляємо проєкцію та тимчасові ребра
CALL gds.graph.drop('movieGraph');

MATCH ()-[co:CO_RATED]-()
DELETE co;


// =====================================================
// 5.2 Louvain — спільноти користувачів
// =====================================================

// Крок 1: матеріалізуємо ребра користувач-користувач
MATCH (u1:User)-[r1:RATED]->(m:Movie)<-[r2:RATED]-(u2:User)
WHERE r1.rating = 5
  AND r2.rating = 5
  AND id(u1) < id(u2)

WITH u1, u2, count(m) AS weight
WHERE weight >= 5

WITH u1, u2, weight
ORDER BY weight DESC
LIMIT 10000

MERGE (u1)-[sim:SIMILAR]-(u2)
SET sim.weight = weight,
    sim.distance = 1.0 / weight;

// Крок 2: створюємо проєкцію
CALL gds.graph.project(
  'userSimilarity',
  'User',
  {
    SIMILAR: {
      orientation: 'UNDIRECTED',
      properties: ['weight', 'distance']
    }
  }
)
YIELD graphName, nodeCount, relationshipCount;


// Крок 3: запускаємо Louvain і записуємо communityId у вузли User
CALL gds.louvain.write(
  'userSimilarity',
  {
    relationshipWeightProperty: 'weight',
    writeProperty: 'communityId'
  }
)
YIELD communityCount, modularity, modularities
RETURN communityCount, modularity, modularities;


// Крок 4: 10 найбільших кластерів
MATCH (u:User)
WHERE u.communityId IS NOT NULL
RETURN u.communityId AS communityId,
       count(u) AS usersInCommunity
ORDER BY usersInCommunity DESC
LIMIT 10;


// Крок 5: топ-3 жанри для кожної з 10 найбільших спільнот
MATCH (u:User)
WHERE u.communityId IS NOT NULL
WITH u.communityId AS communityId, count(u) AS communitySize
ORDER BY communitySize DESC
LIMIT 10

MATCH (user:User {communityId: communityId})-[r:RATED]->(m:Movie)-[:HAS_GENRE]->(g:Genre)
WHERE r.rating >= 4
WITH communityId, communitySize, g.name AS genre, count(*) AS genreLikes
ORDER BY communityId, genreLikes DESC

WITH communityId,
     communitySize,
     collect({genre: genre, likes: genreLikes})[0..3] AS topGenres
RETURN communityId, communitySize, topGenres
ORDER BY communitySize DESC;


// Крок 6: видаляємо проєкцію та тимчасові ребра
CALL gds.graph.drop('userSimilarity');

MATCH ()-[sim:SIMILAR]-()
DELETE sim;


// =====================================================
// 5.3 Dijkstra — найкоротший шлях між користувачами
// =====================================================

// Крок 1: знову створюємо SIMILAR, якщо видалили після Louvain
MATCH (source:User {userId: 4169})
MATCH (target:User {userId: 1680})
CALL gds.shortestPath.dijkstra.stream(
  'userGraph',
  {
    sourceNode: source,
    targetNode: target,
    relationshipWeightProperty: 'distance'
  }
)
YIELD totalCost, nodeIds
RETURN
  source.userId AS sourceUser,
  target.userId AS targetUser,
  totalCost,
  [nodeId IN nodeIds | gds.util.asNode(nodeId).userId] AS userPath,
  size(nodeIds) - 2 AS intermediateUsers;



// Крок 2: проєкція
CALL gds.graph.project(
  'userGraph',
  'User',
  {
    SIMILAR: {
      orientation: 'UNDIRECTED',
      properties: ['weight', 'distance']
    }
  }
)
YIELD graphName, nodeCount, relationshipCount;


// Крок 3: Dijkstra для пари користувачів
MATCH (source:User {userId: 1})
MATCH (target:User {userId: 2})
CALL gds.shortestPath.dijkstra.stream(
  'userGraph',
  {
    sourceNode: source,
    targetNode: target,
    relationshipWeightProperty: 'distance'
  }
)
YIELD index, sourceNode, targetNode, totalCost, nodeIds, costs, path
RETURN
  gds.util.asNode(sourceNode).userId AS sourceUser,
  gds.util.asNode(targetNode).userId AS targetUser,
  totalCost,
  [nodeId IN nodeIds | gds.util.asNode(nodeId).userId] AS userPath,
  size(nodeIds) - 2 AS intermediateUsers;


// Крок 4: перевірка середньої довжини шляху на кількох парах
MATCH (source:User)
WHERE source.userId IN [4169, 1680, 10, 500, 1000]
MATCH (target:User)
WHERE target.userId IN [1680, 4169, 500, 1000, 3000]
  AND source.userId < target.userId
CALL gds.shortestPath.dijkstra.stream(
  'userGraph',
  {
    sourceNode: source,
    targetNode: target,
    relationshipWeightProperty: 'distance'
  }
)
YIELD nodeIds, totalCost
RETURN
  source.userId AS sourceUser,
  target.userId AS targetUser,
  size(nodeIds) - 1 AS pathLength,
  size(nodeIds) - 2 AS intermediateUsers,
  totalCost
ORDER BY pathLength;


// Крок 5: видаляємо проєкцію
CALL gds.graph.drop('userGraph');

MATCH ()-[sim:SIMILAR]-()
DELETE sim;