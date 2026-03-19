// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/Test.sol';
import {IL1OpUSDCFactory} from 'interfaces/IL1OpUSDCFactory.sol';
import {IUSDC} from 'interfaces/external/IUSDC.sol';
import {USDCInitTxs} from 'src/contracts/utils/USDCInitTxs.sol';

contract DeployProtocol is Script {
  /// @notice The address aliasing offset used by the OP Stack for L1 contract addresses on L2.
  /// See https://specs.optimism.io/protocol/deposits.html#address-aliasing
  uint160 internal constant _ADDRESS_ALIAS_OFFSET = 0x1111000000000000000000000000000000001111;

  uint32 public constant MIN_GAS_LIMIT_DEPLOY = 9_000_000;
  IL1OpUSDCFactory public immutable L1_FACTORY = IL1OpUSDCFactory(vm.envAddress('L1_FACTORY'));
  address public immutable BRIDGED_USDC_IMPLEMENTATION = vm.envAddress('BRIDGED_USDC_IMPLEMENTATION');
  address public immutable L1_MESSENGER = vm.envAddress('L1_MESSENGER');
  string public chainName = vm.envString('CHAIN_NAME');
  address public l1Owner = vm.envAddress('L1_OWNER');

  function run() public {
    address _l2Owner = _resolveL2Owner(l1Owner);

    vm.startBroadcast();

    // NOTE: We have these hardcoded to default values, if used in production you will need to change them
    bytes[] memory _usdcInitTxs = new bytes[](3);
    string memory _name = string.concat('Bridged USDC', ' ', '(', chainName, ')');

    _usdcInitTxs[0] = abi.encodeCall(IUSDC.initializeV2, (_name));
    _usdcInitTxs[1] = USDCInitTxs.INITIALIZEV2_1;
    _usdcInitTxs[2] = USDCInitTxs.INITIALIZEV2_2;

    // Sanity check to ensure the caller of this script changed this value to the proper naming
    assert(keccak256(_usdcInitTxs[0]) != keccak256(USDCInitTxs.INITIALIZEV2));

    IL1OpUSDCFactory.L2Deployments memory _l2Deployments = IL1OpUSDCFactory.L2Deployments({
      l2AdapterOwner: _l2Owner,
      usdcImplAddr: BRIDGED_USDC_IMPLEMENTATION,
      usdcInitTxs: _usdcInitTxs,
      minGasLimitDeploy: MIN_GAS_LIMIT_DEPLOY
    });

    // Deploy the L2 contracts
    (address _l1Adapter, address _l2Deploy, address _l2Adapter) =
      L1_FACTORY.deploy(L1_MESSENGER, l1Owner, chainName, _l2Deployments);
    vm.stopBroadcast();

    /// NOTE: Hardcode the newly deployed `_l1Adapter` address on `L1_ADAPTER` inside the `.env` or `env.example` file
    console.log('L1 Adapter:', _l1Adapter);
    console.log('L2 Deploy:', _l2Deploy);
    console.log('L2 Adapter:', _l2Adapter);
    console.log('L2 Adapter Owner:', _l2Owner);
  }

  /**
   * @notice Resolves the L2 adapter owner address from the L1 owner.
   * @dev If L1_OWNER is a contract, the L2 owner is automatically derived via OP Stack address aliasing
   * (L1_OWNER + 0x1111000000000000000000000000000000001111).
   * If L1_OWNER is an EOA, L2_OWNER must be explicitly provided via the environment variable.
   * @param _l1Owner The L1 adapter owner address
   * @return _l2Owner The resolved L2 adapter owner address
   */
  function _resolveL2Owner(address _l1Owner) internal returns (address _l2Owner) {
    if (_l1Owner.code.length > 0) {
      // L1 owner is a contract: auto-derive aliased address for L2
      unchecked {
        _l2Owner = address(uint160(_l1Owner) + _ADDRESS_ALIAS_OFFSET);
      }
      console.log('L1_OWNER is a contract, auto-aliased L2 owner:', _l2Owner);
    } else {
      // L1 owner is an EOA: L2_OWNER must be explicitly set
      _l2Owner = vm.envAddress('L2_OWNER');
      console.log('L1_OWNER is an EOA, using explicit L2 owner:', _l2Owner);
    }
  }
}
