pragma solidity ^0.4.23;

import "./AssetDealBasic.sol";
import "./openzeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "./openzeppelin-solidity/contracts/ownership/Ownable.sol";

contract AssetDeal is AssetDealBasic, Pausable {
    using SafeMath for uint256;

    event WithDraw(address indexed _owner, uint256 _amount);
    event WithDrawToken(address indexed _owner, address _token, uint256 _amount);

    constructor() public {

    }

    /* ERC20 Token control */
    function addAvailableToken(address _token, uint256 _fee) public onlyOwner {
        _setTokenFeeRate(_token, _fee);
    }

    function removeAvailableToken(address _token) public onlyOwner {
        _removeAvailableToken(_token);
    }

    function pauseAvailableToken(address _token) public onlyOwner {
        _setAvailableToken(_token, false);
    }

    function activateAvailableToken(address _token) public onlyOwner {
        _setAvailableToken(_token, true);
    }

    // functions for this contract owner
    function withDraw(uint256 _amount) external onlyOwner {
        require(_amount > address(this).balance);
        owner.transfer(_amount);
        emit WithDraw(owner, _amount);
    }

    // @todo consider: token is available when created deal ailbert forbidden now
    function withDrawToken(uint256 _amount, address _token) external onlyOwner {
        ERC20 token = ERC20(_token);
        require(token.transfer(owner, _amount), "withdraw token failed");
        emit WithDrawToken(owner, _token, _amount);
    }

    // _dealAddresses, _dealValues, dType
    // @param: _dealAddresses: 0.assetType, 1.seller, 2.buyer, 3.tradeAsset
    // @param: _dealValues: 0.duration, 1.createdAt, 2.amount, 3.tokenId
    // @param: dType: DealType
    function createEthDeal(address[4] _dealAddresses, uint[4] _dealValues, DealType _dType)
    public
    canBeStoredWith128Bits(_dealValues[2])
    whenNotPaused
    {
        Deal memory deal = Deal(
            _dealAddresses[0],
            _dealValues[3],
            _dealAddresses[1],
            _dealAddresses[2],
            _dealValues[0],
            now,
            _dType,
            DealState.ONSALE,
            PayMethod.ETH,
            _dealValues[2],
            address(0),
            0
        );
        _createDeal(deal);
    }

    // _dealAddresses, _dealValues, dType
    // @param: _dealAddresses: 0.assetType, 1.seller, 2.buyer, 3.tradeAsset
    // @param: _dealValues: 0.duration, 1.createdAt, 2.amount, 3.tokenId
    // @param: dType: DealType
    function createTokenDeal(address[4] _dealAddresses, uint[4] _dealValues, DealType _dType)
    public
    whenNotPaused
    canBeStoredWith128Bits(_dealValues[2])
    tokenIsValid(_dealAddresses[3])
    {
        Deal memory deal = Deal(
            _dealAddresses[0],
            _dealValues[3],
            _dealAddresses[1],
            _dealAddresses[2],
            _dealValues[0],
            now,
            _dType,
            DealState.ONSALE,
            PayMethod.TOKEN,
            _dealValues[2],
            _dealAddresses[3],
            0
        );
        _createDeal(deal);
    }

    // _dealAddresses, _dealValues, dType
    // @param: _dealAddresses: 0.assetType, 1.seller, 2.buyer, 3.tradeAsset
    // @param: _dealValues: 0.duration, 1.createdAt, 2.amount, 3.tokenId, 4.tradeTokenId
    // @param: dType: DealType
    function createAssetDeal(address[4] _dealAddresses, uint[5] _dealValues, DealType _dType)
    public
    whenNotPaused
    {
        Deal memory deal = Deal(
            _dealAddresses[0],
            _dealValues[3],
            _dealAddresses[1],
            _dealAddresses[2],
            _dealValues[0],
            now,
            _dType,
            DealState.ONSALE,
            PayMethod.TOKEN,
            _dealValues[2],
            _dealAddresses[3],
            _dealValues[4]
        );
        _createDeal(deal);
    }

    // Cancel a deal if condition is satisfied
    function cancelDeal(address _assetType, uint256 _tokenId)
    external
    whenNotPaused
    dealExists(_assetType, _tokenId)
    {
        _cancelDeal(_assetType, _tokenId);
    }

    function payByEth(address _assetType, uint256 _tokenId)
    external
    payable
    whenNotPaused
    dealExists(_assetType, _tokenId)
    {
        _payByEth(_assetType, _tokenId);
    }

    function payByToken(address _assetType, uint256 _tokenId)
    external
    whenNotPaused
    dealExists(_assetType, _tokenId)
    {
        _payByToken(_assetType, _tokenId);
    }

    function payByAsset(address _assetType, uint256 _tokenId, address _tradeAsset, uint256 _tradeTokenId)
    external
    whenNotPaused
    {
        _payByAsset(_assetType, _tokenId, _tradeAsset, _tradeTokenId);
    }


    //============get methods============//
    function getDealInfo(address _assetType, uint256 _tokenId)
    public
    view
    dealExists(_assetType, _tokenId)
    returns
    (
        address     seller,
        address     buyer,
        uint256     duration,
        uint256     createdAt,
        uint256     amount,
        address     tradeAsset,
        uint256     tradeTokenId
    ) {
        Deal memory deal = dealList[_assetType][_tokenId];
        return(
        deal.seller,
        deal.buyer,
        deal.duration,
        deal.createdAt,
        deal.amount,
        deal.tradeAsset,
        deal.tradeTokenId
        );
    }

    function getDealState(address _assetType, uint256 _tokenId)
    public
    view
    dealExists(_assetType, _tokenId)
    returns(DealState) {
        return dealList[_assetType][_tokenId].dState;
    }

    //
    function cancelDealBySeller(address _assetType, uint256 _tokenId) public {
        Deal memory deal = dealList[_assetType][_tokenId];
        require(msg.sender == deal.seller);
        _cancelDeal(_assetType, _tokenId);
    }

}
