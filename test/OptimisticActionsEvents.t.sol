// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "../lib/forge-std/src/Test.sol";

import {OptimisticActions, IOptimisticActions, IDAO, IDAOExtensionWithAdmin} from "../src/OptimisticActions.sol";
import {
    TrustlessManagementMock,
    NO_PERMISSION_CHECKER
} from "../lib/trustless-management/test/mocks/TrustlessManagementMock.sol";
import {DAOMock} from "../lib/trustless-management/test/mocks/DAOMock.sol";
import {ActionHelper} from "../lib/trustless-management/test/helpers/ActionHelper.sol";

contract OptimisticActionsTest is Test {
    DAOMock public dao;
    TrustlessManagementMock public trustlessManagement;
    OptimisticActions public optimisticActions;
    uint256 constant role = 0;

    function setUp() external {
        dao = new DAOMock();
        trustlessManagement = new TrustlessManagementMock();
        optimisticActions = new OptimisticActions();

        vm.startPrank(address(dao));
        trustlessManagement.changeFullAccess(dao, role, NO_PERMISSION_CHECKER);
    }

    /// forge-config: default.fuzz.runs = 10
    function test_createAction(IDAO.Action[] calldata _actions, uint256 _failureMap, string calldata _metadata)
        external
    {
        vm.expectEmit(address(optimisticActions));
        // This has assumption first task will have id 0 and the executionDelay is 0
        emit IOptimisticActions.ActionCreated(
            0, dao, trustlessManagement, role, _actions, _failureMap, _metadata, uint64(block.timestamp)
        );
        optimisticActions.createAction(trustlessManagement, role, _actions, _failureMap, _metadata);
    }

    /// forge-config: default.fuzz.runs = 10
    function test_rejectAction(string calldata _metadata) external {
        IDAO.Action[] memory actions = new IDAO.Action[](0);
        (uint32 id,) = optimisticActions.createAction(trustlessManagement, role, actions, 0, _metadata);

        vm.expectEmit(address(optimisticActions));
        emit IOptimisticActions.ActionRejected(id, dao, _metadata);
        optimisticActions.rejectAction(id, _metadata);
    }

    /// forge-config: default.fuzz.runs = 10
    function test_executeAction(
        uint256[] calldata _callableIndexes,
        bytes[] calldata _calldatas,
        bytes[] calldata _returnValues,
        uint256 _failureMap,
        address _executor
    ) external {
        vm.assume(_calldatas.length >= _callableIndexes.length);
        vm.assume(_returnValues.length >= _callableIndexes.length);
        ActionHelper actionHelper = new ActionHelper(_callableIndexes, _calldatas, _returnValues);
        vm.assume(actionHelper.isValid());

        IDAO.Action[] memory actions = actionHelper.getActions();
        (uint32 id, uint64 executableFrom) =
            optimisticActions.createAction(trustlessManagement, role, actions, _failureMap, "");
        vm.warp(executableFrom);
        bytes[] memory shortendReturnValues = new bytes[](actions.length);
        for (uint256 i; i < shortendReturnValues.length; i++) {
            shortendReturnValues[i] = _returnValues[i];
        }

        vm.stopPrank();
        vm.prank(_executor);
        vm.expectEmit(address(optimisticActions));
        emit IOptimisticActions.ActionExecuted(id, dao, _executor, shortendReturnValues, 0);
        optimisticActions.executeAction(dao, id);
    }

    /// forge-config: default.fuzz.runs = 10
    function test_setExecuteDelay(uint64 _executeDelay) external {
        vm.expectEmit(address(optimisticActions));
        emit IOptimisticActions.ExecuteDelaySet(dao, _executeDelay);
        optimisticActions.setExecuteDelay(dao, _executeDelay);
    }

    /// forge-config: default.fuzz.runs = 10
    function test_setAdmin(address _admin) external {
        vm.expectEmit(address(optimisticActions));
        emit IDAOExtensionWithAdmin.AdminSet(dao, _admin);
        optimisticActions.setAdmin(dao, _admin);
    }
}
