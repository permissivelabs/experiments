import { expect } from "chai";
import hre from "hardhat";

describe('_validatePermission', () => {
    it('should refuse for to', async () => {
        const Permissive = await hre.ethers.getContractFactory("PermissiveAccount");
        const account = await Permissive.deploy('0x0576a174D229E3cFA37253523E645A78A0C91B57');
        const permission = {
            operator: '0x429952c8d27F515011d623dFC9038152af52C5a8',
            to: '0x0576a174D229E3cFA37253523E645A78A0C91B57',
            selector: '0x00000000',
            maxValue: 0,
            maxFee: 0,
            paymaster: '0x429952c8d27F515011d623dFC9038152af52C5a8',
            expires_at_unix: 0,
            expires_at_block: 0
        };
        const operation = {
            sender: '0x429952c8d27F515011d623dFC9038152af52C5a8',
            nonce: 0,
            initCode: [],
            callData: [],
            callGasLimit: 0,
            verificationGasLimit: 0,
            preVerificationGas: 0,
            maxFeePerGas: 0,
            maxPriorityFeePerGas: 0,
            paymasterAndData: [],
            signature: []
        };
        console.log(await account._validatePermission(operation, permission));
    })
})