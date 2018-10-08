pragma solidity ^0.4.23;

import "./openzeppelin-solidity/contracts/token/ERC20/MintableToken.sol";

contract MyTestToken is MintableToken {
    string public constant name = "My Test Token";
    string public constant symbol = "MTT";
    uint8 public constant decimals = 18;
}
