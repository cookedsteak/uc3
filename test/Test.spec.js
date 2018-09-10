const Test = artifacts.require("./Test.sol");

const BigNumber = web3.BigNumber;

require('chai').should()

contract("MyTest", accounts => {
    it("should set version here!", async () => {
        let version = 'V0.0.1';
        const testInstance = await Test.deployed()

        let txRes = await testInstance.setVersion(version, {from:accounts[1]})
        console.log(txRes)

        const v = await testInstance.getVersion.call()
        console.log(v);

        let aa = await testInstance.a.call()
        console.log(aa)

        let alist = await testInstance.alist.call(1)
        console.log(alist)

        let defaultAccount = accounts[5]
        await testInstance.buySth({from:defaultAccount, value:ether(5)})

        let balance = web3.eth.getBalance(testInstance.address)
        console.log('contract account balance:', balance.toString())
    })


})

function ether (n) {
    return new web3.BigNumber(web3.toWei(n, 'ether'));
}

module.exports = {
    ether,
}
