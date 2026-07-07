// ===============================
// Частина 4 — Виявлення супервузлів
// ===============================


// 1. Користувачі з найбільшою кількістю оцінок
MATCH (u:User)-[r:RATED]->(:Movie)
RETURN u.userId AS userId,
       count(r) AS degree
ORDER BY degree DESC
LIMIT 20;


// 2. Фільми з найбільшою кількістю оцінок
MATCH (:User)-[r:RATED]->(m:Movie)
RETURN m.movieId AS movieId,
       m.title AS title,
       count(r) AS degree
ORDER BY degree DESC
LIMIT 20;


// 3. Жанри з найбільшою кількістю фільмів
MATCH (m:Movie)-[rel:HAS_GENRE]->(g:Genre)
RETURN g.name AS genre,
       count(rel) AS degree
ORDER BY degree DESC;


// 4. Загальний пошук вузлів із найбільшою кількістю зв’язків
MATCH (n)
WITH n, count { (n)--() } AS degree
RETURN labels(n) AS labels,
       n.userId AS userId,
       n.movieId AS movieId,
       n.title AS title,
       n.name AS name,
       degree
ORDER BY degree DESC
LIMIT 30;