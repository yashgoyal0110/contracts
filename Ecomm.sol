// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Ecomm {
    address public owner;
    uint public productId;

    constructor() {
        owner = msg.sender;
    }

    struct Product {
        uint id;
        string name;
        uint price;
        address payable seller;
        bool sold;
    }

    struct Order {
        uint productId;
        address buyer;
        uint timestamp;
    }

    mapping(uint => Product) public products;
    mapping(address => Order[]) public orders;

    event ProductAdded(uint id, string name, uint price, address seller);
    event ProductPurchased(uint id, address buyer);

    function addProduct(string memory name, uint price) external {
        productId++;
        products[productId] = Product(productId, name, price, payable(msg.sender), false);
        emit ProductAdded(productId, name, price, msg.sender);
    }

    function buyProduct(uint id) external payable {
        Product storage product = products[id];
        require(!product.sold, "Already sold");
        require(msg.value == product.price, "Incorrect price");
        product.seller.transfer(msg.value);
        product.sold = true;
        orders[msg.sender].push(Order(id, msg.sender, block.timestamp));
        emit ProductPurchased(id, msg.sender);
    }

    function getOrders() external view returns (Order[] memory) {
        return orders[msg.sender];
    }
}

