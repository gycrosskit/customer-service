package io.github.gycrosskit.customerservice

import kotlin.test.Test
import kotlin.test.assertEquals

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
}
