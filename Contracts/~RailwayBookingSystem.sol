// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RailwayBookingSystem {
    address public admin;

    constructor() {
        admin = msg.sender;
    }

    struct Train {
        uint256 trainId;
        string name;
        string origin;
        string destination;
        uint256 departureTime; 
        uint256 totalSeats;
        uint256 availableSeats;
        bool exists;
    }

    struct Ticket {
        address passenger;
        uint256 trainId;
        uint256 seatNumber;
    }

    uint256 public trainCounter = 0;
    mapping(uint256 => Train) public trains;
    mapping(uint256 => Ticket[]) public trainTickets;
    mapping(address => mapping(uint256 => bool)) public hasBooked;
    
    event TrainAdded(uint256 trainId, string name);
    event TicketBooked(address passenger, uint256 trainId, uint256 seatNumber);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    function addTrain(
        string memory name,
        string memory origin,
        string memory destination,
        uint256 departureTime,
        uint256 totalSeats
    ) public onlyAdmin {
        require(totalSeats > 0, "Total seats must be greater than zero");

        trainCounter++;
        trains[trainCounter] = Train({
            trainId: trainCounter,
            name: name,
            origin: origin,
            destination: destination,
            departureTime: departureTime,
            totalSeats: totalSeats,
            availableSeats: totalSeats,
            exists: true
        });

        emit TrainAdded(trainCounter, name);
    }

    function bookTicket(uint256 trainId) public {
        require(trains[trainId].exists, "Train does not exist");
        require(trains[trainId].availableSeats > 0, "No seats available");
        require(!hasBooked[msg.sender][trainId], "You have already booked this train");

        Train storage train = trains[trainId];
        uint256 seatNumber = train.totalSeats - train.availableSeats + 1;

        trainTickets[trainId].push(Ticket({
            passenger: msg.sender,
            trainId: trainId,
            seatNumber: seatNumber
        }));

        train.availableSeats--;
        hasBooked[msg.sender][trainId] = true;

        emit TicketBooked(msg.sender, trainId, seatNumber);
    }

    function getMyTickets() public view returns (Ticket[] memory) {
        uint256 count = 0;
        for (uint256 i = 1; i <= trainCounter; i++) {
            for (uint256 j = 0; j < trainTickets[i].length; j++) {
                if (trainTickets[i][j].passenger == msg.sender) {
                    count++;
                }
            }
        }

        Ticket[] memory result = new Ticket[](count);
        uint256 k = 0;
        for (uint256 i = 1; i <= trainCounter; i++) {
            for (uint256 j = 0; j < trainTickets[i].length; j++) {
                if (trainTickets[i][j].passenger == msg.sender) {
                    result[k++] = trainTickets[i][j];
                }
            }
        }

        return result;
    }

    function getTrainDetails(uint256 trainId) public view returns (
        string memory name,
        string memory origin,
        string memory destination,
        uint256 departureTime,
        uint256 totalSeats,
        uint256 availableSeats
    ) {
        require(trains[trainId].exists, "Train does not exist");

        Train memory t = trains[trainId];
        return (t.name, t.origin, t.destination, t.departureTime, t.totalSeats, t.availableSeats);
    }
}
