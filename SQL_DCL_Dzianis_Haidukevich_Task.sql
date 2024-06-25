-- Create a new user with the username "rentaluser" and the password "rentalpassword"
CREATE USER rentaluser WITH PASSWORD 'rentalpassword';

-- Give the user the ability to connect to the database but no other permissions
GRANT CONNECT ON DATABASE dvdrental TO rentaluser;

-- Grant "rentaluser" SELECT permission for the "customer" table
GRANT SELECT ON TABLE customer TO rentaluser;

-- Create a new user group called "rental" and add "rentaluser" to the group
CREATE ROLE rental;
GRANT rental TO rentaluser;

-- Grant the "rental" group INSERT, UPDATE, and SELECT permissions for the "rental" table
GRANT INSERT, UPDATE, SELECT ON TABLE rental TO rental;

-- Grant "rentaluser" and "rental" group USAGE and SELECT permissions on the sequence rental_rental_id_seq
GRANT USAGE, SELECT ON SEQUENCE rental_rental_id_seq TO rentaluser;
GRANT USAGE, SELECT ON SEQUENCE rental_rental_id_seq TO rental;

-- Check to make sure this permission works correctly
-- Execute this query as rentaluser to verify the permissions
SET ROLE rentaluser;
SELECT * FROM customer;
RESET ROLE;

-- Insert a new row and update one existing row in the "rental" table under that role
SET ROLE rental;
INSERT INTO rental (rental_date, inventory_id, customer_id, return_date, staff_id, last_update)
VALUES (CURRENT_TIMESTAMP, 1, 1, NULL, 1, CURRENT_TIMESTAMP);

UPDATE rental
SET return_date = CURRENT_TIMESTAMP
WHERE rental_id = 1;
RESET ROLE;

-- Revoke the "rental" group's INSERT permission for the "rental" table
REVOKE INSERT ON TABLE rental FROM rental;

-- Try to insert new rows into the "rental" table to make sure this action is denied
SET ROLE rental;
-- This should result in a permission denied error
INSERT INTO rental (rental_date, inventory_id, customer_id, return_date, staff_id, last_update)
VALUES (CURRENT_TIMESTAMP, 2, 2, NULL, 1, CURRENT_TIMESTAMP);
RESET ROLE;

-- Create a personalized role for any customer already existing in the dvd_rental database
DO $$
DECLARE
    customer RECORD;
BEGIN
    FOR customer IN
        SELECT customer_id, first_name, last_name
        FROM customer
        WHERE EXISTS (SELECT 1 FROM payment WHERE payment.customer_id = customer.customer_id)
          AND EXISTS (SELECT 1 FROM rental WHERE rental.customer_id = customer.customer_id)
    LOOP
        EXECUTE format('CREATE ROLE client_%I_%I;', customer.first_name, customer.last_name);
        EXECUTE format('GRANT SELECT ON TABLE rental TO client_%I_%I;', customer.first_name, customer.last_name);
        EXECUTE format('GRANT SELECT ON TABLE payment TO client_%I_%I;', customer.first_name, customer.last_name);
        EXECUTE format('GRANT USAGE ON SCHEMA public TO client_%I_%I;', customer.first_name, customer.last_name);
        EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO client_%I_%I;', customer.first_name, customer.last_name);
    END LOOP;
END
$$;

-- Configure that role so that the customer can only access their own data in the "rental" and "payment" tables
DO $$
DECLARE
    customer RECORD;
BEGIN
    FOR customer IN
        SELECT customer_id, first_name, last_name
        FROM customer
        WHERE EXISTS (SELECT 1 FROM payment WHERE payment.customer_id = customer.customer_id)
          AND EXISTS (SELECT 1 FROM rental WHERE rental.customer_id = customer.customer_id)
    LOOP
        EXECUTE format('CREATE OR REPLACE VIEW rental_view_%I_%I AS SELECT * FROM rental WHERE customer_id = %L;', customer.first_name, customer.last_name, customer.customer_id);
        EXECUTE format('CREATE OR REPLACE VIEW payment_view_%I_%I AS SELECT * FROM payment WHERE customer_id = %L;', customer.first_name, customer.last_name, customer.customer_id);
        EXECUTE format('GRANT SELECT ON rental_view_%I_%I TO client_%I_%I;', customer.first_name, customer.last_name, customer.first_name, customer.last_name);
        EXECUTE format('GRANT SELECT ON payment_view_%I_%I TO client_%I_%I;', customer.first_name, customer.last_name, customer.first_name, customer.last_name);
    END LOOP;
END
$$;

-- Query to make sure this user sees only their own data
SET ROLE client_firstname_lastname; -- replace firstname and lastname accordingly
SELECT * FROM rental_view_firstname_lastname;
SELECT * FROM payment_view_firstname_lastname;
RESET ROLE;
