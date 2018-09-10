const Web3 = require('web3')
const web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:7545"))

let version = web3.version.api
let nodeVersion = web3.version.node

web3.eth.getBlock(2, function (error, res) {
    if (!error) {
        console.log(JSON.stringify(res))
    } else {
        console.error(error)
    }
})

console.log(version, nodeVersion)
