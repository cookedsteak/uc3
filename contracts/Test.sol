pragma solidity ^0.4.23;


contract A {
    address public controller;

    constructor() public{
        controller = msg.sender;
    }
}

contract Test {
    address public owner;
    A public a;

    mapping (uint => A) public alist;

    string private version_;

    constructor() public {
        owner = msg.sender;
    }

    function getVersion() public returns(string) {
        return version_;
    }

    function setVersion(string _version) public {
        a = new A();
        alist[1] = a;
        version_ = _version;
    }

    function buySth() payable public {
    }

    function showBalance() view public returns(uint256) {
        return this.balance;
    }
}
