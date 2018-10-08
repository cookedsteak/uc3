pragma solidity ^0.4.24;

import "./StandardAsset.sol";
import "./openzeppelin-solidity/contracts/ownership/Ownable.sol";

contract Wallet is Ownable{
    //  example address
    address constant public master = 0xCA35b7d915458EF540aDe6068dFe2F44E8fa733c;
    address public operator;

    modifier OnlyMaster() {
        require(msg.sender == master);
        _;
    }
    // id => StandAsset address
    mapping(uint => address) public assetsClass;
    // assetType & tokenIds
    mapping(address=> uint[]) public assetList;

    constructor() public {
        operator = msg.sender;
    }

    function withDraw(uint256 _amount) public OnlyMaster {
        require(_amount <= address(this).balance);
        master.transfer(_amount);
    }

    function takeBack(address _asset, uint256 _tokenId) {
        StandardAsset asset = StandardAsset(_asset);
        asset.safeTransferFrom(address(this), master, _tokenId);
    }

    function Approve(address _approver) public {
        owner = _approver;
    }

    function CancelApprove(address _approver) public {
        owner = master;
    }
}
