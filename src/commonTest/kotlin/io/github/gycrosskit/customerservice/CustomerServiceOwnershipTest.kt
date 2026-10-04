package io.github.gycrosskit.customerservice

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse

class CustomerServiceOwnershipTest {
    @Test
    fun preservesSharedImAndOnlyResetsItsOwnIdentity() {
        val target = CustomerServiceIdentity(100, "member")
        assertEquals(CustomerServicePreparationAction.INITIALIZE, customerServicePreparationAction(null, "member", target))
        assertEquals(CustomerServicePreparationAction.REUSE, customerServicePreparationAction(target, "member", target))
        assertEquals(CustomerServicePreparationAction.REJECT, customerServicePreparationAction(null, "live-owner", target))
        assertEquals(CustomerServicePreparationAction.REJECT, customerServicePreparationAction(target, "live-owner", target))
        assertEquals(CustomerServicePreparationAction.RESET, customerServicePreparationAction(target, "member", target.copy(appId = 101)))
        assertEquals(CustomerServicePreparationAction.RESET, customerServicePreparationAction(target, "member", target.copy(userId = "next")))
        assertEquals(CustomerServicePreparationAction.INITIALIZE, customerServicePreparationAction(target, null, target))
    }

    @Test
    fun rejectsForeignIdentityAcquiredWhileResetWasPending() {
        val owned = CustomerServiceIdentity(100, "member")
        val target = owned.copy(userId = "next")
        assertEquals(
            CustomerServicePreparationAction.RESET,
            customerServicePreparationAction(owned, "member", target),
        )
        assertEquals(
            CustomerServicePreparationAction.REJECT,
            customerServicePreparationAction(null, "foreign-during-reset", target),
        )
    }
    @Test fun sameUserBorrowDoesNotAuthorizeResetOrDifferentSdkAppId() {
        val identity = CustomerServiceIdentity(100, "member")
        assertFalse(customerServiceOwnsActualIdentity(identity, true, "member", 101))
        assertEquals(CustomerServicePreparationAction.REJECT, customerServicePreparationAction(identity, "member", identity, ownsRuntime = true, configuredSdkAppId = 101))
        assertEquals(CustomerServicePreparationAction.REUSE, customerServicePreparationAction(identity, "member", identity, ownsRuntime = false))
        assertEquals(CustomerServicePreparationAction.REJECT, customerServicePreparationAction(identity, "member", identity.copy(userId = "next"), ownsRuntime = false))
        assertEquals(CustomerServicePreparationAction.REJECT, customerServicePreparationAction(null, "member", identity, ownsRuntime = false, configuredSdkAppId = 101))
        assertEquals(CustomerServicePreparationAction.INITIALIZE, customerServicePreparationAction(null, "member", identity, ownsRuntime = false, sdkReady = false))
        assertEquals(CustomerServicePreparationAction.REJECT, customerServicePreparationAction(identity, "foreign-after-late-login", identity, ownsRuntime = true))
        assertEquals(CustomerServicePreparationAction.REJECT, customerServicePreparationAction(identity.copy(userId = "previous"), "member", identity, ownsRuntime = true, configuredSdkAppId = 101))
        assertEquals(CustomerServicePreparationAction.REJECT, customerServicePreparationAction(identity, "member", identity, ownsRuntime = false, configuredSdkAppId = 101))
    }
}
