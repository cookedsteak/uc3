const { BigNumber} = require('bignumber.js')
const { ethGetBalance } = require('./helpers/web3')
const { ether } = require('./helpers/ether')
const AssetRegistry = artifacts.require('./AssetRegistry.sol')
const StandardAsset = artifacts.require('./StandardAsset.sol')

require("chai").use(require('chai-bignumber')(BigNumber)).should()

contract("AssetRegistry", function ([Proxy, Club, Alice, Bob]) {

    const name = "My membership card"
    const symbol = "MMC"
    const supply = new BigNumber(3)
    const classUri = "swarm://cardclass.assets"
    const tokenUri = "swarm://mycard.assets"

    describe('register class', function () {

        beforeEach(async ()=> {
            this.assetRegister = await AssetRegistry.new(
                {from: Proxy}
            )
        })

        it("can register a new asset class", async () => {
            let assetId = await this.assetRegister.registerClass(
                name, symbol, supply, classUri, Club, {from: Proxy}
            )
            let gotId = await this.assetRegister.getId.call(name, symbol, classUri)

            assetId.should.equal(gotId)
        })

        it("should revert if registrant is not the owner", async () => {

        })
    })

    describe('mint asset', function () {
        it("should mint user a new asset", async () => {
            let assetId = await this.assetRegister.getId.call(name, symbol, uri)
            let standardAssetAddress = this.assetRegister.idAssets.call(assetId.toString())

            this.standardAsset = await StandardAsset.at(standardAssetAddress)
            this.standardAsset.mint(Alice, tokenUri, {from: Club})

            this.standardAsset.ownerOf.call().should.equal(Alice)
        })

    })

    describe('burn', function () {

    })


})
