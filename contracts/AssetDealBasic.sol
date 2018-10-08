pragma solidity ^0.4.23;

import "./StandardAsset.sol";
import "./openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./openzeppelin-solidity/contracts/ECRecovery.sol";
import "./openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

// Each type of asset has a specific AssetDeal contract
// Pay type could has erc20 tokens, eth, or even other assets.
// Deal type could be online / online + offline
// Only support standard ERC721 or ERC20 implementation
contract AssetDealBasic {
    using ECRecovery for bytes32;
    using SafeMath for uint256;

    // Fee percentage (unit%)
    uint256 internal ethFeeRate = 5;
    uint256 internal maximumFeeCost = 1 ether;
    uint256 internal minimumFeeCost = 100 wei;

    enum DealType   {ONLINE, OFFLINE}
    enum DealState  {ONSALE, TOSHIP, TOCONFIRM, TOREFUND, FINISHED, CANCELLED}
    enum PayMethod  {ETH, TOKEN, ASSET}

    struct Deal {
        address     assetType;
        uint256     tokenId;
        address     seller;
        address     buyer;
        uint256     duration;
        uint256     createdAt;
        DealType    dType;
        DealState   dState;
        PayMethod   pMethod;        // how to pay
        uint256     amount;         // eth or ERC20 amount
        address     tradeAsset;     // ERC721/ERC20 implementation contract address
        uint256     tradeTokenId;   // swap tokenId
    }

    // Asset address => tokenId for sale
    mapping (address => mapping(uint256 => Deal)) dealList;
    // ERC20 Token address => fee rate
    mapping (address => uint256) tokenFeeRates;
    // ERC20 or ERC721 is available for payment
    mapping (address => bool) tokenAvailable;

    event DealCreated (
        address _assetType,
        uint256 _tokenId,
        address indexed _seller,
        address indexed _buyer,
        uint256 _duration,
        uint256 _createdAt,
        uint256 _amount,
        address _tradeAsset,
        uint256 _tradeTokenId,
        DealType _dType,
        PayMethod _pMethod
    );

    event DealSuccessful(
        address _assetType,
        uint256 _tokenId,
        address indexed _seller,
        address indexed _buyer,
        uint256 _amount,
        address _tradeAsset,
        uint256 _tradeTokenId,
        uint256 _time
    );

    event DealCancelled(
        address _assetType,
        uint256 _tokenId,
        address indexed _seller,
        address indexed _buyer,
        uint256 _time
    );

    event ReceivedLog(address indexed _from, address _assetType, uint256 _tokenId);
    event ShippedLog();
    event ConfirmedLog();

    // Modifiers to check that inputs can be safely stored with a certain
    // number of bits. We use constants and multiple modifiers to save gas.
    modifier canBeStoredWith64Bits(uint256 _value) {
        require(_value <= 18446744073709551615);
        _;
    }

    modifier canBeStoredWith128Bits(uint256 _value) {
        require(_value < 340282366920938463463374607431768211455);
        _;
    }

    modifier dealExists(address _assetType, uint256 _tokenId) {
        require(dealList[_assetType][_tokenId].seller != address(0));
        _;
    }

    modifier dealCanBeCreated(address _assetType, uint256 _tokenId) {
        require(
            dealList[_assetType][_tokenId].seller == address(0) ||
            dealList[_assetType][_tokenId].dState == DealState.FINISHED ||
            dealList[_assetType][_tokenId].dState == DealState.CANCELLED
        , "Can not create deal, it's in process");
        _;
    }

    // Whether token can be used for payment
    modifier tokenIsValid(address _assetType) {
        require(tokenAvailable[_assetType]);
        _;
    }

//    modifier isERC20(address _assetType) {
//        // @todo check if token is a standard erc20 implementation
//        require();
//        _;
//    }

    //===========get & set============//
    // Pay with eth
    function _setEthFeeRate(uint256 _rate) internal {
        require(_rate < 100 && _rate >= 0);
        ethFeeRate = _rate;
    }

    function _setMaximumFeeCost(uint256 _fee) internal canBeStoredWith64Bits(_fee) {
        maximumFeeCost = _fee;
    }

    function _setMinimumFeeCost(uint256 _fee) internal canBeStoredWith64Bits(_fee) {
        maximumFeeCost = _fee;
    }

    function _setDealState(address _assetType, uint256 _tokenId, DealState _state)
    internal
    dealExists(_assetType, _tokenId)
    {
        Deal storage deal = dealList[_assetType][_tokenId];
        deal.dState = _state;
    }

    // Set valid token and it's fee rate
    function _setTokenFeeRate(address _token, uint256 _fee) internal {
        require(_token != address(0), "Invalid token address");
        require(_fee < 100 && _fee >= 0, "Fee is out of range");
        tokenFeeRates[_token] = _fee;
        tokenAvailable[_token] = true;
    }

    function _removeAvailableToken(address _token) internal {
        require(_token != address(0), "Invalid token address");
        tokenAvailable[_token] = false;
        tokenFeeRates[_token] = 0;
    }

    function _setAvailableToken(address _token, bool _bool) internal {
        require(_token != address(0), "Invalid token address");
        tokenAvailable[_token] = _bool;
    }

    function getEthFeeRate() public view returns (uint256) {
        return ethFeeRate;
    }

    function getMaximumFeeCost() public view returns (uint256) {
        return maximumFeeCost;
    }

    function getMinimumFeeCost() public view returns (uint256) {
        return minimumFeeCost;
    }

    function getTokenFeeRate(address _token) public view returns (uint256) {
        return tokenFeeRates[_token];
    }

    //    function getDealHash(Deal _deal)
    //    public
    //    constant
    //    returns (byte32) {
    //        return keccak256(abi.encodePacked(
    //            _deal.seller, _deal.buyer, _deal.duration,
    //            _deal.createdAt, _deal.dType, _deal.pMethod,
    //            _deal.amount, _deal.tradeAsset
    //            ));
    //    }

    // To check if the signature is correct
    // @param _signer Signer's address
    // @param _hash The msg which has been hashed (contains \x19Ethereum....)
    // @param _sig
    function isValidSignature(address _signer, bytes32 _hash, bytes _sig)
    public
    constant
    returns (bool)
    {
        return _signer == _hash.recover(_sig);
    }

    // place asset in escrow
    function _escrow(address _assetType, uint256 _tokenId, address _owner) internal {
        StandardAsset(_assetType).transferFrom(_owner, address(this), _tokenId);
        emit ReceivedLog(_owner, _assetType, _tokenId);
    }
    // take asset back from escrow
    function _cancelEscrow(address _assetType, uint256 _tokenId, address _to) internal {
        StandardAsset(_assetType).transferFrom(address(this), _to, _tokenId);
    }

    // Create a deal for asset
    // @param _assetType Contract address of ERC721 TOKEN for sale
    // @param _tokenId TokenId for sale
    function _createDeal(Deal _deal)
    internal
    dealCanBeCreated(_deal.assetType, _deal.tokenId)
    {
        StandardAsset asset = StandardAsset(_deal.assetType);
        require(asset.ownerOf(_deal.tokenId) == _deal.seller);

        dealList[_deal.assetType][_deal.tokenId] = _deal;
        // @todo create a market signal
        _escrow(_deal.assetType, _deal.tokenId, _deal.seller);

        emit DealCreated(
            _deal.assetType, _deal.tokenId, _deal.seller, _deal.buyer,
            _deal.duration, _deal.createdAt, _deal.amount,
            _deal.tradeAsset, _deal.tradeTokenId, _deal.dType, _deal.pMethod
        );
    }

    // Cancel a processing deal
    // Only when the deal exists
    function _cancelDeal(address _assetType, uint256 _tokenId)
    internal
    {
//        StandardAsset asset = StandardAsset(_assetType);
        Deal storage deal = dealList[_assetType][_tokenId];
        require(
            deal.dState == DealState.ONSALE
            || deal.dState == DealState.TOSHIP
        , "Deal can not be cancelled");
        // return asset to owner
        _cancelEscrow(_assetType, _tokenId, deal.seller);
        _refund(deal);

        deal.dState = DealState.CANCELLED;

        emit DealCancelled(
            _assetType,
            _tokenId,
            deal.seller,
            deal.buyer,
            now
        );
    }

    // refund paid deal
    function _refund(Deal memory deal)
    internal
    {
        require(deal.dState == DealState.TOREFUND || deal.dState == DealState.TOSHIP);

        if (deal.pMethod == PayMethod.ETH) {
            require(address(this).balance > deal.amount);
            deal.buyer.transfer(deal.amount);
        } else if (deal.pMethod == PayMethod.TOKEN) {
            ERC20 token = ERC20(deal.tradeAsset);
            require(token.balanceOf(address(this)) >= deal.amount);
            token.transfer(deal.buyer, deal.amount);
        } else if (deal.pMethod == PayMethod.ASSET) {
            _cancelEscrow(deal.tradeAsset, deal.tradeTokenId, deal.buyer);
        }
    }

    // Pay methods (ETH, TOKEN, ASSET)
    // Pay By eth, fee from eth or upx
    function _payByEth(address _assetType, uint256 _tokenId)
    internal
    {
        Deal storage deal = dealList[_assetType][_tokenId];
        // only on sale
        require(deal.dState == DealState.ONSALE);
        require(now <= deal.createdAt + deal.duration);
        require(msg.value >= deal.amount); // is this require safe?
        require(deal.pMethod == PayMethod.ETH);

        /* give back change will cost extra fee */
        uint256 buyerChange = msg.value.sub(deal.amount);
        if (buyerChange > 0) {
            msg.sender.transfer(buyerChange);
        }

        // if has set a specific buyer
        if (deal.buyer == address(0)) {
            deal.buyer == msg.sender;
        } else {
            require(msg.sender == deal.buyer);
        }

        _afterPaid(deal);
    }

    // @todo To check if the token is a standard ERC20 implementation
    function _payByToken(address _assetType, uint256 _tokenId)
    internal
    dealExists(_assetType, _tokenId)
    {
        Deal storage deal = dealList[_assetType][_tokenId];
        require(now <= deal.createdAt + deal.duration);
        require(deal.pMethod == PayMethod.TOKEN);

        // if has set a specific buyer
        if (deal.buyer == address(0)) {
            deal.buyer == msg.sender;
        } else {
            require(msg.sender == deal.buyer);
        }

        _afterPaid(deal);
    }


    function _payByAsset(address _assetType, uint256 _tokenId, address _tradeAsset, uint256 _tradeTokenId)
    internal
    dealExists(_assetType, _tokenId)
    {
        Deal storage deal = dealList[_assetType][_tokenId];
        require(now <= deal.createdAt + deal.duration);
        require(deal.tradeAsset == _tradeAsset);
        require(deal.pMethod == PayMethod.ASSET);

        StandardAsset tradeAsset = StandardAsset(_tradeAsset);
        require(tradeAsset.ownerOf(_tradeTokenId) == msg.sender);
        deal.tradeTokenId = _tradeTokenId;

        if (deal.buyer == address(0)) {
            deal.buyer == msg.sender;
        } else {
            require(msg.sender == deal.buyer);
        }

        // need user approve contract to trade asset first
        // may implement in DAPP
        _escrow(_tradeAsset, _tradeTokenId, msg.sender);
        _afterPaid(deal);
    }

    // To determine the next operation to the deal
    function _afterPaid(Deal storage deal)
    internal
    {
        if (deal.dType == DealType.ONLINE) {
            // confirm deal simultaneously
            _finishDeal(deal);
        } else if (deal.dType == DealType.OFFLINE) {
            // wait for buyer's confirmation
            deal.dState = DealState.TOSHIP;
        }
    }

    // Get paid & finish the deal
    function _finishDeal(Deal storage deal)
    internal
    {
        uint256 fee;
        uint256 sellerReward;

        if (deal.pMethod == PayMethod.ETH) {
            fee = _calcFee(deal.amount, ethFeeRate);
            sellerReward = deal.amount.sub(fee);
            if (sellerReward > 0) {
                deal.seller.transfer(sellerReward);
            }
        } else if (deal.pMethod == PayMethod.TOKEN) {
            fee = _calcFee(deal.amount, ethFeeRate);
            sellerReward = deal.amount.sub(fee);
            if (sellerReward > 0) {
                // erc20 token is available
                ERC20 token = ERC20(deal.tradeAsset);
                require(token.transferFrom(deal.buyer, deal.seller, sellerReward));
            }
        } else if (deal.pMethod == PayMethod.ASSET) {
            /* no fee */
            StandardAsset(deal.tradeAsset).safeTransferFrom(address(this), deal.seller, deal.tradeTokenId);
        }

        StandardAsset(deal.assetType).safeTransferFrom(address(this), deal.buyer, deal.tokenId);
        deal.dState = DealState.FINISHED;

        emit DealSuccessful(
            deal.assetType, deal.tokenId, deal.seller,
            deal.buyer, deal.amount, deal.tradeAsset,
            deal.tradeTokenId, now
        );
    }

    // ship by seller
    function _shipDeal(Deal storage deal)
    internal
    {
        require(deal.dState == DealState.TOSHIP && deal.dType == DealType.OFFLINE);
        deal.dState = DealState.TOCONFIRM;
    }

    // confirm by buyer
    function _confirmDeal(Deal storage deal)
    internal
    {
        require(deal.dState == DealState.TOCONFIRM && deal.dType == DealType.OFFLINE);
        _finishDeal(deal);
    }

    // How to determined the Token-fee cost limitation?
    function _calcFee(uint256 _amount, uint256 _rate) internal returns(uint256) {
        if (_amount == 0) {
            return 0;
        }

        uint256 fee = _amount.mul(_rate).div(100);
        if (fee >= maximumFeeCost) {
            return maximumFeeCost;
        } else if (fee <= minimumFeeCost) {
            return minimumFeeCost;
        } else {
            return fee;
        }
    }
}



