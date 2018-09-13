const { ethGetBalance } = require('./helpers/web3');
const { ether } = require('./helpers/ether')
const AssetRegistry = artifacts.require("./AssetRegistry.sol")
const StandardAsset = artifacts.require("./StandardAsset.sol")
const AssetDeal = artifacts.require("./AssetDeal.sol")

require("chai")
    .use(require('chai-bignumber')(web3.BigNumber))
    .should()

contract("Personal asset deals", async (accounts) => {
    const tokenId = 1
    // Assets infos
    const name = "My car assets"
    const symbol = "CAR"
    const supply = new web3.BigNumber(3)
    const uri = "swarm://mycar.assets"
    const creator = accounts[0]
    const owner = accounts[1]
    const buyer = accounts[2]

    // Deal infos
    const price = ether(1)
    const tax = ether(0.001)

    it('Register a car asset type', async () => {
        this.assetRegister = await AssetRegistry.new({from:creator})
        console.log("contract address: ",this.assetRegister.address)

        await this.assetRegister.registerClass(
            name, symbol, supply, uri, owner,
            {from:creator}
        )
    })

    it('Mint my car asset', async () => {
        // get Asset Address
        let assetId = await this.assetRegister.getId.call(name, symbol, uri)
        let standardAssetAddress = await this.assetRegister.idAssets.call(assetId.toString())
        console.log("my car asset contract address: ", standardAssetAddress)

        // mint a car
        this.standardAsset = await StandardAsset.at(standardAssetAddress)
        let assetType = await this.standardAsset.getAssetType.call()
        console.log("AssetType address: ", assetType)

        // tokenId start from 1
        await this.standardAsset.mint(owner, uri, {from:owner})
        let tokenOwner = await this.standardAsset.ownerOf.call(tokenId)
        console.log("The owner of token 1 is:", tokenOwner)
        tokenOwner.should.equal(owner)
    })

    it('Create a car deal', async () => {
        // deploy contract
        console.log('Standard Asset address: ', this.standardAsset.address)
        this.assetDeal = await AssetDeal.new(this.standardAsset.address, {from:creator})
        console.log('AssetDeal address: ', this.assetDeal.address)

        // approve deal contract
        await this.standardAsset.approve(this.assetDeal.address, tokenId, {from: owner}) // tokenId 1
        let tokenApprover  = await this.standardAsset.getApproved.call(tokenId)
        console.log("Now the approver is: ", tokenApprover)
        tokenApprover.should.equal(this.assetDeal.address)

        // create a direct deal
        await this.assetDeal.createDirectDeal(tokenId, price, tax, {from:owner})

        let dealId = await this.assetDeal.getDealId.call(
            this.standardAsset.address, tokenId, price
        )
        console.log('DealId: ', dealId.toString())
        let ob = await this.assetDeal.getDeal.call(dealId.toString())

        console.log("Deal info: ", ob.toString())
    })

    it('Buy the car', async () => {
        let currentBuyerBalance = await ethGetBalance(buyer)
        console.log("Buyer account balance-1: ", currentBuyerBalance)
        let dealId = await this.assetDeal.getDealId.call(
            this.standardAsset.address, tokenId, price
        )
        await this.assetDeal.payByEth(dealId,{from:buyer, value:ether(3)})

        let confirmBuyerBalance = await ethGetBalance(buyer)
        console.log("Buyer account balance-2: ", confirmBuyerBalance)

        let realCost = currentBuyerBalance.sub(confirmBuyerBalance)

        console.log("Real cost is: ", realCost.toString())

        let newOwner = await this.assetDeal.getAssetOwner(tokenId)
        newOwner.should.equal(buyer)
    })

})
