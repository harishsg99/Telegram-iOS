import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    import MtProtoKitDynamic
#endif

public enum CreateSecretChatError {
    case generic
}

public func createSecretChat(account: Account, peerId: PeerId) -> Signal<PeerId, CreateSecretChatError> {
    return account.postbox.modify { modifier -> Signal<PeerId, CreateSecretChatError> in
        if let peer = modifier.getPeer(peerId), let inputUser = apiInputUser(peer) {
            return validatedEncryptionConfig(postbox: account.postbox, network: account.network)
                |> mapError { _ -> CreateSecretChatError in return .generic }
                |> mapToSignal { config -> Signal<PeerId, CreateSecretChatError> in
                    let aBytes = malloc(256)!
                    let _ = SecRandomCopyBytes(nil, 256, aBytes.assumingMemoryBound(to: UInt8.self))
                    let a = MemoryBuffer(memory: aBytes, capacity: 256, length: 256, freeWhenDone: true)
                    
                    var gValue: Int32 = config.g.byteSwapped
                    let g = Data(bytes: &gValue, count: 4)
                    let p = config.p.makeData()
                    
                    let aData = a.makeData()
                    let ga = MTExp(g, aData, p)!
                    
                    return account.network.request(Api.functions.messages.requestEncryption(userId: inputUser, randomId: Int32(bitPattern: arc4random()), gA: Buffer(data: ga)))
                        |> mapError { _ -> CreateSecretChatError in
                            return .generic
                        }
                        |> mapToSignal { result -> Signal<PeerId, CreateSecretChatError> in
                            return account.postbox.modify { modifier -> PeerId in
                                updateSecretChat(accountPeerId: account.peerId, modifier: modifier, chat: result, requestData: SecretChatRequestData(g: config.g, p: config.p, a: a))
                                
                                return result.peerId
                            } |> mapError { _ -> CreateSecretChatError in return .generic }
                        }
                }
        } else {
            return .fail(.generic)
        }
    } |> mapError { _ -> CreateSecretChatError in return .generic } |> switchToLatest
}
