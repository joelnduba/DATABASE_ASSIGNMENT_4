DROP TABLE IF EXISTS reservations CASCADE;
DROP TABLE IF EXISTS lab_sessions CASCADE;

CREATE TABLE lab_sessions (
    session_id SERIAL PRIMARY KEY,
    session_name VARCHAR(100) NOT NULL,
    available_workstations INTEGER NOT NULL CHECK (available_workstations >= 0)
);

CREATE TABLE reservations (
    reservation_id SERIAL PRIMARY KEY,
    session_id INTEGER NOT NULL REFERENCES lab_sessions(session_id),
    lecturer VARCHAR(100) NOT NULL,
    workstations INTEGER NOT NULL CHECK (workstations > 0),
    reservation_status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
        CHECK (reservation_status IN ('ACTIVE', 'CANCELLED'))
);

INSERT INTO lab_sessions (session_name, available_workstations) VALUES
('Database Practical', 30),
('Networking Practical', 10),
('Programming Practical', 5);

--TASK 2
DO $$
DECLARE
    v_available INTEGER;
BEGIN
    SELECT available_workstations INTO v_available
    FROM lab_sessions
    WHERE session_id = 1;

    IF v_available = 0 THEN
        RAISE NOTICE 'Database Practical: FULL';
    ELSIF v_available <= 10 THEN
        RAISE NOTICE 'Database Practical: NEARLY FULL';
    ELSE
        RAISE NOTICE 'Database Practical: ENOUGH WORKSTATIONS';
    END IF;
END $$;

--TASK 3
DO $$
DECLARE
    reminder_no INTEGER := 1;
BEGIN
    WHILE reminder_no <= 3 LOOP
        RAISE NOTICE 'Session preparation reminder %', reminder_no;
        reminder_no := reminder_no + 1;
    END LOOP;
END $$;

DO $$
DECLARE
    check_no INTEGER;
BEGIN
    FOR check_no IN 1..3 LOOP
        RAISE NOTICE 'Workstation check number: %', check_no;
    END LOOP;
END $$;

--TASK 4
CREATE OR REPLACE PROCEDURE reserve_workstations(
    p_session_id INTEGER,
    p_lecturer VARCHAR,
    p_workstations INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_available INTEGER;
BEGIN
    IF p_workstations <= 0 THEN
        RAISE EXCEPTION 'Invalid number of workstations: must be greater than zero';
    END IF;

    SELECT available_workstations
    INTO v_available
    FROM lab_sessions
    WHERE session_id = p_session_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Session ID % does not exist', p_session_id;
    END IF;

    IF v_available < p_workstations THEN
        RAISE EXCEPTION 'Not enough workstations. Available: %, Requested: %',
            v_available, p_workstations;
    END IF;

    UPDATE lab_sessions
    SET available_workstations = available_workstations - p_workstations
    WHERE session_id = p_session_id;

    INSERT INTO reservations (
        session_id, lecturer, workstations, reservation_status
    )
    VALUES (
        p_session_id, p_lecturer, p_workstations, 'ACTIVE'
    );

    RAISE NOTICE 'Reservation recorded successfully for %', p_lecturer;
END;
$$;

--TASK 5
CALL reserve_workstations(2, 'Dr. Phiri', 6);

DO $$
BEGIN
    BEGIN
        CALL reserve_workstations(2, 'Dr. Tembo', 10);
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Expected failed reservation: %', SQLERRM;
    END;
END $$;

SELECT * FROM lab_sessions ORDER BY session_id;
SELECT * FROM reservations ORDER BY reservation_id;

--TASK 6
CREATE OR REPLACE PROCEDURE cancel_reservation(p_reservation_id INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    v_session_id INTEGER;
    v_workstations INTEGER;
    v_status VARCHAR(20);
BEGIN
    SELECT session_id, workstations, reservation_status
    INTO v_session_id, v_workstations, v_status
    FROM reservations
    WHERE reservation_id = p_reservation_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reservation ID % does not exist', p_reservation_id;
    END IF;

    IF v_status = 'CANCELLED' THEN
        RAISE NOTICE 'Reservation % is already cancelled. Workstations will not be released again.',
            p_reservation_id;
        RETURN;
    END IF;

    UPDATE lab_sessions
    SET available_workstations = available_workstations + v_workstations
    WHERE session_id = v_session_id;

    UPDATE reservations
    SET reservation_status = 'CANCELLED'
    WHERE reservation_id = p_reservation_id;

    RAISE NOTICE 'Reservation % cancelled successfully', p_reservation_id;
END;
$$;

CALL cancel_reservation(1);
CALL cancel_reservation(1);

--TASK 7
DO $$
DECLARE
    session_cursor CURSOR FOR
        SELECT session_id, session_name, available_workstations
        FROM lab_sessions
        WHERE available_workstations <= 10;
    v_id INTEGER;
    v_name VARCHAR(100);
    v_available INTEGER;
BEGIN
    OPEN session_cursor;
    LOOP
        FETCH session_cursor INTO v_id, v_name, v_available;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Few workstations: ID %, %, remaining %',
            v_id, v_name, v_available;
    END LOOP;
    CLOSE session_cursor;
END $$;

--TASK 8
DO $$
BEGIN
    BEGIN
        CALL reserve_workstations(1, 'Dr. Invalid', 0);
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Invalid quantity handled: %', SQLERRM;
    END;
END $$;

--TASK 9. 
SELECT * FROM lab_sessions ORDER BY session_id;
SELECT * FROM reservations ORDER BY reservation_id;