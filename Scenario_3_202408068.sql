DROP TABLE IF EXISTS allocations CASCADE;
DROP TABLE IF EXISTS hostel_rooms CASCADE;

CREATE TABLE hostel_rooms (
    room_id SERIAL PRIMARY KEY,
    room_number VARCHAR(20) NOT NULL UNIQUE,
    available_bed_spaces INTEGER NOT NULL CHECK (available_bed_spaces >= 0)
);

CREATE TABLE allocations (
    allocation_id SERIAL PRIMARY KEY,
    student_number VARCHAR(30) NOT NULL,
    room_id INTEGER NOT NULL REFERENCES hostel_rooms(room_id),
    allocation_status VARCHAR(20) NOT NULL DEFAULT 'ALLOCATED'
        CHECK (allocation_status IN ('ALLOCATED', 'COMPLETED'))
);

INSERT INTO hostel_rooms (room_number, available_bed_spaces) VALUES
('A101', 4),
('A102', 1),
('A103', 0);

--TASK 2.
DO $$
DECLARE
    v_available INTEGER;
BEGIN
    SELECT available_bed_spaces INTO v_available
    FROM hostel_rooms
    WHERE room_id = 1;

    IF v_available = 0 THEN
        RAISE NOTICE 'Room A101: FULL';
    ELSIF v_available = 1 THEN
        RAISE NOTICE 'Room A101: ONE SPACE LEFT';
    ELSE
        RAISE NOTICE 'Room A101: SEVERAL SPACES';
    END IF;
END $$;

--TASK 3.
DO $$
DECLARE
    day_no INTEGER := 1;
BEGIN
    WHILE day_no <= 3 LOOP
        RAISE NOTICE 'Hostel inspection day %', day_no;
        day_no := day_no + 1;
    END LOOP;
END $$;

DO $$
DECLARE
    check_no INTEGER;
BEGIN
    FOR check_no IN 1..3 LOOP
        RAISE NOTICE 'Room check number: %', check_no;
    END LOOP;
END $$;

--TASK 4.
CREATE OR REPLACE PROCEDURE allocate_room(
    p_student_number VARCHAR,
    p_room_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_available INTEGER;
BEGIN
    IF p_student_number IS NULL OR trim(p_student_number) = '' THEN
        RAISE EXCEPTION 'Student number cannot be blank';
    END IF;

    SELECT available_bed_spaces
    INTO v_available
    FROM hostel_rooms
    WHERE room_id = p_room_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Room ID % does not exist', p_room_id;
    END IF;

    IF v_available <= 0 THEN
        RAISE EXCEPTION 'Room % is full', p_room_id;
    END IF;

    UPDATE hostel_rooms
    SET available_bed_spaces = available_bed_spaces - 1
    WHERE room_id = p_room_id;

    INSERT INTO allocations (
        student_number, room_id, allocation_status
    )
    VALUES (
        p_student_number, p_room_id, 'ALLOCATED'
    );

    RAISE NOTICE 'Student % allocated successfully', p_student_number;
END;
$$;

--TASK 5.
CALL allocate_room('STU001', 1);
CALL allocate_room('STU002', 2);

DO $$
BEGIN
    BEGIN
        CALL allocate_room('STU003', 3);
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Expected failed allocation: %', SQLERRM;
    END;
END $$;

SELECT * FROM hostel_rooms ORDER BY room_id;
SELECT * FROM allocations ORDER BY allocation_id;

--TASK 6.
CREATE OR REPLACE PROCEDURE check_out(p_allocation_id INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    v_room_id INTEGER;
    v_status VARCHAR(20);
BEGIN
    SELECT room_id, allocation_status
    INTO v_room_id, v_status
    FROM allocations
    WHERE allocation_id = p_allocation_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Allocation ID % does not exist', p_allocation_id;
    END IF;

    IF v_status = 'COMPLETED' THEN
        RAISE NOTICE 'Allocation % is already completed. Bed space will not be released again.',
            p_allocation_id;
        RETURN;
    END IF;

    UPDATE hostel_rooms
    SET available_bed_spaces = available_bed_spaces + 1
    WHERE room_id = v_room_id;

    UPDATE allocations
    SET allocation_status = 'COMPLETED'
    WHERE allocation_id = p_allocation_id;

    RAISE NOTICE 'Allocation % checked out successfully', p_allocation_id;
END;
$$;

CALL check_out(1);
CALL check_out(1);

--TASK 7.
DO $$
DECLARE
    room_cursor CURSOR FOR
        SELECT room_id, room_number, available_bed_spaces
        FROM hostel_rooms
        WHERE available_bed_spaces <= 1;
    v_id INTEGER;
    v_room VARCHAR(20);
    v_available INTEGER;
BEGIN
    OPEN room_cursor;
    LOOP
        FETCH room_cursor INTO v_id, v_room, v_available;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Full/nearly full room: %, spaces remaining %',
            v_room, v_available;
    END LOOP;
    CLOSE room_cursor;
END $$;

--TASK 8.
DO $$
BEGIN
    BEGIN
        CALL allocate_room('   ', 1);
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Invalid student number handled: %', SQLERRM;
    END;
END $$;

--TASK 9.
SELECT * FROM hostel_rooms ORDER BY room_id;
SELECT * FROM allocations ORDER BY allocation_id;