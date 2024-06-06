// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {L1OpUSDCFactory} from 'contracts/L1OpUSDCFactory.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/Test.sol';
import {IL1OpUSDCFactory} from 'interfaces/IL1OpUSDCFactory.sol';
import {IUpgradeManager} from 'interfaces/IUpgradeManager.sol';

contract L1FactoryDeployAndSetup is Script {
  address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address public constant L1_MESSENGER_OP = 0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1;
  address public constant L1_MESSENGER_BASE = 0x866E82a600A1414e583f7F13623F1aC5d58b0Afa;
  address public deployer = vm.rememberKey(vm.envUint('MAINNET_DEPLOYER_PK'));

  function run() public {
    vm.startBroadcast(deployer);

    console.log('Deploying L1OpUSDCFactory ...');
    bytes32 _salt = keccak256(abi.encode(block.number, block.timestamp, blockhash(block.number - 1)));
    IL1OpUSDCFactory _l1Factory = new L1OpUSDCFactory(USDC, _salt, deployer);
    console.log('L1OpUSDCFactory deployed at:', address(_l1Factory));

    console.log('L1OpUSDCBridgeAdapter deployed at:', address(_l1Factory.L1_ADAPTER_PROXY()));
    IUpgradeManager _upgradeManager = IUpgradeManager(_l1Factory.UPGRADE_MANAGER());
    console.log('L1 UpgradeManager deployed at:', address(_upgradeManager));
    console.log('-----');
    console.log('L2Factory deployment address:', _l1Factory.L2_FACTORY());
    console.log('L2OpUSDCBridgeAdapter proxy deployment address:', _l1Factory.L2_ADAPTER_PROXY());
    console.log('L2 USDC proxy deployed deployment address:', _l1Factory.L2_USDC_PROXY());
    console.log('-----');

    // TODO: Move to another file?
    console.log('Setting l2 usdc implementation address ...');
    bytes[] memory _initTxs = new bytes[](0);
    _l1Factory.UPGRADE_MANAGER().setBridgedUSDCImplementation(USDC, _initTxs);
    console.log('L2 USDC implementation address set to:', USDC);

    console.log('Setting l2 adapter implementation address ...');
    _l1Factory.UPGRADE_MANAGER().setL2AdapterImplementation(address(_l1Factory.L1_ADAPTER_PROXY()), _initTxs);
    console.log('L2 adapter implementation address set to:', address(_l1Factory.L1_ADAPTER_PROXY()));

    console.log('Set executor for L1 Op Messenger...');
    _upgradeManager.prepareDeploymentForMessenger(L1_MESSENGER_OP, deployer);
    console.log('Executor set for L1 Op Messenger:', L1_MESSENGER_OP);

    console.log('Set executor for L1 Base Messenger...');
    _upgradeManager.prepareDeploymentForMessenger(L1_MESSENGER_BASE, deployer);
    console.log('Executor set for L1 Base Messenger:', L1_MESSENGER_BASE);

    vm.stopBroadcast();
  }
}
