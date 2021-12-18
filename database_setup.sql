CREATE TABLE users (
    id int identity(1,1) primary key not null,
    username varchar(15) not null,
    password char(40) not null,
    userType varchar(6) not null,
    CONSTRAINT userType_value CHECK(userType = 'ADMIN' OR userType = 'AGENCY'),
    CONSTRAINT unique_username UNIQUE(username)
)

CREATE TABLE offers (
    id int identity(1,1) primary key not null,
    nbrTickets int not null,
    discountPercentage int not null,
    CONSTRAINT nbrTickets_positive_offers CHECK(nbrTickets > 0),
    CONSTRAINT discountPercentage_range CHECK(discountPercentage BETWEEN 1 AND 80)
)

-- Monday, Tuesday, Wednesday, Thursday, Friday, Saturday. Sunday,
CREATE TABLE daysOfWeek (
    id int identity(1,1) primary key not null,
    name varchar(9) not null,
    CONSTRAINT name_unique UNIQUE(name)
)

CREATE TABLE stations (
    id int identity(1,1) primary key not null,
    stationCode varchar(5) not null,
    city varchar(20) not null,
    CONSTRAINT stationCode_unique UNIQUE(stationCode)
)

CREATE TABLE routes (
    id int identity(1,1) primary key not null,
    stationDeparture int foreign key references stations(id) not null,
    stationArrive int foreign key references stations(id) not null
)

CREATE TABLE employees (
    id int identity(1,1) primary key not null,
    firstName varchar(15) not null,
    lastName varchar(15) not null,
    phoneNumber varchar(10) not null,
    dateOfBirth date not null,
    salary int not null,
    address text not null,
    startWorkDate date not null,
    profile_image image,
    station int foreign key references stations(id) not null,
    user_profile int foreign key references users(id) not null,
    CONSTRAINT unique_user_account UNIQUE(user_profile)
)

CREATE TABLE drivers (
    id int identity(1,1) primary key not null,
    firstName varchar(15) not null,
    lastName varchar(15) not null,
    phoneNumber varchar(10) not null,
    dateOfBirth date not null,
    salary int not null,
    address text not null,
    startWorkDate date not null,
    station int foreign key references stations(id) not null,
    profile_image image
)

CREATE TABLE workingDays (
    id int identity(1,1) primary key not null,
    driverId int foreign key references drivers(id) not null,
    dayId int foreign key references daysOfWeek(id) not null,
    CONSTRAINT driverId_dayId_unique_together UNIQUE(driverId, dayId)
)

CREATE TABLE buses (
    id int identity(1,1) primary key not null,
    busCode varchar(5) not null,
    nbrSeats int not null,
    mark varchar(20) not null,
    station int foreign key references stations(id) not null,
    CONSTRAINT nbrSeats_positive CHECK(nbrSeats > 0)
)

CREATE TABLE trips (
    id int identity(1,1) primary key not null,
    driverId int foreign key references drivers(id) not null,
    busId int foreign key references buses(id) not null,
    routeId int foreign key references routes(id) not null,
    dateDeparture date not null,
    dateArrive date not null,
    price int not null,
    CONSTRAINT price_positive CHECK(price > 0)
)

CREATE TABLE travelled_clients_tickets (
    id int identity(1,1) primary key not null,
    tripId int foreign key references trips(id) not null,
    nbrTickets int not null,
    totalPrice int not null,
    CONSTRAINT nbrTickets_positive_tct CHECK(nbrTickets > 0),
    CONSTRAINT totalPrice_positive CHECK(totalPrice > 0)
)
GO

-- This trigger for making sure that the departure station of a bus is different
-- than its arrive station.
CREATE TRIGGER departureStationDiffArriveStation ON routes FOR INSERT, UPDATE
AS
BEGIN
    DECLARE @sDeparture int, @sArrive int
    SET @sDeparture = (SELECT TOP 1 stationDeparture FROM inserted)
    SET @sArrive = (SELECT TOP 1 stationArrive FROM inserted)
    IF @sDeparture = @sArrive
    BEGIN
        ROLLBACK
        RAISERROR('Departure station cannot be the same as arrive station', 15,  1)
    END
END
GO

-- This trigger to make sure that the arrive datetime of a trip is greater 
-- than its departure datetime.
-- Also to make sure that the departure data is greater that the current date
-- at the moment of creation.
CREATE TRIGGER arriveDateGreaterDepartureDate ON trips FOR INSERT, UPDATE
AS
BEGIN
    DECLARE @dDeparture date, @dArrive date, @currentDate date
    SET @dDeparture = (SELECT TOP 1 dateDeparture FROM inserted)
    SET @dArrive = (SELECT TOP 1 dateArrive FROM inserted)
    SET @currentDate = (SELECT CAST( GETDATE() AS Date ))
    IF @dDeparture < @currentDate
    BEGIN
        ROLLBACK
        RAISERROR('Departure date cannot be smaller than the current data', 15,  1)
    END
    IF @dDeparture > @dArrive
    BEGIN
        ROLLBACK
        RAISERROR('Arrive date cannot be smaller than departure date', 15,  1)
    END
END
GO

-- This function returns the number of left seats in a bus by subtracting 
-- the number of booked seats from the quantity of the bus
CREATE FUNCTION getNbrPlacesLeftInBus(@tripId int) RETURNS int
AS
BEGIN
    DECLARE @busQuantity int, @tripNbrPassengers int;
    SET @busQuantity = (SELECT nbrSeats FROM buses WHERE id = (
        SELECT busId FROM trips WHERE id = @tripId
    ))
    SET @tripNbrPassengers = (SELECT SUM(nbrTickets) FROM travelled_clients_tickets WHERE tripId = @tripId)
    RETURN @busQuantity - @tripNbrPassengers
END
GO

-- This trigger to make sure that we don't book more seat for a trip that
-- the quantity of the bus go in that trip
CREATE TRIGGER nbrPassengersLtOrEqBusQuantity ON travelled_clients_tickets FOR INSERT
AS
BEGIN
    DECLARE @tripId int
    SET @tripId = (SELECT TOP 1 tripId FROM inserted)
    IF dbo.getNbrPlacesLeftInBus(@tripId) <= 0
    BEGIN
        ROLLBACK
        RAISERROR('All the seats are booked for this trip', 15, 1)
    END
END
GO

-- This function returns the available buses for a date that is passed as argument
CREATE FUNCTION getAvailableBuses(@dDate date, @stationDepartureId int) RETURNS
    TABLE
AS
RETURN
    SELECT id, busCode FROM buses WHERE station = @stationDepartureId AND id NOT IN (
        SELECT busId FROM trips WHERE @dDate BETWEEN dateDeparture AND dateArrive
    )
GO

-- This function returns the available drivers for a date that is passed as argument
CREATE FUNCTION getAvailableDrivers(@dDate date, @stationDepartureId int) RETURNS 
    TABLE
AS
RETURN
    SELECT id, firstName, lastName FROM drivers WHERE station = @stationDepartureId AND id NOT IN (
        SELECT driverId FROM trips WHERE @dDate BETWEEN dateDeparture AND dateArrive
    )
GO

-- users table
-- for the passowrd it has the hash of the password using the SHA-1 hashing function output 160-bits
-- INSERT INTO users VALUES('david.john', '5baa61e4c9b93f3f0682250b6cf8331b7ee68fd8'); -- password= password
INSERT INTO users VALUES('tomas.renolds', 'ab05679fb2ccc049d82d5d52cc96fb505dd818fd', 'ADMIN');  -- password= securePassword
INSERT INTO users VALUES('Omar.Najib', '5baa61e4c9b93f3f0682250b6cf8331b7ee68fd8', 'AGENCY');
INSERT INTO users VALUES('Karim.laasri', 'ab05679fb2ccc049d82d5d52cc96fb505dd818fd', 'AGENCY');

-- daysOfWeek table
INSERT INTO daysOfWeek(name) VALUES ('Monday')
INSERT INTO daysOfWeek(name) VALUES ('Tuesday')
INSERT INTO daysOfWeek(name) VALUES ('Wednesday')
INSERT INTO daysOfWeek(name) VALUES ('Thursday')
INSERT INTO daysOfWeek(name) VALUES ('Friday')
INSERT INTO daysOfWeek(name) VALUES ('Saturday')
INSERT INTO daysOfWeek(name) VALUES ('Sunday')

-- offers table
INSERT INTO offers(nbrTickets, discountPercentage) VALUES(3, 10)
INSERT INTO offers(nbrTickets, discountPercentage) VALUES(5, 20)

-- stations table
INSERT INTO stations(stationCode, city) VALUES('C1234', 'Agadir');
INSERT INTO stations(stationCode, city) VALUES('B1039', 'Rabat');
INSERT INTO stations(stationCode, city) VALUES('C7008', 'Marrakech');

-- routes table
INSERT INTO routes(stationDeparture, stationArrive) VALUES(1, 2)
INSERT INTO routes(stationDeparture, stationArrive) VALUES(1, 3)

-- employees table
INSERT INTO employees(firstName, lastName, phoneNumber, dateOfBirth, salary, address, startWorkDate, station, user_profile)
VALUES('Omar', 'Najib', '0614237613', '1995-02-15', 5000, 'imm 7, appt. 3, Hay Karima, Rabat', '2002-07-13', 2, 2)
INSERT INTO employees(firstName, lastName, phoneNumber, dateOfBirth, salary, address, startWorkDate, station, user_profile)
VALUES('Karim', 'laasri', '0683610079', '1994-10-25', 5000, '349, avenue El Houria, Agadir', '2002-07-13', 1, 3)

-- drivers table
INSERT INTO drivers(firstName, lastName, phoneNumber, dateOfBirth, salary, address, startWorkDate, station)
VALUES('Hassan', 'Monir', '0641651321', '1969-04-02', 3000, '93, bd. Hassan II, Agadir', '2006-01-13', 1)
INSERT INTO drivers(firstName, lastName, phoneNumber, dateOfBirth, salary, address, startWorkDate, station)
VALUES('Karim', 'laasri', '0683610079', '1970-04-02', 3000, '6, rue Brahim Roudani, Rabat', '2006-09-28', 2)

-- workingDays table
INSERT INTO workingDays(driverId, dayId) VALUES (1, 1)
INSERT INTO workingDays(driverId, dayId) VALUES (1, 2)
INSERT INTO workingDays(driverId, dayId) VALUES (1, 4)
INSERT INTO workingDays(driverId, dayId) VALUES (1, 6)
INSERT INTO workingDays(driverId, dayId) VALUES (1, 7)
INSERT INTO workingDays(driverId, dayId) VALUES (2, 1)
INSERT INTO workingDays(driverId, dayId) VALUES (2, 3)
INSERT INTO workingDays(driverId, dayId) VALUES (2, 4)
INSERT INTO workingDays(driverId, dayId) VALUES (2, 6)
INSERT INTO workingDays(driverId, dayId) VALUES (2, 7)

-- buses table
INSERT INTO buses(busCode, nbrSeats, mark, station) VALUES('A0987', 60, 'Toyota', 1)
INSERT INTO buses(busCode, nbrSeats, mark, station) VALUES('D4516', 60, 'Toyota', 2)

-- trips table
INSERT INTO trips(driverId, busId, routeId, dateDeparture, dateArrive, price)
VALUES(1, 1, 1, '2021-12-27', '2021-12-28', '150')
INSERT INTO trips(driverId, busId, routeId, dateDeparture, dateArrive, price)
VALUES(2, 2, 2, '2021-12-26', '2021-12-27', '150')

-- travelled_clients_tickets table
INSERT travelled_clients_tickets(tripId, nbrTickets, totalPrice)
VALUES(1, 5, 600)
INSERT travelled_clients_tickets(tripId, nbrTickets, totalPrice)
VALUES(2, 2, 300)

GO
