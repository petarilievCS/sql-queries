/*
    COMP3311 24T1 Assignment 1
    IMDB Views, SQL Functions, and PlpgSQL Functions
    Student Name: Petar Iliev
    Student ID: z5567169
*/

-- Question 1 --

/**
    Write a SQL View, called Q1, that:
    Retrieves the 10 movies with the highest number of votes.
*/
CREATE OR REPLACE VIEW Q1(Title, Year, Votes) AS
    SELECT Primary_Title, Release_Year, Votes 
    FROM Movies
    WHERE Votes IS NOT NULL 
    ORDER BY Votes 
    DESC LIMIT 10;

-- Question 2 --

/**
    Write a SQL View, called Q2(Name, Title), that:
    Retrieves the names of people who have a year of death recorded in the database
    and are well known for their work in movies released between 2017 and 2019.
*/
CREATE OR REPLACE VIEW PeopleWithYearOfDeath(ID, Name) AS
    SELECT ID, Name 
    FROM People
    WHERE Death_Year IS NOT NULL;

CREATE OR REPLACE VIEW MoviesReleasedBetween2017And2019(ID, Title) AS
    SELECT ID, Primary_Title 
    FROM Movies
    WHERE Release_Year BETWEEN 2017 AND 2019;

CREATE OR REPLACE VIEW Q2(Name, Title) AS
    SELECT pd.Name, m.Title
    FROM PeopleWithYearOfDeath pd
    JOIN Principals p ON (pd.ID = p.Person)
    JOIN MoviesReleasedBetween2017And2019 m ON (m.ID = p.Movie)
    ORDER BY pd.Name;

-- Question 3 --

/**
    Write a SQL View, called Q3(Name, Average), that:
    Retrieves the genres with an average rating not less than 6.5 and with more than 60 released movies.
*/
CREATE OR REPLACE VIEW GenresAndRatings(Genre, Score) AS
    SELECT G.Name, M.Score
    FROM Movies_Genres MG
    JOIN Movies M ON (MG.Movie = M.ID)
    JOIN Genres G ON (MG.Genre = G.ID);

CREATE OR REPLACE VIEW Q3(Name, Average) AS
    SELECT Genre AS Name, ROUND(AVG(Score), 2) AS AverageRating
    FROM GenresAndRatings
    GROUP BY Genre
    HAVING AVG(Score) >= 6.5 AND COUNT(*) > 60
    ORDER BY AverageRating DESC, Name;

-- Question 4 --

/**
    Write a SQL View, called Q4(Region, Average), that:
    Retrieves the regions with an average runtime greater than the average runtime of all movies.
*/
CREATE OR REPLACE VIEW RegionsAndMovies(Region, Movie, Runtime) AS
    SELECT R.Region, M.Primary_Title, M.Runtime
    FROM Releases R
    JOIN Movies M ON (R.Movie = M.ID)
    WHERE M.Runtime IS NOT NULL;

CREATE OR REPLACE VIEW RegionsAndAverageRuntime(Region, AverageRuntime) AS
    SELECT Region, AVG(Runtime)
    FROM RegionsAndMovies
    GROUP BY Region;

CREATE OR REPLACE VIEW AverageRuntimeOfAllMovies(AverageRuntime) AS
    SELECT AVG(Runtime)
    FROM Movies;

CREATE OR REPLACE VIEW Q4(Region, Average) AS
    SELECT Region, AverageRuntime::INTEGER::NUMERIC
    FROM RegionsAndAverageRuntime
    WHERE AverageRuntime > (SELECT AverageRuntime FROM AverageRuntimeOfAllMovies)
    ORDER BY AverageRuntime DESC, Region;

-- Question 5 --

/**
    Write a SQL Function, called Q5(Pattern TEXT) RETURNS TABLE (Movie TEXT, Length TEXT), that:
    Retrieves the movies whose title matches the given regular expression,
    and displays their runtime in hours and minutes.
*/
CREATE OR REPLACE FUNCTION Q5(Pattern TEXT)
    RETURNS TABLE (Movie TEXT, Length Text)
    AS $$
        SELECT 
            Primary_Title AS Movie, 
            CONCAT(FLOOR(Runtime / 60), ' Hours ', Runtime % 60, ' Minutes') AS Length
        FROM Movies 
        WHERE Primary_Title ~ Pattern
        AND Runtime IS NOT NULL
        ORDER BY Primary_Title
    $$ LANGUAGE SQL;

-- Question 6 --

/**
    Write a SQL Function, called Q6(GenreName TEXT) RETURNS TABLE (Year Year, Movies INTEGER), that:
    Retrieves the years with at least 10 movies released in a given genre.
*/
CREATE OR REPLACE FUNCTION Q6(GenreName TEXT)
    RETURNS TABLE (Year Year, Movies INTEGER)
    AS $$
        WITH MoviesInGenre(ReleaseYear) AS (
            SELECT Release_Year 
            FROM Movies M
            JOIN Movies_Genres MG ON (M.ID = MG.Movie)
            JOIN Genres G ON (MG.Genre = G.ID)
            WHERE G.Name = $1 AND Release_Year IS NOT NULL
        )
        SELECT 
            ReleaseYear AS Year, 
            COUNT(*) AS Movies
        FROM MoviesInGenre
        GROUP BY ReleaseYear
        HAVING COUNT(*) > 10
        ORDER BY Movies DESC, Year DESC;
    $$ LANGUAGE SQL;

-- Question 7 --

/**
    Write a SQL Function, called Q7(MovieName TEXT) RETURNS TABLE (Actor TEXT), that:
    Retrieves the actors who have played multiple different roles within the given movie.
*/
CREATE OR REPLACE FUNCTION GetActorsInMovies(MovieName TEXT) 
    RETURNS TABLE (Actor TEXT, Movie Text)
    AS $$
        SELECT 
            P.Name AS Actor, 
            M.Primary_Title AS Movie    
        FROM Movies M
        JOIN Roles R ON (M.ID = R.Movie)
        JOIN People P ON (R.Person = P.ID)
        WHERE M.Primary_Title = $1
    $$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION Q7(MovieName TEXT)
    RETURNS TABLE (Actor TEXT)
    AS $$
        WITH ActorsInGivenMovie AS (
            SELECT * 
            FROM GetActorsInMovies(MovieName)
        )
        SELECT Actor AS Actor
        FROM ActorsInGivenMovie
        GROUP BY Actor
        HAVING COUNT(*) > 1
        ORDER BY Actor;
    $$ LANGUAGE SQL;

-- Question 8 --

/**
    Write a SQL Function, called Q8(MovieName TEXT) RETURNS TEXT, that:
    Retrieves the number of releases for a given movie.
    If the movie is not found, then an error message should be returned.
*/
CREATE OR REPLACE FUNCTION Q8(MovieName TEXT)
    RETURNS TEXT
    AS $$
    DECLARE
        ReleaseCount INTEGER;
        MovieFound BOOLEAN;
    BEGIN
        MovieFound := EXISTS (SELECT 1 FROM Movies WHERE Primary_Title = $1);
        
        IF NOT MovieFound THEN
            RETURN 'Movie "' || MovieName || '" not found';
        END IF;

        SELECT COUNT(*)
            FROM Movies m
            JOIN Releases r ON (m.Id = r.Movie)
            WHERE m.Primary_Title = $1
        INTO ReleaseCount;
        
        IF ReleaseCount > 0 THEN 
            RETURN 'Release count: ' || ReleaseCount::TEXT; 
        ELSE
            RETURN 'No releases found for "' || MovieName || '"';
        END IF;
    END
    $$ LANGUAGE PLpgSQL;

-- Question 9 --

/**
    Write a SQL Function, called Q9(MovieName TEXT) RETURNS SETOF TEXT, that:
    Prints the Cast and Crew of a given movie.
*/
CREATE OR REPLACE FUNCTION GetRoles(MovieName TEXT)
    RETURNS TABLE (Movie TEXT, Name TEXT, Role TEXT)
    AS $$
    BEGIN
        RETURN QUERY
        SELECT 
            m.Primary_Title AS Movie, 
            p.Name AS Name, 
            r.Played AS Role
        FROM Movies m 
        JOIN Roles r ON m.Id = r.Movie
        JOIN People p ON p.Id = r.Person
        WHERE m.Primary_Title = $1;
    END
$$ LANGUAGE PLpgSQL;

CREATE OR REPLACE FUNCTION GetCredits(MovieName TEXT)
    RETURNS TABLE (Movie TEXT, Name TEXT, Profession TEXT)
    AS $$
    BEGIN
        RETURN QUERY
        SELECT 
            m.Primary_Title AS Movie,
            p1.Name AS Name,
            p2.Name AS Profession
        FROM Movies m 
        JOIN Credits c ON m.Id = c.Movie
        JOIN People p1 ON p1.Id = c.Person
        JOIN Professions p2 ON p2.Id = c.Profession
        WHERE m.Primary_Title = $1;
    END
$$ LANGUAGE PLpgSQL;

CREATE OR REPLACE FUNCTION GetRoleStrings(MovieName TEXT)
    RETURNS SETOF TEXT
    AS $$
    DECLARE
        Tuple RECORD;
    BEGIN
        FOR Tuple IN SELECT * FROM GetRoles(MovieName) LOOP
            RETURN NEXT '"' || Tuple.Name || '" played "' || Tuple.Role || '" in "' || Tuple.Movie || '"';
        END LOOP;
    END
$$ LANGUAGE PLpgSQL;

CREATE OR REPLACE FUNCTION GetCreditStrings(MovieName TEXT)
    RETURNS SETOF TEXT
    AS $$
    DECLARE
        Tuple RECORD;
    BEGIN
        FOR Tuple IN SELECT * FROM GetCredits(MovieName) LOOP
            RETURN NEXT '"' || Tuple.Name || '" worked on "' || Tuple.Movie || '" as a ' || Tuple.Profession;
        END LOOP;
    END
$$ LANGUAGE PLpgSQL;

CREATE OR REPLACE FUNCTION Q9(MovieName TEXT)
    RETURNS SETOF TEXT
    AS $$
    BEGIN
        RETURN QUERY
            SELECT *
            FROM GetRoleStrings(MovieName)
            UNION
            SELECT *
            FROM GetCreditStrings(MovieName);
    END
    $$ LANGUAGE PLpgSQL;

-- Question 10 --

/**
    TBA
*/

CREATE OR REPLACE FUNCTION GetReleasesFor(MovieRegion CHAR(4))
    RETURNS TABLE (Movie TEXT, Year Year, Score Rating, MaxScore Numeric(5,2))
    AS $$
    BEGIN
        RETURN QUERY
            SELECT DISTINCT
                m.Primary_Title as Movie,
                m.Release_Year as Year,
                m.Score as Score,
                MAX(m.Score) OVER (PARTITION BY m.Release_Year)
            FROM Releases r
            JOIN Movies m ON (m.Id = r.Movie)
            WHERE r.Region = MovieRegion AND m.Score IS NOT NULL;
    END
    $$ LANGUAGE PLpgSQL;   

CREATE OR REPLACE FUNCTION GetGenresFor(MovieName TEXT, Year Year)
    RETURNS TEXT
    AS $$
    DECLARE
        Result TEXT := '';
        Tuple RECORD;
    BEGIN
        FOR Tuple IN
            SELECT g.Name
            FROM Movies m
            JOIN Movies_Genres mg ON (m.Id = mg.Movie)
            JOIN Genres g ON (g.Id = mg.Genre)
            WHERE m.Primary_Title = MovieName AND m.Release_Year = Year
            ORDER BY g.Name
        LOOP
            Result := Result || Tuple.Name || ', ';
        END LOOP;
        RETURN LEFT(Result, LENGTH(Result) - 2);
    END 
    $$ LANGUAGE PLpgSQL;

CREATE OR REPLACE FUNCTION GetPrincipalsFor(MovieName TEXT, Year Year)
    RETURNS TEXT
    AS $$
     DECLARE
        Result TEXT := '';
        Tuple RECORD;
    BEGIN
        FOR Tuple IN
            SELECT p2.Name
            FROM Movies m
            JOIN Principals p1 ON (m.Id = p1.Movie)
            JOIN People p2 ON (p2.Id = p1.Person)
            WHERE m.Primary_Title = MovieName AND m.Release_Year = Year
            ORDER BY p2.Name
        LOOP
            Result := Result || Tuple.Name || ', ';
        END LOOP;
        RETURN LEFT(Result, LENGTH(Result) - 2);
    END 
    $$ LANGUAGE PLpgSQL;

CREATE OR REPLACE FUNCTION Q10(MovieRegion CHAR(4))
    RETURNS TABLE (Year INTEGER, Best_Movie TEXT, Movie_Genre Text, Principals TEXT)
    AS $$
    BEGIN
        RETURN QUERY
            SELECT
                r.Year::INTEGER AS Year,
                r.Movie AS Best_Movie,
                GetGenresFor(Movie, r.Year) AS MovieGenre,
                GetPrincipalsFor(Movie, r.Year) AS Principals
            FROM GetReleasesFor(MovieRegion) r
            WHERE r.Score = r.MaxScore
            ORDER BY r.Year DESC, r.Movie;
    END
    $$ LANGUAGE PLpgSQL;