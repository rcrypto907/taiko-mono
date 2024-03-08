// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../TaikoTest.sol";

contract DummyGuardianProver is GuardianProver {
    uint256 public metaId;

    function init() external initializer {
        __Essential_init(address(0));
    }

    function approve(bytes32 hash) public returns (bool) {
        return _approve(metaId++, hash);
    }
}

contract TestGuardianProver is TaikoTest {
    DummyGuardianProver target;

    function getSigners(uint256 numGuardians) internal returns (address[] memory signers) {
        signers = new address[](numGuardians);
        for (uint256 i = 0; i < numGuardians; ++i) {
            signers[i] = randAddress();
            vm.deal(signers[i], 1 ether);
        }
    }

    function setUp() public {
        target = DummyGuardianProver(
            deployProxy({
                name: "guardians",
                impl: address(new DummyGuardianProver()),
                data: abi.encodeCall(DummyGuardianProver.init, ())
            })
        );
    }

    function test_guardians_set_guardians() public {
        vm.expectRevert(GuardianProver.INVALID_GUARDIAN_SET.selector);
        target.setGuardians(getSigners(0), 0);

        vm.expectRevert(GuardianProver.INVALID_MIN_GUARDIANS.selector);
        target.setGuardians(getSigners(5), 0);

        vm.expectRevert(GuardianProver.INVALID_MIN_GUARDIANS.selector);
        target.setGuardians(getSigners(5), 6);
    }

    function test_guardians_set_guardians2() public {
        address[] memory signers = getSigners(5);
        signers[0] = address(0);
        vm.expectRevert(GuardianProver.INVALID_GUARDIAN.selector);
        target.setGuardians(signers, 4);

        signers[0] = signers[1];
        vm.expectRevert(GuardianProver.INVALID_GUARDIAN_SET.selector);
        target.setGuardians(signers, 4);
    }

    function test_guardians_approve() public {
        address[] memory signers = getSigners(6);
        target.setGuardians(signers, 4);

        bytes32 hash = keccak256("paris");
        for (uint256 i; i < 6; ++i) {
            vm.prank(signers[0]);
            assertEq(target.approve(hash), false);
            assertEq(target.isApproved(hash), false);
        }

        hash = keccak256("singapore");
        for (uint256 i; i < 6; ++i) {
            vm.startPrank(signers[i]);
            target.approve(hash);

            assertEq(target.approve(hash), i >= 3);
            assertEq(target.isApproved(hash), i >= 3);
            vm.stopPrank();
        }

        // changing the settings will invalid all approval history
        target.setGuardians(signers, 3);
        assertEq(target.version(), 2);
        assertEq(target.isApproved(hash), false);
    }
}