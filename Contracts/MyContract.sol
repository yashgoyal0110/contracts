// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Ownable - A basic ownership contract
contract Ownable {
    address owner;

    // Modifier that restricts function access to only the contract owner
    modifier onlyOwner() {
        require(msg.sender == owner, "must be owner");
        _;
    }

    // Sets the deployer as the initial owner
    constructor() {
        owner = msg.sender;
    }
}

/// @title SecretVault - A simple contract to store a secret
contract SecretVault {
    string private secret;  // Private variable to store the secret

    // Constructor that sets the secret during deployment
    constructor(string memory _secret) {
        secret = _secret;
    }

    // Public getter to return the stored secret
    function getSecret() public view returns (string memory) {
        return secret;
    }
}

/// @title MyContract - Ownable contract that creates and manages a SecretVault
contract MyContract is Ownable {
    address private secretVault; // Stores the address of the deployed SecretVault

    // Constructor that creates a new SecretVault instance with the provided secret
    constructor(string memory _secret) {
        SecretVault _secretVault = new SecretVault(_secret); // Deploy new SecretVault contract
        secretVault = address(_secretVault);                 // Store its address
    }

    // Function to retrieve the secret from the deployed SecretVault
    // Only callable by the owner of MyContract
    function getSecret() public view onlyOwner returns (string memory) {
        return SecretVault(secretVault).getSecret(); // Calls the getSecret function from the deployed contract
    }
}
