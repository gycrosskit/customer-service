import Foundation

struct CustomerServiceIdentity: Equatable {
    let appId: Int32
    let userId: String
}

enum CustomerServicePreparationAction { case reuse, initialize, reset, reject }

func customerServicePreparationAction(owned: CustomerServiceIdentity?, actualUser: String?, target: CustomerServiceIdentity) -> CustomerServicePreparationAction {
    if owned == target && actualUser == target.userId { return .reuse }
    if let actualUser, actualUser != target.userId && actualUser != owned?.userId { return .reject }
    if let owned, actualUser == owned.userId && owned != target { return .reset }
    return .initialize
}
