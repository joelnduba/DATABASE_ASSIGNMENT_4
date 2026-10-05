
-- Scenario 1: University Library Book Loans--
DROP TABLE IF EXISTS book_loans CASCADE;
DROP TABLE IF EXISTS books CASCADE;

CREATE TABLE books (
    book_id SERIAL PRIMARY KEY,
    title VARCHAR(150) NOT NULL,
    available_copies INTEGER NOT NULL CHECK (available_copies >= 0)
);

CREATE TABLE book_loans (
    loan_id SERIAL PRIMARY KEY,
    book_id INTEGER NOT NULL REFERENCES books(book_id),
    student_number VARCHAR(30) NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    loan_status VARCHAR(20) NOT NULL DEFAULT 'BORROWED'
        CHECK (loan_status IN ('BORROWED', 'RETURNED'))
);

INSERT INTO books (title, available_copies) VALUES
('Database Systems', 5),
('Computer Networks', 2),
('Operating Systems', 0);

--TASK 2.
DO $$
DECLARE
    copies INTEGER;
BEGIN
    SELECT available_copies INTO copies FROM books WHERE book_id = 1;

    IF copies = 0 THEN
        RAISE NOTICE 'Database Systems: UNAVAILABLE';
    ELSIF copies <= 2 THEN
        RAISE NOTICE 'Database Systems: LOW ON COPIES';
    ELSE
        RAISE NOTICE 'Database Systems: SUFFICIENTLY STOCKED';
    END IF;
END $$;

--TASK 3.
DO $$
DECLARE
    reminder_no INTEGER := 1;
BEGIN
    WHILE reminder_no <= 3 LOOP
        RAISE NOTICE 'Overdue reminder number: %', reminder_no;
        reminder_no := reminder_no + 1;
    END LOOP;
END $$;

--TASK 4
DO $$
DECLARE
    shelf_no INTEGER;
BEGIN
    FOR shelf_no IN 1..3 LOOP
        RAISE NOTICE 'Library shelf number: %', shelf_no;
    END LOOP;
END $$;


CREATE OR REPLACE PROCEDURE borrow_book(
    p_book_id INTEGER,
    p_student_number VARCHAR,
    p_quantity INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_available INTEGER;
BEGIN
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Invalid quantity: quantity must be greater than zero';
    END IF;

    SELECT available_copies
    INTO v_available
    FROM books
    WHERE book_id = p_book_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Book ID % does not exist', p_book_id;
    END IF;

    IF v_available < p_quantity THEN
        RAISE EXCEPTION 'Not enough copies. Available: %, Requested: %',
            v_available, p_quantity;
    END IF;

    UPDATE books
    SET available_copies = available_copies - p_quantity
    WHERE book_id = p_book_id;

    INSERT INTO book_loans (book_id, student_number, quantity, loan_status)
    VALUES (p_book_id, p_student_number, p_quantity, 'BORROWED');

    RAISE NOTICE 'Loan recorded successfully for student %', p_student_number;
END;
$$;

--TASK 5.
CALL borrow_book(1, 'STU001', 2);
CALL borrow_book(2, 'STU002', 1);

DO $$
BEGIN
    BEGIN
        CALL borrow_book(2, 'STU003', 5);
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Expected failed loan: %', SQLERRM;
    END;
END $$;

SELECT * FROM books ORDER BY book_id;
SELECT * FROM book_loans ORDER BY loan_id;

--TASK 6
CREATE OR REPLACE PROCEDURE return_book(p_loan_id INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    v_book_id INTEGER;
    v_quantity INTEGER;
    v_status VARCHAR(20);
BEGIN
    SELECT book_id, quantity, loan_status
    INTO v_book_id, v_quantity, v_status
    FROM book_loans
    WHERE loan_id = p_loan_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Loan ID % does not exist', p_loan_id;
    END IF;

    IF v_status = 'RETURNED' THEN
        RAISE NOTICE 'Loan % is already returned. Stock will not be restored again.', p_loan_id;
        RETURN;
    END IF;

    UPDATE books
    SET available_copies = available_copies + v_quantity
    WHERE book_id = v_book_id;

    UPDATE book_loans
    SET loan_status = 'RETURNED'
    WHERE loan_id = p_loan_id;

    RAISE NOTICE 'Loan % returned successfully', p_loan_id;
END;
$$;

CALL return_book(1);
CALL return_book(1);

--TASK 7.
DO $$
DECLARE
    book_cursor CURSOR FOR
        SELECT book_id, title, available_copies
        FROM books
        WHERE available_copies <= 2;
    v_book_id INTEGER;
    v_title VARCHAR(150);
    v_copies INTEGER;
BEGIN
    OPEN book_cursor;
    LOOP
        FETCH book_cursor INTO v_book_id, v_title, v_copies;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Few copies: ID %, %, copies remaining %',
            v_book_id, v_title, v_copies;
    END LOOP;
    CLOSE book_cursor;
END $$;

--TASK 8.
DO $$
BEGIN
    BEGIN
        CALL borrow_book(1, 'STU004', 0);
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Invalid quantity handled: %', SQLERRM;
    END;
END $$;

--TASK 9.
SELECT * FROM books ORDER BY book_id;
SELECT * FROM book_loans ORDER BY loan_id;
