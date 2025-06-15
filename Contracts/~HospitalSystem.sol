// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract HospitalSystem {
    address public admin;

    constructor() {
        admin = msg.sender;
    }

    enum Gender { MALE, FEMALE, OTHER }

    struct Person {
        string name;
        uint age;
        Gender gender;
    }

    struct Patient {
        Person person;
        address wallet;
        string[] medicalRecords; // IPFS hash or off-chain ref
        bool exists;
    }

    struct Doctor {
        Person person;
        address wallet;
        string specialization;
        bool exists;
    }

    struct Appointment {
        uint id;
        address patient;
        address doctor;
        uint timestamp;
        string reason;
    }

    mapping(address => Patient) public patients;
    mapping(address => Doctor) public doctors;
    mapping(uint => Appointment) public appointments;

    uint public appointmentCounter = 0;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin allowed");
        _;
    }

    modifier onlyDoctor() {
        require(doctors[msg.sender].exists, "Only doctor allowed");
        _;
    }

    modifier onlyPatient() {
        require(patients[msg.sender].exists, "Only patient allowed");
        _;
    }

    // -------------------- Registration --------------------

    function registerPatient(string memory _name, uint _age, Gender _gender) external {
        require(!patients[msg.sender].exists, "Already registered");
        patients , true);
    }

    function registerDoctor(string memory _name, uint _age, Gender _gender, string memory _specialization) external {
        require(!doctors[msg.sender].exists, "Already registered");
        doctors[msg.sender] = Doctor(Person(_name, _age, _gender), msg.sender, _specialization, true);
    }

    // -------------------- Appointment --------------------

    function scheduleAppointment(address _doctor, uint _timestamp, string memory _reason) external onlyPatient {
        require(doctors[_doctor].exists, "Doctor not found");
        appointmentCounter++;
        appointments[appointmentCounter] = Appointment(appointmentCounter, msg.sender, _doctor, _timestamp, _reason);
    }

    function getAppointment(uint _id) external view returns (Appointment memory) {
        Appointment memory app = appointments[_id];
        require(
            msg.sender == app.patient || msg.sender == app.doctor || msg.sender == admin,
            "Unauthorized access"
        );
        return app;
    }

    // -------------------- Medical Records --------------------

    function addMedicalRecord(address _patient, string memory _recordHash) external onlyDoctor {
        require(patients[_patient].exists, "Patient not found");
        patients[_patient].medicalRecords.push(_recordHash);
    }

    function getMedicalRecords() external view onlyPatient returns (string[] memory) {
        return patients[msg.sender].medicalRecords;
    }

    function getPatientRecords(address _patient) external view returns (string[] memory) {
        require(
            doctors[msg.sender].exists || msg.sender == _patient || msg.sender == admin,
            "Unauthorized"
        );
        return patients[_patient].medicalRecords;
    }
}
