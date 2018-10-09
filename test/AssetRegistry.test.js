const { assertRevert } = require('./helpers/assertRevert')
const { BigNumber} = require('bignumber.js')
const { ethGetBalance } = require('./helpers/web3')
const { ether } = require('./helpers/ether')
const AssetRegistry = artifacts.require('./AssetRegistry.sol')
const StandardAsset = artifacts.require('./StandardAsset.sol')

require("chai").use(require('chai-bignumber')(BigNumber)).should()

contract("AssetRegistry", function ([Proxy, Club, Alice, Bob]) {
    const initTokenId = 1
    const name = "My membership card"
    const symbol = "MMC"
    const supply = new BigNumber(1)
    const classUri = "swarm://cardclass.assets"
    const tokenUri = "swarm://mycard.assets"

    describe('register asset class', function () {
        let assetRegistry = null
        let assetId = null

        beforeEach(async () => {
            assetRegistry = await AssetRegistry.new({from: Proxy})
            assetId = await assetRegistry.getId.call(name, symbol, classUri)
        })

        it("can register a new asset class", async () => {
            await assetRegistry.registerClass(
                name, symbol, supply, classUri, Club, {from: Proxy}
            )
            let standardAsset = await StandardAsset.at(
                await assetRegistry.idAssets.call(assetId.toString())
            )
            // owner id club
            let owner = await standardAsset.owner.call()
            owner.should.equal(Club)
        })

        it("should revert if registrant is not the owner", async () => {
            assertRevert(assetRegistry.registerClass(
                name, symbol, supply, classUri, Club, {from: Bob}
            ))
        })
    })

    describe('mint asset', function () {
        let assetRegistry = null
        let standardAsset = null
        let assetId = null

        beforeEach(async ()=> {
            assetRegistry = await AssetRegistry.new({from: Proxy})
            assetId = await assetRegistry.getId.call(name, symbol, classUri)
            await assetRegistry.registerClass(
                name, symbol, supply, classUri, Club, {from: Proxy}
            )
            let standardAssetAddress = await assetRegistry.idAssets.call(assetId.toString())
            standardAsset = await StandardAsset.at(standardAssetAddress)
        })

        it("should mint user a new asset", async () => {
            await standardAsset.mint(Alice, tokenUri, {from: Club})
            // alice 's token id  if shows 0 when mint, plz
            let ownedTokenCount = await standardAsset.balanceOf.call(Alice)
            ownedTokenCount.toNumber().should.equal(1)

            let tokenId = await standardAsset.tokenOfOwnerByIndex.call(Alice, ownedTokenCount.toNumber()-1)
            tokenId.toNumber().should.equal(initTokenId)
            let tokenOwner = await standardAsset.ownerOf.call(tokenId.toNumber())
            tokenOwner.toString().should.equal(Alice)
        })

        it("should revert if mint out of supply limit", async ()=> {
            await standardAsset.mint(Alice, tokenUri, {from: Club})
            assertRevert(standardAsset.mint(Bob, tokenUri, {from: Club}))

        })

    })

    describe('burn asset', function () {
        let assetRegistry = null
        let standardAsset = null
        let assetId = null

        beforeEach(async ()=> {
            assetRegistry = await AssetRegistry.new({from: Proxy})
            assetId = await assetRegistry.getId.call(name, symbol, classUri)
            await assetRegistry.registerClass(
                name, symbol, supply, classUri, Club, {from: Proxy}
            )
            let standardAssetAddress = await assetRegistry.idAssets.call(assetId.toString())
            standardAsset = await StandardAsset.at(standardAssetAddress)
        })

        it("should revert if token does not exist", async () => {
            assertRevert(standardAsset.burn(9))
        })

    })

})
