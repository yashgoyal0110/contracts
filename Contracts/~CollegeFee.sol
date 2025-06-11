// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract CollegeFee {
    address public owner;

    struct Student {
        uint256 fee;
        bool isRegistered;
        bool hasPaid;
    }

    mapping(address => Student) public students;

    event StudentRegistered(address student, uint256 fee);
    event FeePaid(address student, uint256 amount);
    event Withdrawn(uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only college can perform this action");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function registerStudent(address _student, uint256 _fee) external onlyOwner {
        require(!students[_student].isRegistered, "Already registered");
        students[_student] = Student(_fee, true, false);
        emit StudentRegistered(_student, _fee);
    }

    function payFee() external payable {
        Student storage student = students[msg.sender];
        require(student.isRegistered, "Not a registered student");
        require(!student.hasPaid, "Fee already paid");
        require(msg.value == student.fee, "Incorrect fee amount");

        student.hasPaid = true;
        emit FeePaid(msg.sender, msg.value);
    }

    function hasPaid(address _student) external view returns (bool) {
        return students[_student].hasPaid;
    }

    function getFee(address _student) external view returns (uint256) {
        return students[_student].fee;
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");

        payable(owner).transfer(balance);
        emit Withdrawn(balance);
    }

    receive() external payable {
        revert("Use payFee function to pay");
    }
}
