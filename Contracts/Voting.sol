// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Voting {
    address public admin;

    struct Proposal {
        uint id;
        string description;
        uint voteCount;
    }

    mapping(uint => Proposal) public proposals;
    mapping(address => bool) public hasVoted;

    uint public proposalId;
    bool public votingOpen;

    constructor() {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    function addProposal(string memory description) external onlyAdmin {
        proposalId++;
        proposals[proposalId] = Proposal(proposalId, description, 0);
    }

    function startVoting() external onlyAdmin {
        votingOpen = true;
    }

    function endVoting() external onlyAdmin {
        votingOpen = false;
    }

    function vote(uint id) external {
        require(votingOpen, "Voting closed");
        require(!hasVoted[msg.sender], "Already voted");
        require(id > 0 && id <= proposalId, "Invalid proposal");
        hasVoted[msg.sender] = true;
        proposals[id].voteCount++;
    }

    function getWinner() external view returns (uint winnerId, string memory description, uint votes) {
        uint maxVotes = 0;
        for (uint i = 1; i <= proposalId; i++) {
            if (proposals[i].voteCount > maxVotes) {
                maxVotes = proposals[i].voteCount;
                winnerId = proposals[i].id;
                description = proposals[i].description;
                votes = proposals[i].voteCount;
            }
        }
    }
}

