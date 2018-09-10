const { ether } = require('./ether.js')
const AssetRegistry = artifacts.require("./AssetRegistry.sol")
const StandardAsset = artifacts.require("./StandardAsset.sol")
const AssetDeal = artifacts.require("./AssetDeal.sol")

require("chai")
    .use(require('chai-bignumber')(web3.BigNumber))
    .should()

contract("Personal asset deals", async (accounts) => {
    // Assets infos
    const name = "My car assets"
    const symbol = "CAR"
    const supply = new web3.BigNumber(3)
    const uri = "swarm://mycar.assets"
    const creator = accounts[0]
    const owner = accounts[1]

    // Deal infos
    const price = ether(10)
    const tax = ether(0)


    it('Register a car asset type', async () => {
        this.assetRegister = await AssetRegistry.new({from:creator})
        console.log("contract address: ",this.assetRegister.address)

        await this.assetRegister.registerClass(
            name, symbol, supply, uri, owner,
            {from:creator}
        )
    })

    it('Mint my car asset', async () => {
        let assetId = await this.assetRegister.getId.call(name, symbol, uri)
        let standardAssetAddress = await this.assetRegister.idAssets.call(assetId.toString())
        console.log("my car asset contract address: ", standardAssetAddress)

        // mint a car
        console.log()
        this.standardAsset = await StandardAsset.at(standardAssetAddress)
        let assetType = await this.standardAsset.getAssetType.call()
        console.log("AssetType address: ", assetType)
        // tokenId start from 1
        await this.standardAsset.mint(owner, uri, {from:owner})
        let tokenOwner = await this.standardAsset.ownerOf.call(1)
        console.log("The owner of token 1 is:", tokenOwner)
        tokenOwner.should.equal(owner)
    })

    it('Create a car deal', async () => {
        console.log('Standard Asset address: ', this.standardAsset.address)
        this.assetDeal = await AssetDeal.new(this.standardAsset.address, {from:creator})
        console.log('AssetDeal address: ', this.assetDeal.address)



        let res = await this.assetDeal.createDirectDeal(1, price, tax, {from:owner})
        console.log(res) // _escrow方法有问题
        let dealId = await this.assetDeal.getDealId.call(
            this.standardAsset.address, 1, price
        )
        console.log('DealId: ', dealId.toString())
        // let ob = await this.assetDeal.getDeal.call(dealId.toString())
        //
        // console.log('Deal info: ', ob.toString())
    })



})
