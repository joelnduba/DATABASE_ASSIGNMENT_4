DROP TABLE IF EXISTS dispensing_records CASCADE;
DROP TABLE IF EXISTS medicines CASCADE;

CREATE TABLE medicines (
    medicine_id SERIAL PRIMARY KEY,
    medicine_name VARCHAR(100) NOT NULL,
    stock_quantity INTEGER NOT NULL CHECK (stock_quantity >= 0)
);

CREATE TABLE dispensing_records (
    dispensing_id SERIAL PRIMARY KEY,
    medicine_id INTEGER NOT NULL REFERENCES medicines(medicine_id),
    student_number VARCHAR(30) NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    dispensing_status VARCHAR(20) NOT NULL DEFAULT 'DISPENSED'
        CHECK (dispensing_status IN ('DISPENSED', 'REVERSED'))
);

INSERT INTO medicines (medicine_name, stock_quantity) VALUES
('Paracetamol', 50),
('Amoxicillin', 10),
('Ibuprofen', 0);

--TASK 2.
DO $$
DECLARE
    v_stock INTEGER;
BEGIN
    SELECT stock_quantity INTO v_stock
    FROM medicines
    WHERE medicine_id = 1;

    IF v_stock = 0 THEN
        RAISE NOTICE 'Paracetamol: OUT OF STOCK';
    ELSIF v_stock <= 10 THEN
        RAISE NOTICE 'Paracetamol: LOW ON STOCK';
    ELSE
        RAISE NOTICE 'Paracetamol: SUFFICIENTLY STOCKED';
    END IF;
END $$;

--TASK 3.
DO $$
DECLARE
    day_no INTEGER := 1;
BEGIN
    WHILE day_no <= 3 LOOP
        RAISE NOTICE 'Stock review day %', day_no;
        day_no := day_no + 1;
    END LOOP;
END $$;

DO $$
DECLARE
    inspection_no INTEGER;
BEGIN
    FOR inspection_no IN 1..3 LOOP
        RAISE NOTICE 'Shelf inspection number: %', inspection_no;
    END LOOP;
END $$;

--TASK 4.
CREATE OR REPLACE PROCEDURE dispense_medicine(
    p_medicine_id INTEGER,
    p_student_number VARCHAR,
    p_quantity INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_stock INTEGER;
BEGIN
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Invalid dispensing quantity: must be greater than zero';
    END IF;

    SELECT stock_quantity
    INTO v_stock
    FROM medicines
    WHERE medicine_id = p_medicine_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Medicine ID % does not exist', p_medicine_id;
    END IF;

    IF v_stock < p_quantity THEN
        RAISE EXCEPTION 'Insufficient stock. Available: %, Requested: %',
            v_stock, p_quantity;
    END IF;

    UPDATE medicines
    SET stock_quantity = stock_quantity - p_quantity
    WHERE medicine_id = p_medicine_id;

    INSERT INTO dispensing_records (
        medicine_id, student_number, quantity, dispensing_status
    )
    VALUES (
        p_medicine_id, p_student_number, p_quantity, 'DISPENSED'
    );

    RAISE NOTICE 'Medicine dispensed successfully to student %', p_student_number;
END;
$$;

--TASK 5.
CALL dispense_medicine(1, 'STU001', 5);
CALL dispense_medicine(2, 'STU002', 4);

DO $$
BEGIN
    BEGIN
        CALL dispense_medicine(2, 'STU003', 10);
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Expected failed dispensing: %', SQLERRM;
    END;
END $$;

SELECT * FROM medicines ORDER BY medicine_id;
SELECT * FROM dispensing_records ORDER BY dispensing_id;

--TASK 6.
CREATE OR REPLACE PROCEDURE reverse_dispensing(p_dispensing_id INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    v_medicine_id INTEGER;
    v_quantity INTEGER;
    v_status VARCHAR(20);
BEGIN
    SELECT medicine_id, quantity, dispensing_status
    INTO v_medicine_id, v_quantity, v_status
    FROM dispensing_records
    WHERE dispensing_id = p_dispensing_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Dispensing record % does not exist', p_dispensing_id;
    END IF;

    IF v_status = 'REVERSED' THEN
        RAISE NOTICE 'Record % is already reversed. Stock will not be restored again.',
            p_dispensing_id;
        RETURN;
    END IF;

    UPDATE medicines
    SET stock_quantity = stock_quantity + v_quantity
    WHERE medicine_id = v_medicine_id;

    UPDATE dispensing_records
    SET dispensing_status = 'REVERSED'
    WHERE dispensing_id = p_dispensing_id;

    RAISE NOTICE 'Dispensing record % reversed successfully', p_dispensing_id;
END;
$$;

CALL reverse_dispensing(1);
CALL reverse_dispensing(1);

--TASK 7.
DO $$
DECLARE
    medicine_cursor CURSOR FOR
        SELECT medicine_id, medicine_name, stock_quantity
        FROM medicines
        WHERE stock_quantity < 10;
    v_id INTEGER;
    v_name VARCHAR(100);
    v_stock INTEGER;
BEGIN
    OPEN medicine_cursor;
    LOOP
        FETCH medicine_cursor INTO v_id, v_name, v_stock;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Low stock: %, quantity remaining %',
            v_name, v_stock;
    END LOOP;
    CLOSE medicine_cursor;
END $$;

--TASK 8.
DO $$
BEGIN
    BEGIN
        CALL dispense_medicine(1, 'STU004', -2);
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Invalid negative quantity handled: %', SQLERRM;
    END;
END $$;

--TASK 9.
SELECT * FROM medicines ORDER BY medicine_id;
SELECT * FROM dispensing_records ORDER BY dispensing_id;
