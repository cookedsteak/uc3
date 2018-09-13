pragma solidity ^0.4.23;

import "./StandardAsset.sol";
import "./openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./openzeppelin-solidity/contracts/math/SafeMath.sol";


// more like a price/buyer-fixed transaction
// more suitable for online trading
contract AssetDeal is Ownable {
    using SafeMath for uint256;

    //    uint256 dealId;
    uint32 feePercentage = 5; // %
    uint256 defaultClaimExp = 5 days;

    StandardAsset public standardAsset;

    enum Type   {DIRECT, SECURED}
    enum State  {ONSALE, ONDELIVERY, ONCONFIRM, FINISHED, CANCELLED}

    struct Deal {
        address seller;
        address buyer;
        uint256 price;
        uint256 tax;
        uint256 claimExp;
        uint256 tokenId;
        Type    dealType;
        State   dealState;
        uint256 createdAt;
    }

    mapping (uint256 => Deal) public dealList;

    event CreateDeal(address indexed _assetType, uint256 _tokenId, address indexed _seller, address indexed _buyer, uint256 _price, uint256 _tax, uint256 _dealId);
    event PayByEth(address _buyer, address _seller, uint256 _amount, uint256 tokenId);
    event Delivered(address indexed _from, uint256 _dealId, uint256 _time);
    event Confirmed(address indexed _from, uint256 _dealId, uint256 _time);

    constructor(address _assetAddress) public {
        standardAsset = StandardAsset(_assetAddress);
    }

    function getAssetOwner(uint256 _tokenId) view public returns (address) {
        return standardAsset.ownerOf(_tokenId);
    }

    function getDealState(uint256 _dealId) view public returns (State) {
        return dealList[_dealId].dealState;
    }

    function getDeal(uint256 _dealId) external view returns (
        address seller, address buyer,
        uint256 price, uint256 tax,
        uint256 claimExp, uint256 tokenId,
        Type dealType, State dealState, uint256 createdAt
    ) {
        Deal memory deal = dealList[_dealId];
        seller = deal.seller;
        buyer = deal.buyer;
        price = deal.price;
        tax = deal.tax;
        claimExp = deal.claimExp;
        tokenId = deal.tokenId;
        dealType = deal.dealType;
        dealState = deal.dealState;
        createdAt = deal.createdAt;
    }

    function _escrow(address _owner, uint256 _tokenId) internal {
        standardAsset.transferFrom(_owner, address(this), _tokenId);
    }

    function _cancelEscrow(address _owner, uint256 _tokenId) internal {
        standardAsset.transferFrom(address(this), _owner, _tokenId);
    }

    function _newDeal(
        uint256 _tokenId,
        address _buyer,
        uint256 _price,
        uint256 _tax,
        Type _dealType
    ) internal {
        require(msg.sender != _buyer);
        require(_price == uint256(uint128(_price)));
        require(_tax == uint256(uint128(_tax)));
        require(getAssetOwner(_tokenId) == msg.sender);

        Deal memory deal = Deal(
            msg.sender,
            _buyer,
            _price,
            _tax,
            defaultClaimExp,
            _tokenId,
            _dealType,
            State.ONSALE,
            now
        );
        // transfer to contract
        _escrow(msg.sender, _tokenId);

        uint256 dealId = getDealId(standardAsset, _tokenId, _price);
        dealList[dealId] = deal;
        emit CreateDeal(standardAsset, _tokenId, msg.sender, _buyer, _price, _tax, dealId);
    }

    function createDirectDeal(uint256 _tokenId, uint256 _price, uint256 _tax) external {
        _newDeal(_tokenId, address(0), _price, _tax, Type.DIRECT);
    }

    function createSecuredDeal(uint256 _tokenId, uint256 _price, uint256 _tax) external {
        _newDeal(_tokenId, address(0), _price, _tax, Type.SECURED);
    }

    function cancelDeal(uint256 _dealId) public {
        Deal storage deal = dealList[_dealId];

        require(deal.dealState == State.ONSALE);
        require(msg.sender == deal.seller);

        _cancelEscrow(msg.sender, deal.tokenId);
        deal.dealState = State.CANCELLED;
    }

    function payByEth(uint256 _dealId) external payable {
        _payByEth(_dealId);
    }

    function _payByEth(uint256 _dealId) internal {
        Deal storage deal = dealList[_dealId];
        require(deal.dealState == State.ONSALE, "Deal state is not correct");

        uint256 wholePrice = deal.price.add(deal.tax);
        uint256 buyerChange = 0;

        require(wholePrice > 0 && msg.value >= wholePrice, "Whole price is not correct");
        // if deal is not free
        buyerChange = msg.value.sub(wholePrice);

        if (deal.buyer == address(0)) {
            // normal sale
            deal.buyer = msg.sender;
        } else {
            // specific sale
            require(msg.sender == deal.buyer);
        }
        if (buyerChange > 0) {
            deal.buyer.transfer(buyerChange);
        }

        uint256 fee = _calcFee(deal.price);
        uint256 sellerReward = wholePrice.sub(fee);

        if (deal.dealType == Type.DIRECT) {
            if (sellerReward > 0) {
                deal.seller.transfer(sellerReward);
            }
            standardAsset.safeTransferFrom(this, deal.buyer, deal.tokenId);
            deal.dealState = State.FINISHED;
        } else if (deal.dealType == Type.SECURED) {
            // @todo seller delivery exp
            deal.dealState = State.ONDELIVERY;
        }

        emit PayByEth(deal.buyer, deal.seller, wholePrice, deal.tokenId);
    }

    function deliver(uint256 _dealId) public {
        Deal storage deal = dealList[_dealId];
        require(deal.dealType == Type.SECURED);
        require(deal.dealState == State.ONDELIVERY);
        require(msg.sender == deal.seller);

        deal.dealState = State.ONCONFIRM;
        emit Delivered(msg.sender, _dealId, now);
    }

    function confirm(uint256 _dealId) public {
        // check sale status
        Deal storage deal = dealList[_dealId];
        require(deal.dealType == Type.SECURED);
        require(now <= deal.createdAt + deal.claimExp);
        require(deal.dealState == State.ONCONFIRM);
        require(msg.sender == deal.buyer);
        //
        standardAsset.safeTransferFrom(this, deal.buyer, deal.tokenId);
        uint256 sellerReward = deal.price.add(deal.tax).sub(_calcFee(deal.price));
        deal.seller.transfer(sellerReward);

        deal.dealState = State.FINISHED;
        emit Confirmed(msg.sender, _dealId, now);
    }

    function getDealId(address _asset, uint256 _tokenId, uint256 _price) public view returns (uint256) {
        uint256 id = uint256(keccak256(abi.encodePacked(_asset, _tokenId, _price, now)));
        return id;
    }

    // calculate Trade Fee
    function _calcFee(uint256 _price) internal view returns (uint256) {
        return uint256(_price * feePercentage / 100);
    }
}
