// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract DecentralizedMarketplace {
    
    // State variables
    address public owner;
    uint256 public platformFeePercent = 250; // 2.5% (basis points)
    uint256 public constant MAX_FEE_PERCENT = 1000;
    uint256 public itemCounter;
    uint256 public totalPlatformFees;
    
    enum ItemStatus { Active, Sold, Inactive }
    enum OrderStatus { Pending, Completed, Disputed, Refunded }
    
    struct Item {
        uint256 id;
        string name;
        string description;
        uint256 price;
        address payable seller;
        ItemStatus status;
        uint256 createdAt;
        string imageHash;
        uint256 categoryId;
    }
    
    struct Order {
        uint256 id;
        uint256 itemId;
        address buyer;
        address seller;
        uint256 amount;
        OrderStatus status;
        uint256 createdAt;
        uint256 completedAt;
    }
    
    struct Review {
        address reviewer;
        address reviewee;
        uint256 itemId;
        uint8 rating; // 1-5 stars
        string comment;
        uint256 timestamp;
    }
    
    struct Seller {
        bool isRegistered;
        string storeName;
        string description;
        uint256 totalSales;
        uint256 averageRating;
        uint256 totalReviews;
        uint256 registrationDate;
    }
    
    // Mappings
    mapping(uint256 => Item) public items;
    mapping(uint256 => Order) public orders;
    mapping(address => Seller) public sellers;
    mapping(address => uint256[]) public sellerItems;
    mapping(address => uint256[]) public buyerOrders;
    mapping(uint256 => Review[]) public itemReviews;
    mapping(address => mapping(address => bool)) public hasReviewed;
    mapping(address => uint256) public pendingWithdrawals;
    mapping(uint256 => string) public categories;
    mapping(address => bool) public authorizedModerators;
    
    // Arrays
    uint256[] public activeItems;
    uint256[] public allOrders;
    uint256[] public categoryIds;
    
    // Events
    event ItemListed(uint256 indexed itemId, address indexed seller, uint256 price);
    event ItemPurchased(uint256 indexed itemId, uint256 indexed orderId, address indexed buyer, uint256 amount);
    event OrderCompleted(uint256 indexed orderId, uint256 timestamp);
    event ReviewSubmitted(uint256 indexed itemId, address indexed reviewer, uint8 rating);
    event SellerRegistered(address indexed seller, string storeName);
    event PlatformFeeUpdated(uint256 oldFee, uint256 newFee);
    event WithdrawalMade(address indexed user, uint256 amount);
    event DisputeRaised(uint256 indexed orderId, address indexed buyer);
    event CategoryAdded(uint256 indexed categoryId, string categoryName);
    event ModeratorAdded(address indexed moderator);
    event ModeratorRemoved(address indexed moderator);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyRegisteredSeller() {
        require(sellers[msg.sender].isRegistered, "Must be a registered seller");
        _;
    }
    
    modifier onlyModerator() {
        require(authorizedModerators[msg.sender] || msg.sender == owner, "Unauthorized moderator");
        _;
    }
    
    modifier validItem(uint256 _itemId) {
        require(_itemId > 0 && _itemId <= itemCounter, "Invalid item ID");
        _;
    }
    
    modifier itemExists(uint256 _itemId) {
        require(items[_itemId].id != 0, "Item does not exist");
        _;
    }
    
    // Constructor
    constructor() {
        owner = msg.sender;
        authorizedModerators[msg.sender] = true;
        
        // Initialize some default categories
        _addCategory("Electronics");
        _addCategory("Clothing");
        _addCategory("Books");
        _addCategory("Home & Garden");
        _addCategory("Sports");
    }
    
    // Seller registration functions
    function registerSeller(string calldata _storeName, string calldata _description) external {
        require(!sellers[msg.sender].isRegistered, "Already registered as seller");
        require(bytes(_storeName).length > 0, "Store name cannot be empty");
        
        sellers[msg.sender] = Seller({
            isRegistered: true,
            storeName: _storeName,
            description: _description,
            totalSales: 0,
            averageRating: 0,
            totalReviews: 0,
            registrationDate: block.timestamp
        });
        
        emit SellerRegistered(msg.sender, _storeName);
    }
    
    function updateSellerInfo(string calldata _storeName, string calldata _description) external onlyRegisteredSeller {
        require(bytes(_storeName).length > 0, "Store name cannot be empty");
        
        sellers[msg.sender].storeName = _storeName;
        sellers[msg.sender].description = _description;
    }
    
    // Item listing functions
    function listItem(
        string calldata _name,
        string calldata _description,
        uint256 _price,
        string calldata _imageHash,
        uint256 _categoryId
    ) external onlyRegisteredSeller {
        require(bytes(_name).length > 0, "Item name cannot be empty");
        require(_price > 0, "Price must be greater than 0");
        require(_categoryId > 0 && _categoryExists(_categoryId), "Invalid category");
        
        itemCounter++;
        uint256 newItemId = itemCounter;
        
        items[newItemId] = Item({
            id: newItemId,
            name: _name,
            description: _description,
            price: _price,
            seller: payable(msg.sender),
            status: ItemStatus.Active,
            createdAt: block.timestamp,
            imageHash: _imageHash,
            categoryId: _categoryId
        });
        
        sellerItems[msg.sender].push(newItemId);
        activeItems.push(newItemId);
        
        emit ItemListed(newItemId, msg.sender, _price);
    }
    
    function updateItemStatus(uint256 _itemId, ItemStatus _status) external validItem(_itemId) {
        require(items[_itemId].seller == msg.sender, "Only seller can update item status");
        require(items[_itemId].status != ItemStatus.Sold, "Cannot update sold item");
        
        items[_itemId].status = _status;
        
        if (_status == ItemStatus.Inactive) {
            _removeFromActiveItems(_itemId);
        } else if (_status == ItemStatus.Active) {
            _addToActiveItems(_itemId);
        }
    }
    
    // Purchase functions
    function purchaseItem(uint256 _itemId) external payable validItem(_itemId) itemExists(_itemId) {
        Item storage item = items[_itemId];
        require(item.status == ItemStatus.Active, "Item not available for purchase");
        require(msg.sender != item.seller, "Sellers cannot buy their own items");
        require(msg.value == item.price, "Incorrect payment amount");
        
        // Calculate platform fee
        uint256 platformFee = (msg.value * platformFeePercent) / 10000;
        uint256 sellerAmount = msg.value - platformFee;
        
        // Update item status
        item.status = ItemStatus.Sold;
        _removeFromActiveItems(_itemId);
        
        // Create order
        uint256 orderId = allOrders.length + 1;
        orders[orderId] = Order({
            id: orderId,
            itemId: _itemId,
            buyer: msg.sender,
            seller: item.seller,
            amount: msg.value,
            status: OrderStatus.Pending,
            createdAt: block.timestamp,
            completedAt: 0
        });
        
        allOrders.push(orderId);
        buyerOrders[msg.sender].push(orderId);
        
        // Add to pending withdrawals
        pendingWithdrawals[item.seller] += sellerAmount;
        totalPlatformFees += platformFee;
        
        // Update seller stats
        sellers[item.seller].totalSales++;
        
        emit ItemPurchased(_itemId, orderId, msg.sender, msg.value);
    }
    
    function completeOrder(uint256 _orderId) external {
        require(_orderId > 0 && _orderId <= allOrders.length, "Invalid order ID");
        Order storage order = orders[_orderId];
        require(order.buyer == msg.sender, "Only buyer can complete order");
        require(order.status == OrderStatus.Pending, "Order already processed");
        
        order.status = OrderStatus.Completed;
        order.completedAt = block.timestamp;
        
        emit OrderCompleted(_orderId, block.timestamp);
    }
    
    // Review system
    function submitReview(
        uint256 _itemId,
        uint8 _rating,
        string calldata _comment
    ) external validItem(_itemId) {
        require(_rating >= 1 && _rating <= 5, "Rating must be between 1 and 5");
        require(_hasOrderForItem(msg.sender, _itemId), "Must have purchased item to review");
        require(!hasReviewed[msg.sender][items[_itemId].seller], "Already reviewed this seller");
        
        Review memory newReview = Review({
            reviewer: msg.sender,
            reviewee: items[_itemId].seller,
            itemId: _itemId,
            rating: _rating,
            comment: _comment,
            timestamp: block.timestamp
        });
        
        itemReviews[_itemId].push(newReview);
        hasReviewed[msg.sender][items[_itemId].seller] = true;
        
        _updateSellerRating(items[_itemId].seller, _rating);
        
        emit ReviewSubmitted(_itemId, msg.sender, _rating);
    }
    
    // Withdrawal functions
    function withdraw() external {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No funds to withdraw");
        
        pendingWithdrawals[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
        
        emit WithdrawalMade(msg.sender, amount);
    }
    
    function withdrawPlatformFees() external onlyOwner {
        uint256 amount = totalPlatformFees;
        require(amount > 0, "No platform fees to withdraw");
        
        totalPlatformFees = 0;
        payable(owner).transfer(amount);
        
        emit WithdrawalMade(owner, amount);
    }
    
    // Admin functions
    function setPlatformFee(uint256 _feePercent) external onlyOwner {
        require(_feePercent <= MAX_FEE_PERCENT, "Fee too high");
        
        uint256 oldFee = platformFeePercent;
        platformFeePercent = _feePercent;
        
        emit PlatformFeeUpdated(oldFee, _feePercent);
    }
    
    function addCategory(string calldata _categoryName) external onlyModerator {
        _addCategory(_categoryName);
    }
    
    function addModerator(address _moderator) external onlyOwner {
        require(_moderator != address(0), "Invalid moderator address");
        authorizedModerators[_moderator] = true;
        emit ModeratorAdded(_moderator);
    }
    
    function removeModerator(address _moderator) external onlyOwner {
        require(_moderator != owner, "Cannot remove owner as moderator");
        authorizedModerators[_moderator] = false;
        emit ModeratorRemoved(_moderator);
    }
    
    // View functions
    function getActiveItems() external view returns (uint256[] memory) {
        return activeItems;
    }
    
    function getSellerItems(address _seller) external view returns (uint256[] memory) {
        return sellerItems[_seller];
    }
    
    function getBuyerOrders(address _buyer) external view returns (uint256[] memory) {
        return buyerOrders[_buyer];
    }
    
    function getItemReviews(uint256 _itemId) external view returns (Review[] memory) {
        return itemReviews[_itemId];
    }
    
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    // Internal functions
    function _addCategory(string memory _categoryName) internal {
        require(bytes(_categoryName).length > 0, "Category name cannot be empty");
        
        uint256 categoryId = categoryIds.length + 1;
        categories[categoryId] = _categoryName;
        categoryIds.push(categoryId);
        
        emit CategoryAdded(categoryId, _categoryName);
    }
    
    function _categoryExists(uint256 _categoryId) internal view returns (bool) {
        return bytes(categories[_categoryId]).length > 0;
    }
    
    function _removeFromActiveItems(uint256 _itemId) internal {
        for (uint256 i = 0; i < activeItems.length; i++) {
            if (activeItems[i] == _itemId) {
                activeItems[i] = activeItems[activeItems.length - 1];
                activeItems.pop();
                break;
            }
        }
    }
    
    function _addToActiveItems(uint256 _itemId) internal {
        for (uint256 i = 0; i < activeItems.length; i++) {
            if (activeItems[i] == _itemId) {
                return; // Already in active items
            }
        }
        activeItems.push(_itemId);
    }
    
    function _hasOrderForItem(address _buyer, uint256 _itemId) internal view returns (bool) {
        uint256[] memory orders = buyerOrders[_buyer];
        for (uint256 i = 0; i < orders.length; i++) {
            if (orders[orders[i]].itemId == _itemId) {
                return true;
            }
        }
        return false;
    }
    
    function _updateSellerRating(address _seller, uint8 _newRating) internal {
        Seller storage seller = sellers[_seller];
        uint256 totalReviews = seller.totalReviews;
        uint256 currentTotal = seller.averageRating * totalReviews;
        
        seller.totalReviews = totalReviews + 1;
        seller.averageRating = (currentTotal + _newRating) / seller.totalReviews;
    }
    
    fallback() external payable {
        revert("Function not found");
    }
}