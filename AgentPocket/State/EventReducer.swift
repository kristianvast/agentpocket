import Foundation

struct EventReducer {
    func reduce(event: OpenCodeEvent, state: AppState) {
        switch event {
        case .serverConnected:
            state.isConnected = true
            state.connectionError = nil

        case .serverHeartbeat:
            break

        case .sessionCreated(let data):
            if let info = data.info, !state.sessionStore.sessions.contains(where: { $0.id == info.id }) {
                state.sessionStore.sessions.insert(info, at: 0)
            }

        case .sessionUpdated(let data):
            if let info = data.info {
                state.sessionStore.updateSession(info)
            }

        case .sessionDeleted(let data):
            state.sessionStore.sessions.removeAll { $0.id == data.sessionID }
            state.sessionStore.messages.removeValue(forKey: data.sessionID)

        case .sessionStatus(let data):
            state.sessionStatuses[data.sessionID] = data.status

        case .messageUpdated(let data):
            state.sessionStore.addOrUpdateMessage(data.info, for: data.sessionID)

        case .messageRemoved(let data):
            state.sessionStore.removeMessage(messageID: data.messageID, sessionID: data.sessionID)

        case .messagePartUpdated(let data):
            state.sessionStore.addOrUpdatePart(data.part, for: data.sessionID)
            state.sessionStore.clearStreamingText(messageID: data.part.messageID, partID: data.part.id)

        case .messagePartDelta(let data):
            state.sessionStore.applyDelta(
                sessionID: data.sessionID,
                messageID: data.messageID,
                partID: data.partID,
                field: data.field,
                delta: data.delta
            )

        case .messagePartRemoved(let data):
            state.sessionStore.removePart(partID: data.partID, messageID: data.messageID, sessionID: data.sessionID)

        case .permissionAsked(let request):
            if !state.pendingPermissions.contains(where: { $0.id == request.id }) {
                state.pendingPermissions.append(request)
            }

        case .permissionReplied(let data):
            state.pendingPermissions.removeAll { $0.id == data.requestID }

        case .questionAsked(let request):
            if !state.pendingQuestions.contains(where: { $0.id == request.id }) {
                state.pendingQuestions.append(request)
            }

        case .questionReplied(let data):
            state.pendingQuestions.removeAll { $0.id == data.requestID }

        case .todoUpdated(let data):
            state.todos[data.sessionID] = data.todos

        case .ptyCreated(let data):
            if !state.ptyList.contains(where: { $0.id == data.info.id }) {
                state.ptyList.append(data.info)
            }

        case .ptyUpdated(let data):
            if let idx = state.ptyList.firstIndex(where: { $0.id == data.info.id }) {
                state.ptyList[idx] = data.info
            }

        case .ptyExited(let data):
            if let idx = state.ptyList.firstIndex(where: { $0.id == data.id }) {
                state.ptyList[idx].status = .exited
            }

        case .ptyDeleted(let data):
            state.ptyList.removeAll { $0.id == data.id }

        case .projectUpdated(let data):
            if let idx = state.projects.firstIndex(where: { $0.id == data.id }), let name = data.name {
                state.projects[idx].name = name
            }

        case .vcsBranchUpdated(let data):
            state.currentBranch = data.branch

        case .lspUpdated:
            break

        case .unknown:
            break
        }
    }
}
