-- Create the view sales_revenue_by_category_qtr
CREATE OR REPLACE VIEW sales_revenue_by_category_qtr AS
SELECT 
    c.name AS category,
    SUM(p.amount) AS total_sales_revenue
FROM 
    payment p
    JOIN rental r ON p.rental_id = r.rental_id
    JOIN inventory i ON r.inventory_id = i.inventory_id
    JOIN film f ON i.film_id = f.film_id
    JOIN film_category fc ON f.film_id = fc.film_id
    JOIN category c ON fc.category_id = c.category_id
WHERE 
    DATE_PART('quarter', p.payment_date) = DATE_PART('quarter', CURRENT_DATE)
    AND DATE_PART('year', p.payment_date) = DATE_PART('year', CURRENT_DATE)
GROUP BY 
    c.name
HAVING 
    SUM(p.amount) > 0;

-- Drop the existing function if it exists
DROP FUNCTION IF EXISTS get_sales_revenue_by_category_qtr(integer);

-- Create the new function get_sales_revenue_by_category_qtr
CREATE OR REPLACE FUNCTION get_sales_revenue_by_category_qtr(current_quarter INT)
RETURNS TABLE (category VARCHAR, total_sales_revenue NUMERIC) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.name AS category,
        SUM(p.amount) AS total_sales_revenue
    FROM 
        payment p
        JOIN rental r ON p.rental_id = r.rental_id
        JOIN inventory i ON r.inventory_id = i.inventory_id
        JOIN film f ON i.film_id = f.film_id
        JOIN film_category fc ON f.film_id = fc.film_id
        JOIN category c ON fc.category_id = c.category_id
    WHERE 
        DATE_PART('quarter', p.payment_date) = current_quarter
        AND DATE_PART('year', p.payment_date) = DATE_PART('year', CURRENT_DATE)
    GROUP BY 
        c.name
    HAVING 
        SUM(p.amount) > 0;
END;
$$ LANGUAGE plpgsql;

-- Drop the existing procedure if it exists
DROP FUNCTION IF EXISTS new_movie(VARCHAR);

-- Create the new procedure new_movie
CREATE OR REPLACE FUNCTION new_movie(movie_title VARCHAR)
RETURNS VOID AS $$
DECLARE
    new_film_id INT;
BEGIN
    -- Check if the language 'Klingon' exists
    IF NOT EXISTS (SELECT 1 FROM language WHERE name = 'Klingon') THEN
        RAISE EXCEPTION 'Language Klingon does not exist';
    END IF;

    -- Generate a new unique film ID
    SELECT MAX(film_id) + 1 INTO new_film_id FROM film;

    -- Insert the new movie into the film table
    INSERT INTO film (film_id, title, description, release_year, language_id, rental_duration, rental_rate, replacement_cost)
    VALUES (new_film_id, movie_title, NULL, EXTRACT(YEAR FROM CURRENT_DATE), 
            (SELECT language_id FROM language WHERE name = 'Klingon'), 
            3, 4.99, 19.99);
END;
$$ LANGUAGE plpgsql;
