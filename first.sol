pragma solidity ^0.8.21;

contract MultiSigWallet {
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint public numConfirmationsRequired;

    struct Transaction {
        address to;
        uint value;
        bool executed;
        mapping(address => bool) isConfirmed;
        uint numConfirmations;
    }

    Transaction[] public transactions;

    event Deposit(address indexed sender, uint value, uint balance);
    event SubmitTransaction(address indexed owner, uint indexed transactionId, address indexed to, uint value);
    event ConfirmTransaction(address indexed owner, uint indexed transactionId);
    event ExecuteTransaction(address indexed owner, uint indexed transactionId);

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }

    constructor(address[] memory _owners, uint _numConfirmationsRequired) {
        require(_owners.length > 0, "Owners required");
        require(_numConfirmationsRequired > 0 && _numConfirmationsRequired <= _owners.length, "Invalid number of confirmations");
        
        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Duplicate owner");

            isOwner[owner] = true;
            owners.push(owner);
        }
        
        numConfirmationsRequired = _numConfirmationsRequired;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    function submitTransaction(address _to, uint _value) external onlyOwner {
        uint transactionId = transactions.length;
        transactions.push(Transaction({
            to: _to,
            value: _value,
            executed: false,
            numConfirmations: 0
        }));

        emit SubmitTransaction(msg.sender, transactionId, _to, _value);
    }

    function confirmTransaction(uint _transactionId) external onlyOwner {
        require(_transactionId < transactions.length, "Transaction not found");
        Transaction storage transaction = transactions[_transactionId];
        require(!transaction.isConfirmed[msg.sender], "Already confirmed");
        
        transaction.isConfirmed[msg.sender] = true;
        transaction.numConfirmations++;

        emit ConfirmTransaction(msg.sender, _transactionId);

        if (transaction.numConfirmations >= numConfirmationsRequired) {
            executeTransaction(_transactionId);
        }
    }

    function executeTransaction(uint _transactionId) public onlyOwner {
        require(_transactionId < transactions.length, "Transaction not found");
        Transaction storage transaction = transactions[_transactionId];
        require(transaction.numConfirmations >= numConfirmationsRequired, "Not enough confirmations");
        require(!transaction.executed, "Already executed");

        transaction.executed = true;
        (bool success, ) = transaction.to.call{value: transaction.value}("");
        require(success, "Execution failed");

        emit ExecuteTransaction(msg.sender, _transactionId);
    }

    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    function getTransactions() external view returns (Transaction[] memory) {
        return transactions;
    }
}
