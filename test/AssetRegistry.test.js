const { assertRevert } = require('./helpers/assertRevert')
const { BigNumber} = require('bignumber.js')
const { ethGetBalance } = require('./helpers/web3')
const { ether } = require('./helpers/ether')
const AssetRegistry = artifacts.require('./AssetRegistry.sol')
const StandardAsset = artifacts.require('./StandardAsset.sol')

require("chai").use(require('chai-bignumber')(BigNumber)).should()

contract("AssetRegistry", function ([Proxy, Club, Alice, Bob]) {
    const tokenId = 1
    const name = "My membership card"
    const symbol = "MMC"
    const supply = new BigNumber(3)
    const classUri = "swarm://cardclass.assets"
    const tokenUri = "swarm://mycard.assets"


    describe('register asset class', function () {
        let assetRegister = null
        let assetId = null

        beforeEach(async () => {
            assetRegister = await AssetRegistry.new({from: Proxy})
            assetId = await assetRegister.getId.call(name, symbol, classUri)
        })

        it("can register a new asset class", async () => {
            await assetRegister.registerClass(
                name, symbol, supply, classUri, Club, {from: Proxy}
            )
            let standardAsset = await StandardAsset.at(
                await assetRegister.idAssets.call(assetId.toString())
            )
            // owner id club
            let owner = await standardAsset.owner.call()
            owner.should.equal(Club)
        })

        it("should revert if registrant is not the owner", async () => {
            assertRevert(assetRegister.registerClass(
                name, symbol, supply, classUri, Club, {from: Alice}
            ))
        })
    })

    describe('mint asset', function () {
        let assetRegister = null
        let standardAsset = null
        let assetId = null

        beforeEach(async ()=> {
            assetRegister = await AssetRegistry.new({from: Proxy})
            assetId = await assetRegister.getId.call(name, symbol, classUri)
            await assetRegister.registerClass(
                name, symbol, supply, classUri, Club, {from: Proxy}
            )
            let standardAssetAddress = await assetRegister.idAssets.call(assetId.toString())
            standardAsset = await StandardAsset.at(standardAssetAddress)
        })

        it("should mint user a new asset", async () => {
            standardAsset.mint(Alice, tokenUri, {from: Club})
            // standardAsset.ownerOf.call().should.equal(Alice)
        })

    })

    describe('burn', function () {

    })


})
